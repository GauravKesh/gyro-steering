//
//  ReceiverTransport.swift
//  GyroSteer - macOS Receiver
//
//  Protocol for incoming packet transports on macOS.
//

import Foundation

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public protocol ReceiverTransportDelegate: AnyObject, Sendable {
    func transport(
        _ transport: any ReceiverTransport,
        didReceive packet: SteeringPacket,
        on transportType: TransportType,
        sourceDescription: String
    )
}

public protocol ReceiverTransport: AnyObject {
    var transportType: TransportType { get }
    var isListening: Bool { get }
    var delegate: (any ReceiverTransportDelegate)? { get set }

    func start()
    func stop()
}
