//
//  MenuBarView.swift
//  GyroSteer - macOS Receiver UI
//
//  Compact MenuBarExtra status popup for background simulator streaming.
//

import SwiftUI

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public struct MenuBarView: View {
    @ObservedObject var arbiter: TransportArbiter
    @ObservedObject var coordinator: OutputCoordinator

    public init(arbiter: TransportArbiter, coordinator: OutputCoordinator) {
        self.arbiter = arbiter
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status Header
            HStack(spacing: 8) {
                Circle()
                    .fill(arbiter.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(arbiter.isConnected ? arbiter.activeTransport.displayName : "DISCONNECTED")
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                if arbiter.isConnected {
                    Text("\(Int(arbiter.liveHz)) Hz")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text("•")
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f ms", arbiter.estimatedLatencyMs))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            .padding(.bottom, 4)

            Divider()

            // Mini Steering Indicator Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("STEERING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%+.2f", arbiter.latestPacket.steeringAngle))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                GeometryReader { geo in
                    let mid = geo.size.width / 2.0
                    let angle = CGFloat(arbiter.latestPacket.steeringAngle)
                    let barWidth = abs(angle) * mid

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))

                        Rectangle()
                            .fill(Color.cyan)
                            .frame(width: barWidth, height: 6)
                            .offset(x: angle < 0 ? mid - barWidth : mid)
                    }
                }
                .frame(height: 6)
            }

            // Pedals Mini Bars
            HStack(spacing: 12) {
                miniPedalBar(title: "BRAKE", value: arbiter.latestPacket.normalizedBrake, color: .red)
                miniPedalBar(title: "THROTTLE", value: arbiter.latestPacket.normalizedThrottle, color: .green)
            }

            Divider()

            // Connection Mode Selector
            Picker("Connection Mode", selection: $arbiter.connectionPreference) {
                ForEach(ConnectionPreference.allCases) { pref in
                    Text(pref.rawValue).tag(pref)
                }
            }
            .pickerStyle(.menu)

            // Output Mode Selector
            Picker("Output Mode", selection: $coordinator.activeMode) {
                ForEach(OutputMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)

            Divider()

            // Quick Actions
            HStack {
                Button("Recenter Wheel (0°)") {
                    coordinator.recalibrate(currentAngle: arbiter.latestPacket.steeringAngle)
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private func miniPedalBar(title: String, value: Float, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(height: 5)
        }
    }
}
