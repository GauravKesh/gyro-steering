//
//  HapticManager.swift
//  GyroSteer - iOS Transmitter
//
//  Tactile haptic feedback for pedals, detents, and simulator controls.
//

import Foundation

#if os(iOS)
import UIKit

@MainActor
public final class HapticManager: ObservableObject {
    public static let shared = HapticManager()

    @Published public var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "gyrosteer.haptics.enabled")
        }
    }

    @Published public var enableCenterDetent: Bool = true {
        didSet {
            UserDefaults.standard.set(enableCenterDetent, forKey: "gyrosteer.haptics.centerDetent")
        }
    }

    @Published public var enablePedalNotches: Bool = true {
        didSet {
            UserDefaults.standard.set(enablePedalNotches, forKey: "gyrosteer.haptics.pedalNotches")
        }
    }

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private var lastCenterDetentTime: TimeInterval = 0

    private init() {
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.enabled") != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.enabled")
        }
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.centerDetent") != nil {
            self.enableCenterDetent = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.centerDetent")
        }
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.pedalNotches") != nil {
            self.enablePedalNotches = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.pedalNotches")
        }
        prepare()
    }

    public func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        selection.prepare()
    }

    /// Triggered when pedals move through graduation notches
    public func pedalTick() {
        guard isEnabled && enablePedalNotches else { return }
        lightImpact.impactOccurred(intensity: 0.6)
    }

    /// Triggered when pedal hits 100% full floor
    public func pedalFloor() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred(intensity: 0.9)
    }

    /// Triggered on standard button taps
    public func buttonTap() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred(intensity: 0.8)
    }

    /// Distinct mechanical clack for toggle switches (Lights, Wipers, Hazards)
    public func toggleSwitch(active: Bool) {
        guard isEnabled else { return }
        if active {
            rigidImpact.impactOccurred(intensity: 0.9)
        } else {
            softImpact.impactOccurred(intensity: 0.7)
        }
    }

    /// Heavy tactile snap on gear shifts (Left Shift / Left Ctrl)
    public func gearShift() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred(intensity: 1.0)
    }

    /// Double rumble on engine ignition start/stop
    public func engineIgnition() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.mediumImpact.impactOccurred(intensity: 0.8)
        }
    }

    /// Solid mechanical lock on parking brake / handbrake
    public func parkingBrake() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred(intensity: 1.0)
    }

    /// High energy double pulse for Nitro Boost in arcade racers
    public func nitroBoost() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.heavyImpact.impactOccurred(intensity: 0.9)
        }
    }

    /// Triggered when steering passes through 0° center detent (debounced to 120ms)
    public func centerDetent() {
        guard isEnabled && enableCenterDetent else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastCenterDetentTime > 0.12 {
            lastCenterDetentTime = now
            selection.selectionChanged()
        }
    }

    /// Triggered on calibration / recenter action
    public func calibrationSuccess() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }
}
#else
@MainActor
public final class HapticManager: ObservableObject {
    public static let shared = HapticManager()
    @Published public var isEnabled: Bool = true
    @Published public var enableCenterDetent: Bool = true
    @Published public var enablePedalNotches: Bool = true

    public func pedalTick() {}
    public func pedalFloor() {}
    public func buttonTap() {}
    public func toggleSwitch(active: Bool) {}
    public func gearShift() {}
    public func engineIgnition() {}
    public func parkingBrake() {}
    public func nitroBoost() {}
    public func centerDetent() {}
    public func calibrationSuccess() {}
}
#endif
