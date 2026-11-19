//
//  AccessibilityPermissionHelper.swift
//  GyroSteer - macOS Receiver
//
//  Verifies and requests macOS Accessibility permissions for CGEvent keyboard injection.
//

import Foundation
import ApplicationServices
import AppKit

public enum AccessibilityPermissionHelper {
    /// Checks whether the application currently has Accessibility permissions.
    public static var isAccessibilityGranted: Bool {
        return AXIsProcessTrusted()
    }

    /// Prompts the user with system dialog to grant Accessibility permissions.
    @discardableResult
    public static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Accessibility.
    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
