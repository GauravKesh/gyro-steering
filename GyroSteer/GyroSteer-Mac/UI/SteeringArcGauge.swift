//
//  SteeringArcGauge.swift
//  GyroSteer - macOS Receiver UI
//
//  High-resolution analog steering arc gauge showing exact degrees,
//  lock limits, and center deadzone alignment.
//

import SwiftUI

public struct SteeringArcGauge: View {
    let steeringAngle: Float // -1.0 to +1.0
    let maxLockAngle: Double

    public init(steeringAngle: Float, maxLockAngle: Double) {
        self.steeringAngle = steeringAngle
        self.maxLockAngle = maxLockAngle
    }

    public var body: some View {
        let currentDegrees = Double(steeringAngle) * (maxLockAngle / 2.0)
        let isCentered = abs(steeringAngle) < 0.01

        ZStack {
            // Background Arc Track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(90))
                .frame(width: 180, height: 180)

            // Dynamic Active Angle Arc
            Circle()
                .trim(from: arcStart, to: arcEnd)
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .blue, .purple],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .frame(width: 180, height: 180)
                .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.85), value: steeringAngle)

            // Needle Pointer
            VStack {
                Rectangle()
                    .fill(isCentered ? Color.green : Color.red)
                    .frame(width: 3, height: 40)
                    .cornerRadius(1.5)
                    .shadow(color: isCentered ? .green : .red, radius: 4)
                Spacer()
            }
            .frame(width: 180, height: 180)
            .rotationEffect(.degrees(Double(steeringAngle) * 126.0)) // 126° max deflection on 252° arc
            .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.85), value: steeringAngle)

            // Center Digital Telemetry Box
            VStack(spacing: 2) {
                // Live Degree Angle
                Text(String(format: "%+.1f°", currentDegrees))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(isCentered ? .green : .white)

                // Normalized [-1.0 ... +1.0]
                Text(String(format: "NORM: %+.3f", steeringAngle))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)

                // Status Pill
                Text(isCentered ? "CENTERED" : (steeringAngle < 0 ? "◀ TURNING LEFT" : "TURNING RIGHT ▶"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isCentered ? .green : .secondary)
            }
        }
        .frame(width: 200, height: 200)
    }

    private var arcStart: CGFloat {
        // Base center point is 0.50
        if steeringAngle < 0 {
            let offset = CGFloat(abs(steeringAngle)) * 0.35
            return 0.50 - offset
        } else {
            return 0.50
        }
    }

    private var arcEnd: CGFloat {
        if steeringAngle > 0 {
            let offset = CGFloat(steeringAngle) * 0.35
            return 0.50 + offset
        } else {
            return 0.50
        }
    }
}
