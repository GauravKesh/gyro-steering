//
//  MotionManager.swift
//  GyroSteer - iOS Transmitter
//
//  High-performance 100Hz gyroscope engine using CoreMotion.
//

import Foundation
import CoreMotion
import Combine

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

@MainActor
public final class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue

    // MARK: - Published Telemetry

    /// Current raw steering angle in degrees relative to calibrated zero
    @Published public private(set) var currentDegrees: Double = 0.0

    /// Normalized steering value [-1.0 ... +1.0] ready for transmission
    @Published public private(set) var normalizedSteering: Float = 0.0

    /// Sensor update health
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var sensorFrequencyHz: Double = 0.0

    // MARK: - Configuration Settings

    /// Maximum lock angle in degrees (e.g. 900.0 for ETS2 truck lock-to-lock, 450° each way)
    @Published public var maxLockAngleDegrees: Double = ProtocolConstants.defaultMaxLockAngleDegrees

    /// Center deadzone threshold (0.0 to 0.2)
    @Published public var centerDeadzone: Double = 0.02

    /// Linearity gamma exponent (1.0 = linear, 1.5 - 2.0 = fine precision at center)
    @Published public var linearityExponent: Double = 1.0

    /// Exponential smoothing alpha (1.0 = raw / no filter, 0.8 = light smoothing)
    @Published public var smoothingAlpha: Double = 0.85

    // MARK: - Calibration State

    private var hasInitialCalibration = false
    private var calibratedZeroAngle: Double = 0.0
    private var isLandscapeRight = true
    private var lastSmoothedDegrees: Double = 0.0
    private var lastSteerSign: Bool = true
    private var sampleCount: Int = 0
    private var lastFrequencyTimestamp: TimeInterval = 0.0

    nonisolated public init() {
        let queue = OperationQueue()
        queue.name = "com.gyrosteer.motionQueue"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
        self.motionQueue = queue
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Lifecycle

    public func start() {
        guard motionManager.isDeviceMotionAvailable else {
            print("[MotionManager] Device motion is not available on this hardware.")
            return
        }

        guard !isRunning else { return }

        // Configure for 100Hz update frequency (10ms)
        motionManager.deviceMotionUpdateInterval = ProtocolConstants.targetIntervalSeconds
        motionManager.showsDeviceMovementDisplay = false

        lastFrequencyTimestamp = ProcessInfo.processInfo.systemUptime
        sampleCount = 0

        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: motionQueue
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            self.processMotion(motion)
        }

        isRunning = true
    }

    public func stop() {
        guard isRunning else { return }
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
    }

    // MARK: - Zero-Point Recalibration

    /// Sets the current phone tilt angle as the 0° steering center point.
    public func recenter() {
        guard let motion = motionManager.deviceMotion else { return }
        let gx = motion.gravity.x
        let gy = motion.gravity.y

        calibratedZeroAngle = atan2(gy, gx)
        isLandscapeRight = (gx >= 0)
        hasInitialCalibration = true

        lastSmoothedDegrees = 0.0
        currentDegrees = 0.0
        normalizedSteering = 0.0
    }

    // MARK: - Sensor Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        let gx = motion.gravity.x
        let gy = motion.gravity.y

        // Angle in the screen plane (device XY axes)
        let currentAngle = atan2(gy, gx)

        if !hasInitialCalibration {
            calibratedZeroAngle = currentAngle
            isLandscapeRight = (gx >= 0)
            hasInitialCalibration = true
        }

        var delta = currentAngle - calibratedZeroAngle

        // Normalize delta to [-pi, pi]
        while delta > .pi { delta -= 2.0 * .pi }
        while delta < -.pi { delta += 2.0 * .pi }

        var degrees = MathUtilities.radiansToDegrees(delta)

        // In LandscapeRight (camera on the left, gx > 0), tilting left makes gy increase (delta > 0).
        // Standard convention: Left turn is negative (-), Right turn is positive (+).
        if isLandscapeRight {
            degrees = -degrees
        }

        // Apply exponential moving average (EMA) smoothing to eliminate gyro noise
        let alpha = smoothingAlpha
        let smoothedDegrees = (alpha * degrees) + ((1.0 - alpha) * lastSmoothedDegrees)
        lastSmoothedDegrees = smoothedDegrees

        // Map to normalized [-1.0, 1.0] steering value
        let normalized = MathUtilities.normalizeSteering(
            rawDegrees: smoothedDegrees,
            maxLockAngleDegrees: maxLockAngleDegrees,
            deadzone: centerDeadzone,
            linearity: linearityExponent
        )

        // Tactile Center Detent Haptic when wheel passes through 0°
        let currentSign = smoothedDegrees >= 0.0
        if currentSign != lastSteerSign && abs(smoothedDegrees) < 4.0 {
            DispatchQueue.main.async {
                HapticManager.shared.centerDetent()
            }
        }
        lastSteerSign = currentSign

        // Track frequency
        sampleCount += 1
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastFrequencyTimestamp
        var calculatedHz = sensorFrequencyHz
        if elapsed >= 1.0 {
            calculatedHz = Double(sampleCount) / elapsed
            sampleCount = 0
            lastFrequencyTimestamp = now
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentDegrees = smoothedDegrees
            self.normalizedSteering = normalized
            if elapsed >= 1.0 {
                self.sensorFrequencyHz = calculatedHz
            }
        }
    }
}
