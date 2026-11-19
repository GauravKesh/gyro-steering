//
//  OscilloscopeView.swift
//  GyroSteer - macOS Receiver UI
//
//  Real-time oscilloscope / waveform graph of gyro telemetry and pedal inputs.
//

import SwiftUI

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public struct OscilloscopeView: View {
    let history: TelemetryHistory

    public init(history: TelemetryHistory) {
        self.history = history
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
            let points = history.snapshot()

            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2.0

                ZStack {
                    // Dark Oscilloscope Display Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    // Grid Lines
                    Path { path in
                        // Center Zero Line
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: width, y: midY))

                        // +50% and -50% Lines
                        path.move(to: CGPoint(x: 0, y: midY - (height * 0.25)))
                        path.addLine(to: CGPoint(x: width, y: midY - (height * 0.25)))

                        path.move(to: CGPoint(x: 0, y: midY + (height * 0.25)))
                        path.addLine(to: CGPoint(x: width, y: midY + (height * 0.25)))

                        // Vertical Time Grid Lines
                        let colCount = 6
                        for c in 1..<colCount {
                            let x = width * CGFloat(c) / CGFloat(colCount)
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                    }
                    .stroke(Color.cyan.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Zero Line Accent
                    Rectangle()
                        .fill(Color.cyan.opacity(0.3))
                        .frame(height: 1)
                        .offset(y: 0)

                    // Steering Telemetry Waveform Path
                    if points.count >= 2 {
                        Path { path in
                            for (index, point) in points.enumerated() {
                                let x = width * (CGFloat(index) / CGFloat(max(1, points.count - 1)))
                                // Angle is -1.0 to 1.0 (invert Y since 0 is top)
                                let y = midY - (CGFloat(point.steeringAngle) * (height * 0.44))

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [.green, .cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: .cyan.opacity(0.5), radius: 4)

                        // Current Value Pulse Dot at the Leading Edge
                        if let last = points.last {
                            let lastX = width
                            let lastY = midY - (CGFloat(last.steeringAngle) * (height * 0.44))

                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .shadow(color: .cyan, radius: 6)
                                .position(x: lastX - 4, y: lastY)
                        }
                    }

                    // Scope Legend Overlays
                    VStack {
                        HStack {
                            Text("TELEMETRY OSCILLOSCOPE (3s)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)

                            Spacer()

                            Text("+1.00 (RIGHT)")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.6))
                        }
                        Spacer()
                        HStack {
                            Text("0.00 CENTER")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.6))
                            Spacer()
                            Text("-1.00 (LEFT)")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.6))
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(height: 160)
    }
}
