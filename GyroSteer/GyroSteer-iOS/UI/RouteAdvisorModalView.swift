//
//  RouteAdvisorModalView.swift
//  GyroSteer - iOS Transmitter UI
//
//  Authentic Euro Truck Simulator 2 Route Advisor & Vehicle Service Terminal.
//  Provides one-tap Emergency Tow Service (F7 + Enter), Seat & Mirror
//  Customization (F4), Cargo Freight Info (F6), and full Advisor control.
//

import SwiftUI
#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public struct RouteAdvisorModalView: View {
    @ObservedObject var coordinator: TransmissionCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: AdvisorTab = .service
    @State private var showTowConfirmationBanner: Bool = false

    public enum AdvisorTab: String, CaseIterable, Identifiable {
        case service = "Tow & Service"
        case seat = "Seat & Mirrors"
        case advisor = "Route Advisor"
        case cargo = "Freight / Job"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .service: return "wrench.and.screwdriver.fill"
            case .seat: return "car.side.fill"
            case .advisor: return "location.north.circle.fill"
            case .cargo: return "shippingbox.fill"
            }
        }

        public var functionKeyLabel: String {
            switch self {
            case .service: return "F7"
            case .seat: return "F4"
            case .advisor: return "F1 / F3 / F5"
            case .cargo: return "F6"
            }
        }
    }

    public init(coordinator: TransmissionCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ZStack {
            // Dark cockpit glass background
            Color(red: 0.04, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                // MARK: - Tab Switcher
                tabSwitcher
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                // MARK: - Active Section Content
                ScrollView {
                    VStack(spacing: 16) {
                        if showTowConfirmationBanner {
                            towSuccessBanner
                                .transition(.scale.combined(with: .opacity))
                        }

                        switch selectedTab {
                        case .service:
                            serviceAndTowingSection
                        case .seat:
                            seatAndMirrorSection
                        case .advisor:
                            routeAdvisorModesSection
                        case .cargo:
                            cargoAndJobSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }

                // MARK: - Bottom Action Bar (Enter / Escape)
                bottomControlBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.07).opacity(0.95))
            }
        }
    }

    // =========================================================================
    // MARK: - 1. Header Bar
    // =========================================================================

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "truck.box.badge.clock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ETS2 ROUTE ADVISOR & SERVICE")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Interactive Terminal & Vehicle Diagnostics")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            Spacer()

            // Close / Resume Driving Button
            Button {
                coordinator.pressButton(.escapeKey)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    coordinator.releaseButton(.escapeKey)
                }
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("RESUME")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                )
            }
        }
    }

    // =========================================================================
    // MARK: - 2. Tab Switcher
    // =========================================================================

    private var tabSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(AdvisorTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    HapticManager.shared.buttonTap()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                    // Automatically trigger the corresponding in-game menu
                    switch tab {
                    case .service:
                        triggerKey(.serviceF7)
                    case .seat:
                        triggerKey(.seatAdjustF4)
                    case .advisor:
                        triggerKey(.advisorF1)
                    case .cargo:
                        triggerKey(.jobInfoF6)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 11, weight: .bold))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                            Text(tab.functionKeyLabel)
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .opacity(0.7)
                        }
                    }
                    .foregroundColor(isSelected ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.orange : Color(white: 0.12).opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.orange : Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 3. Service & Towing Section (F7)
    // =========================================================================

    private var serviceAndTowingSection: some View {
        VStack(spacing: 14) {
            // Main Towing Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 18, weight: .bold))
                    Text("EMERGENCY ROADSIDE TOWING (F7)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text("SERVICE CALL")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(4)
                }

                Text("Call the heavy-recovery tow truck to transport your vehicle and trailer to the nearest authorized workshop facility.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))

                // Big Action Button: CALL TOW TRUCK
                Button {
                    callTowTruckAction()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "towtruck.fill")
                            .font(.system(size: 20, weight: .black))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CALL TOW TRUCK NOW")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                            Text("Opens F7 Assistance & Confirms with Enter")
                                .font(.system(size: 9, weight: .medium))
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                    }
                    .foregroundColor(.white)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.85, green: 0.15, blue: 0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.9), lineWidth: 1.5)
                                    .shadow(color: Color.red.opacity(0.8), radius: 8)
                            )
                    )
                }

                HStack(spacing: 10) {
                    // Inspect Diagnostics only (F7)
                    Button {
                        triggerKey(.serviceF7)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.path.ecg")
                            Text("VIEW DAMAGE (F7)")
                        }
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                    }

                    // Confirm Action (Enter)
                    Button {
                        triggerKey(.enter)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("CONFIRM (ENTER)")
                        }
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.08).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.4), lineWidth: 1.2)
                    )
            )

            // Vehicle Wear & Diagnostics Guide
            VStack(alignment: .leading, spacing: 8) {
                Text("ROUTE ADVISOR DIAGNOSTICS KEY")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)

                diagnosticRow(icon: "engine.combustion.fill", title: "Engine & Transmission", desc: "Excessive damage causes engine stalling & gear slipping.")
                diagnosticRow(icon: "circle.circle", title: "Chassis & Wheels", desc: "Tire wear increases braking distance and loss of traction.")
                diagnosticRow(icon: "trailer", title: "Trailer Cargo Damage", desc: "Reduces payout and company rating upon final delivery.")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.08).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private func diagnosticRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // =========================================================================
    // MARK: - 4. Seat, Mirrors & Cabin Customization Section (F4)
    // =========================================================================

    private var seatAndMirrorSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundColor(.cyan)
                        .font(.system(size: 18, weight: .bold))
                    Text("CABIN & SEAT CUSTOMIZATION (F4)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                }

                Text("Adjust driver seat position, eye-level field of view, and side mirrors directly from your phone.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))

                // F4 Trigger Button
                Button {
                    triggerKey(.seatAdjustF4)
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .bold))
                        Text("TOGGLE ETS2 SEAT & MIRRORS MENU (F4)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.cyan.opacity(0.35))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.cyan, lineWidth: 1)
                    )
                }

                // Sub-category selector in ETS2 (Keys 1, 2, 3)
                HStack(spacing: 8) {
                    customizationCategoryButton(number: "1", title: "SEAT") {
                        triggerKey(.cabinView) // Key '1'
                    }
                    customizationCategoryButton(number: "2", title: "MIRRORS") {
                        triggerKey(.cameraView) // Key '2' in ETS2
                    }
                    customizationCategoryButton(number: "3", title: "LIGHTS") {
                        triggerKey(.hazardLights) // keycode or 3
                    }
                }

                Divider().background(Color.white.opacity(0.2))

                // Directional D-Pad for Ergonomic Seat / Mirror Control
                Text("DIRECTIONAL ADJUSTMENT D-PAD")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.85))

                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        // UP
                        dpadButton(icon: "chevron.up", label: "UP / RAISE") {
                            sendDirectionalPulse(up: true)
                        }

                        HStack(spacing: 20) {
                            // LEFT
                            dpadButton(icon: "chevron.left", label: "BACK / LEFT") {
                                sendDirectionalPulse(left: true)
                            }

                            // Center Reset / Recenter
                            Button {
                                coordinator.recenter()
                            } label: {
                                Text("0°")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Circle())
                            }

                            // RIGHT
                            dpadButton(icon: "chevron.right", label: "FWD / RIGHT") {
                                sendDirectionalPulse(right: true)
                            }
                        }

                        // DOWN
                        dpadButton(icon: "chevron.down", label: "DOWN / LOWER") {
                            sendDirectionalPulse(down: true)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.08).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1.2)
                    )
            )
        }
    }

    private func customizationCategoryButton(number: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(number)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                Text(title)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
        }
    }

    private func dpadButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                Text(label)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white)
            .frame(width: 64, height: 48)
            .background(Color.white.opacity(0.14))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
            )
        }
    }

    // =========================================================================
    // MARK: - 5. Route Advisor Display Modes Section (F1 / F3 / F5)
    // =========================================================================

    private var routeAdvisorModesSection: some View {
        VStack(spacing: 12) {
            advisorModeCard(
                key: "F1",
                title: "ADVISOR PAUSE / MOUSE POINTER",
                desc: "Pauses ETS2 and reveals the desktop mouse cursor over the Route Advisor.",
                buttonAction: { triggerKey(.advisorF1) }
            )

            advisorModeCard(
                key: "F3",
                title: "NAVIGATION & SPEED LIMIT",
                desc: "Cycles GPS map sizes and displays current road speed limits & ETA.",
                buttonAction: { triggerKey(.routeAdvisor) }
            )

            advisorModeCard(
                key: "F5",
                title: "NAVIGATION MAP ZOOM",
                desc: "Zooms in and out on the GPS map (Close, Medium, Full overview).",
                buttonAction: { triggerKey(.mapZoom) }
            )

            advisorModeCard(
                key: "M",
                title: "FULL EUROPEAN WORLD MAP",
                desc: "Opens the fullscreen interactive world map with route planning.",
                buttonAction: { triggerKey(.worldMap) }
            )
        }
    }

    private func advisorModeCard(key: String, title: String, desc: String, buttonAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: buttonAction) {
                Text(key)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.cyan)
                    .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // =========================================================================
    // MARK: - 6. Freight / Cargo Job Section (F6)
    // =========================================================================

    private var cargoAndJobSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18, weight: .bold))
                    Text("CURRENT JOB & CARGO INFO (F6)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                }

                Text("Display the active delivery contract, cargo weight, destination company, delivery deadline, and estimated freight income.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))

                Button {
                    triggerKey(.jobInfoF6)
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("SHOW CARGO DETAILS ON SCREEN (F6)")
                    }
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.green.opacity(0.3))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1)
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.08).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // =========================================================================
    // MARK: - 7. Bottom Control Bar
    // =========================================================================

    private var bottomControlBar: some View {
        HStack(spacing: 12) {
            // Escape / Back
            Button {
                triggerKey(.escapeKey)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("ESC (BACK)")
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
            }

            // Enter / Confirm
            Button {
                triggerKey(.enter)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("ENTER (CONFIRM)")
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green)
                .cornerRadius(8)
            }
        }
    }

    // =========================================================================
    // MARK: - Banner Notification
    // =========================================================================

    private var towSuccessBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text("TOW ASSISTANCE REQUESTED!")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("Sent F7 Service Call & confirmed with Enter to ETS2.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.05, green: 0.25, blue: 0.1))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green, lineWidth: 1))
        )
    }

    // =========================================================================
    // MARK: - Action Helpers
    // =========================================================================

    private func triggerKey(_ button: SteeringButtons) {
        HapticManager.shared.buttonTap()
        coordinator.pressButton(button)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            coordinator.releaseButton(button)
        }
    }

    private func callTowTruckAction() {
        HapticManager.shared.buttonTap()
        // Step 1: Open F7 Vehicle Diagnostics & Service screen
        coordinator.pressButton(.serviceF7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            coordinator.releaseButton(.serviceF7)
        }

        // Step 2: Confirm calling assistance with Enter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            coordinator.pressButton(.enter)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                coordinator.releaseButton(.enter)
            }
        }

        withAnimation {
            showTowConfirmationBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation {
                showTowConfirmationBanner = false
            }
        }
    }

    private func sendDirectionalPulse(up: Bool = false, down: Bool = false, left: Bool = false, right: Bool = false) {
        HapticManager.shared.pedalTick()
        if up {
            coordinator.throttle = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { coordinator.throttle = 0.0 }
        } else if down {
            coordinator.brake = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { coordinator.brake = 0.0 }
        } else if left {
            // Pulse left blinker or left steer
            coordinator.pressButton(.gearDown)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { coordinator.releaseButton(.gearDown) }
        } else if right {
            coordinator.pressButton(.gearUp)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { coordinator.releaseButton(.gearUp) }
        }
    }
}
