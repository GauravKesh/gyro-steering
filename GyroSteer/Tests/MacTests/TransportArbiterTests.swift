//
//  TransportArbiterTests.swift
//  GyroSteer - Mac Receiver Tests
//

import Foundation
#if canImport(XCTest)
import XCTest
#endif
#if canImport(GyroSteerMacCore)
@testable import GyroSteerMacCore
#endif
#if canImport(GyroSteerShared)
@testable import GyroSteerShared
#endif

public final class TransportArbiterTests {

    public static func runAllTests() {
        print("▶ Running TransportArbiterTests...")
        testTransportPriorityAndHandover()
        testSequenceDeduplication()
        testOutputCoordinatorTuning()
        testConnectionPreferenceFiltering()
        print("✔ All TransportArbiterTests passed successfully!")
    }

    public static func testTransportPriorityAndHandover() {
        let arbiter = TransportArbiter()

        // Dummy transport conforming to ReceiverTransport
        class DummyTransport: ReceiverTransport {
            var transportType: TransportType = .wifi
            var isListening: Bool = true
            weak var delegate: (any ReceiverTransportDelegate)?
            func start() {}
            func stop() {}
        }
        let dummy = DummyTransport()

        // 1. Send BLE packet
        let p1 = SteeringPacket(sequenceID: 1, steeringAngle: 0.1, throttle: 100, brake: 0)
        arbiter.transport(dummy, didReceive: p1, on: .ble, sourceDescription: "BLE")

        // 2. Send Wi-Fi packet (higher priority than BLE)
        let p2 = SteeringPacket(sequenceID: 2, steeringAngle: 0.2, throttle: 200, brake: 0)
        arbiter.transport(dummy, didReceive: p2, on: .wifi, sourceDescription: "Wi-Fi")
        assert(arbiter.totalPacketsReceived >= 2, "Both higher priority packets should be received")

        // 3. Send USB packet (highest priority)
        let p3 = SteeringPacket(sequenceID: 3, steeringAngle: 0.3, throttle: 300, brake: 0)
        arbiter.transport(dummy, didReceive: p3, on: .usb, sourceDescription: "USB")
        assert(arbiter.totalPacketsReceived >= 3, "USB packet must be accepted")

        // 4. Send Wi-Fi packet while USB is active -> should be dropped
        let p4 = SteeringPacket(sequenceID: 4, steeringAngle: 0.4, throttle: 400, brake: 0)
        let initialDrops = arbiter.droppedPacketsCount
        arbiter.transport(dummy, didReceive: p4, on: .wifi, sourceDescription: "Wi-Fi")
        assert(arbiter.droppedPacketsCount > initialDrops, "Wi-Fi packet while USB is active must be dropped by arbiter")
    }

    public static func testSequenceDeduplication() {
        let arbiter = TransportArbiter()

        class DummyTransport: ReceiverTransport {
            var transportType: TransportType = .usb
            var isListening: Bool = true
            weak var delegate: (any ReceiverTransportDelegate)?
            func start() {}
            func stop() {}
        }
        let dummy = DummyTransport()

        // Send sequence 100
        let p1 = SteeringPacket(sequenceID: 100, steeringAngle: 0.5, throttle: 0, brake: 0)
        arbiter.transport(dummy, didReceive: p1, on: .usb, sourceDescription: "USB")

        // Send duplicate sequence 100
        let dropsBefore = arbiter.droppedPacketsCount
        arbiter.transport(dummy, didReceive: p1, on: .usb, sourceDescription: "USB")
        assert(arbiter.droppedPacketsCount == dropsBefore + 1, "Duplicate packet must be dropped")

        // Send stale sequence 95
        let pStale = SteeringPacket(sequenceID: 95, steeringAngle: 0.2, throttle: 0, brake: 0)
        arbiter.transport(dummy, didReceive: pStale, on: .usb, sourceDescription: "USB")
        assert(arbiter.droppedPacketsCount == dropsBefore + 2, "Stale sequence packet must be dropped")

        // Send newer sequence 101
        let pNew = SteeringPacket(sequenceID: 101, steeringAngle: 0.6, throttle: 0, brake: 0)
        arbiter.transport(dummy, didReceive: pNew, on: .usb, sourceDescription: "USB")
        assert(arbiter.droppedPacketsCount == dropsBefore + 2, "Newer sequence must be accepted")
    }

    public static func testOutputCoordinatorTuning() {
        let coordinator = OutputCoordinator()
        assert(coordinator.activeMode == .virtualGamepad, "Default mode should be virtualGamepad")

        coordinator.switchOutputMode(to: .keyboardEmulation)
        assert(coordinator.activeMode == .keyboardEmulation, "Mode switch to keyboardEmulation failed")

        coordinator.recalibrate(currentAngle: 0.25)
        assert(coordinator.localZeroOffset == 0.25, "Recalibration offset should be saved")

        coordinator.resetCalibration()
        assert(coordinator.localZeroOffset == 0.0, "Reset calibration failed")
    }

    public static func testConnectionPreferenceFiltering() {
        let arbiter = TransportArbiter()
        class DummyTransport: ReceiverTransport {
            var transportType: TransportType = .wifi
            var isListening: Bool = true
            weak var delegate: (any ReceiverTransportDelegate)?
            func start() {}
            func stop() {}
        }
        let dummy = DummyTransport()

        // Set preference to USB only
        arbiter.connectionPreference = .usb

        // Send Wi-Fi packet -> should be ignored because preference is USB
        let pWifi = SteeringPacket(sequenceID: 10, steeringAngle: 0.1, throttle: 0, brake: 0)
        let countBefore = arbiter.totalPacketsReceived
        arbiter.transport(dummy, didReceive: pWifi, on: .wifi, sourceDescription: "Wi-Fi")
        assert(arbiter.totalPacketsReceived == countBefore, "Wi-Fi packet must be rejected when preference is USB")

        // Send USB packet -> should be accepted
        let pUsb = SteeringPacket(sequenceID: 11, steeringAngle: 0.2, throttle: 0, brake: 0)
        arbiter.transport(dummy, didReceive: pUsb, on: .usb, sourceDescription: "USB")
        assert(arbiter.totalPacketsReceived == countBefore + 1, "USB packet must be accepted when preference is USB")

        // Set preference to Wi-Fi only
        arbiter.connectionPreference = .wifi
        let pUsb2 = SteeringPacket(sequenceID: 12, steeringAngle: 0.3, throttle: 0, brake: 0)
        arbiter.transport(dummy, didReceive: pUsb2, on: .usb, sourceDescription: "USB")
        assert(arbiter.totalPacketsReceived == countBefore + 1, "USB packet must be rejected when preference is Wi-Fi")

        let pWifi2 = SteeringPacket(sequenceID: 13, steeringAngle: 0.4, throttle: 0, brake: 0)
        arbiter.transport(dummy, didReceive: pWifi2, on: .wifi, sourceDescription: "Wi-Fi")
        assert(arbiter.totalPacketsReceived == countBefore + 2, "Wi-Fi packet must be accepted when preference is Wi-Fi")
    }
}
