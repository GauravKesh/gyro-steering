//
//  AppDelegate.swift
//  GyroSteer - macOS Receiver
//
//  Application lifecycle and menu handling for macOS.
//

#if os(macOS)
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app window stays responsive and activates to the foreground
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Return false so MenuBarExtra keeps streaming even if the dashboard window is closed
        return false
    }
}
#endif
