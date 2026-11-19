//
//  KeyboardMouseEmulator.swift
//  GyroSteer - macOS Receiver
//
//  Zero-driver keyboard fallback with high-frequency Pulse-Width Modulation (PWM)
//  for proportional analog steering, throttle, and brake using CGEvent.
//

import Foundation
import CoreGraphics
import AppKit

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public final class KeyboardMouseEmulator: InputInjector, @unchecked Sendable {
    public let outputMode: OutputMode = .keyboardEmulation
    public private(set) var isRunning: Bool = false
    public var isDrivingActive: Bool = true

    /// When true, steering is injected as smooth analog mouse X-delta (ETS2 Mouse Steering mode).
    /// Eliminates A/D key typing and gives 100% smooth, analog steering in Euro Truck Simulator 2!
    public var useMouseSteering: Bool = true
    public var steeringSensitivity: Double = 900.0
    private var currentVirtualSteering: Float = 0.0

    /// Steering sensitivity multiplier for keyboard / arcade mode (default 2.5x so a gentle 8°-12° tilt steers fully)
    public var keyboardSteeringGain: Float = 2.5
    private let eventSource = CGEventSource(stateID: .combinedSessionState)

    // MARK: - Keycodes (macOS Virtual Keycodes)
    // Steering: A (0) / D (2) or Left (123) / Right (124)
    public var keyLeft: CGKeyCode = 0       // 'A'
    public var keyRight: CGKeyCode = 2      // 'D'
    public var keyThrottle: CGKeyCode = 13  // 'W'
    public var keyBrake: CGKeyCode = 1      // 'S'

    // Universal Secondary Keys for Arcade / Asphalt compatibility
    public var keyLeftArrow: CGKeyCode = 123   // Left Arrow
    public var keyRightArrow: CGKeyCode = 124  // Right Arrow
    public var keyUpArrow: CGKeyCode = 126     // Up Arrow
    public var keyDownArrow: CGKeyCode = 125   // Down Arrow
    public var keySpace: CGKeyCode = 49        // Spacebar (Nitro)
    public var keyNitroN: CGKeyCode = 45       // 'N' (Nitro in Asphalt)
    public var keyShift: CGKeyCode = 56        // Shift (Drift)

    // Simulator Action Keys (ETS2 Defaults)
    public var keyLeftBlinker: CGKeyCode = 33   // '[' (Left Blinker)
    public var keyRightBlinker: CGKeyCode = 30  // ']' (Right Blinker)
    public var keyHorn: CGKeyCode = 4           // 'H' (Standard Horn)
    public var keyAirHorn: CGKeyCode = 45       // 'N' (Air Horn in ETS2)
    public var keyHeadlights: CGKeyCode = 37    // 'L' (Headlights)
    public var keyHighBeams: CGKeyCode = 40     // 'K' (High Beams)
    public var keyHazard: CGKeyCode = 3         // 'F' (Hazard Warning Lights)
    public var keyWipers: CGKeyCode = 35        // 'P' (Windshield Wipers)
    public var keyEngineStart: CGKeyCode = 14   // 'E' (Engine Start / Stop)
    public var keyParkingBrake: CGKeyCode = 49  // Spacebar (Parking Brake / Handbrake)
    public var keyTrailerAttach: CGKeyCode = 17 // 'T' (Trailer Attach / Detach)
    public var keyGearUp: CGKeyCode = 56        // Left Shift (Gear Shift Up)
    public var keyGearDown: CGKeyCode = 59      // Left Control (Gear Shift Down)
    public var keyCruise: CGKeyCode = 8         // 'C' (Cruise Control)
    public var keyCameraView: CGKeyCode = 18    // '1' (Interior Cockpit Camera)
    public var keyRespawn: CGKeyCode = 15       // 'R' (Respawn in Asphalt 8)
    public var keyEnter: CGKeyCode = 36         // Return / Enter (Toll booth, Ferry, Jobs, Gas stations)
    public var keyTransmissionMode: CGKeyCode = 5 // 'G' (Gearbox Switch Automatic / Sequential in ETS2)
    public var keyRetarderDown: CGKeyCode = 41  // ';' (Retarder Decrease in ETS2)
    public var keyRetarderUp: CGKeyCode = 39    // '\'' (Retarder Increase in ETS2)
    public var keyEngineBrake: CGKeyCode = 11   // 'B' (Engine Brake Toggle in ETS2)
    public var keyNeutral: CGKeyCode = 45       // 'N' (Shift to Neutral in ETS2)
    public var keyCabinView: CGKeyCode = 18     // '1' (Interior Cockpit / Cabin View in ETS2)
    public var keyRouteAdvisor: CGKeyCode = 99  // 'F3' (Route Advisor Display Modes in ETS2)
    public var keyMapZoom: CGKeyCode = 96       // 'F5' (Route Advisor Navigation Map Zoom in ETS2)
    public var keyWorldMap: CGKeyCode = 46      // 'M' (World Map in ETS2)

    // Camera View Cycling (1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 1)
    private var currentCameraIndex: Int = 1
    private let cameraKeycodes: [(index: Int, code: CGKeyCode, name: String)] = [
        (1, 18, "1 (Cabin / Cockpit)"),
        (2, 19, "2 (Chase / Behind Truck)"),
        (3, 20, "3 (Top-Down Bird's Eye)"),
        (4, 21, "4 (Roof Mount)"),
        (5, 23, "5 (Window / Lean Out)"),
        (6, 22, "6 (Front Bumper)")
    ]

    private let lock = NSLock()
    private var currentPacket: SteeringPacket = SteeringPacket()
    private var previousButtons: SteeringButtons = []

    private var pwmTimer: DispatchSourceTimer?
    private let pwmQueue = DispatchQueue(label: "com.gyrosteer.pwmemulator", qos: .userInteractive)

    // PWM Frequency: 50Hz = 20ms period
    private let pwmPeriodMs: Double = 20.0

    // Diagnostic State Tracking for EventLogger
    private var lastLoggedApp: String = ""
    private var lastSteerLogState: String = ""
    private var lastThrottleState: Bool = false
    private var lastBrakeState: Bool = false
    private var lastSteerLeftState: Bool = false
    private var lastSteerRightState: Bool = false

    // System-wide Performance Fix: Cache frontmost app via NSWorkspace notifications
    // Eliminates 50Hz synchronous Mach IPC roundtrips to WindowServer!
    private var workspaceObserver: NSObjectProtocol?
    private var cachedFrontmostAppIsBlocked: Bool = false
    private let focusLock = NSLock()
    private var areKeysReleased: Bool = true

    public init() {
        updateFrontmostAppState()
        self.workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.updateFrontmostAppState()
        }
    }

    deinit {
        stop()
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    public func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return true }

        if !AccessibilityPermissionHelper.isAccessibilityGranted {
            print("[KeyboardMouseEmulator] ⚠️ Accessibility permission NOT granted! Keystrokes cannot be posted until authorized.")
            EventLogger.shared.log("EMULATOR: ⚠️ Accessibility NOT granted! Events will be blocked by macOS until authorized.")
            AccessibilityPermissionHelper.requestAccessibilityPermission()
            AccessibilityPermissionHelper.openAccessibilitySettings()
        } else {
            print("[KeyboardMouseEmulator] ✔ Accessibility permission confirmed. 50Hz PWM keyboard emulation active.")
            EventLogger.shared.log("EMULATOR: Started. Mode=\(useMouseSteering ? "MouseSteering" : "Keyboard/Arcade"). Accessibility=GRANTED.")
        }

        startPWMTimer()
        isRunning = true
        return true
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        pwmTimer?.cancel()
        pwmTimer = nil

        // Release all keys
        releaseAllKeys()
        isRunning = false
    }

    public func inject(packet: SteeringPacket) {
        lock.lock()
        let oldButtons = self.previousButtons
        self.currentPacket = packet
        self.previousButtons = packet.buttons
        lock.unlock()

        // Handle edge-triggered simulator buttons
        handleButtonDeltas(oldButtons: oldButtons, newButtons: packet.buttons)
    }

    // MARK: - Proportional PWM Loop (50Hz)

    private func startPWMTimer() {
        let timer = DispatchSource.makeTimerSource(queue: pwmQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(Int(pwmPeriodMs)))

        timer.setEventHandler { [weak self] in
            self?.executePWMFrame()
        }

        self.pwmTimer = timer
        timer.resume()
    }

    private func executePWMFrame() {
        guard isDrivingActive else {
            releaseAllKeys()
            return
        }

        // Smart Focus Filter: Completely silent when on desktop, browser, or coding IDE!
        guard shouldInjectForFrontmostApp() else {
            releaseAllKeys()
            return
        }

        lock.lock()
        let packet = currentPacket
        lock.unlock()

        // Automatically switch between ETS2 Mouse Steering and Arcade Keyboard Steering
        if packet.buttons.contains(.arcadeProfile) {
            if useMouseSteering {
                useMouseSteering = false
                EventLogger.shared.log("PROFILE: AUTO-SWITCHED TO ARCADE KEYBOARD (Asphalt)")
            }
        } else {
            if !useMouseSteering {
                useMouseSteering = true
                EventLogger.shared.log("PROFILE: AUTO-SWITCHED TO MOUSE STEERING (ETS2)")
            }
        }

        let rawSteer = packet.steeringAngle
        let steer = useMouseSteering ? rawSteer : max(-1.0, min(1.0, rawSteer * keyboardSteeringGain))
        let throttleNorm = packet.normalizedThrottle
        let brakeNorm = packet.normalizedBrake

        // 1. Steering Output
        if useMouseSteering {
            // Analog Mouse Steering for ETS2:
            // Closed-loop tracking of target normalized angle (-1.0 ... +1.0) into smooth delta X mouse movements
            let targetNormalized = steer
            let deltaNorm = targetNormalized - currentVirtualSteering
            let deltaPixels = Int32(deltaNorm * Float(steeringSensitivity))
            if abs(deltaPixels) >= 1 {
                postMouseDeltaX(deltaPixels)
                currentVirtualSteering += Float(deltaPixels) / Float(steeringSensitivity)
            }
        } else {
            // Arcade Steering (Asphalt & Fast Racers):
            // State-based solid keyboard hold for 100% responsiveness without frame drops
            let isLeft = steer < -0.05
            let isRight = steer > 0.05

            if isLeft != lastSteerLeftState {
                lastSteerLeftState = isLeft
                postKey(keyLeft, down: isLeft)
                postKey(keyLeftArrow, down: isLeft)
            }

            if isRight != lastSteerRightState {
                lastSteerRightState = isRight
                postKey(keyRight, down: isRight)
                postKey(keyRightArrow, down: isRight)
            }

            // Diagnostic logging on steer state transition
            var currentSteerState = "CENTER"
            if isLeft {
                currentSteerState = "LEFT [A + LeftArrow DOWN]"
            } else if isRight {
                currentSteerState = "RIGHT [D + RightArrow DOWN]"
            }

            if currentSteerState != lastSteerLogState {
                lastSteerLogState = currentSteerState
                EventLogger.shared.log("STEER: \(currentSteerState) (Raw=\(String(format: "%.2f", rawSteer)), Effective=\(String(format: "%.2f", steer)))")
            }
        }

        // 2. Throttle Output (Edge-triggered state transition)
        let isThrottle = throttleNorm > 0.08
        if isThrottle != lastThrottleState {
            lastThrottleState = isThrottle
            if useMouseSteering {
                postKey(keyThrottle, down: isThrottle)
            } else {
                postKey(keyThrottle, down: isThrottle)
                postKey(keyUpArrow, down: isThrottle)
            }
            EventLogger.shared.log("THROTTLE: \(isThrottle ? "PRESSED" : "RELEASED") [\(useMouseSteering ? "W" : "W + UpArrow")] (Val=\(String(format: "%.2f", throttleNorm)))")
        }

        // 3. Brake Output (Edge-triggered state transition)
        let isBrake = brakeNorm > 0.08
        if isBrake != lastBrakeState {
            lastBrakeState = isBrake
            if useMouseSteering {
                postKey(keyBrake, down: isBrake)
            } else {
                postKey(keyBrake, down: isBrake)
                postKey(keyDownArrow, down: isBrake)
            }
            EventLogger.shared.log("BRAKE: \(isBrake ? "PRESSED" : "RELEASED") [\(useMouseSteering ? "S" : "S + DownArrow")] (Val=\(String(format: "%.2f", brakeNorm)))")
        }
    }

    private func postMouseDeltaX(_ dx: Int32) {
        guard dx != 0 else { return }
        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let centerPoint = CGPoint(x: screen.midX, y: screen.midY)

        guard let event = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .mouseMoved,
            mouseCursorPosition: centerPoint,
            mouseButton: .left
        ) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx))
        event.setIntegerValueField(.mouseEventDeltaY, value: 0)
        event.post(tap: .cghidEventTap)
        event.post(tap: .cgSessionEventTap)
    }

    public func resetVirtualSteering() {
        currentVirtualSteering = 0.0
    }

    private func pulseKey(_ key: CGKeyCode, dutyCycle: Double, period: Double) {
        let clampedDuty = max(0.05, min(0.90, dutyCycle))
        let onDuration = period * clampedDuty
        postKey(key, down: true)

        pwmQueue.asyncAfter(deadline: .now() + onDuration) { [weak self] in
            self?.postKey(key, down: false)
        }
    }

    // MARK: - Smart Application Focus Filter
    // Automatically blocks simulated key typing and mouse movement in terminals, text editors, browsers, and desktop apps.

    public var enableGameOnlyFilter: Bool = true

    /// Instantaneous O(1) in-memory check without touching WindowServer Mach IPC!
    public func shouldInjectForFrontmostApp() -> Bool {
        guard enableGameOnlyFilter else { return true }
        // Never block in Arcade / Asphalt mode
        if !useMouseSteering { return true }
        focusLock.lock()
        let isBlocked = cachedFrontmostAppIsBlocked
        focusLock.unlock()
        return !isBlocked
    }

    /// Executed exclusively when NSWorkspace notifies an active window change
    private func updateFrontmostAppState() {
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        let name = (front.localizedName ?? "").lowercased()
        let id = (front.bundleIdentifier ?? "").lowercased()

        let nonGameApps = [
            "terminal", "iterm", "alacritty", "kitty", "warp",
            "xcode", "code", "cursor", "sublime", "atom", "intellij", "antigravity",
            "safari", "chrome", "firefox", "edge", "brave", "arc", "opera",
            "slack", "discord", "telegram", "messages", "whatsapp", "signal",
            "textedit", "notes", "pages", "notion", "reminders", "calendar",
            "gyrosteer", "finder", "system settings", "system preferences",
            "preview", "spotify", "music"
        ]

        var isBlocked = false
        for app in nonGameApps {
            if name.contains(app) || id.contains(app) {
                isBlocked = true
                break
            }
        }

        focusLock.lock()
        cachedFrontmostAppIsBlocked = isBlocked
        focusLock.unlock()

        let appKey = "\(name)|\(isBlocked)|\(enableGameOnlyFilter)"
        if appKey != lastLoggedApp {
            lastLoggedApp = appKey
            let status = (enableGameOnlyFilter && isBlocked) ? "BLOCKED (Desktop App)" : "ALLOWED (Active Game)"
            EventLogger.shared.log("FOCUS: Active Window is \"\(front.localizedName ?? "Unknown")\" [\(id)] => \(status)")
        }
    }

    // MARK: - Simulator Button Triggers

    private func handleButtonDeltas(oldButtons: SteeringButtons, newButtons: SteeringButtons) {
        guard isDrivingActive, shouldInjectForFrontmostApp() else { return }

        // Left Blinker (tap on press)
        if !oldButtons.contains(.leftBlinker) && newButtons.contains(.leftBlinker) {
            tapKey(keyLeftBlinker)
            EventLogger.shared.log("BUTTON: LEFT BLINKER ([)")
        }

        // Right Blinker (tap on press)
        if !oldButtons.contains(.rightBlinker) && newButtons.contains(.rightBlinker) {
            tapKey(keyRightBlinker)
            EventLogger.shared.log("BUTTON: RIGHT BLINKER (])")
        }

        // Headlights (tap on press)
        if !oldButtons.contains(.headlights) && newButtons.contains(.headlights) {
            tapKey(keyHeadlights)
            EventLogger.shared.log("BUTTON: HEADLIGHTS (L)")
        }

        // High Beams (tap on press)
        if !oldButtons.contains(.highBeams) && newButtons.contains(.highBeams) {
            tapKey(keyHighBeams)
            EventLogger.shared.log("BUTTON: HIGH BEAMS (K)")
        }

        // Hazard Lights (tap on press)
        if !oldButtons.contains(.hazardLights) && newButtons.contains(.hazardLights) {
            tapKey(keyHazard)
            EventLogger.shared.log("BUTTON: HAZARD LIGHTS (F)")
        }

        // Wipers (tap on press)
        if !oldButtons.contains(.wipers) && newButtons.contains(.wipers) {
            tapKey(keyWipers)
            EventLogger.shared.log("BUTTON: WIPERS (P)")
        }

        // Engine Start / Stop (tap on any toggle state change)
        if oldButtons.contains(.engineStart) != newButtons.contains(.engineStart) {
            tapKey(keyEngineStart)
            EventLogger.shared.log("BUTTON: ENGINE START/STOP (E) -> \(newButtons.contains(.engineStart) ? "STARTED" : "STOPPED")")
        }

        // Parking Brake / Handbrake (ETS2 Spacebar):
        // In ETS2, Spacebar is an on/off toggle. Whenever the button state transitions (ON->OFF or OFF->ON),
        // we pulse Spacebar so ETS2 engages or releases the air brake in exact sync with the cockpit!
        // Parking Brake (ETS2) / Nitro Boost (Asphalt):
        if !useMouseSteering {
            // In Asphalt mode, holding Nitro holds Spacebar & 'N'
            if !oldButtons.contains(.parkingBrake) && newButtons.contains(.parkingBrake) {
                postKey(keySpace, down: true)
                postKey(keyNitroN, down: true)
                EventLogger.shared.log("BUTTON: NITRO (Space + N) DOWN")
            } else if oldButtons.contains(.parkingBrake) && !newButtons.contains(.parkingBrake) {
                postKey(keySpace, down: false)
                postKey(keyNitroN, down: false)
                EventLogger.shared.log("BUTTON: NITRO (Space + N) UP")
            }
        } else {
            // In ETS2 mode, Spacebar is toggled
            if oldButtons.contains(.parkingBrake) != newButtons.contains(.parkingBrake) {
                tapKey(keyParkingBrake)
                EventLogger.shared.log("BUTTON: PARKING BRAKE (Space) -> \(newButtons.contains(.parkingBrake) ? "ENGAGED" : "RELEASED")")
            }
        }

        // Enter / Confirm Action (Return key - Toll booths, jobs, gas stations, ferry, rest in ETS2)
        if !oldButtons.contains(.enter) && newButtons.contains(.enter) {
            tapKey(keyEnter)
            EventLogger.shared.log("BUTTON: ENTER (Return / 0x24)")
        }

        // Trailer Attach / Detach (tap on press) / Respawn in Asphalt (R)
        if !oldButtons.contains(.trailerAttach) && newButtons.contains(.trailerAttach) {
            if useMouseSteering {
                tapKey(keyTrailerAttach)
                EventLogger.shared.log("BUTTON: TRAILER (T)")
            } else {
                tapKey(keyRespawn)
                EventLogger.shared.log("BUTTON: RESPAWN (R)")
            }
        }

        // Gear Up (Shift modifier)
        if !oldButtons.contains(.gearUp) && newButtons.contains(.gearUp) {
            tapKey(keyGearUp)
            EventLogger.shared.log("BUTTON: GEAR UP (Left Shift)")
        }

        // Gear Down (ETS2 Control modifier) / Drift (Asphalt Shift + Down Arrow)
        if !useMouseSteering {
            if !oldButtons.contains(.gearDown) && newButtons.contains(.gearDown) {
                postKey(keyShift, down: true)
                postKey(keyDownArrow, down: true)
                EventLogger.shared.log("BUTTON: DRIFT (Shift + Down) DOWN")
            } else if oldButtons.contains(.gearDown) && !newButtons.contains(.gearDown) {
                postKey(keyShift, down: false)
                postKey(keyDownArrow, down: false)
                EventLogger.shared.log("BUTTON: DRIFT (Shift + Down) UP")
            }
        } else {
            if !oldButtons.contains(.gearDown) && newButtons.contains(.gearDown) {
                tapKey(keyGearDown)
                EventLogger.shared.log("BUTTON: GEAR DOWN (Left Ctrl)")
            }
        }

        // Cruise Control (tap on press)
        if !oldButtons.contains(.cruiseControl) && newButtons.contains(.cruiseControl) {
            tapKey(keyCruise)
            EventLogger.shared.log("BUTTON: CRUISE CONTROL (C)")
        }

        // Camera View (cycles 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 1 on each tap)
        if !oldButtons.contains(.cameraView) && newButtons.contains(.cameraView) {
            if useMouseSteering {
                // ETS2: Advance to next camera view in order
                currentCameraIndex = (currentCameraIndex % 6) + 1
                if let cam = cameraKeycodes.first(where: { $0.index == currentCameraIndex }) {
                    tapKey(cam.code)
                    EventLogger.shared.log("BUTTON: ETS2 CAMERA VIEW \(cam.name)")
                }
            } else {
                // Asphalt 8: Tap 'C' for camera angle toggle
                tapKey(keyCruise) // 8 = 'C'
                EventLogger.shared.log("BUTTON: ASPHALT CAMERA VIEW (C)")
            }
        }

        // Horn (hold while pressed): Send BOTH 'H' (Standard Horn) and 'N' (Air Horn) for ETS2
        if !oldButtons.contains(.horn) && newButtons.contains(.horn) {
            postKey(keyHorn, down: true)
            postKey(keyAirHorn, down: true)
            EventLogger.shared.log("BUTTON: HORN ('H' + 'N') DOWN")
        } else if oldButtons.contains(.horn) && !newButtons.contains(.horn) {
            postKey(keyHorn, down: false)
            postKey(keyAirHorn, down: false)
            EventLogger.shared.log("BUTTON: HORN ('H' + 'N') UP")
        }

        // Gearbox Switch: Automatic vs Manual / Sequential (ETS2: 'G' / keycode 5)
        if !oldButtons.contains(.transmissionMode) && newButtons.contains(.transmissionMode) {
            tapKey(keyTransmissionMode)
            EventLogger.shared.log("BUTTON: GEARBOX MODE SWITCH ('G' - Automatic / Sequential)")
        }

        // Retarder Decrease (ETS2: ';' / keycode 41)
        if !oldButtons.contains(.retarderDown) && newButtons.contains(.retarderDown) {
            tapKey(keyRetarderDown)
            EventLogger.shared.log("BUTTON: RETARDER DECREASE (;)")
        }

        // Retarder Increase (ETS2: '\'' / keycode 39)
        if !oldButtons.contains(.retarderUp) && newButtons.contains(.retarderUp) {
            tapKey(keyRetarderUp)
            EventLogger.shared.log("BUTTON: RETARDER INCREASE (')")
        }

        // Engine Brake Toggle (ETS2: 'B' / keycode 11)
        if !oldButtons.contains(.engineBrake) && newButtons.contains(.engineBrake) {
            tapKey(keyEngineBrake)
            EventLogger.shared.log("BUTTON: ENGINE BRAKE TOGGLE (B)")
        }

        // Shift to Neutral (ETS2: 'N' / keycode 45)
        if !oldButtons.contains(.neutral) && newButtons.contains(.neutral) {
            tapKey(keyNeutral)
            EventLogger.shared.log("BUTTON: SHIFT TO NEUTRAL (N)")
        }

        // Cabin View (ETS2: '1' / keycode 18)
        if !oldButtons.contains(.cabinView) && newButtons.contains(.cabinView) {
            tapKey(keyCabinView)
            EventLogger.shared.log("BUTTON: CABIN INTERIOR VIEW (1)")
        }

        // Route Advisor (ETS2: 'F3' / keycode 99)
        if !oldButtons.contains(.routeAdvisor) && newButtons.contains(.routeAdvisor) {
            tapKey(keyRouteAdvisor)
            EventLogger.shared.log("BUTTON: ROUTE ADVISOR (F3)")
        }

        // Steering Calibration / Recenter (0°)
        if !oldButtons.contains(.recenter) && newButtons.contains(.recenter) {
            resetVirtualSteering()
            EventLogger.shared.log("STEERING: RECENTERED (0°)")
        }

        // Map Zoom / Navigation View (ETS2: 'F5' / keycode 96)
        if !oldButtons.contains(.mapZoom) && newButtons.contains(.mapZoom) {
            tapKey(keyMapZoom)
            EventLogger.shared.log("BUTTON: MAP ZOOM (F5)")
        }

        // World Map (ETS2: 'M' / keycode 46)
        if !oldButtons.contains(.worldMap) && newButtons.contains(.worldMap) {
            tapKey(keyWorldMap)
            EventLogger.shared.log("BUTTON: WORLD MAP (M)")
        }
    }

    // MARK: - CGEvent Dispatch

    private func tapKey(_ key: CGKeyCode) {
        postKey(key, down: true)
        let holdDuration: Double = (key == keyGearUp || key == keyGearDown) ? 0.12 : 0.08
        pwmQueue.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
            self?.postKey(key, down: false)
        }
    }

    private func postKey(_ key: CGKeyCode, down: Bool) {
        if down {
            areKeysReleased = false
        }
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: down) else { return }
        
        // Critical Fix for Modifier Keys (Left Shift 56, Left Control 59 for Gear Up / Gear Down in ETS2)
        if key == keyGearUp || key == keyGearDown {
            let modifierFlag: CGEventFlags = (key == keyGearUp) ? .maskShift : .maskControl

            // 1. Post .flagsChanged event (required by macOS Cocoa modifier event handlers)
            if let flagsEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: down) {
                flagsEvent.type = .flagsChanged
                flagsEvent.flags = down ? modifierFlag : []
                flagsEvent.post(tap: .cghidEventTap)
                flagsEvent.post(tap: .cgSessionEventTap)
            }

            // 2. Post .keyDown / .keyUp event with modifier flag attached (required by ETS2 / SDL2 game engines)
            event.flags = down ? modifierFlag : []
            event.post(tap: .cghidEventTap)
            event.post(tap: .cgSessionEventTap)
            return
        }

        if let char = unicodeFor(keyCode: key) {
            let utf16Chars = [char]
            utf16Chars.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress {
                    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: base)
                }
            }
        }

        event.post(tap: .cghidEventTap)
        event.post(tap: .cgSessionEventTap)
    }

    private func unicodeFor(keyCode: CGKeyCode) -> UniChar? {
        switch keyCode {
        case 0: return 0x61     // 'a'
        case 2: return 0x64     // 'd'
        case 13: return 0x77    // 'w'
        case 1: return 0x73     // 's'
        case 49: return 0x20    // ' ' (Spacebar - Parking Brake / Nitro)
        case 45: return 0x6E    // 'n'
        case 14: return 0x65    // 'e' (Engine Start / Stop)
        case 15: return 0x72    // 'r' (Respawn in Asphalt 8)
        case 35: return 0x70    // 'p' (Windshield Wipers)
        case 3: return 0x66     // 'f' (Hazard Warning Lights)
        case 40: return 0x6B    // 'k' (High Beams)
        case 17: return 0x74    // 't' (Trailer Attach / Detach)
        case 18: return 0x31    // '1' (Cockpit Camera)
        case 19: return 0x32    // '2' (Chase Camera)
        case 20: return 0x33    // '3' (Top-Down Camera)
        case 21: return 0x34    // '4' (Roof Camera)
        case 23: return 0x35    // '5' (Window / Lean Out Camera)
        case 22: return 0x36    // '6' (Front Bumper Camera)
        case 123: return 0xF702 // Left Arrow
        case 124: return 0xF703 // Right Arrow
        case 125: return 0xF701 // Down Arrow
        case 126: return 0xF700 // Up Arrow
        case 8: return 0x63     // 'c'
        case 4: return 0x68     // 'h'
        case 37: return 0x6C    // 'l'
        case 33: return 0x5B    // '['
        case 30: return 0x5D    // ']'
        case 36: return 0x0D    // '\r' Return / Enter
        case 5:  return 0x67    // 'g' (Gearbox Mode Automatic / Sequential)
        case 41: return 0x3B    // ';' (Retarder Decrease)
        case 39: return 0x27    // '\'' (Retarder Increase)
        case 11: return 0x62    // 'b' (Engine Brake)
        case 46: return 0x6D    // 'm' (World Map)
        case 96: return nil     // F5 (Map Zoom)
        case 99: return nil     // F3 (Route Advisor)
        default: return nil
        }
    }

    private func releaseAllKeys() {
        guard !areKeysReleased else { return }
        lastSteerLeftState = false
        lastSteerRightState = false
        lastThrottleState = false
        lastBrakeState = false

        let keys = [
            keyLeft, keyRight, keyThrottle, keyBrake, keyHorn, keyAirHorn,
            keyLeftArrow, keyRightArrow, keyUpArrow, keyDownArrow, keySpace, keyNitroN, keyShift,
            keyGearUp, keyGearDown, keyParkingBrake, keyEngineStart, keyWipers, keyHazard, keyHighBeams, keyTrailerAttach, keyEnter, keyTransmissionMode,
            keyRetarderDown, keyRetarderUp, keyEngineBrake, keyNeutral, keyCabinView, keyRouteAdvisor, keyMapZoom, keyWorldMap
        ]
        for key in keys {
            postKey(key, down: false)
        }
        areKeysReleased = true
    }
}
