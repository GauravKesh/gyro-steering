//
//  DashboardView.swift
//  GyroSteer - macOS Receiver UI
//
//  Primary macOS dashboard window: transport arbiter telemetry, live oscilloscope,
//  analog steering arc gauge, dual pedal meters, and ETS2 output mode controls.
//

import SwiftUI

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public struct DashboardView: View {
    @ObservedObject var arbiter: TransportArbiter
    @ObservedObject var coordinator: OutputCoordinator
    @ObservedObject private var logger = EventLogger.shared

    private var hasAccessibility: Bool {
        AccessibilityPermissionHelper.isAccessibilityGranted
    }

    public init(arbiter: TransportArbiter = TransportArbiter(), coordinator: OutputCoordinator = OutputCoordinator()) {
        self.arbiter = arbiter
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Accessibility Warning Banner
            if !hasAccessibility {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 16, weight: .bold))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("macOS Accessibility Permission Required")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text("macOS is blocking keyboard and steering inputs to ETS2 until authorized in System Settings.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    Button("Open System Settings") {
                        AccessibilityPermissionHelper.openAccessibilitySettings()
                        AccessibilityPermissionHelper.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.3))
                .overlay(Rectangle().frame(height: 1).foregroundColor(.orange), alignment: .bottom)
            }

            // MARK: - Header Status & Metrics Bar
            headerBar
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(white: 0.12))

            Divider()

            // MARK: - Main Split Layout
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // Top Telemetry Row: Arc Gauge + Pedals + Button Matrix
                    HStack(alignment: .top, spacing: 24) {
                        // Left: Steering Arc Gauge
                        VStack(spacing: 12) {
                            Text("STEERING TELEMETRY")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)

                            SteeringArcGauge(
                                steeringAngle: arbiter.latestPacket.steeringAngle,
                                maxLockAngle: coordinator.maxLockAngle
                            )
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.10)))

                        // Center: Dual Throttle & Brake Pedals
                        VStack(spacing: 12) {
                            Text("PEDALS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)

                            HStack(spacing: 20) {
                                pedalMeter(
                                    title: "BRAKE",
                                    value: arbiter.latestPacket.normalizedBrake,
                                    color: .red
                                )
                                pedalMeter(
                                    title: "THROTTLE",
                                    value: arbiter.latestPacket.normalizedThrottle,
                                    color: .green
                                )
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.10)))

                        // Right: Simulator Action Buttons Matrix
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SIMULATOR BUTTONS (16-BIT)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)

                            buttonsMatrix
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.10)))
                    }

                    // Middle Row: Real-Time Oscilloscope Waveform
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundColor(.cyan)
                            Text("LIVE GYRO OSCILLOSCOPE (ROLL TELEMETRY)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("WINDOW: 300 SAMPLES @ 100 Hz")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        OscilloscopeView(history: arbiter.telemetryHistory)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.10)))

                    // Bottom Row: Output Mode & Calibration Controls
                    tuningAndOutputSection
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.10)))

                    // Live Diagnostics & Event Logs
                    liveDiagnosticSection
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.10)))
                }
                .padding(20)
            }
        }
        .frame(minWidth: 880, minHeight: 680)
        .background(Color(white: 0.07))
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 16) {
            // App Title & Logo
            HStack(spacing: 8) {
                Image(systemName: "steeringwheel")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.cyan)

                VStack(alignment: .leading, spacing: 1) {
                    Text("GyroSteer Receiver")
                        .font(.system(size: 16, weight: .heavy))
                    Text("Euro Truck Simulator 2 Ecosystem")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // User Connection Link Mode Selector (Cable / Wi-Fi / BT / Auto)
            connectionPreferencePicker

            Spacer()

            // Active Connection Badge
            HStack(spacing: 8) {
                Image(systemName: arbiter.isConnected ? arbiter.activeTransport.iconName : "bolt.slash.fill")
                    .foregroundColor(arbiter.isConnected ? .green : .red)

                VStack(alignment: .leading, spacing: 1) {
                    Text(arbiter.isConnected
                         ? (arbiter.connectionPreference == .auto ? arbiter.activeTransport.displayName : arbiter.connectionPreference.rawValue)
                         : "SEARCHING...")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(arbiter.isConnected ? .white : .gray)

                    Text(arbiter.isConnected ? "Transport Arbiter Active" : "Waiting for \(arbiter.connectionPreference.rawValue) link")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.16)))

            // Live Hz & Latency Telemetry Readout
            HStack(spacing: 14) {
                metricPill(label: "RATE", value: "\(Int(arbiter.liveHz)) Hz", color: .cyan)
                metricPill(label: "LATENCY", value: String(format: "%.1f ms", arbiter.estimatedLatencyMs), color: .green)
                metricPill(label: "JITTER", value: String(format: "±%.1f ms", arbiter.jitterMs), color: .orange)
            }
        }
    }

    private var connectionPreferencePicker: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("CONNECTION MODE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                Text("• \(arbiter.connectionPreference.subtitle)")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }

            Picker("Link", selection: $arbiter.connectionPreference) {
                ForEach(ConnectionPreference.allCases) { pref in
                    Text(pref.shortName).tag(pref)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
    }

    private func metricPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.16)))
    }

    // MARK: - Pedals Visualizer

    private func pedalMeter(title: String, value: Float, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(Int(value * 100))%")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(value > 0.05 ? .white : .gray)

            GeometryReader { geo in
                let height = geo.size.height
                let fill = CGFloat(value) * height

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(white: 0.16))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(height: fill)
                }
            }
            .frame(width: 38, height: 140)

            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Button Bitmask Matrix

    private var buttonsMatrix: some View {
        let buttons = arbiter.latestPacket.buttons

        let buttonList: [(String, SteeringButtons)] = [
            ("◀ Left Blinker", .leftBlinker),
            ("Right Blinker ▶", .rightBlinker),
            ("🎺 Horn", .horn),
            ("💡 Headlights", .headlights),
            ("Gear Up (+)", .gearUp),
            ("Gear Down (-)", .gearDown),
            ("Cruise Control", .cruiseControl),
            ("Recenter (0°)", .recenter),
            ("Hazard Lights", .hazardLights),
            ("Wipers", .wipers),
            ("Engine Start", .engineStart),
            ("Parking Brake", .parkingBrake),
            ("⏎ Enter", .enter),
            ("⚙️ Gearbox A/M (G)", .transmissionMode),
            ("🎥 Camera View", .cameraView),
            ("Retarder - (;)", .retarderDown),
            ("Retarder + (')", .retarderUp),
            ("Engine Brake (B)", .engineBrake),
            ("Neutral (N)", .neutral),
            ("Cabin View (1)", .cabinView),
            ("Route Advisor (F3)", .routeAdvisor),
            ("Map Zoom (F5)", .mapZoom),
            ("World Map (M)", .worldMap)
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(buttonList, id: \.0) { item in
                let isActive = buttons.contains(item.1)
                HStack(spacing: 6) {
                    Circle()
                        .fill(isActive ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .shadow(color: isActive ? .green : .clear, radius: 4)

                    Text(item.0)
                        .font(.system(size: 11, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .white : .gray)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.green.opacity(0.15) : Color(white: 0.14))
                )
            }
        }
        .frame(width: 280)
    }

    // MARK: - Tuning & Output Section

    private var tuningAndOutputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("OUTPUT ENGINE & SIMULATOR DYNAMICS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)

                Spacer()

                // Quick Game Preset Buttons
                HStack(spacing: 8) {
                    Button {
                        coordinator.useMouseSteering = true
                        coordinator.maxLockAngle = 45.0
                        coordinator.deadzone = 0.02
                    } label: {
                        Text("🚛 ETS2 Mode")
                            .font(.caption)
                            .fontWeight(coordinator.useMouseSteering ? .bold : .regular)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(coordinator.useMouseSteering ? .blue : .secondary.opacity(0.2))

                    Button {
                        coordinator.useMouseSteering = false
                        coordinator.maxLockAngle = 30.0
                        coordinator.deadzone = 0.0
                    } label: {
                        Text("🏎️ Asphalt Mode")
                            .font(.caption)
                            .fontWeight(!coordinator.useMouseSteering ? .bold : .regular)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(!coordinator.useMouseSteering ? .purple : .secondary.opacity(0.2))
                }
            }

            HStack(alignment: .top, spacing: 24) {
                // Left Column: Output Mode Picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Controller Mode")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    Picker("Mode", selection: $coordinator.activeMode) {
                        ForEach(OutputMode.allCases) { mode in
                            HStack {
                                Image(systemName: mode.iconName)
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text(coordinator.activeMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if coordinator.activeMode == .keyboardEmulation {
                        Button {
                            coordinator.isDrivingActive.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: coordinator.isDrivingActive ? "pause.fill" : "play.fill")
                                Text(coordinator.isDrivingActive ? "DRIVING ACTIVE (KEYS ON)" : "DRIVING PAUSED (KEYS MUTED)")
                                    .fontWeight(.bold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(coordinator.isDrivingActive ? .green : .secondary)
                        .controlSize(.regular)

                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Smart Game Shield (Auto-Mute on Desktop)", isOn: $coordinator.enableGameOnlyFilter)
                                .font(.caption)
                                .toggleStyle(.switch)

                            Toggle("Analog Mouse Steering (ETS2)", isOn: $coordinator.useMouseSteering)
                                .font(.caption)
                                .toggleStyle(.switch)
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(hasAccessibility ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)

                            Text(hasAccessibility ? "Accessibility Permission Granted" : "Accessibility Permission Required")
                                .font(.caption)
                                .foregroundColor(hasAccessibility ? .green : .orange)

                            if !hasAccessibility {
                                Button("Authorize") {
                                    AccessibilityPermissionHelper.requestAccessibilityPermission()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Right Column: Tuning Sliders
                VStack(alignment: .leading, spacing: 10) {
                    if !coordinator.useMouseSteering {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Arcade Steering Sensitivity")
                                Spacer()
                                Text(String(format: "%.1fx", coordinator.keyboardSteeringSensitivity))
                                    .foregroundColor(.purple)
                                    .fontWeight(.bold)
                            }
                            Slider(value: $coordinator.keyboardSteeringSensitivity, in: 1.0...5.0, step: 0.5)
                            Text("Higher sensitivity turns sharp corners with minimal phone tilt.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }

                    HStack {
                        Text("Max Lock Angle")
                        Spacer()
                        Picker("", selection: $coordinator.maxLockAngle) {
                            ForEach(ProtocolConstants.lockAngleOptionsDegrees, id: \.self) { angle in
                                Text("\(Int(angle))°").tag(angle)
                            }
                        }
                        .frame(width: 100)
                    }

                    HStack {
                        Text("Mac-Side Deadzone Override")
                        Spacer()
                        Text("\(Int(coordinator.deadzone * 100))%")
                            .foregroundColor(.cyan)
                    }
                    Slider(value: $coordinator.deadzone, in: 0.0...0.10, step: 0.01)

                    HStack {
                        Text("Linearity Exponent")
                        Spacer()
                        Text(String(format: "%.2fx", coordinator.linearity))
                            .foregroundColor(.cyan)
                    }
                    Slider(value: $coordinator.linearity, in: 0.8...2.5, step: 0.05)

                    HStack {
                        Button("Recenter Zero Point") {
                            coordinator.recalibrate(currentAngle: arbiter.latestPacket.steeringAngle)
                        }
                        .buttonStyle(.borderedProminent)

                        if coordinator.localZeroOffset != 0.0 {
                            Button("Reset Offset") {
                                coordinator.resetCalibration()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Live Diagnostic Console

    private var liveDiagnosticSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.green)
                Text("LIVE DIAGNOSTIC LOGS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)

                Spacer()

                Text("Disk Log: /tmp/gyrosteer.log")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if logger.recentLogs.isEmpty {
                            Text("Waiting for events... Connect phone or tilt wheel.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                        } else {
                            ForEach(logger.recentLogs.indices, id: \.self) { idx in
                                Text(logger.recentLogs[idx])
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.green.opacity(0.9))
                                    .id(idx)
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(height: 110)
                .background(Color.black.opacity(0.85))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .onChange(of: logger.recentLogs.count) { _, _ in
                    if !logger.recentLogs.isEmpty {
                        proxy.scrollTo(logger.recentLogs.count - 1, anchor: .bottom)
                    }
                }
            }
        }
    }
}
