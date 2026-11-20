//
//  TransmissionCoordinator.swift
//  GyroSteer - iOS Transmitter
//
//  Orchestrates sensor sampling, pedal controls, button states,
//  and dispatches 12-byte binary packets at 100Hz to active transports.
//

import Foundation
import Combine
import SwiftUI

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

@MainActor
public final class TransmissionCoordinator: ObservableObject {
    // MARK: - Subcomponents

    public var motionManager: MotionManager
    public var nwTransmitter: NWTransmitter
    public var bleTransmitter: BLETransmitter

    // MARK: - Input State

    @Published public var throttle: Float = 0.0
    @Published public var brake: Float = 0.0
    @Published public var activeButtons: SteeringButtons = []

    // MARK: - Game HUD Profile
    @Published public var activeHUDProfile: GameHUDProfile = .ets2 {
        didSet {
            UserDefaults.standard.set(activeHUDProfile.rawValue, forKey: "gyrosteer.hudProfile")
        }
    }

    // MARK: - Button Display Mode (Icon Only vs Icon + Text)
    @Published public var buttonDisplayMode: ButtonDisplayMode = .iconOnly {
        didSet {
            UserDefaults.standard.set(buttonDisplayMode.rawValue, forKey: "gyrosteer.buttonDisplayMode")
        }
    }

    // MARK: - Connection Selection (Cable, Wi-Fi, Bluetooth, Auto)
    @Published public var preferredConnection: ConnectionPreference = .auto {
        didSet {
            UserDefaults.standard.set(preferredConnection.rawValue, forKey: "gyrosteer.preferredConnection")
            refreshConnectionStatus()
        }
    }

    // MARK: - Transmission Mode (Automatic vs Manual / Sequential)
    @Published public var transmissionMode: TransmissionMode = .automatic {
        didSet {
            UserDefaults.standard.set(transmissionMode.rawValue, forKey: "gyrosteer.transmissionMode")
        }
    }

    // MARK: - Free Camera & Mouse Look State
    public var isFreeCameraLookActive: Bool = false
    public var cameraDeltaX: Float = 0.0
    public var cameraDeltaY: Float = 0.0

    public func sendCameraLook(dx: Float, dy: Float) {
        isFreeCameraLookActive = true
        cameraDeltaX += dx
        cameraDeltaY += dy
    }

    public func endCameraLook() {
        isFreeCameraLookActive = false
        cameraDeltaX = 0.0
        cameraDeltaY = 0.0
    }

    // MARK: - Transmission Telemetry

    @Published public private(set) var sequenceID: UInt16 = 0
    @Published public private(set) var packetsSentCount: UInt64 = 0
    @Published public private(set) var currentHz: Double = 0.0
    @Published public private(set) var activeTransport: TransportType = .wifi
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var latencyMs: Double = 0.0

    private var timerSubscription: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private var secondCounter: Int = 0
    private var lastSecondUptime: TimeInterval = 0.0

    @MainActor
    public init() {
        self.motionManager = MotionManager()
        self.nwTransmitter = NWTransmitter()
        self.bleTransmitter = BLETransmitter()

        if let savedProfile = UserDefaults.standard.string(forKey: "gyrosteer.hudProfile"),
           let profile = GameHUDProfile(rawValue: savedProfile) {
            self.activeHUDProfile = profile
            self.motionManager.maxLockAngleDegrees = profile.defaultLockAngle
            if profile == .asphalt {
                self.activeButtons.insert(.arcadeProfile)
            }
        }

        if let savedDisplay = UserDefaults.standard.string(forKey: "gyrosteer.buttonDisplayMode"),
           let displayMode = ButtonDisplayMode(rawValue: savedDisplay) {
            self.buttonDisplayMode = displayMode
        } else {
            self.buttonDisplayMode = .iconOnly
        }

        if let savedConnection = UserDefaults.standard.string(forKey: "gyrosteer.preferredConnection"),
           let pref = ConnectionPreference(rawValue: savedConnection) {
            self.preferredConnection = pref
        }

        if let savedMode = UserDefaults.standard.string(forKey: "gyrosteer.transmissionMode"),
           let mode = TransmissionMode(rawValue: savedMode) {
            self.transmissionMode = mode
        }

        setupTransportObservers()
    }

    @MainActor
    public init(
        motionManager: MotionManager,
        nwTransmitter: NWTransmitter,
        bleTransmitter: BLETransmitter
    ) {
        self.motionManager = motionManager
        self.nwTransmitter = nwTransmitter
        self.bleTransmitter = bleTransmitter

        if let savedProfile = UserDefaults.standard.string(forKey: "gyrosteer.hudProfile"),
           let profile = GameHUDProfile(rawValue: savedProfile) {
            self.activeHUDProfile = profile
            self.motionManager.maxLockAngleDegrees = profile.defaultLockAngle
            if profile == .asphalt {
                self.activeButtons.insert(.arcadeProfile)
            }
        }

        if let savedDisplay = UserDefaults.standard.string(forKey: "gyrosteer.buttonDisplayMode"),
           let displayMode = ButtonDisplayMode(rawValue: savedDisplay) {
            self.buttonDisplayMode = displayMode
        } else {
            self.buttonDisplayMode = .iconOnly
        }

        if let savedConnection = UserDefaults.standard.string(forKey: "gyrosteer.preferredConnection"),
           let pref = ConnectionPreference(rawValue: savedConnection) {
            self.preferredConnection = pref
        }

        if let savedMode = UserDefaults.standard.string(forKey: "gyrosteer.transmissionMode"),
           let mode = TransmissionMode(rawValue: savedMode) {
            self.transmissionMode = mode
        }

        setupTransportObservers()
    }

    public func toggleTransmissionMode() {
        transmissionMode = (transmissionMode == .automatic) ? .manual : .automatic
        #if os(iOS)
        HapticManager.shared.gearShift()
        #endif
        pressButton(.transmissionMode)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.releaseButton(.transmissionMode)
        }
    }

    public func setTransmissionMode(_ mode: TransmissionMode) {
        guard mode != transmissionMode else { return }
        transmissionMode = mode
        #if os(iOS)
        HapticManager.shared.gearShift()
        #endif
        pressButton(.transmissionMode)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.releaseButton(.transmissionMode)
        }
    }

    public func toggleButtonDisplayMode() {
        buttonDisplayMode = (buttonDisplayMode == .iconOnly) ? .iconAndText : .iconOnly
        #if os(iOS)
        HapticManager.shared.buttonTap()
        #endif
    }

    public func setConnectionPreference(_ preference: ConnectionPreference) {
        preferredConnection = preference
        #if os(iOS)
        HapticManager.shared.buttonTap()
        #endif
        refreshConnectionStatus()
    }

    public func refreshConnectionStatus() {
        let nwConn = nwTransmitter.isConnected
        let bleConn = bleTransmitter.isConnected
        let nwType = nwTransmitter.transportType

        switch preferredConnection {
        case .auto:
            self.isConnected = nwConn || bleConn
            if nwConn {
                self.activeTransport = nwType
                self.latencyMs = nwTransmitter.currentLatencyMs
            } else if bleConn {
                self.activeTransport = .ble
                self.latencyMs = bleTransmitter.currentLatencyMs
            }
        case .usb:
            self.isConnected = nwConn && nwType == .usb
            self.activeTransport = .usb
            self.latencyMs = nwTransmitter.currentLatencyMs
        case .wifi:
            self.isConnected = nwConn && nwType == .wifi
            self.activeTransport = .wifi
            self.latencyMs = nwTransmitter.currentLatencyMs
        case .ble:
            self.isConnected = bleConn
            self.activeTransport = .ble
            self.latencyMs = bleTransmitter.currentLatencyMs
        }
    }

    private func setupTransportObservers() {
        Publishers.CombineLatest(nwTransmitter.$isConnected, bleTransmitter.$isConnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.refreshConnectionStatus()
            }
            .store(in: &cancellables)

        nwTransmitter.$transportType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshConnectionStatus()
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    public func start() {
        motionManager.start()
        nwTransmitter.start()
        bleTransmitter.start()

        lastSecondUptime = ProcessInfo.processInfo.systemUptime
        secondCounter = 0

        // 100Hz transmission timer (10ms interval)
        timerSubscription = Timer.publish(every: ProtocolConstants.targetIntervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.sendNextPacket()
            }
    }

    public func stop() {
        timerSubscription?.cancel()
        timerSubscription = nil
        motionManager.stop()
        nwTransmitter.stop()
        bleTransmitter.stop()
        #if os(iOS)
        HapticManager.shared.stopEngineRumble()
        #endif
    }

    // MARK: - Packet Dispatch (100Hz)

    private func sendNextPacket() {
        sequenceID &+= 1

        let packet: SteeringPacket
        if isFreeCameraLookActive {
            var camButtons = activeButtons
            camButtons.insert(.freeCamera)
            let clampedDy = Int16(max(-32767, min(32767, Int(cameraDeltaY))))
            packet = SteeringPacket(
                sequenceID: sequenceID,
                steeringAngle: cameraDeltaX,
                throttle: UInt16(bitPattern: clampedDy),
                brake: 0,
                buttons: camButtons
            )
            // Decay deltas after transmission
            cameraDeltaX = 0
            cameraDeltaY = 0
        } else {
            packet = SteeringPacket(
                sequenceID: sequenceID,
                steeringAngle: motionManager.normalizedSteering,
                normalizedThrottle: throttle,
                normalizedBrake: brake,
                buttons: activeButtons
            )
        }

        #if os(iOS)
        let isEngineRunning = activeButtons.contains(.engineStart)
        let isBlinkerActive = activeButtons.contains(.leftBlinker) || activeButtons.contains(.rightBlinker) || activeButtons.contains(.hazardLights)
        HapticManager.shared.updateDrivingDynamics(
            throttle: throttle,
            brake: brake,
            normalizedSteering: motionManager.normalizedSteering,
            isEngineRunning: isEngineRunning,
            isBlinkerActive: isBlinkerActive
        )
        #endif

        // Route packets according to user's explicit connection preference
        switch preferredConnection {
        case .auto:
            if nwTransmitter.isConnected {
                nwTransmitter.send(packet: packet)
            }
            if bleTransmitter.isConnected {
                bleTransmitter.send(packet: packet)
            }
        case .usb:
            // Prefer USB Cable connection
            if nwTransmitter.isConnected && nwTransmitter.transportType == .usb {
                nwTransmitter.send(packet: packet)
            } else if nwTransmitter.isConnected {
                // If not explicitly identified as USB interface, still forward over network
                nwTransmitter.send(packet: packet)
            }
        case .wifi:
            // Transmit over Wi-Fi
            if nwTransmitter.isConnected && nwTransmitter.transportType == .wifi {
                nwTransmitter.send(packet: packet)
            } else if nwTransmitter.isConnected {
                nwTransmitter.send(packet: packet)
            }
        case .ble:
            // Transmit strictly over Bluetooth LE
            if bleTransmitter.isConnected {
                bleTransmitter.send(packet: packet)
            }
        }

        packetsSentCount &+= 1
        secondCounter += 1

        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastSecondUptime
        if elapsed >= 1.0 {
            currentHz = Double(secondCounter) / elapsed
            secondCounter = 0
            lastSecondUptime = now
        }
    }

    // MARK: - Game Profile Control

    public func setProfile(_ profile: GameHUDProfile) {
        activeHUDProfile = profile
        motionManager.maxLockAngleDegrees = profile.defaultLockAngle
        if profile == .asphalt {
            activeButtons.insert(.arcadeProfile)
        } else {
            activeButtons.remove(.arcadeProfile)
        }
        #if os(iOS)
        HapticManager.shared.calibrationSuccess()
        #endif
    }

    // MARK: - Button Controls

    public func pressButton(_ button: SteeringButtons) {
        activeButtons.insert(button)
        #if os(iOS)
        if button == .gearUp || button == .gearDown || button == .neutral {
            HapticManager.shared.gearShift()
        } else if button == .retarderUp || button == .retarderDown {
            HapticManager.shared.pedalTick()
        } else if button == .engineStart {
            HapticManager.shared.engineIgnition()
        } else if button == .parkingBrake {
            if activeHUDProfile == .asphalt {
                HapticManager.shared.nitroBoost()
            } else {
                HapticManager.shared.parkingBrake()
            }
        } else {
            HapticManager.shared.buttonTap()
        }
        #endif
    }

    public func releaseButton(_ button: SteeringButtons) {
        activeButtons.remove(button)
    }

    public func toggleButton(_ button: SteeringButtons) {
        let isNowActive: Bool
        if activeButtons.contains(button) {
            activeButtons.remove(button)
            isNowActive = false
        } else {
            activeButtons.insert(button)
            isNowActive = true
        }

        #if os(iOS)
        if button == .engineStart {
            HapticManager.shared.engineIgnition()
        } else if button == .parkingBrake {
            if activeHUDProfile == .asphalt {
                HapticManager.shared.nitroBoost()
            } else {
                HapticManager.shared.parkingBrake()
            }
        } else {
            HapticManager.shared.toggleSwitch(active: isNowActive)
        }
        #endif
    }

    public func recenter() {
        motionManager.recenter()
        #if os(iOS)
        HapticManager.shared.calibrationSuccess()
        #endif

        // Momentarily set recenter bit in packet
        activeButtons.insert(.recenter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.activeButtons.remove(.recenter)
        }
    }
}
