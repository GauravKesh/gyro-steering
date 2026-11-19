//
//  TransportProtocol.swift
//  GyroSteer - iOS Transmitter
//
//  Unified transmitter interface for USB, Wi-Fi, and Bluetooth transports.
//

import Foundation

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

@MainActor
public protocol TransmitterTransport: AnyObject {
    var transportType: TransportType { get }
    var isConnected: Bool { get }
    var currentLatencyMs: Double { get }

    func start()
    func stop()
    func send(packet: SteeringPacket)
}
