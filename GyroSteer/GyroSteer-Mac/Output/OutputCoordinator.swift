//
//  OutputCoordinator.swift
//  GyroSteer - macOS Receiver
//
//  Directs incoming steering packets to the selected output engine (Virtual Gamepad vs Keyboard).
//

import Foundation
import Combine

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public final class OutputCoordinator: ObservableObject, @unchecked Sendable {
    @Published public var activeMode: OutputMode = .virtualGamepad {
        didSet {
            if activeMode != oldValue {
                updateActiveInjector(for: activeMode)
            }
        }
    }

    /// Master driving active switch: When false, zero keystrokes are sent to macOS.
    @Published public var isDrivingActive: Bool = true {
        didSet {
            keyboardEmulator.isDrivingActive = isDrivingActive
        }
    }

    /// When true, steering is injected as smooth analog mouse X-delta for ETS2.
    @Published public var useMouseSteering: Bool = true {
        didSet {
            keyboardEmulator.useMouseSteering = useMouseSteering
        }
    }

    /// Smart Filter: Automatically suppresses all cursor and typing when outside games (Finder, Chrome, Terminal, etc.)
    @Published public var enableGameOnlyFilter: Bool = true {
        didSet {
            keyboardEmulator.enableGameOnlyFilter = enableGameOnlyFilter
        }
    }

    /// Arcade steering sensitivity multiplier (2.5x default)
    @Published public var keyboardSteeringSensitivity: Double = 2.5 {
        didSet {
            keyboardEmulator.keyboardSteeringGain = Float(keyboardSteeringSensitivity)
        }
    }

    // Tuning Parameters
    @Published public var maxLockAngle: Double = ProtocolConstants.defaultMaxLockAngleDegrees
    @Published public var deadzone: Double = 0.0
    @Published public var linearity: Double = 1.0

    // Calibrated zero angle offset on Mac side (optional local override)
    @Published public var localZeroOffset: Float = 0.0

    public let gamepadDriver: VirtualGamepadDriver
    public let keyboardEmulator: KeyboardMouseEmulator

    private var activeInjector: any InputInjector
    private let lock = NSLock()

    public init(
        gamepadDriver: VirtualGamepadDriver = VirtualGamepadDriver(),
        keyboardEmulator: KeyboardMouseEmulator = KeyboardMouseEmulator()
    ) {
        self.gamepadDriver = gamepadDriver
        self.keyboardEmulator = keyboardEmulator
        self.activeInjector = gamepadDriver

        _ = self.activeInjector.start()
    }

    deinit {
        gamepadDriver.stop()
        keyboardEmulator.stop()
    }

    public func switchOutputMode(to mode: OutputMode) {
        if activeMode != mode {
            activeMode = mode
        } else {
            updateActiveInjector(for: mode)
        }
    }

    private func updateActiveInjector(for mode: OutputMode) {
        lock.lock()
        defer { lock.unlock() }

        activeInjector.stop()

        switch mode {
        case .virtualGamepad:
            if !gamepadDriver.isDeviceActive {
                print("[OutputCoordinator] Note: Virtual Gamepad driver requires Apple Developer entitlement. Falling back to Keyboard Emulation (Zero-Driver).")
                activeInjector = keyboardEmulator
            } else {
                activeInjector = gamepadDriver
            }
        case .keyboardEmulation:
            activeInjector = keyboardEmulator
        }

        _ = activeInjector.start()
        print("[OutputCoordinator] Switched output mode to \(mode.rawValue)")
    }

    public func processIncomingPacket(_ packet: SteeringPacket) {
        lock.lock()
        var adjusted = packet

        // Apply local zero-calibration offset if set
        if localZeroOffset != 0.0 {
            adjusted.steeringAngle = max(-1.0, min(1.0, adjusted.steeringAngle - localZeroOffset))
        }

        // Apply optional extra deadzone / linearity if configured on Mac
        if deadzone > 0.0 || linearity != 1.0 {
            let withDeadzone = MathUtilities.applyDeadzone(adjusted.steeringAngle, deadzone: Float(deadzone))
            adjusted.steeringAngle = MathUtilities.applyLinearity(withDeadzone, exponent: Float(linearity))
        }

        let injector = activeInjector
        lock.unlock()

        injector.inject(packet: adjusted)
    }

    public func recalibrate(currentAngle: Float) {
        lock.lock()
        localZeroOffset = currentAngle
        keyboardEmulator.resetVirtualSteering()
        lock.unlock()
    }

    public func resetCalibration() {
        lock.lock()
        localZeroOffset = 0.0
        keyboardEmulator.resetVirtualSteering()
        lock.unlock()
    }
}
