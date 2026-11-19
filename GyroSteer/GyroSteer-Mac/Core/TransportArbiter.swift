//
//  TransportArbiter.swift
//  GyroSteer - macOS Receiver
//
//  Prioritizes USB > Wi-Fi > Bluetooth, deduplicates out-of-order frames,
//  computes jitter/Hz telemetry, and executes seamless hot-plug handover.
//

import Foundation
import Combine

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public final class TransportArbiter: ObservableObject, ReceiverTransportDelegate, @unchecked Sendable {
    // MARK: - Published Telemetry

    @Published public private(set) var activeTransport: TransportType = .wifi
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var latestPacket: SteeringPacket = SteeringPacket()
    @Published public private(set) var liveHz: Double = 0.0
    @Published public private(set) var jitterMs: Double = 0.0
    @Published public private(set) var estimatedLatencyMs: Double = 0.0
    public private(set) var totalPacketsReceived: UInt64 = 0
    public private(set) var droppedPacketsCount: UInt64 = 0

    // MARK: - Connection Mode Selection (Cable vs Wi-Fi vs BT vs Auto)
    @Published public var connectionPreference: ConnectionPreference = .auto {
        didSet {
            UserDefaults.standard.set(connectionPreference.rawValue, forKey: "gyrosteer.macConnectionPreference")
            EventLogger.shared.log("TRANSPORT: Preferred connection mode changed to \(connectionPreference.rawValue)")
        }
    }

    // MARK: - Subcomponents

    public let nwReceiver: NWReceiver
    public let bleReceiver: BLEReceiver
    public let telemetryHistory: TelemetryHistory

    public var onPacketAccepted: (@Sendable (SteeringPacket, TransportType) -> Void)?

    // MARK: - Internal State

    private let lock = NSLock()
    private var lastSequenceID: UInt16?
    private var lastPacketUptime: TimeInterval = 0.0
    private var lastInterval: TimeInterval = ProtocolConstants.targetIntervalSeconds
    private var rollingJitterSum: Double = 0.0
    private var jitterSampleCount: Int = 0

    private var lastUSBTimestamp: TimeInterval = 0.0
    private var lastWiFiTimestamp: TimeInterval = 0.0
    private var lastBLETimestamp: TimeInterval = 0.0

    private var secondCounter: Int = 0
    private var lastSecondUptime: TimeInterval = 0.0
    private var lastUIUpdateUptime: TimeInterval = 0.0

    private var watchdogTimer: DispatchSourceTimer?

    public init(
        nwReceiver: NWReceiver = NWReceiver(),
        bleReceiver: BLEReceiver = BLEReceiver(),
        telemetryHistory: TelemetryHistory = TelemetryHistory()
    ) {
        self.nwReceiver = nwReceiver
        self.bleReceiver = bleReceiver
        self.telemetryHistory = telemetryHistory

        self.nwReceiver.delegate = self
        self.bleReceiver.delegate = self

        if let savedPref = UserDefaults.standard.string(forKey: "gyrosteer.macConnectionPreference"),
           let pref = ConnectionPreference(rawValue: savedPref) {
            self.connectionPreference = pref
        }

        startWatchdog()
    }

    deinit {
        watchdogTimer?.cancel()
        watchdogTimer = nil
        nwReceiver.stop()
        bleReceiver.stop()
    }

    public func start() {
        nwReceiver.start()
        bleReceiver.start()
    }

    public func stop() {
        nwReceiver.stop()
        bleReceiver.stop()
        if Thread.isMainThread {
            self.isConnected = false
            self.liveHz = 0.0
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.liveHz = 0.0
            }
        }
    }

    // MARK: - ReceiverTransportDelegate

    public func transport(
        _ transport: any ReceiverTransport,
        didReceive packet: SteeringPacket,
        on transportType: TransportType,
        sourceDescription: String
    ) {
        // Enforce user's connection selection: If user picked Cable, Wi-Fi or BT specifically, ignore others
        if !connectionPreference.matches(transportType: transportType) {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime

        lock.lock()

        // 1. Record heartbeat for the specific transport
        switch transportType {
        case .usb:
            lastUSBTimestamp = now
        case .wifi:
            lastWiFiTimestamp = now
        case .ble:
            lastBLETimestamp = now
        }

        // 2. Determine highest priority active transport
        let effectiveActive = resolveActiveTransport(at: now)

        // 3. Drop packets from lower-priority transports if higher-priority is actively streaming
        if transportType.priority < effectiveActive.priority {
            droppedPacketsCount &+= 1
            lock.unlock()
            return
        }

        // 4. Sequence number deduplication & out-of-order rejection
        if let lastSeq = lastSequenceID {
            if !SteeringPacket.isSequenceNewer(packet.sequenceID, than: lastSeq) {
                // Duplicate or stale packet arrived out of order over UDP/BLE
                droppedPacketsCount &+= 1
                lock.unlock()
                return
            }
        }
        lastSequenceID = packet.sequenceID

        // 5. Jitter and Latency Metrics
        if totalPacketsReceived == 0 {
            print("[TransportArbiter] Telemetry stream active on \(effectiveActive.displayName)! (Initial Steering: \(String(format: "%+.2f", packet.steeringAngle)), Seq: \(packet.sequenceID))")
        }

        if lastPacketUptime > 0 {
            let delta = now - lastPacketUptime
            let jitter = abs(delta - ProtocolConstants.targetIntervalSeconds) * 1000.0
            rollingJitterSum += jitter
            jitterSampleCount += 1
        }
        lastPacketUptime = now
        totalPacketsReceived &+= 1
        secondCounter += 1

        let estLatency: Double
        switch effectiveActive {
        case .usb: estLatency = 1.2
        case .wifi: estLatency = 5.2
        case .ble: estLatency = 16.5
        }

        lock.unlock()

        // 6. Append to telemetry history for oscilloscope
        telemetryHistory.append(
            angle: packet.steeringAngle,
            throttle: packet.normalizedThrottle,
            brake: packet.normalizedBrake
        )

        // 7. Notify Output Injection Pipeline (at full 100Hz with zero latency)
        onPacketAccepted?(packet, effectiveActive)

        // 8. Update UI on Main Queue (immediate on state change, throttled to 60fps for continuous gyro)
        let shouldForceUpdate = !isConnected || activeTransport != effectiveActive
        if shouldForceUpdate || (now - lastUIUpdateUptime >= 0.016) {
            lastUIUpdateUptime = now
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.latestPacket = packet
                self.activeTransport = effectiveActive
                self.isConnected = true
                self.estimatedLatencyMs = estLatency
            }
        }
    }

    // MARK: - Transport Priority Arbiter Logic

    private func resolveActiveTransport(at now: TimeInterval) -> TransportType {
        // When user explicitly selects a connection mode, honor it directly
        switch connectionPreference {
        case .usb:
            return .usb
        case .wifi:
            return .wifi
        case .ble:
            return .ble
        case .auto:
            break
        }

        let timeout = ProtocolConstants.transportSilenceTimeoutSeconds
        // Priority 1: USB (< 150ms since last packet)
        if lastUSBTimestamp > 0 && (now - lastUSBTimestamp) < timeout {
            return .usb
        }
        // Priority 2: Wi-Fi (< 150ms since last packet)
        if lastWiFiTimestamp > 0 && (now - lastWiFiTimestamp) < timeout {
            return .wifi
        }
        // Priority 3: BLE (< 150ms since last packet)
        if lastBLETimestamp > 0 && (now - lastBLETimestamp) < timeout {
            return .ble
        }
        return .ble
    }

    // MARK: - Watchdog & Periodic Frequency Calculation

    private func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            self?.tickWatchdog()
        }
        self.watchdogTimer = timer
        timer.resume()
    }

    private func tickWatchdog() {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        let count = secondCounter
        secondCounter = 0

        let avgJitter = jitterSampleCount > 0 ? (rollingJitterSum / Double(jitterSampleCount)) : 0.0
        rollingJitterSum = 0.0
        jitterSampleCount = 0

        let timeSinceLast = now - lastPacketUptime
        let stillAlive = timeSinceLast < ProtocolConstants.transportSilenceTimeoutSeconds
        let active = resolveActiveTransport(at: now)
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.liveHz = Double(count)
            self.jitterMs = avgJitter
            if !stillAlive {
                self.isConnected = false
                self.liveHz = 0.0
            } else {
                self.activeTransport = active
            }
        }
    }
}
