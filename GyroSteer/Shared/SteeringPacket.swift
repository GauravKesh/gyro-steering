//
//  SteeringPacket.swift
//  GyroSteer - Shared Protocol
//
//  Unified 12-byte Little-Endian binary protocol for zero-allocation
//  streaming between iOS Transmitter and macOS Receiver.
//

import Foundation

/// Simulator and controller action button bitmask (32 bits)
public struct SteeringButtons: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let leftBlinker       = SteeringButtons(rawValue: 1 << 0)
    public static let rightBlinker      = SteeringButtons(rawValue: 1 << 1)
    public static let horn              = SteeringButtons(rawValue: 1 << 2)
    public static let headlights        = SteeringButtons(rawValue: 1 << 3)
    public static let gearUp            = SteeringButtons(rawValue: 1 << 4)
    public static let gearDown          = SteeringButtons(rawValue: 1 << 5)
    public static let cruiseControl     = SteeringButtons(rawValue: 1 << 6)
    public static let transmissionMode  = SteeringButtons(rawValue: 1 << 7)
    public static let hazardLights      = SteeringButtons(rawValue: 1 << 8)
    public static let wipers            = SteeringButtons(rawValue: 1 << 9)
    public static let engineStart       = SteeringButtons(rawValue: 1 << 10)
    public static let parkingBrake      = SteeringButtons(rawValue: 1 << 11)
    public static let trailerAttach     = SteeringButtons(rawValue: 1 << 12)
    public static let highBeams         = SteeringButtons(rawValue: 1 << 13)
    public static let cameraView        = SteeringButtons(rawValue: 1 << 14)
    public static let enter             = SteeringButtons(rawValue: 1 << 15)
    public static let menuEscape        = SteeringButtons(rawValue: 1 << 15) // Alias for backwards compatibility

    // MARK: - Premium ETS2 Extended Simulator Actions
    public static let retarderDown      = SteeringButtons(rawValue: 1 << 16)
    public static let retarderUp        = SteeringButtons(rawValue: 1 << 17)
    public static let engineBrake       = SteeringButtons(rawValue: 1 << 18)
    public static let neutral           = SteeringButtons(rawValue: 1 << 19)
    public static let cabinView         = SteeringButtons(rawValue: 1 << 20)
    public static let routeAdvisor      = SteeringButtons(rawValue: 1 << 21)
    public static let worldMap          = SteeringButtons(rawValue: 1 << 22)
    public static let recenter          = SteeringButtons(rawValue: 1 << 23)
    public static let mapZoom           = SteeringButtons(rawValue: 1 << 24)
    public static let arcadeProfile     = SteeringButtons(rawValue: 1 << 25)
}

/// Unified 14-Byte Binary Packet Struct
///
/// Byte Layout:
/// - Bytes 0–1:   `sequenceID` (UInt16, Little-Endian)
/// - Bytes 2–5:   `steeringAngle` (Float32, Little-Endian IEEE 754, normalized -1.0 to +1.0)
/// - Bytes 6–7:   `throttle` (UInt16, Little-Endian, 0 to 65535)
/// - Bytes 8–9:   `brake` (UInt16, Little-Endian, 0 to 65535)
/// - Bytes 10–13: `buttons` (UInt32, Little-Endian bitmask)
public struct SteeringPacket: Sendable, Equatable {
    public static let packetSize = 14

    public var sequenceID: UInt16
    public var steeringAngle: Float32 // -1.0 (full left) to +1.0 (full right)
    public var throttle: UInt16      // 0 to 65535 (0.0 to 1.0)
    public var brake: UInt16         // 0 to 65535 (0.0 to 1.0)
    public var buttons: SteeringButtons

    public init(
        sequenceID: UInt16 = 0,
        steeringAngle: Float32 = 0.0,
        throttle: UInt16 = 0,
        brake: UInt16 = 0,
        buttons: SteeringButtons = []
    ) {
        self.sequenceID = sequenceID
        self.steeringAngle = max(-1.0, min(1.0, steeringAngle))
        self.throttle = throttle
        self.brake = brake
        self.buttons = buttons
    }

    /// Convenience initializer using normalized 0.0...1.0 floats for pedals
    public init(
        sequenceID: UInt16,
        steeringAngle: Float32,
        normalizedThrottle: Float,
        normalizedBrake: Float,
        buttons: SteeringButtons = []
    ) {
        self.sequenceID = sequenceID
        self.steeringAngle = max(-1.0, min(1.0, steeringAngle))
        let clampedThrottle = max(0.0, min(1.0, normalizedThrottle))
        let clampedBrake = max(0.0, min(1.0, normalizedBrake))
        self.throttle = UInt16(clampedThrottle * Float(UInt16.max))
        self.brake = UInt16(clampedBrake * Float(UInt16.max))
        self.buttons = buttons
    }

    /// Normalized pedal values (0.0 ... 1.0)
    public var normalizedThrottle: Float {
        Float(throttle) / Float(UInt16.max)
    }

    public var normalizedBrake: Float {
        Float(brake) / Float(UInt16.max)
    }

    // MARK: - Zero-Allocation Binary Serialization

    /// Serializes this packet directly into a pre-allocated buffer of at least 14 bytes.
    /// Returns the number of bytes written (always 14 on success, 0 on failure).
    @discardableResult
    public func serialize(into buffer: UnsafeMutableRawBufferPointer) -> Int {
        guard buffer.count >= Self.packetSize else { return 0 }

        let seqLE = sequenceID.littleEndian
        let angleBits = steeringAngle.bitPattern.littleEndian
        let throttleLE = throttle.littleEndian
        let brakeLE = brake.littleEndian
        let buttonsLE = buttons.rawValue.littleEndian

        var offset = 0

        buffer.storeBytes(of: seqLE, toByteOffset: offset, as: UInt16.self)
        offset += 2

        buffer.storeBytes(of: angleBits, toByteOffset: offset, as: UInt32.self)
        offset += 4

        buffer.storeBytes(of: throttleLE, toByteOffset: offset, as: UInt16.self)
        offset += 2

        buffer.storeBytes(of: brakeLE, toByteOffset: offset, as: UInt16.self)
        offset += 2

        buffer.storeBytes(of: buttonsLE, toByteOffset: offset, as: UInt32.self)
        offset += 4

        return offset
    }

    /// Borrows serialized bytes with zero heap allocation.
    public func withSerializedBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        // Build contiguous 14-byte stack array
        var stackArray = (
            UInt8(0), UInt8(0), UInt8(0), UInt8(0),
            UInt8(0), UInt8(0), UInt8(0), UInt8(0),
            UInt8(0), UInt8(0), UInt8(0), UInt8(0),
            UInt8(0), UInt8(0)
        )
        return try withUnsafeMutableBytes(of: &stackArray) { stackBuffer in
            self.serialize(into: stackBuffer)
            return try body(UnsafeRawBufferPointer(stackBuffer))
        }
    }

    /// Encodes into standard Foundation Data (14 bytes)
    public func serializedData() -> Data {
        var data = Data(count: Self.packetSize)
        data.withUnsafeMutableBytes { buffer in
            _ = serialize(into: buffer)
        }
        return data
    }

    // MARK: - Binary Deserialization

    /// Deserializes from a raw buffer pointer. Supports both 14-byte extended and 12-byte legacy packets.
    public init?(buffer: UnsafeRawBufferPointer) {
        guard buffer.count >= 12 else { return nil }

        var offset = 0
        let seqLE = buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
        offset += 2

        let angleBits = buffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        offset += 4

        let throttleLE = buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
        offset += 2

        let brakeLE = buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
        offset += 2

        if buffer.count >= 14 {
            let buttonsLE = buffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            self.buttons = SteeringButtons(rawValue: UInt32(littleEndian: buttonsLE))
        } else {
            let buttonsLE = buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
            self.buttons = SteeringButtons(rawValue: UInt32(UInt16(littleEndian: buttonsLE)))
        }

        self.sequenceID = UInt16(littleEndian: seqLE)
        self.steeringAngle = Float32(bitPattern: UInt32(littleEndian: angleBits))
        self.throttle = UInt16(littleEndian: throttleLE)
        self.brake = UInt16(littleEndian: brakeLE)
    }

    /// Deserializes from Foundation Data.
    public init?(data: Data) {
        guard data.count >= 12 else { return nil }
        self = data.withUnsafeBytes { buffer in
            Self(buffer: buffer)
        }!
    }

    // MARK: - Sequence Number Ordering

    /// Computes whether `newSeq` is newer than `lastSeq`, taking 16-bit integer wrap-around into account.
    /// Returns true if `newSeq` is newer (within a 32767 packet forward window).
    public static func isSequenceNewer(_ newSeq: UInt16, than lastSeq: UInt16) -> Bool {
        if newSeq == lastSeq { return false }
        let diff = Int16(bitPattern: newSeq &- lastSeq)
        return diff > 0
    }
}
