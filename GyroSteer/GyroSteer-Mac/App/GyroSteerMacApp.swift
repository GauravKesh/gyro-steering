//
//  GyroSteerMacApp.swift
//  GyroSteer - macOS Receiver
//
//  SwiftUI App entry point with native WindowGroup Dashboard and MenuBarExtra.
//

import SwiftUI

#if os(macOS)
#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

@main
struct GyroSteerMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sharedArbiter: TransportArbiter
    @StateObject private var sharedCoordinator: OutputCoordinator

    init() {
        let arbiter = TransportArbiter()
        let coordinator = OutputCoordinator()

        if !coordinator.gamepadDriver.isDeviceActive {
            coordinator.switchOutputMode(to: .keyboardEmulation)
        }

        arbiter.onPacketAccepted = { [weak coordinator] packet, _ in
            coordinator?.processIncomingPacket(packet)
        }
        arbiter.start()

        _sharedArbiter = StateObject(wrappedValue: arbiter)
        _sharedCoordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        WindowGroup("GyroSteer Dashboard") {
            DashboardView(arbiter: sharedArbiter, coordinator: sharedCoordinator)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("GyroSteer", systemImage: "steeringwheel") {
            MenuBarView(arbiter: sharedArbiter, coordinator: sharedCoordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
#endif
