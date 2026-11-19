//
//  HapticManager.swift
//  GyroSteer - iOS Transmitter
//
//  High-Fidelity Dynamic Driving CoreHaptics Engine.
//  Simulates realistic diesel engine RPM rumble, ABS emergency brake chatter,
//  steering rack lock bump-stops, progressive pedal notches, and turn signal tick-tocks.
//

import Foundation

#if os(iOS)
import UIKit
import CoreHaptics

@MainActor
public final class HapticManager: ObservableObject {
    public static let shared = HapticManager()

    // MARK: - User Settings & Preferences

    @Published public var isEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "gyrosteer.haptics.enabled") }
    }

    @Published public var masterIntensity: Double = 1.0 {
        didSet { UserDefaults.standard.set(masterIntensity, forKey: "gyrosteer.haptics.masterIntensity") }
    }

    @Published public var enableEngineRumble: Bool = true {
        didSet {
            UserDefaults.standard.set(enableEngineRumble, forKey: "gyrosteer.haptics.engineRumble")
            if !enableEngineRumble { stopEngineRumble() }
        }
    }

    @Published public var enableABSPulse: Bool = true {
        didSet { UserDefaults.standard.set(enableABSPulse, forKey: "gyrosteer.haptics.absPulse") }
    }

    @Published public var enableSteeringLockBumper: Bool = true {
        didSet { UserDefaults.standard.set(enableSteeringLockBumper, forKey: "gyrosteer.haptics.steeringLockBumper") }
    }

    @Published public var enableCenterDetent: Bool = true {
        didSet { UserDefaults.standard.set(enableCenterDetent, forKey: "gyrosteer.haptics.centerDetent") }
    }

    @Published public var enablePedalNotches: Bool = true {
        didSet { UserDefaults.standard.set(enablePedalNotches, forKey: "gyrosteer.haptics.pedalNotches") }
    }

    @Published public var enableBlinkerTicks: Bool = true {
        didSet { UserDefaults.standard.set(enableBlinkerTicks, forKey: "gyrosteer.haptics.blinkerTicks") }
    }

    // MARK: - CoreHaptics Engine & Players

    private var hapticEngine: CHHapticEngine?
    private var engineRumblePlayer: CHHapticAdvancedPatternPlayer?
    private var centerDetentPattern: CHHapticPattern?
    private var isEngineRumblePlaying: Bool = false

    // Dynamic State Tracking
    private var lastCenterDetentTime: TimeInterval = 0
    private var lastABSPulseTime: TimeInterval = 0
    private var hasHitSteeringLock: Bool = false
    private var wasCentered: Bool = true
    private var lastBlinkerTickTime: TimeInterval = 0
    private var blinkerToggle: Bool = false

    // UIKit Fallback Generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    // MARK: - Initialization

    private init() {
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.enabled") != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.enabled")
        }
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.masterIntensity") != nil {
            self.masterIntensity = UserDefaults.standard.double(forKey: "gyrosteer.haptics.masterIntensity")
        }
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.engineRumble") != nil {
            self.enableEngineRumble = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.engineRumble")
        }
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.absPulse") != nil {
            self.enableABSPulse = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.absPulse")
        }
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.steeringLockBumper") != nil {
            self.enableSteeringLockBumper = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.steeringLockBumper")
        }
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.centerDetent") != nil {
            self.enableCenterDetent = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.centerDetent")
        }
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.pedalNotches") != nil {
            self.enablePedalNotches = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.pedalNotches")
        }
        if UserDefaults.standard.object(forKey: "gyrosteer.haptics.blinkerTicks") != nil {
            self.enableBlinkerTicks = UserDefaults.standard.bool(forKey: "gyrosteer.haptics.blinkerTicks")
        }

        prepare()
        setupCoreHaptics()
    }

    public func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        selection.prepare()
    }

    private func setupCoreHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true

            engine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    try? self?.hapticEngine?.start()
                }
            }

            try engine.start()
            self.hapticEngine = engine
            prepareEngineRumblePlayer()
            prepareCenterDetentPattern()
        } catch {
            self.hapticEngine = nil
        }
    }

    private func prepareCenterDetentPattern() {
        guard hapticEngine != nil else { return }

        // Apple F1 Movie / Cinematic Spatial Steering Center Detent Pattern:
        // Event 1: High-attack mechanical latch transient (0ms, 100% intensity, 95% sharpness)
        let strikeIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let strikeSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95)
        let strikeEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [strikeIntensity, strikeSharpness],
            relativeTime: 0
        )

        // Event 2: Low-frequency chassis resonance decay (12ms -> 45ms, 45% intensity, 15% sharpness)
        let rumbleIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45)
        let rumbleSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
        let rumbleEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [rumbleIntensity, rumbleSharpness],
            relativeTime: 0.012,
            duration: 0.035
        )

        // Event 3: Secondary settling lock-in notch (22ms, 70% intensity, 35% sharpness)
        let settleIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.70)
        let settleSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
        let settleEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [settleIntensity, settleSharpness],
            relativeTime: 0.022
        )

        do {
            self.centerDetentPattern = try CHHapticPattern(events: [strikeEvent, rumbleEvent, settleEvent], parameters: [])
        } catch {
            self.centerDetentPattern = nil
        }
    }

    private func prepareEngineRumblePlayer() {
        guard let engine = hapticEngine else { return }

        // Continuous low-frequency rumble event simulating diesel engine cylinder firing
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.15)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)

        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0,
            duration: 30.0
        )

        do {
            let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            self.engineRumblePlayer = player
        } catch {
            self.engineRumblePlayer = nil
        }
    }

    // MARK: - Dynamic Telemetry Loop (Called at 100Hz from TransmissionCoordinator)

    public func updateDrivingDynamics(
        throttle: Float,
        brake: Float,
        normalizedSteering: Float,
        isEngineRunning: Bool,
        isBlinkerActive: Bool
    ) {
        guard isEnabled else {
            stopEngineRumble()
            return
        }

        // 1. Engine RPM Continuous Rumble
        updateEngineRumble(throttle: throttle, isEngineRunning: isEngineRunning)

        // 2. ABS Brake Chatter
        triggerABSPulse(brake: brake)

        // 3. Steering Lock Bump-Stop
        checkSteeringLockBumper(normalizedSteering: normalizedSteering)

        // 4. Center 0° Detent
        checkCenterDetent(normalizedSteering: normalizedSteering)

        // 5. Turn Signal Tick-Tock
        if isBlinkerActive {
            blinkerTick()
        }
    }

    // MARK: - 1. Engine RPM Continuous Rumble

    public func updateEngineRumble(throttle: Float, isEngineRunning: Bool) {
        guard isEnabled && enableEngineRumble, isEngineRunning else {
            stopEngineRumble()
            return
        }

        // Scaling: Idle hum = 0.10, Scaling to 0.70 at 100% full throttle * masterIntensity
        let targetIntensity = Float(masterIntensity) * (0.10 + (throttle * 0.55))
        let targetSharpness = 0.18 + (throttle * 0.45) // Higher RPM feels crisper

        if !isEngineRumblePlaying {
            do {
                try hapticEngine?.start()
                try engineRumblePlayer?.start(atTime: CHHapticTimeImmediate)
                isEngineRumblePlaying = true
            } catch {
                return
            }
        }

        guard let player = engineRumblePlayer else { return }
        let intensityParam = CHHapticDynamicParameter(
            parameterID: .hapticIntensityControl,
            value: targetIntensity,
            relativeTime: 0
        )
        let sharpnessParam = CHHapticDynamicParameter(
            parameterID: .hapticSharpnessControl,
            value: targetSharpness,
            relativeTime: 0
        )
        try? player.sendParameters([intensityParam, sharpnessParam], atTime: CHHapticTimeImmediate)
    }

    public func stopEngineRumble() {
        guard isEngineRumblePlaying, let player = engineRumblePlayer else { return }
        try? player.stop(atTime: CHHapticTimeImmediate)
        isEngineRumblePlaying = false
    }

    // MARK: - 2. ABS Brake Chatter (>75% Heavy Braking)

    public func triggerABSPulse(brake: Float) {
        guard isEnabled && enableABSPulse, brake > 0.75 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // Pulsing at ~14Hz (every 70ms) simulating ABS hydraulic pump pulsations
        guard now - lastABSPulseTime > 0.07 else { return }
        lastABSPulseTime = now

        let strength = Float(masterIntensity) * ((brake - 0.75) / 0.25)
        playTransient(intensity: 0.55 + (strength * 0.45), sharpness: 0.90)
    }

    // MARK: - 3. Steering Rack Lock Bump-Stop (Physical Collision at ±45°/Max Angle)

    public func checkSteeringLockBumper(normalizedSteering: Float) {
        guard isEnabled && enableSteeringLockBumper else { return }
        let isAtLock = abs(normalizedSteering) >= 0.98
        if isAtLock && !hasHitSteeringLock {
            hasHitSteeringLock = true
            // Solid, heavy mechanical thud
            rigidImpact.impactOccurred(intensity: CGFloat(masterIntensity * 1.0))
        } else if !isAtLock && abs(normalizedSteering) < 0.92 {
            // Hysteresis reset
            hasHitSteeringLock = false
        }
    }

    // MARK: - 4. Steering Center Detent (Apple F1 Movie Spatial Magnetic Notch)

    public func checkCenterDetent(normalizedSteering: Float) {
        guard isEnabled && enableCenterDetent else { return }
        let isNowCentered = abs(normalizedSteering) < 0.022
        if isNowCentered && !wasCentered {
            wasCentered = true
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastCenterDetentTime > 0.08 {
                lastCenterDetentTime = now
                playAppleF1CenterDetent()
            }
        } else if !isNowCentered && abs(normalizedSteering) > 0.038 {
            if wasCentered {
                // Subtle mechanical breakaway sensation when overcoming the centering spring
                softImpact.impactOccurred(intensity: CGFloat(masterIntensity * 0.40))
            }
            wasCentered = false
        }
    }

    /// Plays Apple F1 Movie / Cinematic Spatial Magnetic Centering Detent
    public func playAppleF1CenterDetent() {
        guard isEnabled && enableCenterDetent else { return }

        if let engine = hapticEngine, let pattern = centerDetentPattern {
            do {
                try engine.start()
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                // Fall through to dual-stage mechanical impact
            }
        }

        // Dual-Stage Mechanical Impact Fallback (Solid strike + resonance settle)
        rigidImpact.impactOccurred(intensity: CGFloat(masterIntensity * 1.0))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.022) { [weak self] in
            guard let self = self else { return }
            self.mediumImpact.impactOccurred(intensity: CGFloat(self.masterIntensity * 0.6))
        }
    }

    public func centerDetent() {
        playAppleF1CenterDetent()
    }

    // MARK: - 5. Turn Signal "Tick-Tock" (Alternating Blinker Audio-Haptic)

    public func blinkerTick() {
        guard isEnabled && enableBlinkerTicks else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastBlinkerTickTime > 0.35 else { return }
        lastBlinkerTickTime = now

        blinkerToggle.toggle()
        if blinkerToggle {
            // Crisp "Tick"
            lightImpact.impactOccurred(intensity: CGFloat(masterIntensity * 0.75))
        } else {
            // Deeper "Tock"
            softImpact.impactOccurred(intensity: CGFloat(masterIntensity * 0.50))
        }
    }

    // MARK: - Discrete Driver Controls (Pedals, Gear Shifts, Switches)

    /// Triggered when pedals move through graduation notches
    public func pedalTick() {
        guard isEnabled && enablePedalNotches else { return }
        lightImpact.impactOccurred(intensity: CGFloat(masterIntensity * 0.6))
    }

    /// Triggered when pedal hits 100% full floor
    public func pedalFloor() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred(intensity: CGFloat(masterIntensity * 0.9))
    }

    /// Triggered on standard button taps
    public func buttonTap() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred(intensity: CGFloat(masterIntensity * 0.8))
    }

    /// Distinct mechanical clack for toggle switches (Lights, Wipers, Hazards)
    public func toggleSwitch(active: Bool) {
        guard isEnabled else { return }
        if active {
            rigidImpact.impactOccurred(intensity: CGFloat(masterIntensity * 0.9))
        } else {
            softImpact.impactOccurred(intensity: CGFloat(masterIntensity * 0.7))
        }
    }

    /// Heavy tactile snap on gear shifts (Left Shift / Left Ctrl)
    public func gearShift() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred(intensity: CGFloat(masterIntensity * 1.0))
    }

    /// Double rumble on engine ignition start/stop
    public func engineIgnition() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred(intensity: CGFloat(masterIntensity * 1.0))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self else { return }
            self.mediumImpact.impactOccurred(intensity: CGFloat(self.masterIntensity * 0.8))
        }
    }

    /// Solid mechanical lock on parking brake / handbrake
    public func parkingBrake() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred(intensity: CGFloat(masterIntensity * 1.0))
    }

    /// High energy double pulse for Nitro Boost in arcade racers
    public func nitroBoost() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred(intensity: CGFloat(masterIntensity * 1.0))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self = self else { return }
            self.heavyImpact.impactOccurred(intensity: CGFloat(self.masterIntensity * 0.9))
        }
    }

    /// Triggered on calibration / recenter action
    public func calibrationSuccess() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    // MARK: - CoreHaptics Helper

    private func playTransient(intensity: Float, sharpness: Float) {
        let scaledIntensity = min(1.0, max(0.0, intensity * Float(masterIntensity)))
        if let engine = hapticEngine {
            let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: scaledIntensity)
            let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
            if let pattern = try? CHHapticPattern(events: [event], parameters: []),
               let player = try? engine.makePlayer(with: pattern) {
                try? player.start(atTime: CHHapticTimeImmediate)
                return
            }
        }
        mediumImpact.impactOccurred(intensity: CGFloat(scaledIntensity))
    }
}
#else
@MainActor
public final class HapticManager: ObservableObject {
    public static let shared = HapticManager()
    @Published public var isEnabled: Bool = true
    @Published public var masterIntensity: Double = 1.0
    @Published public var enableEngineRumble: Bool = true
    @Published public var enableABSPulse: Bool = true
    @Published public var enableSteeringLockBumper: Bool = true
    @Published public var enableCenterDetent: Bool = true
    @Published public var enablePedalNotches: Bool = true
    @Published public var enableBlinkerTicks: Bool = true

    public func pedalTick() {}
    public func pedalFloor() {}
    public func buttonTap() {}
    public func toggleSwitch(active: Bool) {}
    public func gearShift() {}
    public func engineIgnition() {}
    public func parkingBrake() {}
    public func nitroBoost() {}
    public func centerDetent() {}
    public func playAppleF1CenterDetent() {}
    public func calibrationSuccess() {}
    public func updateDrivingDynamics(throttle: Float, brake: Float, normalizedSteering: Float, isEngineRunning: Bool, isBlinkerActive: Bool) {}
    public func stopEngineRumble() {}
}
#endif
