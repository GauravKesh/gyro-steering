//
//  VerticalSlider.swift
//  GyroSteer - iOS Transmitter UI
//
//  Premium automotive pedal slider for throttle and brake with
//  neon glassmorphism borders, spring-to-zero release, and tactile haptics.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

public struct VerticalSlider: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    let iconName: String
    let displayMode: ButtonDisplayMode
    @Binding var value: Float // 0.0 to 1.0

    @State private var lastHapticThreshold: Int = 0
    @State private var isTouching: Bool = false

    public init(
        title: String,
        subtitle: String,
        accentColor: Color,
        iconName: String,
        displayMode: ButtonDisplayMode = .iconAndText,
        value: Binding<Float>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.iconName = iconName
        self.displayMode = displayMode
        self._value = value
    }

    public var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let width = geometry.size.width
            let fillHeight = CGFloat(value) * height

            ZStack(alignment: .bottom) {
                // 1. Dark Glass Background Track with Neon Border
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.12).opacity(0.85),
                                Color(white: 0.05).opacity(0.95),
                                Color.black.opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                accentColor.opacity(isTouching ? 0.95 : 0.65),
                                lineWidth: isTouching ? 3 : 2
                            )
                            .shadow(color: accentColor.opacity(isTouching ? 0.8 : 0.4), radius: isTouching ? 12 : 6)
                    )

                // 2. Subtle Tick Graduation Marks
                VStack(spacing: 0) {
                    ForEach(0..<9) { index in
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(index % 2 == 0 ? 0.20 : 0.08))
                            .frame(width: index % 2 == 0 ? width * 0.45 : width * 0.25, height: 1.5)
                    }
                    Spacer()
                }

                // 3. Fluid Neon Fill
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.4),
                                accentColor.opacity(0.75),
                                accentColor
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: fillHeight)
                    .animation(.interactiveSpring(response: 0.10, dampingFraction: 0.82), value: fillHeight)

                // 4. White Glowing Horizon Line at Active Level
                if fillHeight > 4 {
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 3)
                        .shadow(color: accentColor, radius: 8)
                        .offset(y: -fillHeight + 1.5)
                }

                // 5. Visual Pedal Labels & Automotive Icon
                VStack(spacing: 6) {
                    // Top: Live Percentage readout
                    if isTouching || value > 0.02 {
                        Text("\(Int(value * 100))%")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.top, 10)
                            .transition(.opacity)
                    } else {
                        // Resting upper indicator chevron
                        Image(systemName: title == "BRAKE" ? "exclamationmark.circle" : "chevron.up.2")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(accentColor.opacity(0.6))
                            .padding(.top, 12)
                    }

                    Spacer()

                    // Center Primary Pedal Icon
                    ZStack {
                        if title == "BRAKE" {
                            // Custom Authentic Brake Disc Symbol: ( ! )
                            HStack(spacing: 2) {
                                Text("(")
                                    .font(.system(size: 26, weight: .light, design: .rounded))
                                    .foregroundColor(.white)
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(.white)
                                Text(")")
                                    .font(.system(size: 26, weight: .light, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        } else {
                            // Authentic Accelerator Icon: Lightning bolt + double chevron
                            VStack(spacing: 2) {
                                Image(systemName: "chevron.up.2")
                                    .font(.system(size: 14, weight: .black))
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 24, weight: .black))
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .shadow(color: accentColor.opacity(0.8), radius: isTouching ? 8 : 4)

                    // Pedal Label
                    Text(title)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 3)
                        .padding(.bottom, 14)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isTouching = true
                        let locationY = gesture.location.y
                        let progress = 1.0 - (locationY / height)
                        let clamped = Float(max(0.0, min(1.0, progress)))
                        value = clamped
                        checkHapticThreshold(clamped)
                    }
                    .onEnded { _ in
                        isTouching = false
                        // Spring back to 0.0 on release like a real physical pedal
                        withAnimation(.easeOut(duration: 0.14)) {
                            value = 0.0
                        }
                        lastHapticThreshold = 0
                    }
            )
        }
        .frame(width: 82)
    }

    private func checkHapticThreshold(_ current: Float) {
        if current >= 0.98 && lastHapticThreshold != 100 {
            lastHapticThreshold = 100
            #if os(iOS)
            HapticManager.shared.pedalFloor()
            #endif
            return
        }

        let currentStep = Int(current * 8.0) // 8 haptic tick increments across travel
        if currentStep != lastHapticThreshold && current < 0.98 {
            lastHapticThreshold = currentStep
            #if os(iOS)
            HapticManager.shared.pedalTick()
            #endif
        }
    }
}
