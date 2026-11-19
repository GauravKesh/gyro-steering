//
//  GyroSteerIOSApp.swift
//  GyroSteer - iOS Transmitter
//
//  SwiftUI App entry point for iOS.
//

import SwiftUI

#if os(iOS)
@main
struct GyroSteerIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            CockpitView()
                .preferredColorScheme(.dark)
        }
    }
}
#endif
