//
//  MathUtilities.swift
//  GyroSteer - Shared Protocol
//
//  Math and filtering helpers for steering telemetry.
//

import Foundation

public enum MathUtilities {
    /// Applies a deadzone around zero.
    /// - Parameters:
    ///   - value: Raw normalized value in range [-1.0, 1.0].
    ///   - deadzone: Deadzone threshold in range [0.0, 0.5].
    /// - Returns: Adjusted value in range [-1.0, 1.0], with zero within the threshold.
    public static func applyDeadzone(_ value: Float, deadzone: Float) -> Float {
        let clampedDeadzone = max(0.0, min(0.5, deadzone))
        let magnitude = abs(value)
        if magnitude <= clampedDeadzone {
            return 0.0
        }
        let sign: Float = value >= 0 ? 1.0 : -1.0
        let scaled = (magnitude - clampedDeadzone) / (1.0 - clampedDeadzone)
        return sign * min(1.0, max(0.0, scaled))
    }

    /// Applies non-linear sensitivity/linearity curve.
    /// - Parameters:
    ///   - value: Normalized value in range [-1.0, 1.0].
    ///   - exponent: Linearity gamma exponent (1.0 = linear, > 1.0 = more precision in center).
    /// - Returns: Shaped value in [-1.0, 1.0].
    public static func applyLinearity(_ value: Float, exponent: Float) -> Float {
        let sign: Float = value >= 0 ? 1.0 : -1.0
        let magnitude = abs(value)
        let curved = pow(magnitude, max(0.1, exponent))
        return sign * min(1.0, max(0.0, curved))
    }

    /// Converts radians to degrees.
    public static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180.0 / .pi
    }

    /// Converts degrees to radians.
    public static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180.0
    }

    /// Normalizes raw degrees to [-1.0, 1.0] given max lock degrees each way, deadzone, and linearity.
    public static func normalizeSteering(
        rawDegrees: Double,
        maxLockAngleDegrees: Double,
        deadzone: Double = 0.02,
        linearity: Double = 1.0
    ) -> Float {
        guard maxLockAngleDegrees > 0 else { return 0.0 }
        let clampedDegrees = max(-maxLockAngleDegrees, min(maxLockAngleDegrees, rawDegrees))
        let normalized = Float(clampedDegrees / maxLockAngleDegrees)
        let withDeadzone = applyDeadzone(normalized, deadzone: Float(deadzone))
        return applyLinearity(withDeadzone, exponent: Float(linearity))
    }
}
