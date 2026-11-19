//
//  SteeringWheelGauge.swift
//  GyroSteer - iOS Transmitter UI
//
//  Real-time animated steering wheel visualizer with degree readout,
//  turn indicators, and racing center marker.
//

import SwiftUI

public struct SteeringWheelGauge: View {
    let degrees: Double
    let normalizedSteering: Float
    let maxLockAngle: Double
    let isCentered: Bool
    let profile: GameHUDProfile
    let isLeftBlinkerActive: Bool
    let isRightBlinkerActive: Bool

    public init(
        degrees: Double,
        normalizedSteering: Float,
        maxLockAngle: Double,
        isCentered: Bool = false,
        profile: GameHUDProfile = .ets2,
        isLeftBlinkerActive: Bool = false,
        isRightBlinkerActive: Bool = false
    ) {
        self.degrees = degrees
        self.normalizedSteering = normalizedSteering
        self.maxLockAngle = maxLockAngle
        self.isCentered = isCentered
        self.profile = profile
        self.isLeftBlinkerActive = isLeftBlinkerActive
        self.isRightBlinkerActive = isRightBlinkerActive
    }

    public var body: some View {
        ZStack {
            // Outer Degree Arc Ticks
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 4)
                .frame(width: 220, height: 220)

            // Dynamic Angle Arc
            Circle()
                .trim(from: arcTrimStart, to: arcTrimEnd)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: arcColors),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))

            // The Rotating Steering Wheel
            SteeringWheelShape()
                .fill(Color(white: 0.16))
                .overlay(
                    SteeringWheelShape()
                        .stroke(isCentered ? Color.green.opacity(0.8) : Color.white.opacity(0.3), lineWidth: 3)
                )
                .frame(width: 190, height: 190)
                .overlay(
                    // Top 12-o'clock racing center stripe
                    Rectangle()
                        .fill(centerStripeColor)
                        .frame(width: 8, height: 18)
                        .cornerRadius(2)
                        .offset(y: -95)
                )
                .rotationEffect(.degrees(degrees))
                .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.85), value: degrees)

            // Center Digital Telemetry Hub
            VStack(spacing: 2) {
                // Turn Indicator Icons
                HStack(spacing: 14) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(isLeftBlinkerActive ? Color.green : (normalizedSteering < -0.05 ? profile.accentColor : .gray.opacity(0.25)))
                        .shadow(color: isLeftBlinkerActive ? .green : .clear, radius: 6)

                    Image(systemName: isCentered ? "circle.circle.fill" : "circle.circle")
                        .font(.system(size: 13))
                        .foregroundColor(isCentered ? .green : .gray)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(isRightBlinkerActive ? Color.green : (normalizedSteering > 0.05 ? profile.accentColor : .gray.opacity(0.25)))
                        .shadow(color: isRightBlinkerActive ? .green : .clear, radius: 6)
                }

                // Digital Degree Readout
                Text(String(format: "%+.1f°", degrees))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(isCentered ? .green : .white)

                // Normalized Steering Readout
                Text(String(format: "OUT: %+.2f", normalizedSteering))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(profile.accentColor)

                // Lock Angle Reference
                Text("LOCK ±\(Int(maxLockAngle))°")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .frame(width: 110, height: 110)
            .background(Circle().fill(Color(white: 0.08)).shadow(radius: 6))
        }
        .frame(width: 240, height: 240)
    }

    private var arcColors: [Color] {
        switch profile {
        case .ets2:
            return [.yellow, .orange, .red]
        case .asphalt:
            return [.cyan, .purple, .pink]
        case .f1Sim:
            return [.green, .yellow, .red]
        }
    }

    private var centerStripeColor: Color {
        switch profile {
        case .ets2: return .orange
        case .asphalt: return .pink
        case .f1Sim: return .yellow
        }
    }

    private var arcTrimStart: CGFloat {
        if normalizedSteering < 0 {
            return CGFloat(0.5 + (Double(normalizedSteering) * 0.25))
        } else {
            return 0.5
        }
    }

    private var arcTrimEnd: CGFloat {
        if normalizedSteering > 0 {
            return CGFloat(0.5 + (Double(normalizedSteering) * 0.25))
        } else {
            return 0.5
        }
    }
}

/// Custom 3-Spoke Steering Wheel Graphic
struct SteeringWheelShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = rect.width / 2
        let innerRadius = outerRadius * 0.72

        // Outer Rim
        path.addEllipse(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2))
        path.addEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2))

        // Left Spoke
        path.addRect(CGRect(x: center.x - innerRadius, y: center.y - 8, width: innerRadius * 0.6, height: 16))

        // Right Spoke
        path.addRect(CGRect(x: center.x + (innerRadius * 0.4), y: center.y - 8, width: innerRadius * 0.6, height: 16))

        // Bottom Spoke
        path.addRect(CGRect(x: center.x - 8, y: center.y + (innerRadius * 0.4), width: 16, height: innerRadius * 0.6))

        return path
    }
}
