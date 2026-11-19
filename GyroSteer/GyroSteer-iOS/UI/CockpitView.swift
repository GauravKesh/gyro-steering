//
//  CockpitView.swift
//  GyroSteer - iOS Transmitter UI
//
//  Landscape racing and truck cockpit dashboard with dual pedal thumb zones,
//  multi-game HUD profiles (ETS2, Asphalt 8, F1 Sim), large iconography,
//  and Icon-Only vs Icon+Text display modes.
//

import SwiftUI

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public struct CockpitView: View {
    @StateObject private var coordinator = TransmissionCoordinator()
    @State private var isShowingSettings = false
    @State private var currentCameraIndex: Int = 1

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background cockpit gradient tailored to active game profile
                LinearGradient(
                    colors: coordinator.activeHUDProfile.backgroundGradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                HStack(spacing: 8) {
                    // MARK: - Left Thumb Zone: Brake Pedal
                    VStack(spacing: 6) {
                        VerticalSlider(
                            title: "BRAKE",
                            subtitle: "PULL",
                            accentColor: .red,
                            iconName: "car.side.fill",
                            displayMode: coordinator.buttonDisplayMode,
                            value: $coordinator.brake
                        )
                    }
                    .frame(width: coordinator.buttonDisplayMode == .iconOnly ? 64 : 76)
                    .padding(.leading, 6)

                    // MARK: - Center Zone: Telemetry, Gauge & Controls
                    VStack(spacing: 6) {
                        // Universal Header: Profile Switcher Pill + Display Mode Toggle + Telemetry Badge + Settings
                        universalHeaderBar

                        Spacer(minLength: 2)

                        // Center Layout based on Active Game Profile
                        switch coordinator.activeHUDProfile {
                        case .ets2:
                            ets2TruckCockpitLayout
                        case .asphalt:
                            asphaltArcadeCockpitLayout
                        case .f1Sim:
                            f1SimCockpitLayout
                        }

                        Spacer(minLength: 2)
                    }
                    .frame(maxWidth: .infinity)

                    // MARK: - Right Thumb Zone: Throttle Pedal & Quick Actions
                    HStack(spacing: 6) {
                        throttleQuickActionsBank

                        VerticalSlider(
                            title: "THROTTLE",
                            subtitle: "PULL",
                            accentColor: .green,
                            iconName: "bolt.fill",
                            displayMode: coordinator.buttonDisplayMode,
                            value: $coordinator.throttle
                        )
                        .frame(width: coordinator.buttonDisplayMode == .iconOnly ? 64 : 76)
                    }
                    .padding(.trailing, 6)
                }
                .padding(.vertical, 6)
            }
        }
        .onAppear {
            coordinator.start()
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
        }
        .onDisappear {
            coordinator.stop()
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheetView(coordinator: coordinator)
        }
    }

    // MARK: - Universal Header Bar

    private var universalHeaderBar: some View {
        HStack(spacing: 8) {
            // Game Profile Dropdown Pill (1-Tap Switching)
            Menu {
                ForEach(GameHUDProfile.allCases) { profile in
                    Button {
                        coordinator.setProfile(profile)
                    } label: {
                        HStack {
                            Image(systemName: profile.iconName)
                            Text(profile.title)
                            if coordinator.activeHUDProfile == profile {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: coordinator.activeHUDProfile.iconName)
                        .font(.system(size: 13, weight: .bold))
                    Text(coordinator.activeHUDProfile.shortName)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(coordinator.activeHUDProfile.accentColor.opacity(0.25))
                        .overlay(Capsule().stroke(coordinator.activeHUDProfile.accentColor, lineWidth: 1.5))
                )
            }

            // Quick Toggle: Icon Only vs Icon + Text
            Button {
                coordinator.toggleButtonDisplayMode()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: coordinator.buttonDisplayMode.iconName)
                        .font(.system(size: 11, weight: .bold))
                    Text(coordinator.buttonDisplayMode == .iconOnly ? "ICONS" : "TEXT")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(white: 0.16))
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
            }

            Spacer()

            // Connection Status & Hz Badge
            connectionStatusBadge

            Spacer()

            // Settings Sheet Trigger
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(8)
                    .background(Circle().fill(Color(white: 0.16)))
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Layout 1: 🚛 Euro Truck Simulator 2 (Authentic Truck Cluster)

    private var ets2TruckCockpitLayout: some View {
        HStack(spacing: 8) {
            // Left Ergonomic Shifter Paddle: GEAR - (Directly beside Brake Pedal!)
            transmissionPaddle(title: "GEAR -", icon: "chevron.down.2", button: .gearDown, isUp: false)

            // Center Truck Cockpit Core
            VStack(spacing: 6) {
                // Top Row: Lighting & Vision Switchbank (Large 22pt Icons!)
                HStack(spacing: 6) {
                    dashButton(icon: "arrow.left", title: "L BLINK", isActive: coordinator.activeButtons.contains(.leftBlinker), activeColor: .orange) {
                        coordinator.toggleButton(.leftBlinker)
                    }

                    dashButton(icon: "exclamationmark.triangle.fill", title: "HAZARD", isActive: coordinator.activeButtons.contains(.hazardLights), activeColor: .red) {
                        coordinator.toggleButton(.hazardLights)
                    }

                    dashButton(icon: "windshield.front.and.wiper", title: "WIPERS", isActive: coordinator.activeButtons.contains(.wipers), activeColor: .cyan) {
                        coordinator.toggleButton(.wipers)
                    }

                    dashButton(icon: "lightbulb.fill", title: "LIGHTS", isActive: coordinator.activeButtons.contains(.headlights), activeColor: .yellow) {
                        coordinator.toggleButton(.headlights)
                    }

                    dashButton(icon: "flashlight.on.fill", title: "BEAM", isActive: coordinator.activeButtons.contains(.highBeams), activeColor: .blue) {
                        coordinator.toggleButton(.highBeams)
                    }

                    dashButton(icon: "arrow.right", title: "R BLINK", isActive: coordinator.activeButtons.contains(.rightBlinker), activeColor: .orange) {
                        coordinator.toggleButton(.rightBlinker)
                    }
                }

                // Center Truck Wheel Gauge with Live Blinking Turn Signals
                SteeringWheelGauge(
                    degrees: coordinator.motionManager.currentDegrees,
                    normalizedSteering: coordinator.motionManager.normalizedSteering,
                    maxLockAngle: coordinator.motionManager.maxLockAngleDegrees,
                    isCentered: abs(coordinator.motionManager.normalizedSteering) < 0.01,
                    profile: .ets2,
                    isLeftBlinkerActive: coordinator.activeButtons.contains(.leftBlinker) || coordinator.activeButtons.contains(.hazardLights),
                    isRightBlinkerActive: coordinator.activeButtons.contains(.rightBlinker) || coordinator.activeButtons.contains(.hazardLights)
                )

                // Bottom Row: Cab Operations Console (Large Spaced Switches)
                HStack(spacing: 8) {
                    // Push-to-Start Engine Button
                    engineStartButton

                    // Trailer Attach/Detach
                    dashTapButton(icon: "trailer", title: "TRAIL", button: .trailerAttach, color: .orange)

                    // Cruise Control Lock
                    dashButton(icon: "gauge.with.needle.fill", title: "CRUISE", isActive: coordinator.activeButtons.contains(.cruiseControl), activeColor: .green) {
                        coordinator.toggleButton(.cruiseControl)
                    }

                    // Air Horn (Hold or tap to blast)
                    dashHoldButton(icon: "speaker.wave.3.fill", title: "HORN", button: .horn, activeColor: .purple)

                    // Recenter 0° Calibration
                    recenterButton
                }
            }

            // Right Ergonomic Shifter Paddle: GEAR + (Directly beside Throttle Pedal!)
            transmissionPaddle(title: "GEAR +", icon: "chevron.up.2", button: .gearUp, isUp: true)
        }
    }

    // MARK: - Layout 2: 🏎️ Asphalt 8 Arcade (Nitro & Drift Focused)

    private var asphaltArcadeCockpitLayout: some View {
        VStack(spacing: 8) {
            // Top Quick Arcade Bar
            HStack(spacing: 8) {
                dashTapButton(icon: "video.fill", title: "CAM (C)", button: .cruiseControl, color: .cyan)
                dashTapButton(icon: "arrow.counterclockwise.circle.fill", title: "RESPAWN", button: .trailerAttach, color: .orange)

                Spacer()

                dashTapButton(icon: "pause.fill", title: "PAUSE", button: .wipers, color: .yellow)
            }
            .padding(.horizontal, 6)

            // Center Wheel Gauge
            SteeringWheelGauge(
                degrees: coordinator.motionManager.currentDegrees,
                normalizedSteering: coordinator.motionManager.normalizedSteering,
                maxLockAngle: coordinator.motionManager.maxLockAngleDegrees,
                isCentered: abs(coordinator.motionManager.normalizedSteering) < 0.01,
                profile: .asphalt
            )

            // High-Energy Arcade Action Zone
            HStack(spacing: 14) {
                // Instant Drift Slide Trigger
                Button {
                    coordinator.pressButton(.gearDown)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        coordinator.releaseButton(.gearDown)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "skew")
                            .font(.system(size: 22, weight: .black))
                        if coordinator.buttonDisplayMode == .iconAndText {
                            Text("DRIFT")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(height: 48)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.35))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan, lineWidth: 1.5))
                    )
                }

                // Massive Glowing NITRO BOOST Button
                Button {
                    coordinator.pressButton(.parkingBrake)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        coordinator.releaseButton(.parkingBrake)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 26, weight: .black))
                        if coordinator.buttonDisplayMode == .iconAndText {
                            Text("NITRO")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.purple.opacity(0.7), radius: 12)
                    )
                }

                // Recenter
                recenterButton
            }
        }
    }

    // MARK: - Layout 3: 🏁 Formula 1 & Sim Racing (Paddle Shifter & Rev Lights)

    private var f1SimCockpitLayout: some View {
        HStack(spacing: 8) {
            // F1 Left Paddle
            transmissionPaddle(title: "DOWN", icon: "chevron.down.circle.fill", button: .gearDown, isUp: false)

            VStack(spacing: 6) {
                // F1 LED Shift Light Bar
                f1ShiftLightBar

                // Center Wheel Gauge
                SteeringWheelGauge(
                    degrees: coordinator.motionManager.currentDegrees,
                    normalizedSteering: coordinator.motionManager.normalizedSteering,
                    maxLockAngle: coordinator.motionManager.maxLockAngleDegrees,
                    isCentered: abs(coordinator.motionManager.normalizedSteering) < 0.01,
                    profile: .f1Sim
                )

                // Bottom Race Controls Bar
                HStack(spacing: 8) {
                    dashButton(icon: "wind", title: "DRS", isActive: coordinator.activeButtons.contains(.parkingBrake), activeColor: .green) {
                        coordinator.toggleButton(.parkingBrake)
                    }

                    dashButton(icon: "speedometer", title: "PIT", isActive: coordinator.activeButtons.contains(.cruiseControl), activeColor: .yellow) {
                        coordinator.toggleButton(.cruiseControl)
                    }

                    recenterButton

                    dashTapButton(icon: "bolt.fill", title: "FLASH", button: .headlights, color: .blue)

                    dashButton(icon: "power", title: "ENG", isActive: coordinator.activeButtons.contains(.engineStart), activeColor: .red) {
                        coordinator.toggleButton(.engineStart)
                    }
                }
            }

            // F1 Right Paddle
            transmissionPaddle(title: "UP", icon: "chevron.up.circle.fill", button: .gearUp, isUp: true)
        }
    }

    // MARK: - Specialized Components

    /// Large Transmission Shifter Paddle placed directly beside the thumb pedals
    private func transmissionPaddle(title: String, icon: String, button: SteeringButtons, isUp: Bool) -> some View {
        Button {
            coordinator.pressButton(button)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                coordinator.releaseButton(button)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .bold))

                if coordinator.buttonDisplayMode == .iconAndText {
                    Text(title)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
            }
            .foregroundColor(.white)
            .frame(width: 50, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.6), lineWidth: 1.5)
                    )
            )
        }
    }

    // MARK: - Right Thumb Quick Action Bank (Placed directly beside Throttle Pedal)
    private var throttleQuickActionsBank: some View {
        VStack(spacing: 6) {
            switch coordinator.activeHUDProfile {
            case .ets2:
                // 1. Camera View Cycling (1..6 with live badge)
                cyclingCameraButton

                // 2. Enter / Confirm Key (Tolls, Ferries, Jobs, Fuel, Rest)
                dashTapButton(icon: "arrow.turn.down.left", title: "ENTER", button: .enter, color: .cyan)

                // 3. Gearbox Switch: Automatic vs Manual / Sequential
                gearboxModeButton

                // 4. Air Parking Brake Toggle
                dashButton(
                    icon: "p.circle.fill",
                    title: "PARK",
                    isActive: coordinator.activeButtons.contains(.parkingBrake),
                    activeColor: .red
                ) {
                    coordinator.toggleButton(.parkingBrake)
                }

            case .asphalt:
                // 1. Camera Angle
                dashTapButton(icon: "video.fill", title: "CAM", button: .cruiseControl, color: .cyan)

                // 2. Nitro Boost Trigger
                dashTapButton(icon: "flame.fill", title: "NITRO", button: .parkingBrake, color: .purple)

                // 3. Drift Slide
                dashTapButton(icon: "skew", title: "DRIFT", button: .gearDown, color: .blue)

                // 4. Respawn Track Reset
                dashTapButton(icon: "arrow.counterclockwise.circle.fill", title: "RESPAWN", button: .trailerAttach, color: .orange)

            case .f1Sim:
                // 1. DRS Wing Open
                dashButton(icon: "wind", title: "DRS", isActive: coordinator.activeButtons.contains(.parkingBrake), activeColor: .green) {
                    coordinator.toggleButton(.parkingBrake)
                }

                // 2. Pit Lane Limiter
                dashButton(icon: "speedometer", title: "PIT", isActive: coordinator.activeButtons.contains(.cruiseControl), activeColor: .yellow) {
                    coordinator.toggleButton(.cruiseControl)
                }

                // 3. Flash Headlights
                dashTapButton(icon: "bolt.fill", title: "FLASH", button: .headlights, color: .blue)

                // 4. Engine Ignition Toggle
                dashButton(icon: "power", title: "ENG", isActive: coordinator.activeButtons.contains(.engineStart), activeColor: .red) {
                    coordinator.toggleButton(.engineStart)
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.08).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    /// Push-to-Start Button with illuminated LED ring
    private var engineStartButton: some View {
        let isRunning = coordinator.activeButtons.contains(.engineStart)
        return Button {
            coordinator.toggleButton(.engineStart)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "power")
                    .font(.system(size: 22, weight: .bold))
                if coordinator.buttonDisplayMode == .iconAndText {
                    Text("START")
                        .font(.system(size: 8, weight: .black))
                }
            }
            .foregroundColor(isRunning ? .black : .white)
            .frame(width: coordinator.buttonDisplayMode == .iconOnly ? 44 : 48, height: 44)
            .background(
                Circle()
                    .fill(isRunning ? Color.green : Color(white: 0.16))
                    .overlay(
                        Circle()
                            .stroke(isRunning ? Color.green : Color.red.opacity(0.6), lineWidth: 2)
                    )
                    .shadow(color: isRunning ? Color.green.opacity(0.6) : Color.clear, radius: 6)
            )
            .contentShape(Rectangle())
        }
    }

    /// Gearbox Switch: Automatic vs Manual / Sequential Shifting
    private var gearboxModeButton: some View {
        let isAuto = coordinator.transmissionMode == .automatic
        return Button {
            coordinator.toggleTransmissionMode()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isAuto ? "gearshape.2.fill" : "slider.vertical.3")
                    .font(.system(size: coordinator.buttonDisplayMode == .iconOnly ? 20 : 15, weight: .bold))
                if coordinator.buttonDisplayMode == .iconAndText {
                    Text(isAuto ? "AUTO" : "MAN")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                }
            }
            .foregroundColor(isAuto ? .black : .white)
            .frame(width: coordinator.buttonDisplayMode == .iconOnly ? 44 : 48, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isAuto ? Color.green : Color.orange)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isAuto ? Color.green : Color.orange, lineWidth: 1.5)
                    )
                    .shadow(color: (isAuto ? Color.green : Color.orange).opacity(0.6), radius: 5)
            )
            .contentShape(Rectangle())
        }
    }

    /// Cycling Camera View Button with glowing number badge
    private var cyclingCameraButton: some View {
        Button {
            currentCameraIndex = (currentCameraIndex % 6) + 1
            coordinator.pressButton(.cameraView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                coordinator.releaseButton(.cameraView)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    Image(systemName: cameraIcon)
                        .font(.system(size: 20, weight: .bold))
                    if coordinator.buttonDisplayMode == .iconAndText {
                        Text(cameraTitle)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                }
                .foregroundColor(.white)
                .frame(width: coordinator.buttonDisplayMode == .iconOnly ? 44 : 50, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.cyan.opacity(0.8), lineWidth: 1.5)
                        )
                )
                .contentShape(Rectangle())

                // Glowing Camera Number Badge (1..6)
                Text("\(currentCameraIndex)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.cyan))
                    .offset(x: 4, y: -4)
            }
        }
    }

    private var recenterButton: some View {
        Button {
            coordinator.recenter()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.system(size: 18, weight: .bold))
                if coordinator.buttonDisplayMode == .iconAndText {
                    Text("0°")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
            }
            .foregroundColor(.black)
            .frame(height: 44)
            .padding(.horizontal, coordinator.buttonDisplayMode == .iconOnly ? 12 : 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yellow)
                    .shadow(color: Color.yellow.opacity(0.4), radius: 6)
            )
        }
    }

    private var f1ShiftLightBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<15) { index in
                Circle()
                    .fill(f1LEDColor(for: index))
                    .frame(width: 12, height: 12)
                    .shadow(color: f1LEDColor(for: index).opacity(0.8), radius: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(white: 0.10)))
    }

    private func f1LEDColor(for index: Int) -> Color {
        let absSteer = Double(abs(coordinator.motionManager.normalizedSteering))
        let threshold = Double(index) / 15.0

        guard absSteer >= threshold else {
            return Color(white: 0.2)
        }

        if index < 5 {
            return Color.green
        } else if index < 10 {
            return Color.yellow
        } else {
            return Color.red
        }
    }

    // MARK: - Camera Cycle View Helpers

    private var cameraTitle: String {
        switch currentCameraIndex {
        case 1: return "CABIN"
        case 2: return "CHASE"
        case 3: return "TOP"
        case 4: return "ROOF"
        case 5: return "WINDOW"
        case 6: return "BUMPER"
        default: return "C\(currentCameraIndex)"
        }
    }

    private var cameraIcon: String {
        switch currentCameraIndex {
        case 1: return "steeringwheel"
        case 2: return "car.rear.fill"
        case 3: return "arrow.up.and.down.and.arrow.left.and.right"
        case 4: return "arrow.up.circle.fill"
        case 5: return "person.crop.circle"
        case 6: return "car.side.fill"
        default: return "camera.viewfinder"
        }
    }

    // MARK: - Status Badge (with 1-Tap Connection Mode Picker)

    private var connectionStatusBadge: some View {
        Menu {
            Section("Select Connection Mode") {
                ForEach(ConnectionPreference.allCases) { pref in
                    Button {
                        coordinator.setConnectionPreference(pref)
                    } label: {
                        HStack {
                            Image(systemName: pref.iconName)
                            Text(pref.rawValue)
                            if coordinator.preferredConnection == pref {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: coordinator.isConnected ? coordinator.activeTransport.iconName : "bolt.slash.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(coordinator.isConnected ? .green : .red)

                HStack(spacing: 4) {
                    Text(coordinator.isConnected
                         ? (coordinator.preferredConnection == .auto ? coordinator.activeTransport.displayName : coordinator.preferredConnection.rawValue)
                         : "SEARCHING...")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(coordinator.isConnected ? .white : .gray)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                }

                if coordinator.isConnected {
                    Text("• \(Int(coordinator.currentHz)) Hz")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text("• \(String(format: "%.1f ms", coordinator.latencyMs))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(white: 0.12))
                    .overlay(Capsule().stroke(coordinator.isConnected ? Color.green.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1))
            )
        }
    }

    // MARK: - Adaptive Universal Button Views (Large Icons!)

    private func dashButton(
        icon: String,
        title: String,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: coordinator.buttonDisplayMode == .iconOnly ? 22 : 16, weight: .bold))
                if coordinator.buttonDisplayMode == .iconAndText {
                    Text(title)
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .foregroundColor(isActive ? .black : .white)
            .frame(width: coordinator.buttonDisplayMode == .iconOnly ? 44 : 48, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? activeColor : Color(white: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? activeColor : Color.white.opacity(0.12), lineWidth: 1.5)
                    )
                    .shadow(color: isActive ? activeColor.opacity(0.5) : Color.clear, radius: 5)
            )
            .contentShape(Rectangle())
        }
    }

    private func dashTapButton(
        icon: String,
        title: String,
        button: SteeringButtons,
        color: Color
    ) -> some View {
        Button {
            coordinator.pressButton(button)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                coordinator.releaseButton(button)
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: coordinator.buttonDisplayMode == .iconOnly ? 22 : 16, weight: .bold))
                if coordinator.buttonDisplayMode == .iconAndText {
                    Text(title)
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(width: coordinator.buttonDisplayMode == .iconOnly ? 44 : 48, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.6), lineWidth: 1.2)
                    )
            )
            .contentShape(Rectangle())
        }
    }

    private func dashHoldButton(
        icon: String,
        title: String,
        button: SteeringButtons,
        activeColor: Color
    ) -> some View {
        let isPressed = coordinator.activeButtons.contains(button)
        return Button {
            // Backup action for rapid taps: guarantees minimum 0.25s loud blast
            coordinator.pressButton(button)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                coordinator.releaseButton(button)
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: coordinator.buttonDisplayMode == .iconOnly ? 22 : 16, weight: .bold))
                if coordinator.buttonDisplayMode == .iconAndText {
                    Text(title)
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .foregroundColor(isPressed ? .black : .white)
            .frame(width: coordinator.buttonDisplayMode == .iconOnly ? 44 : 48, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPressed ? activeColor : Color(white: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isPressed ? activeColor : Color.white.opacity(0.12), lineWidth: 1.5)
                    )
                    .shadow(color: isPressed ? activeColor.opacity(0.5) : Color.clear, radius: 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(InstantHoldButtonStyle(
            onPress: {
                coordinator.pressButton(button)
            },
            onRelease: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    coordinator.releaseButton(button)
                }
            }
        ))
    }
}

// MARK: - Native Low-Latency Hold Button Style
public struct InstantHoldButtonStyle: ButtonStyle {
    public let onPress: () -> Void
    public let onRelease: () -> Void

    public init(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.onPress = onPress
        self.onRelease = onRelease
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed {
                    onPress()
                } else {
                    onRelease()
                }
            }
    }
}
