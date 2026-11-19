//
//  TelemetryHistory.swift
//  GyroSteer - macOS Receiver
//
//  Rolling time-series buffer for rendering real-time gyro oscilloscopes and waveforms.
//

import Foundation

public struct TelemetryPoint: Sendable, Identifiable {
    public let id = UUID()
    public let timestamp: TimeInterval
    public let steeringAngle: Float // -1.0 to 1.0
    public let throttle: Float      // 0.0 to 1.0
    public let brake: Float         // 0.0 to 1.0

    public init(timestamp: TimeInterval, steeringAngle: Float, throttle: Float, brake: Float) {
        self.timestamp = timestamp
        self.steeringAngle = steeringAngle
        self.throttle = throttle
        self.brake = brake
    }
}

public final class TelemetryHistory: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: [TelemetryPoint] = []
    public let capacity: Int

    public init(capacity: Int = 300) {
        self.capacity = capacity
        self.buffer.reserveCapacity(capacity)
    }

    public func append(angle: Float, throttle: Float, brake: Float) {
        let point = TelemetryPoint(
            timestamp: ProcessInfo.processInfo.systemUptime,
            steeringAngle: angle,
            throttle: throttle,
            brake: brake
        )

        lock.lock()
        defer { lock.unlock() }

        if buffer.count >= capacity {
            buffer.removeFirst(buffer.count - capacity + 1)
        }
        buffer.append(point)
    }

    public func snapshot() -> [TelemetryPoint] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll(keepingCapacity: true)
    }
}
