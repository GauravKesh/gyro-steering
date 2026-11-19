//
//  BLETransmitter.swift
//  GyroSteer - iOS Transmitter
//
//  Bluetooth Low Energy peripheral transmitter for offline / fallback streaming.
//

import Foundation
@preconcurrency import CoreBluetooth
import Combine

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

@MainActor
public final class BLETransmitter: NSObject, ObservableObject, TransmitterTransport {
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var transportType: TransportType = .ble
    @Published public private(set) var currentLatencyMs: Double = 16.0
    @Published public private(set) var subscribedCentralCount: Int = 0

    private var peripheralManager: CBPeripheralManager?
    private var steeringCharacteristic: CBMutableCharacteristic?
    private var feedbackCharacteristic: CBMutableCharacteristic?

    private let serviceUUID = CBUUID(string: ProtocolConstants.bleServiceUUIDString)
    private let characteristicUUID = CBUUID(string: ProtocolConstants.bleCharacteristicUUIDString)
    private let feedbackUUID = CBUUID(string: ProtocolConstants.bleFeedbackCharacteristicUUIDString)

    private let queue = DispatchQueue(label: "com.gyrosteer.bletransmitter", qos: .userInteractive)
    private var lastSentUptime: TimeInterval = 0.0

    nonisolated public override init() {
        super.init()
    }

    public func start() {
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
        } else if peripheralManager?.state == .poweredOn {
            setupServicesAndAdvertise()
        }
    }

    public func stop() {
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        DispatchQueue.main.async {
            self.isConnected = false
            self.subscribedCentralCount = 0
        }
    }

    private func setupServicesAndAdvertise() {
        guard let pm = peripheralManager, pm.state == .poweredOn else { return }

        pm.removeAllServices()

        let steeringChar = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.notify, .writeWithoutResponse, .write],
            value: nil,
            permissions: [.writeable, .readable]
        )

        let feedbackChar = CBMutableCharacteristic(
            type: feedbackUUID,
            properties: [.notify, .write],
            value: nil,
            permissions: [.writeable, .readable]
        )

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [steeringChar, feedbackChar]

        pm.add(service)

        self.steeringCharacteristic = steeringChar
        self.feedbackCharacteristic = feedbackChar

        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "GyroSteer-Wheel"
        ]
        pm.startAdvertising(advertisementData)
        print("[BLETransmitter] Advertising GyroSteer-Wheel service")
    }

    // MARK: - Sending Packets

    public func send(packet: SteeringPacket) {
        guard isConnected,
              let pm = peripheralManager,
              let char = steeringCharacteristic else { return }

        let now = ProcessInfo.processInfo.systemUptime
        // CoreBluetooth GATT rate limit: send every ~28ms (approx 35Hz) to prevent queue overflow
        guard (now - lastSentUptime) >= 0.028 else { return }
        lastSentUptime = now

        let data = packet.serializedData()
        queue.async {
            _ = pm.updateValue(data, for: char, onSubscribedCentrals: nil)
        }
    }
}

extension BLETransmitter: CBPeripheralManagerDelegate {
    public nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            switch peripheral.state {
            case .poweredOn:
                self.setupServicesAndAdvertise()
            case .poweredOff, .resetting, .unauthorized, .unsupported:
                self.isConnected = false
                self.subscribedCentralCount = 0
            default:
                break
            }
        }
    }

    public nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        Task { @MainActor in
            self.subscribedCentralCount += 1
            self.isConnected = true
            print("[BLETransmitter] Central subscribed: \(central.identifier)")
        }
    }

    public nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        Task { @MainActor in
            self.subscribedCentralCount = max(0, self.subscribedCentralCount - 1)
            self.isConnected = self.subscribedCentralCount > 0
            print("[BLETransmitter] Central unsubscribed: \(central.identifier)")
        }
    }

    public nonisolated func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // BLE buffer drained and ready for next packet
    }

    public nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
