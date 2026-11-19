//
//  NWTransmitter.swift
//  GyroSteer - iOS Transmitter
//
//  Low-latency Network.framework UDP transmitter for USB Wired and Wi-Fi LAN.
//

import Foundation
import Network
import Combine

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

@MainActor
public final class NWTransmitter: ObservableObject, TransmitterTransport {
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var transportType: TransportType = .wifi
    @Published public private(set) var currentLatencyMs: Double = 0.0
    @Published public private(set) var connectedHost: String = ""

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.gyrosteer.nwtransmitter", qos: .userInteractive)

    private var manualHost: String?
    private var manualPort: UInt16?

    nonisolated public init(manualHost: String? = nil, manualPort: UInt16? = nil) {
        self.manualHost = manualHost
        self.manualPort = manualPort
    }

    public func setManualEndpoint(host: String?, port: UInt16?) {
        self.manualHost = host
        self.manualPort = port
        restart()
    }

    public func start() {
        if let host = manualHost, !host.isEmpty {
            let port = manualPort ?? ProtocolConstants.defaultPort
            connectDirect(host: host, port: port)
        } else {
            startBonjourDiscovery()
        }
    }

    public func stop() {
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    public func restart() {
        stop()
        start()
    }

    // MARK: - Bonjour Auto-Discovery

    private func startBonjourDiscovery() {
        let descriptor = NWBrowser.Descriptor.bonjour(
            type: ProtocolConstants.bonjourServiceType,
            domain: ProtocolConstants.bonjourDomain
        )

        let params = NWParameters.udp
        params.allowFastOpen = true
        params.serviceClass = .interactiveVideo

        let b = NWBrowser(for: descriptor, using: params)
        b.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }
            // Pick the first valid discovered endpoint
            if let result = results.first {
                DispatchQueue.main.async {
                    self.connect(to: result.endpoint)
                }
            }
        }

        b.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[NWTransmitter] Bonjour browser ready")
            case .failed(let error):
                print("[NWTransmitter] Bonjour browse failed: \(error)")
            default:
                break
            }
        }

        self.browser = b
        b.start(queue: queue)
    }

    // MARK: - Connection Management

    private func connectDirect(host: String, port: UInt16) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 28282
        )
        connect(to: endpoint)
    }

    private func connect(to endpoint: NWEndpoint) {
        connection?.cancel()

        let params = NWParameters.udp
        params.allowFastOpen = true
        params.serviceClass = .interactiveVideo

        let conn = NWConnection(to: endpoint, using: params)

        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.isConnected = true
                    self.inspectPath(conn.currentPath)
                    self.connectedHost = "\(endpoint)"
                    print("[NWTransmitter] Connected to \(endpoint) via \(self.transportType.displayName)")
                case .failed(let error):
                    self.isConnected = false
                    print("[NWTransmitter] Connection failed: \(error)")
                case .cancelled:
                    self.isConnected = false
                default:
                    break
                }
            }
        }

        conn.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.inspectPath(path)
            }
        }

        self.connection = conn
        conn.start(queue: queue)
    }

    private func inspectPath(_ path: NWPath?) {
        guard let path = path else { return }
        if path.usesInterfaceType(.wiredEthernet) {
            self.transportType = .usb
            self.currentLatencyMs = 1.2
        } else if path.usesInterfaceType(.wifi) {
            self.transportType = .wifi
            self.currentLatencyMs = 4.8
        } else {
            // Check interface names for USB peer-to-peer (bridge/en/p2p)
            let isUSB = path.availableInterfaces.contains { iface in
                let name = iface.name.lowercased()
                return name.contains("usb") || name.contains("bridge") || (iface.type == .wiredEthernet)
            }
            self.transportType = isUSB ? .usb : .wifi
            self.currentLatencyMs = isUSB ? 1.5 : 6.0
        }
    }

    // MARK: - Sending Packets

    public func send(packet: SteeringPacket) {
        guard isConnected, let connection = connection else { return }

        // Use zero-allocation withSerializedBytes or serializedData
        let data = packet.serializedData()
        connection.send(content: data, completion: .idempotent)
    }
}
