//
//  RunAllTests.swift
//  GyroSteer - Standalone Test Suite Runner
//

import Foundation
#if canImport(GyroSteerShared)
import GyroSteerShared
#endif
#if canImport(GyroSteerMacCore)
import GyroSteerMacCore
#endif

@main
struct TestRunnerMain {
    static func main() {
        print("========================================")
        print("  GyroSteer Unified Test Suite Runner   ")
        print("========================================")

        runSharedTests()
        TransportArbiterTests.runAllTests()

        print("========================================")
        print("  ALL 100% UNIT TESTS PASSED GLOBALLY!  ")
        print("========================================")
    }

    static func runSharedTests() {
        print("▶ Running SteeringPacket Serialization Tests...")

        // 1. Exact size test
        assert(SteeringPacket.packetSize == 12, "Packet size must be 12 bytes")

        // 2. Round-trip test
        let original = SteeringPacket(
            sequenceID: 55443,
            steeringAngle: -0.875,
            throttle: 65000,
            brake: 32000,
            buttons: [.leftBlinker, .horn, .gearUp, .recenter, .enter, .parkingBrake]
        )

        let data = original.serializedData()
        assert(data.count == 12, "Serialized data length must be 12")

        guard let decoded = SteeringPacket(data: data) else {
            fatalError("Failed to deserialize packet")
        }

        assert(decoded.sequenceID == 55443, "Sequence ID mismatch")
        assert(abs(decoded.steeringAngle - (-0.875)) < 0.0001, "Steering angle mismatch")
        assert(decoded.throttle == 65000, "Throttle mismatch")
        assert(decoded.brake == 32000, "Brake mismatch")
        assert(decoded.buttons == [.leftBlinker, .horn, .gearUp, .recenter, .enter, .parkingBrake], "Buttons mismatch")

        // 3. Sequence number ordering test
        assert(SteeringPacket.isSequenceNewer(2, than: 1), "2 > 1")
        assert(SteeringPacket.isSequenceNewer(0, than: 65535), "Wrap 0 > 65535")
        assert(!SteeringPacket.isSequenceNewer(65535, than: 0), "Wrap 65535 not > 0")
        assert(!SteeringPacket.isSequenceNewer(100, than: 100), "Equal sequence not newer")

        // 4. Deadzone math
        assert(MathUtilities.applyDeadzone(0.01, deadzone: 0.05) == 0.0, "Deadzone center failed")
        assert(abs(MathUtilities.applyDeadzone(0.525, deadzone: 0.05) - 0.5) < 0.001, "Deadzone scale failed")

        // 5. Linearity math
        assert(abs(MathUtilities.applyLinearity(0.5, exponent: 2.0) - 0.25) < 0.001, "Linearity exponent failed")

        print("✔ Shared SteeringPacket tests passed successfully!")
    }
}
