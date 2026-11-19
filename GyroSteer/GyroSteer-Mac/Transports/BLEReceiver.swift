//
//  BLEReceiver.swift
//  GyroSteer - macOS Receiver
//
//  CoreBluetooth CBCentralManager for discovering and receiving BLE steering telemetry.
//

import Foundation
@preconcurrency import CoreBluetooth

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public final class BLEReceiver: NSObject, ReceiverTransport, @unchecked Sendable {
    public let transportType: TransportType = .ble
    public private(set) var isListening: Bool = false
    public weak var delegate: (any ReceiverTransportDelegate)?

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var steeringCharacteristic: CBCharacteristic?

    private let serviceUUID = CBUUID(string: ProtocolConstants.bleServiceUUIDString)
    private let characteristicUUID = CBUUID(string: ProtocolConstants.bleCharacteristicUUIDString)

    private let queue = DispatchQueue(label: "com.gyrosteer.blereceiver", qos: .userInteractive)

    public override init() {
        super.init()
    }

    public func start() {
        guard !isListening else { return }
        isListening = true
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: queue)
        } else if centralManager?.state == .poweredOn {
            startScanning()
        }
    }

    public func stop() {
        isListening = false
        centralManager?.stopScan()
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
        }
    }

    private func startScanning() {
        guard let cm = centralManager, cm.state == .poweredOn, isListening else { return }
        print("[BLEReceiver] Scanning for GyroSteer peripherals with service \(serviceUUID)")
        cm.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
}

extension BLEReceiver: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if isListening {
                startScanning()
            }
        case .poweredOff, .resetting, .unauthorized, .unsupported:
            connectedPeripheral = nil
            steeringCharacteristic = nil
        default:
            break
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("[BLEReceiver] Discovered peripheral: \(peripheral.name ?? "unnamed") (RSSI: \(RSSI))")
        connectedPeripheral = peripheral
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[BLEReceiver] Connected to peripheral \(peripheral.name ?? "unnamed")")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[BLEReceiver] Peripheral disconnected: \(String(describing: error)). Resuming scan.")
        connectedPeripheral = nil
        steeringCharacteristic = nil
        if isListening {
            startScanning()
        }
    }
}

extension BLEReceiver: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services, error == nil else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics, error == nil else { return }
        for characteristic in characteristics where characteristic.uuid == characteristicUUID {
            self.steeringCharacteristic = characteristic
            // Subscribe to notifications for streaming telemetry
            peripheral.setNotifyValue(true, for: characteristic)
            print("[BLEReceiver] Subscribed to steering characteristic notifications")
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BLEReceiver] Error receiving characteristic update: \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value, data.count >= SteeringPacket.packetSize else {
            if let count = characteristic.value?.count {
                print("[BLEReceiver] Warning: Received packet of \(count) bytes (expected \(SteeringPacket.packetSize))")
            }
            return
        }

        if let packet = SteeringPacket(data: data) {
            delegate?.transport(
                self,
                didReceive: packet,
                on: .ble,
                sourceDescription: peripheral.name ?? "BLE"
            )
        }
    }
}
