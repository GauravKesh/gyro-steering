//
//  SteeringPacketTests.swift
//  GyroSteer - Shared Protocol Tests
//

import XCTest
#if canImport(GyroSteerShared)
@testable import GyroSteerShared
#endif

final class SteeringPacketTests: XCTestCase {

    func testPacketExactSize() {
        XCTAssertEqual(SteeringPacket.packetSize, 12, "Packet size must be exactly 12 bytes")
    }

    func testSerializationDeserializationRoundtrip() {
        let original = SteeringPacket(
            sequenceID: 42100,
            steeringAngle: -0.732,
            throttle: 54321,
            brake: 12345,
            buttons: [.leftBlinker, .horn, .gearUp]
        )

        let data = original.serializedData()
        XCTAssertEqual(data.count, 12)

        guard let decoded = SteeringPacket(data: data) else {
            XCTFail("Failed to deserialize valid packet data")
            return
        }

        XCTAssertEqual(decoded.sequenceID, 42100)
        XCTAssertEqual(decoded.steeringAngle, -0.732, accuracy: 0.0001)
        XCTAssertEqual(decoded.throttle, 54321)
        XCTAssertEqual(decoded.brake, 12345)
        XCTAssertEqual(decoded.buttons, [.leftBlinker, .horn, .gearUp])
    }

    func testNormalizedPedalInitializers() {
        let packet = SteeringPacket(
            sequenceID: 1,
            steeringAngle: 0.5,
            normalizedThrottle: 1.0,
            normalizedBrake: 0.25,
            buttons: [.headlights]
        )

        XCTAssertEqual(packet.throttle, UInt16.max)
        XCTAssertEqual(packet.normalizedThrottle, 1.0, accuracy: 0.001)
        XCTAssertEqual(packet.normalizedBrake, 0.25, accuracy: 0.01)
        XCTAssertTrue(packet.buttons.contains(.headlights))
    }

    func testLittleEndianByteLayout() {
        let packet = SteeringPacket(
            sequenceID: 0x0102,
            steeringAngle: 0.0,
            throttle: 0x0304,
            brake: 0x0506,
            buttons: SteeringButtons(rawValue: 0x0708)
        )

        let data = packet.serializedData()
        XCTAssertEqual(data.count, 12)

        // Byte 0-1: sequenceID little endian (0x02, 0x01)
        XCTAssertEqual(data[0], 0x02)
        XCTAssertEqual(data[1], 0x01)

        // Byte 2-5: steering angle 0.0 -> Float32 bitPattern 0x00000000
        XCTAssertEqual(data[2], 0x00)
        XCTAssertEqual(data[3], 0x00)
        XCTAssertEqual(data[4], 0x00)
        XCTAssertEqual(data[5], 0x00)

        // Byte 6-7: throttle little endian (0x04, 0x03)
        XCTAssertEqual(data[6], 0x04)
        XCTAssertEqual(data[7], 0x03)

        // Byte 8-9: brake little endian (0x06, 0x05)
        XCTAssertEqual(data[8], 0x06)
        XCTAssertEqual(data[9], 0x05)

        // Byte 10-11: buttons little endian (0x08, 0x07)
        XCTAssertEqual(data[10], 0x08)
        XCTAssertEqual(data[11], 0x07)
    }

    func testZeroAllocationBufferSerialization() {
        let packet = SteeringPacket(
            sequenceID: 999,
            steeringAngle: 0.85,
            throttle: 1000,
            brake: 2000,
            buttons: [.recenter]
        )

        var rawBuffer = [UInt8](repeating: 0, count: 16)
        let written = rawBuffer.withUnsafeMutableBytes { ptr in
            packet.serialize(into: ptr)
        }

        XCTAssertEqual(written, 12)

        let decoded = rawBuffer.withUnsafeBytes { ptr in
            SteeringPacket(buffer: ptr)
        }

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.sequenceID, 999)
        XCTAssertEqual(decoded?.buttons, [.recenter])
    }

    func testSequenceNumberOrdering() {
        // Normal sequential
        XCTAssertTrue(SteeringPacket.isSequenceNewer(2, than: 1))
        XCTAssertTrue(SteeringPacket.isSequenceNewer(100, than: 99))
        XCTAssertFalse(SteeringPacket.isSequenceNewer(99, than: 100))
        XCTAssertFalse(SteeringPacket.isSequenceNewer(100, than: 100))

        // Wrap around 65535 -> 0
        XCTAssertTrue(SteeringPacket.isSequenceNewer(0, than: 65535))
        XCTAssertTrue(SteeringPacket.isSequenceNewer(5, than: 65530))
        XCTAssertFalse(SteeringPacket.isSequenceNewer(65530, than: 5))

        // Far stale packet
        XCTAssertFalse(SteeringPacket.isSequenceNewer(1, than: 33000))
    }

    func testMathUtilitiesDeadzone() {
        // Within deadzone
        XCTAssertEqual(MathUtilities.applyDeadzone(0.01, deadzone: 0.05), 0.0)
        XCTAssertEqual(MathUtilities.applyDeadzone(-0.04, deadzone: 0.05), 0.0)

        // Outside deadzone
        let positive = MathUtilities.applyDeadzone(0.525, deadzone: 0.05)
        XCTAssertEqual(positive, 0.5, accuracy: 0.001)

        let negative = MathUtilities.applyDeadzone(-0.525, deadzone: 0.05)
        XCTAssertEqual(negative, -0.5, accuracy: 0.001)

        // Full scale
        XCTAssertEqual(MathUtilities.applyDeadzone(1.0, deadzone: 0.05), 1.0)
        XCTAssertEqual(MathUtilities.applyDeadzone(-1.0, deadzone: 0.05), -1.0)
    }

    func testMathUtilitiesLinearity() {
        // Linear (gamma = 1.0)
        XCTAssertEqual(MathUtilities.applyLinearity(0.5, exponent: 1.0), 0.5, accuracy: 0.001)
        XCTAssertEqual(MathUtilities.applyLinearity(-0.5, exponent: 1.0), -0.5, accuracy: 0.001)

        // Progressive curve (gamma = 2.0)
        XCTAssertEqual(MathUtilities.applyLinearity(0.5, exponent: 2.0), 0.25, accuracy: 0.001)
        XCTAssertEqual(MathUtilities.applyLinearity(-0.5, exponent: 2.0), -0.25, accuracy: 0.001)

        // Maxima
        XCTAssertEqual(MathUtilities.applyLinearity(1.0, exponent: 2.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(MathUtilities.applyLinearity(-1.0, exponent: 2.0), -1.0, accuracy: 0.001)
    }
}
