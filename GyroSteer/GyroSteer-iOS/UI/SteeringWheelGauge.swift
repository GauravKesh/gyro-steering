//
//  SteeringWheelGauge.swift
//  GyroSteer - iOS Transmitter UI
//
//  Premium authentic truck steering wheel visualizer inspired by
//  Scania / Volvo cockpits, featuring live angle, lock readout,
//  12 o'clock / 6 o'clock markers, spoke switches, and turn signal arrows.
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
    var onSteerDrag: ((Float) -> Void)? = nil
    var onCalibrate: (() -> Void)? = nil

    @State private var dragStartAngle: Double = 0.0
    @State private var isDragging: Bool = false

    public init(
        degrees: Double,
        normalizedSteering: Float,
        maxLockAngle: Double,
        isCentered: Bool = false,
        profile: GameHUDProfile = .ets2,
        isLeftBlinkerActive: Bool = false,
        isRightBlinkerActive: Bool = false,
        onSteerDrag: ((Float) -> Void)? = nil,
        onCalibrate: (() -> Void)? = nil
    ) {
        self.degrees = degrees
        self.normalizedSteering = normalizedSteering
        self.maxLockAngle = maxLockAngle
        self.isCentered = isCentered
        self.profile = profile
        self.isLeftBlinkerActive = isLeftBlinkerActive
        self.isRightBlinkerActive = isRightBlinkerActive
        self.onSteerDrag = onSteerDrag
        self.onCalibrate = onCalibrate
    }

    public var body: some View {
        ZStack {
            // Background Subtle Glow Ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.cyan.opacity(0.15),
                            Color.blue.opacity(0.1),
                            Color.orange.opacity(0.15),
                            Color.cyan.opacity(0.15)
                        ],
                        center: .center
                    ),
                    lineWidth: 6
                )
                .frame(width: 236, height: 236)
                .blur(radius: 4)

            // Dynamic Proportional Steering Arc
            Circle()
                .trim(from: arcTrimStart, to: arcTrimEnd)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan, Color.orange, Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 234, height: 234)
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.orange.opacity(0.6), radius: 6)

            // The Realistic Rotating Truck Steering Wheel
            ZStack {
                // 1. Heavy Outer Rim with Leather Texture & Shading
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(white: 0.28),
                                Color(white: 0.12),
                                Color(white: 0.08),
                                Color(white: 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 24
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 4)

                // Outer Rim Accent Bevel Line
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 218, height: 218)

                // Inner Rim Accent Bevel Line
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                    .frame(width: 178, height: 178)

                // 2. Wheel Spoke Structure (Left, Right, Bottom-V)
                // Left Spoke with tactile switch texture
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.14)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 44, height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))

                        // Spoke buttons texture
                        HStack(spacing: 3) {
                            ForEach(0..<3) { _ in
                                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
                            }
                        }
                    }
                    .offset(x: 20)

                    Spacer()

                    // Right Spoke with tactile switch texture
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.14)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 44, height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))

                        // Spoke buttons texture
                        HStack(spacing: 3) {
                            ForEach(0..<3) { _ in
                                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
                            }
                        }
                    }
                    .offset(x: -20)
                }
                .frame(width: 200)

                // Bottom Dual-Spoke Support
                VStack {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 38, height: 38)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.14), lineWidth: 1))

                        // Bottom Center Alignment Stripe (Yellow)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(width: 14, height: 5)
                            .offset(y: 12)
                    }
                    .offset(y: 10)
                }
                .frame(height: 200)

                // 3. Top 12 o'clock Racing / Truck Alignment Center Marker (Amber/Yellow)
                VStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange)
                        .frame(width: 10, height: 20)
                        .shadow(color: Color.orange.opacity(0.8), radius: 4)
                        .offset(y: -9)
                    Spacer()
                }
                .frame(height: 200)
            }
            .rotationEffect(.degrees(degrees))
            .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.85), value: degrees)

            // Center Digital Telemetry Cluster (Non-rotating, matches real truck digital hub)
            ZStack {
                // Hub Enclosure
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.16), Color(white: 0.06), Color.black],
                            center: .center,
                            startRadius: 10,
                            endRadius: 65
                        )
                    )
                    .frame(width: 124, height: 124)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.5), Color.white.opacity(0.15), Color.orange.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.9), radius: 8, x: 0, y: 3)

                // Digital Cluster Content
                VStack(spacing: 3) {
                    // Top: Scania / Truck Griffin Crest Shield (Tappable to calibrate)
                    Button {
                        onCalibrate?()
                    } label: {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isCentered ? .green : .blue.opacity(0.85))
                            .shadow(color: isCentered ? .green.opacity(0.6) : .cyan.opacity(0.6), radius: 4)
                            .padding(.top, 3)
                    }
                    .buttonStyle(.plain)

                    // Middle: Left & Right Turn Signal Arrows with CALIBRATE Button in between
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(isLeftBlinkerActive ? Color.orange : Color.gray.opacity(0.25))
                            .shadow(color: isLeftBlinkerActive ? Color.orange.opacity(0.9) : Color.clear, radius: 5)

                        // Calibration Button right between left and right arrows
                        Button {
                            onCalibrate?()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "scope")
                                    .font(.system(size: 10, weight: .black))
                                Text("CAL")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                            }
                            .foregroundColor(isCentered ? Color.green : Color.cyan)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.75))
                                    .overlay(
                                        Capsule()
                                            .stroke(isCentered ? Color.green.opacity(0.8) : Color.cyan.opacity(0.8), lineWidth: 1.2)
                                    )
                                    .shadow(color: (isCentered ? Color.green : Color.cyan).opacity(0.4), radius: 4)
                            )
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(isRightBlinkerActive ? Color.orange : Color.gray.opacity(0.25))
                            .shadow(color: isRightBlinkerActive ? Color.orange.opacity(0.9) : Color.clear, radius: 5)
                    }

                    // Large Digital Angle Readout (Tap to calibrate/recenter)
                    Button {
                        onCalibrate?()
                    } label: {
                        Text(String(format: "%d°", Int(round(degrees))))
                            .font(.system(size: 23, weight: .black, design: .monospaced))
                            .foregroundColor(isCentered ? Color.green : Color.white)
                            .shadow(color: isCentered ? Color.green.opacity(0.6) : Color.clear, radius: 6)
                    }
                    .buttonStyle(.plain)

                    // Output Percentage
                    Text(String(format: "OUT: %+.2f", normalizedSteering))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(Color.orange)

                    // Steering Lock
                    Text("LOCK ±\(Int(maxLockAngle))°")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.gray.opacity(0.75))
                        .padding(.bottom, 2)
                }
            }
        }
        .frame(width: 240, height: 240)
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
