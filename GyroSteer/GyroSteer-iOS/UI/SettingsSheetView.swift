//
//  SettingsSheetView.swift
//  GyroSteer - iOS Transmitter UI
//
//  Configuration sheet for Game HUD Profiles, Haptics, steering curves,
//  and connection endpoints.
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
                // MARK: - Preferred Connection Method Section
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

                // MARK: - Game HUD Profile Section
                Section(header: Text("Active Game HUD Profile")) {
                    ForEach(GameHUDProfile.allCases) { profile in
                        Button {
                            coordinator.setProfile(profile)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(profile.accentColor.opacity(0.18))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: profile.iconName)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(profile.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(profile.title)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.primary)

                                        if coordinator.activeHUDProfile == profile {
                                            Text("ACTIVE")
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(profile.accentColor))
                                        }
                                    }

                                    Text(profile.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if coordinator.activeHUDProfile == profile {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(profile.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - Cockpit Button Appearance
                Section(header: Text("Cockpit Buttons Appearance")) {
                    Picker("Button Display Style", selection: $coordinator.buttonDisplayMode) {
                        ForEach(ButtonDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(coordinator.buttonDisplayMode == .iconOnly
                         ? "Minimal & Clean: Extra-large automotive icons (22-26pt) with zero text clutter."
                         : "Detailed: Large icons paired with clear function labels.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - Tactile Haptic Engine Section
                Section(header: Text("Tactile Haptic Engine")) {
                    Toggle("Enable Haptic Feedback", isOn: $haptics.isEnabled)
                        .tint(coordinator.activeHUDProfile.accentColor)

                    if haptics.isEnabled {
                        Toggle("Steering Center Detent", isOn: $haptics.enableCenterDetent)
                            .tint(coordinator.activeHUDProfile.accentColor)
                        Text("Generates a physical tactile notch in your hands whenever the steering passes through 0° center.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle("Pedal Notch Ticks", isOn: $haptics.enablePedalNotches)
                            .tint(coordinator.activeHUDProfile.accentColor)
                        Text("Subtle mechanical clicks as you pull through throttle and brake travel, plus a solid clack at 100% floor.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - Transmission Mode (Automatic vs Manual)
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

                // MARK: - Steering Dynamics Section
                Section(header: Text("Steering Wheel Geometry")) {
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

                // MARK: - Connection & Port Forwarding
                Section(header: Text("Connection & USB Muxing")) {
                    Text("Auto-discovery uses Bonjour over Wi-Fi and Apple USB-to-Lightning/USB-C network link.")
                        .font(.caption)
                        .foregroundColor(.gray)

                    HStack {
                        Text("Manual Target IP")
                        Spacer()
                        TextField("e.g. 127.0.0.1 or 192.168.1.50", text: $manualHost)
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
            .navigationTitle("GyroSteer Settings")
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
}
