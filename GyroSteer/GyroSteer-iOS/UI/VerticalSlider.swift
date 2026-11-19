//
//  VerticalSlider.swift
//  GyroSteer - iOS Transmitter UI
//
//  Proportional vertical touch slider for throttle and brake pedals
//  with spring-to-zero release and tactile haptic feedback ticks.
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
        displayMode: ButtonDisplayMode = .iconOnly,
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
                // Background Track
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isTouching ? accentColor.opacity(0.6) : Color(white: 0.2), lineWidth: 2)
                    )

                // Graduation Tick Marks
                VStack(spacing: 0) {
                    ForEach(0..<10) { index in
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(index % 2 == 0 ? 0.25 : 0.12))
                            .frame(width: index % 2 == 0 ? width * 0.4 : width * 0.25, height: 1.5)
                    }
                    Spacer()
                }

                // Active Fill
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.85), accentColor],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: fillHeight)
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: fillHeight)

                // Thumb Glow Indicator Line
                if fillHeight > 0 {
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 3)
                        .shadow(color: accentColor, radius: 8)
                        .offset(y: -fillHeight + 1.5)
                }

                // Overlay Content (Labels & Icon)
                VStack(spacing: 8) {
                    // Top: Percentage readout
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(value > 0.05 ? .white : .gray)
                        .padding(.top, 12)

                    Spacer()

                    // Bottom: Icon and Title
                    Image(systemName: iconName)
                        .font(.system(size: displayMode == .iconOnly ? 30 : 22, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, displayMode == .iconOnly ? 16 : 0)

                    if displayMode == .iconAndText {
                        Text(title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        Text(subtitle)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.bottom, 12)
                    }
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
                        withAnimation(.easeOut(duration: 0.15)) {
                            value = 0.0
                        }
                        lastHapticThreshold = 0
                    }
            )
        }
        .frame(width: 90)
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
