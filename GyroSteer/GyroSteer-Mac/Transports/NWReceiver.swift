//
//  NWReceiver.swift
//  GyroSteer - macOS Receiver
//
//  Network.framework UDP listener with Bonjour advertisement for USB and Wi-Fi streaming.
//

import Foundation
import Network

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public final class NWReceiver: ReceiverTransport, @unchecked Sendable {
    public let transportType: TransportType = .wifi // Can resolve to .usb or .wifi per packet
    public private(set) var isListening: Bool = false
    public weak var delegate: (any ReceiverTransportDelegate)?

    private var udpListener: NWListener?
    private var tcpListener: NWListener?
    private let queue = DispatchQueue(label: "com.gyrosteer.nwreceiver", qos: .userInteractive)

    public init() {}

    public func start() {
        guard !isListening else { return }
        startUDPListener()
        startTCPListener()
        isListening = true
    }

    public func stop() {
        udpListener?.cancel()
        udpListener = nil
        tcpListener?.cancel()
        tcpListener = nil
        isListening = false
    }

    // MARK: - UDP Listener (Primary for Low-Latency Streaming)

    private func startUDPListener() {
        do {
            let params = NWParameters.udp
            params.allowFastOpen = true
            params.serviceClass = .interactiveVideo

            let port = NWEndpoint.Port(rawValue: ProtocolConstants.defaultPort) ?? 28282
            let listener = try NWListener(using: params, on: port)

            // Bonjour advertisement
            listener.service = NWListener.Service(
                type: ProtocolConstants.bonjourServiceType,
                domain: ProtocolConstants.bonjourDomain
            )

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleUDPConnection(connection)
            }

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[NWReceiver] UDP Listener ready on port \(port), advertising \(ProtocolConstants.bonjourServiceType)")
                case .failed(let error):
                    print("[NWReceiver] UDP Listener failed: \(error)")
                default:
                    break
                }
            }

            self.udpListener = listener
            listener.start(queue: queue)
        } catch {
            print("[NWReceiver] Failed to create UDP listener: \(error)")
        }
    }

    private func handleUDPConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveNextUDPDatagram(on: connection)
    }

    private func receiveNextUDPDatagram(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] content, context, isComplete, error in
            guard let self = self else { return }

            if let data = content, data.count >= SteeringPacket.packetSize {
                let detectedType = self.detectTransportType(for: connection)
                let remote = connection?.endpoint.debugDescription ?? "unknown"

                if let packet = SteeringPacket(data: data) {
                    self.delegate?.transport(
                        self,
                        didReceive: packet,
                        on: detectedType,
                        sourceDescription: remote
                    )
                }
            }

            if error == nil, let connection = connection, connection.state == .ready {
                self.receiveNextUDPDatagram(on: connection)
            }
        }
    }

    // MARK: - TCP Fallback Listener (for usbmuxd / iproxy port forward)

    private func startTCPListener() {
        do {
            let params = NWParameters.tcp
            params.serviceClass = .interactiveVideo

            let port = NWEndpoint.Port(rawValue: ProtocolConstants.defaultPort) ?? 28282
            let listener = try NWListener(using: params, on: port)

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleTCPConnection(connection)
            }

            self.tcpListener = listener
            listener.start(queue: queue)
        } catch {
            print("[NWReceiver] Failed to create TCP listener: \(error)")
        }
    }

    private func handleTCPConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveTCPStream(on: connection)
    }

    private func receiveTCPStream(on connection: NWConnection) {
        // Read exactly 12-byte packet chunks
        connection.receive(minimumIncompleteLength: SteeringPacket.packetSize, maximumLength: SteeringPacket.packetSize) { [weak self, weak connection] content, _, isComplete, error in
            guard let self = self else { return }

            if let data = content, data.count == SteeringPacket.packetSize {
                let detectedType = self.detectTransportType(for: connection)
                let remote = connection?.endpoint.debugDescription ?? "localhost"

                if let packet = SteeringPacket(data: data) {
                    self.delegate?.transport(
                        self,
                        didReceive: packet,
                        on: detectedType,
                        sourceDescription: remote
                    )
                }
            }

            if error == nil, !isComplete, let connection = connection {
                self.receiveTCPStream(on: connection)
            }
        }
    }

    // MARK: - Transport Interface Detection

    private func detectTransportType(for connection: NWConnection?) -> TransportType {
        guard let path = connection?.currentPath else { return .wifi }

        // Localhost implies usbmuxd USB tunnel
        if let endpoint = connection?.endpoint, case .hostPort(let host, _) = endpoint {
            if host == "127.0.0.1" || host == "localhost" {
                return .usb
            }
        }

        if path.usesInterfaceType(.wiredEthernet) {
            return .usb
        }

        // Check if interface is a wired iPhone USB NCM/bridge connection
        let hasUSBInterface = path.availableInterfaces.contains { iface in
            let name = iface.name.lowercased()
            return (iface.type == .wiredEthernet) || name.contains("usb") || name.contains("bridge")
        }

        return hasUSBInterface ? .usb : .wifi
    }
}
