//
//  SettingsSheetView.swift
//  GyroSteer - iOS Transmitter UI
//
//  Hamburger menu configuration sheet for connection diagnostics,
//  steering dynamics, haptics, transmission modes, and ETS2 key mappings.
//

import SwiftUI

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public struct SettingsSheetView: View {
    @ObservedObject var coordinator: TransmissionCoordinator
    @ObservedObject var motionManager: MotionManager
    @ObservedObject private var haptics = HapticManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var manualHost: String = ""
    @State private var manualPort: String = "28282"

    public init(coordinator: TransmissionCoordinator) {
        self.coordinator = coordinator
        self.motionManager = coordinator.motionManager
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - 1. Live Connection & Technical Diagnostics
                Section(header: Text("Live Connection & Technical Diagnostics")) {
                    HStack {
                        Label("Active Transport", systemImage: coordinator.activeTransport.iconName)
                        Spacer()
                        Text(coordinator.activeTransport.displayName)
                            .fontWeight(.bold)
                            .foregroundColor(coordinator.isConnected ? .green : .orange)
                    }

                    HStack {
                        Label("Telemetry Latency", systemImage: "timer")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(coordinator.latencyMs < 5.0 ? Color.green : (coordinator.latencyMs < 20.0 ? Color.yellow : Color.red))
                                .frame(width: 8, height: 8)
                            Text(String(format: "%.1f ms", coordinator.latencyMs))
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                        }
                    }

                    HStack {
                        Label("Stream Frequency", systemImage: "waveform.path.ecg")
                        Spacer()
                        Text(String(format: "%.0f Hz", coordinator.currentHz))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                    }

                    HStack {
                        Label("Packets Transmitted", systemImage: "arrow.up.circle.fill")
                        Spacer()
                        Text("\(coordinator.packetsSentCount)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - 2. Preferred Connection Method Section
                Section(header: Text("Connection Method (Cable / Wi-Fi / Bluetooth)")) {
                    Picker("Preferred Transport", selection: Binding(
                        get: { coordinator.preferredConnection },
                        set: { coordinator.setConnectionPreference($0) }
                    )) {
                        ForEach(ConnectionPreference.allCases) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 8) {
                        Image(systemName: coordinator.preferredConnection.iconName)
                            .foregroundColor(coordinator.activeHUDProfile.accentColor)
                            .font(.system(size: 14, weight: .bold))

                        Text(coordinator.preferredConnection.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                // MARK: - 3. Transmission Mode (Automatic vs Manual)
                Section(header: Text("Transmission Mode (ETS2 Gearbox)")) {
                    Picker("Gearbox Mode", selection: Binding(
                        get: { coordinator.transmissionMode },
                        set: { coordinator.setTransmissionMode($0) }
                    )) {
                        ForEach(TransmissionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("In ETS2, set Transmission to 'Sequential' and bind key 'G' to 'Gearbox Switch Automatic / Sequential' in Options -> Keys & Buttons. GyroSteer pulses key 'G' to toggle modes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - 4. Steering Dynamics Section
                Section(header: Text("Steering Wheel Geometry & Curves")) {
                    Picker("Max Lock Angle", selection: $motionManager.maxLockAngleDegrees) {
                        ForEach(ProtocolConstants.lockAngleOptionsDegrees, id: \.self) { angle in
                            Text("\(Int(angle))° (±\(Int(angle / 2))°)")
                                .tag(angle)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Center Deadzone")
                            Spacer()
                            Text("\(Int(motionManager.centerDeadzone * 100))%")
                                .foregroundColor(.cyan)
                        }
                        Slider(value: $motionManager.centerDeadzone, in: 0.0...0.10, step: 0.005)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Linearity Curve (Gamma)")
                            Spacer()
                            Text(String(format: "%.2fx", motionManager.linearityExponent))
                                .foregroundColor(.cyan)
                        }
                        Slider(value: $motionManager.linearityExponent, in: 0.8...2.5, step: 0.05)
                        Text("Higher values give smoother, more precise highway steering at center.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sensor Smoothing (EMA)")
                            Spacer()
                            Text(String(format: "%.2f", motionManager.smoothingAlpha))
                                .foregroundColor(.cyan)
                        }
                        Slider(value: $motionManager.smoothingAlpha, in: 0.4...1.0, step: 0.05)
                    }
                }

                // MARK: - 5. Tactile Haptic Engine Section
                Section(header: Text("Dynamic Driving Haptic Engine")) {
                    Toggle("Enable Haptic Feedback", isOn: $haptics.isEnabled)
                        .tint(coordinator.activeHUDProfile.accentColor)

                    if haptics.isEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Master Haptic Intensity")
                                Spacer()
                                Text("\(Int(haptics.masterIntensity * 100))%")
                                    .foregroundColor(.cyan)
                            }
                            Slider(value: $haptics.masterIntensity, in: 0.2...1.0, step: 0.05)
                        }

                        Toggle("Engine RPM Rumble", isOn: $haptics.enableEngineRumble)
                            .tint(coordinator.activeHUDProfile.accentColor)
                        Text("Continuous diesel engine vibration that ramps up in frequency and intensity with throttle input.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle("ABS Brake Chatter (>75%)", isOn: $haptics.enableABSPulse)
                            .tint(coordinator.activeHUDProfile.accentColor)
                        Text("Simulates rapid anti-lock brake pump pulsations during heavy emergency braking.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle("Steering Lock Bump-Stop", isOn: $haptics.enableSteeringLockBumper)
                            .tint(coordinator.activeHUDProfile.accentColor)
                        Text("Solid physical impact sensation when reaching maximum steering wheel lock angle.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle("Steering Center Detent (0°)", isOn: $haptics.enableCenterDetent)
                            .tint(coordinator.activeHUDProfile.accentColor)
                        Text("Generates a physical tactile notch in your hands whenever the steering passes through 0° center.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle("Turn Signal Tick-Tock", isOn: $haptics.enableBlinkerTicks)
                            .tint(coordinator.activeHUDProfile.accentColor)
                        Text("Alternating mechanical clicks in sync with left and right blinkers.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle("Pedal Notch Ticks", isOn: $haptics.enablePedalNotches)
                            .tint(coordinator.activeHUDProfile.accentColor)
                        Text("Subtle mechanical clicks as you pull through throttle and brake travel, plus a solid clack at 100% floor.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - 6. ETS2 Controller Bindings Reference
                Section(header: Text("ETS2 Default Key Bindings Reference")) {
                    VStack(alignment: .leading, spacing: 6) {
                        keyRow(action: "Gear Up (+)", key: "Left Shift")
                        keyRow(action: "Gear Down (-)", key: "Left Ctrl")
                        keyRow(action: "Shift to Neutral (N)", key: "N")
                        keyRow(action: "Retarder Increase (+)", key: "' (Quote)")
                        keyRow(action: "Retarder Decrease (-)", key: "; (Semicolon)")
                        keyRow(action: "Engine Brake Toggle", key: "B")
                        keyRow(action: "Parking Brake / Handbrake", key: "Spacebar")
                        keyRow(action: "Engine Start / Stop", key: "E")
                        keyRow(action: "Enter / Toll / Ferry", key: "Return / Enter")
                        keyRow(action: "Trailer Attach / Detach", key: "T")
                        keyRow(action: "Cabin Interior Camera", key: "1")
                        keyRow(action: "Camera Views 1-6", key: "1, 2, 3, 4, 5, 6")
                        keyRow(action: "Route Advisor Modes", key: "F3")
                        keyRow(action: "Map View / Zoom", key: "F5")
                        keyRow(action: "World Map", key: "M")
                        keyRow(action: "Cruise Control", key: "C")
                        keyRow(action: "Horn & Air Horn", key: "H + N")
                        keyRow(action: "Left / Right Blinker", key: "[ / ]")
                        keyRow(action: "Hazard Warning Lights", key: "F")
                        keyRow(action: "Windshield Wipers", key: "P")
                        keyRow(action: "Headlights / High Beam", key: "L / K")
                        keyRow(action: "Gearbox Auto / Sequential", key: "G")
                    }
                    .font(.caption)
                }

                // MARK: - 7. Manual Endpoint & Port Forwarding
                Section(header: Text("Manual Connection Endpoint")) {
                    HStack {
                        Text("Manual Target IP")
                        Spacer()
                        TextField("e.g. 192.168.1.50", text: $manualHost)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    HStack {
                        Text("Target Port")
                        Spacer()
                        TextField("28282", text: $manualPort)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }

                    Button("Apply Custom IP Endpoint") {
                        let port = UInt16(manualPort) ?? ProtocolConstants.defaultPort
                        coordinator.nwTransmitter.setManualEndpoint(host: manualHost.isEmpty ? nil : manualHost, port: port)
                    }
                    .foregroundColor(.cyan)

                    if !manualHost.isEmpty {
                        Button("Reset to Bonjour Auto-Discovery", role: .destructive) {
                            manualHost = ""
                            coordinator.nwTransmitter.setManualEndpoint(host: nil, port: nil)
                        }
                    }
                }
            }
            .navigationTitle("GyroSteer Controller Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func keyRow(action: String, key: String) -> some View {
        HStack {
            Text(action)
                .foregroundColor(.primary)
            Spacer()
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.cyan)
        }
    }
}
