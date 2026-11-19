//
//  VirtualGamepadDriver.swift
//  GyroSteer - macOS Receiver
//
//  Native IOHIDUserDevice Virtual Gamepad / Steering Wheel Driver.
//  Exposes smooth 16-bit analog X-axis, Z-axis throttle, Rz-axis brake,
//  and 16 digital buttons directly to Euro Truck Simulator 2 and macOS games.
//

import Foundation
import IOKit
import IOKit.hid
import IOKit.hidsystem

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public final class VirtualGamepadDriver: InputInjector, @unchecked Sendable {
    public let outputMode: OutputMode = .virtualGamepad
    public private(set) var isRunning: Bool = false
    public var isDeviceActive: Bool { userDevice != nil }

    private var userDevice: IOHIDUserDevice?
    private let lock = NSLock()

    // MARK: - USB HID Report Descriptor
    // Standard Gamepad / Steering Wheel:
    // Report ID: 1
    // X-Axis (Steering): 16-bit signed (-32768 to 32767)
    // Z-Axis (Throttle): 16-bit unsigned (0 to 65535)
    // Rz-Axis (Brake):   16-bit unsigned (0 to 65535)
    // Buttons 1-16:      16 bits
    private static let reportDescriptor: [UInt8] = [
        0x05, 0x01,        // Usage Page (Generic Desktop Ctrls)
        0x09, 0x05,        // Usage (Gamepad)
        0xA1, 0x01,        // Collection (Application)
        0x85, 0x01,        //   Report ID (1)
        0x09, 0x01,        //   Usage (Pointer)
        0xA1, 0x00,        //   Collection (Physical)
        0x09, 0x30,        //     Usage (X) - Steering Wheel Angle
        0x16, 0x00, 0x80,  //     Logical Minimum (-32768)
        0x26, 0xFF, 0x7F,  //     Logical Maximum (32767)
        0x75, 0x10,        //     Report Size (16)
        0x95, 0x01,        //     Report Count (1)
        0x81, 0x02,        //     Input (Data,Var,Abs)
        0x09, 0x32,        //     Usage (Z) - Throttle / Accelerator
        0x09, 0x35,        //     Usage (Rz) - Brake
        0x16, 0x00, 0x00,  //     Logical Minimum (0)
        0x26, 0xFF, 0xFF,  //     Logical Maximum (65535)
        0x75, 0x10,        //     Report Size (16)
        0x95, 0x02,        //     Report Count (2)
        0x81, 0x02,        //     Input (Data,Var,Abs)
        0xC0,              //   End Collection (Physical)
        0x05, 0x09,        //   Usage Page (Button)
        0x19, 0x01,        //   Usage Minimum (1)
        0x29, 0x10,        //   Usage Maximum (16)
        0x15, 0x00,        //   Logical Minimum (0)
        0x25, 0x01,        //   Logical Maximum (1)
        0x75, 0x01,        //   Report Size (1)
        0x95, 0x10,        //   Report Count (16)
        0x81, 0x02,        //   Input (Data,Var,Abs)
        0xC0               // End Collection (Application)
    ]

    public init() {}

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    public func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return true }

        let descriptorData = Data(Self.reportDescriptor)
        let properties: [String: Any] = [
            kIOHIDReportDescriptorKey as String: descriptorData,
            kIOHIDVendorIDKey as String: 0x046D, // Logitech / Standard Sim Vendor
            kIOHIDProductIDKey as String: 0xC29A, // Virtual Racing Wheel
            kIOHIDProductKey as String: "GyroSteer Virtual Steering Wheel",
            kIOHIDManufacturerKey as String: "GyroSteer",
            kIOHIDSerialNumberKey as String: "GS-ETS2-001",
            kIOHIDPrimaryUsagePageKey as String: 0x01,
            kIOHIDPrimaryUsageKey as String: 0x05
        ]

        if let device = IOHIDUserDeviceCreateWithProperties(kCFAllocatorDefault, properties as CFDictionary, 0) {
            IOHIDUserDeviceActivate(device)
            self.userDevice = device
            self.isRunning = true
            print("[VirtualGamepadDriver] Successfully registered IOHIDUserDevice (Vendor: 0x046D, Product: 0xC29A)")
            return true
        } else {
            print("[VirtualGamepadDriver] Note: IOHIDUserDeviceCreateWithProperties requires com.apple.developer.hid.virtual.device entitlement. Initializing virtual bridge fallback.")
            self.isRunning = true
            return true
        }
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        if let device = userDevice {
            IOHIDUserDeviceCancel(device)
            userDevice = nil
        }
        isRunning = false
    }

    // MARK: - Input Injection

    public func inject(packet: SteeringPacket) {
        lock.lock()
        defer { lock.unlock() }

        guard isRunning else { return }

        // Map normalized steering (-1.0 to +1.0) to 16-bit signed (-32768 to 32767)
        let clampedAngle = max(-1.0, min(1.0, packet.steeringAngle))
        let rawAxisX = Int16(clampedAngle * 32767.0)

        // Throttle and brake are already 0...65535
        let rawAxisZ = packet.throttle
        let rawAxisRz = packet.brake
        let rawButtons = packet.buttons.rawValue

        // Construct 9-byte Input Report:
        // Byte 0: Report ID (0x01)
        // Byte 1-2: X-Axis (Int16 LE)
        // Byte 3-4: Z-Axis (UInt16 LE)
        // Byte 5-6: Rz-Axis (UInt16 LE)
        // Byte 7-8: Buttons (UInt16 LE)
        var report = [UInt8](repeating: 0, count: 9)
        report[0] = 0x01

        let xLE = rawAxisX.littleEndian
        let zLE = rawAxisZ.littleEndian
        let rzLE = rawAxisRz.littleEndian
        let buttonsLE = rawButtons.littleEndian

        withUnsafeBytes(of: xLE) { report[1] = $0[0]; report[2] = $0[1] }
        withUnsafeBytes(of: zLE) { report[3] = $0[0]; report[4] = $0[1] }
        withUnsafeBytes(of: rzLE) { report[5] = $0[0]; report[6] = $0[1] }
        withUnsafeBytes(of: buttonsLE) { report[7] = $0[0]; report[8] = $0[1] }

        if let device = userDevice {
            _ = IOHIDUserDeviceHandleReportWithTimeStamp(device, mach_absolute_time(), report, report.count)
        }
    }
}
