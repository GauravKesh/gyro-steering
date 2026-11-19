//
//  ProtocolConstants.swift
//  GyroSteer - Shared Protocol
//
//  Network, Bluetooth, and Simulator Constants.
//

import Foundation

public enum TransportType: String, Sendable, CaseIterable, Identifiable {
    case usb = "USB"
    case wifi = "Wi-Fi"
    case ble = "Bluetooth"

    public var id: String { rawValue }

    /// Priority order: USB (3) > Wi-Fi (2) > Bluetooth (1)
    public var priority: Int {
        switch self {
        case .usb: return 3
        case .wifi: return 2
        case .ble: return 1
        }
    }

    public var displayName: String {
        switch self {
        case .usb: return "USB Wired"
        case .wifi: return "Wi-Fi (LAN)"
        case .ble: return "Bluetooth LE"
        }
    }

    public var iconName: String {
        switch self {
        case .usb: return "cable.connector"
        case .wifi: return "wifi"
        case .ble: return "dot.radiowaves.left.and.right"
        }
    }
}

public enum ConnectionPreference: String, Sendable, CaseIterable, Identifiable {
    case auto = "Auto"
    case usb = "Cable (USB)"
    case wifi = "Wi-Fi"
    case ble = "Bluetooth"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .auto: return "AUTO"
        case .usb: return "CABLE"
        case .wifi: return "WI-FI"
        case .ble: return "BT"
        }
    }

    public var subtitle: String {
        switch self {
        case .auto: return "Auto-selects best: Cable > Wi-Fi > BT"
        case .usb: return "Lowest latency (<1.5ms) via USB-C / Lightning"
        case .wifi: return "Wireless local network via Bonjour UDP"
        case .ble: return "Zero-network direct pairing via Bluetooth"
        }
    }

    public var iconName: String {
        switch self {
        case .auto: return "sparkles"
        case .usb: return "cable.connector"
        case .wifi: return "wifi"
        case .ble: return "dot.radiowaves.left.and.right"
        }
    }

    public func matches(transportType: TransportType) -> Bool {
        switch self {
        case .auto:
            return true
        case .usb:
            return transportType == .usb
        case .wifi:
            return transportType == .wifi
        case .ble:
            return transportType == .ble
        }
    }
}

/// Transmission Gearbox Mode (Automatic vs Manual / Sequential)
public enum TransmissionMode: String, Sendable, CaseIterable, Identifiable {
    case automatic = "AUTO"
    case manual = "MANUAL"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .manual: return "Manual / Sequential"
        }
    }
}

public enum ProtocolConstants {
    /// Bonjour service type for Network.framework UDP discovery
    public static let bonjourServiceType = "_gyrosteer._udp"

    /// Bonjour domain
    public static let bonjourDomain = "local."

    /// Default UDP port for local network and usbmuxd communication
    public static let defaultPort: UInt16 = 28282

    /// CoreBluetooth GATT Service UUID for GyroSteer
    public static let bleServiceUUIDString = "5A8D0001-9F3B-4C92-A3D2-832F6E35C801"

    /// CoreBluetooth GATT Characteristic UUID for 12-byte SteeringPacket (Write Without Response)
    public static let bleCharacteristicUUIDString = "5A8D0002-9F3B-4C92-A3D2-832F6E35C801"

    /// CoreBluetooth GATT Characteristic UUID for Haptic Feedback / Status from Mac to iOS (Notify / Write)
    public static let bleFeedbackCharacteristicUUIDString = "5A8D0003-9F3B-4C92-A3D2-832F6E35C801"

    /// Motion manager polling rate: 100 Hz = 10 ms interval
    public static let targetFrequencyHz: Double = 100.0
    public static let targetIntervalSeconds: TimeInterval = 1.0 / targetFrequencyHz

    /// Failover timeout: If USB hasn't produced a packet in 150ms, allow fallback to Wi-Fi / BLE
    public static let transportSilenceTimeoutSeconds: TimeInterval = 0.150

    /// Default lock angles in degrees (±45° natural phone tilt = full lock)
    public static let defaultMaxLockAngleDegrees: Double = 45.0
    public static let lockAngleOptionsDegrees: [Double] = [15.0, 20.0, 30.0, 45.0, 60.0, 90.0, 180.0, 360.0]
}
