//
//  CockpitView.swift
//  GyroSteer - iOS Transmitter UI
//
//  Premium ETS2 Truck Simulator Cockpit Interface.
//  Faithfully implements the glassmorphic truck cockpit layout with
//  central steering wheel, Left Control Zone (Brake, Gear DOWN, Retarder, Engine Brake, Park),
//  Right Control Zone (Gear UP, Neutral, Camera, Cruise, Horn, Throttle),
//  Top Essential Lighting Capsule, and Bottom Gameplay Action Dock.
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
                // MARK: - Dark Atmospheric Driving Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.12),
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Subtle Horizon Glow behind Cockpit
                RadialGradient(
                    colors: [
                        Color.orange.opacity(0.12),
                        Color.blue.opacity(0.08),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 50,
                    endRadius: 400
                )
                .ignoresSafeArea()

                // MARK: - Main Cockpit Layout (Top Bar, Driving Horizon, Bottom Dock)
                VStack(spacing: 4) {
                    // 1. TOP CONTROL BAR
                    topControlBar
                        .padding(.top, 4)

                    Spacer(minLength: 2)

                    // 2. MAIN DRIVING HORIZON (Left Controls, Central Wheel, Right Controls)
                    if coordinator.activeHUDProfile == .ets2 {
                        ets2DrivingHorizon
                    } else if coordinator.activeHUDProfile == .asphalt {
                        asphaltArcadeCockpitLayout
                    } else {
                        f1SimCockpitLayout
                    }

                    Spacer(minLength: 2)

                    // 3. BOTTOM GAMEPLAY ACTION DOCK
                    if coordinator.activeHUDProfile == .ets2 {
                        bottomGameplayDock
                            .padding(.bottom, 4)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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

    // =========================================================================
    // MARK: - 1. Top Control Bar (Essential Lighting Capsule + Hamburger Menu)
    // =========================================================================

    private var topControlBar: some View {
        HStack(alignment: .center) {
            // Hamburger Menu Button (Opens All Technical & Diagnostic Settings)
            Button {
                isShowingSettings = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.14).opacity(0.85))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                        .frame(width: 38, height: 38)
                        .shadow(color: .black.opacity(0.6), radius: 4)

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Essential Vehicle Lighting & Indicator Capsule (Centered)
            HStack(spacing: 14) {
                // 1. Left Indicator
                indicatorButton(
                    icon: "arrow.left",
                    isActive: coordinator.activeButtons.contains(.leftBlinker) || coordinator.activeButtons.contains(.hazardLights),
                    activeColor: .green
                ) {
                    coordinator.toggleButton(.leftBlinker)
                }

                // 2. Hazard Lights
                indicatorButton(
                    icon: "exclamationmark.triangle.fill",
                    isActive: coordinator.activeButtons.contains(.hazardLights),
                    activeColor: .red
                ) {
                    coordinator.toggleButton(.hazardLights)
                }

                // 3. Windshield Wipers
                indicatorButton(
                    icon: "windshield.front.and.wiper",
                    isActive: coordinator.activeButtons.contains(.wipers),
                    activeColor: .cyan
                ) {
                    coordinator.toggleButton(.wipers)
                }

                // 4. Low Beam Headlights
                indicatorButton(
                    icon: "lightbulb.fill",
                    isActive: coordinator.activeButtons.contains(.headlights),
                    activeColor: .yellow
                ) {
                    coordinator.toggleButton(.headlights)
                }

                // 5. High Beam Headlights
                indicatorButton(
                    icon: "flashlight.on.fill",
                    isActive: coordinator.activeButtons.contains(.highBeams),
                    activeColor: .cyan
                ) {
                    coordinator.toggleButton(.highBeams)
                }

                // 6. Right Indicator
                indicatorButton(
                    icon: "arrow.right",
                    isActive: coordinator.activeButtons.contains(.rightBlinker) || coordinator.activeButtons.contains(.hazardLights),
                    activeColor: .green
                ) {
                    coordinator.toggleButton(.rightBlinker)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(white: 0.08).opacity(0.92))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1.2)
                    )
                    .shadow(color: .black.opacity(0.7), radius: 8, y: 2)
            )

            Spacer()

            // Subtle Status / Profile Pill
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
                HStack(spacing: 4) {
                    Image(systemName: coordinator.activeHUDProfile.iconName)
                        .font(.system(size: 11, weight: .bold))
                    Text(coordinator.activeHUDProfile.shortName)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(white: 0.12).opacity(0.85))
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                )
            }
        }
    }

    private func indicatorButton(
        icon: String,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundColor(isActive ? activeColor : Color.white.opacity(0.35))
                .shadow(color: isActive ? activeColor.opacity(0.8) : .clear, radius: 6)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
    }

    // =========================================================================
    // MARK: - 2. ETS2 Main Driving Horizon
    // =========================================================================

    private var ets2DrivingHorizon: some View {
        HStack(alignment: .center, spacing: 10) {
            // --- LEFT ZONE: Brake Pedal + Left Control Zone ---
            HStack(spacing: 8) {
                // Large Vertical Brake Pedal (Far Left)
                VerticalSlider(
                    title: "BRAKE",
                    subtitle: "PULL",
                    accentColor: Color(red: 1.0, green: 0.16, blue: 0.28),
                    iconName: "exclamationmark.circle",
                    displayMode: coordinator.buttonDisplayMode,
                    value: $coordinator.brake
                )

                // Left Control Zone: Gear DOWN, Retarder, Engine Brake, Parking Brake
                leftControlZone
            }

            Spacer(minLength: 4)

            // --- CENTRAL ZONE: Large Truck Steering Wheel ---
            SteeringWheelGauge(
                degrees: coordinator.motionManager.currentDegrees,
                normalizedSteering: coordinator.motionManager.normalizedSteering,
                maxLockAngle: coordinator.motionManager.maxLockAngleDegrees,
                isCentered: abs(coordinator.motionManager.normalizedSteering) < 0.01,
                profile: .ets2,
                isLeftBlinkerActive: coordinator.activeButtons.contains(.leftBlinker) || coordinator.activeButtons.contains(.hazardLights),
                isRightBlinkerActive: coordinator.activeButtons.contains(.rightBlinker) || coordinator.activeButtons.contains(.hazardLights),
                onCalibrate: {
                    coordinator.recenter()
                }
            )

            Spacer(minLength: 4)

            // --- RIGHT ZONE: Right Control Zone + Throttle Pedal ---
            HStack(spacing: 8) {
                // Right Control Zone: Gear UP, Neutral, Camera, Cruise, Horn
                rightControlZone

                // Large Vertical Throttle Pedal (Far Right)
                VerticalSlider(
                    title: "THROTTLE",
                    subtitle: "PULL",
                    accentColor: Color(red: 0.0, green: 1.0, blue: 0.53),
                    iconName: "bolt.fill",
                    displayMode: coordinator.buttonDisplayMode,
                    value: $coordinator.throttle
                )
            }
        }
    }

    // =========================================================================
    // MARK: - 3. Left Control Zone (Gear DOWN, Retarder, Engine Brake, Park)
    // =========================================================================

    private var leftControlZone: some View {
        VStack(spacing: 7) {
            // 1. Dedicated Gear DOWN Button (LEFT SIDE ONLY)
            Button {
                coordinator.pressButton(.gearDown)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    coordinator.releaseButton(.gearDown)
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 20, weight: .black))
                    Text("GEAR\nDOWN")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)
                .frame(width: 98, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.85), lineWidth: 1.5)
                                .shadow(color: Color.cyan.opacity(0.6), radius: 6)
                        )
                )
                .contentShape(Rectangle())
            }

            // 2. Retarder Module (Retarder - / Retarder +)
            VStack(spacing: 2) {
                Text("RETARDER")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(Color.cyan.opacity(0.85))

                HStack(spacing: 4) {
                    // Retarder Decrease (-)
                    Button {
                        coordinator.pressButton(.retarderDown)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            coordinator.releaseButton(.retarderDown)
                        }
                    } label: {
                        Text("−")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 26)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }

                    // Retarder Increase (+)
                    Button {
                        coordinator.pressButton(.retarderUp)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            coordinator.releaseButton(.retarderUp)
                        }
                    } label: {
                        Text("+")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 26)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                }
            }
            .frame(width: 98, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.12).opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.5), lineWidth: 1.2)
                    )
            )

            // 3. Engine Brake Toggle
            let isEngineBrakeActive = coordinator.activeButtons.contains(.engineBrake)
            Button {
                coordinator.toggleButton(.engineBrake)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "engine.combustion.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("ENGINE BRAKE")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                }
                .foregroundColor(isEngineBrakeActive ? .black : .white)
                .frame(width: 98, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isEngineBrakeActive ? Color.cyan : Color(white: 0.12).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isEngineBrakeActive ? Color.cyan : Color.cyan.opacity(0.5), lineWidth: 1.2)
                                .shadow(color: isEngineBrakeActive ? Color.cyan.opacity(0.8) : .clear, radius: 6)
                        )
                )
                .contentShape(Rectangle())
            }

            // 4. Parking Brake Toggle (Illuminated Red)
            let isParkActive = coordinator.activeButtons.contains(.parkingBrake)
            Button {
                coordinator.toggleButton(.parkingBrake)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "p.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("PARKING\nBRAKE")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(isParkActive ? .white : Color.white.opacity(0.85))
                .frame(width: 98, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isParkActive ? Color(red: 0.9, green: 0.1, blue: 0.2) : Color(white: 0.12).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.95, green: 0.15, blue: 0.25).opacity(0.8), lineWidth: 1.5)
                                .shadow(color: isParkActive ? Color.red.opacity(0.8) : .clear, radius: 8)
                        )
                )
                .contentShape(Rectangle())
            }
        }
    }

    // =========================================================================
    // MARK: - 4. Right Control Zone (Gear UP, Neutral, Camera, Cruise, Horn)
    // =========================================================================

    private var rightControlZone: some View {
        VStack(spacing: 6) {
            // 1. Dedicated Gear UP Button (RIGHT SIDE ONLY)
            Button {
                coordinator.pressButton(.gearUp)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    coordinator.releaseButton(.gearUp)
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 20, weight: .black))
                    Text("GEAR\nUP")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)
                .frame(width: 98, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.85), lineWidth: 1.5)
                                .shadow(color: Color.cyan.opacity(0.6), radius: 6)
                        )
                )
                .contentShape(Rectangle())
            }

            // 2. NEUTRAL (N) Dedicated Button (Directly below Gear Up)
            Button {
                coordinator.pressButton(.neutral)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    coordinator.releaseButton(.neutral)
                }
            } label: {
                VStack(spacing: 2) {
                    Text("N")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                    Text("NEUTRAL")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white)
                .frame(width: 98, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.7), lineWidth: 1.2)
                        )
                )
                .contentShape(Rectangle())
            }

            // 3. Camera Switch with Live View Indicator
            Button {
                currentCameraIndex = (currentCameraIndex % 6) + 1
                coordinator.pressButton(.cameraView)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    coordinator.releaseButton(.cameraView)
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 2) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("CAMERA")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(width: 98, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.12).opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cyan.opacity(0.7), lineWidth: 1.2)
                            )
                    )
                    .contentShape(Rectangle())

                    // Camera Number Badge (1..6)
                    Text("\(currentCameraIndex)")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(Color.cyan))
                        .offset(x: -4, y: 3)
                }
            }

            // 4. Cruise Control Lock
            let isCruiseActive = coordinator.activeButtons.contains(.cruiseControl)
            Button {
                coordinator.toggleButton(.cruiseControl)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 16, weight: .bold))
                    Text("CRUISE")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                }
                .foregroundColor(isCruiseActive ? .black : .white)
                .frame(width: 98, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCruiseActive ? Color.green : Color(white: 0.12).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isCruiseActive ? Color.green : Color.cyan.opacity(0.7), lineWidth: 1.2)
                                .shadow(color: isCruiseActive ? Color.green.opacity(0.8) : .clear, radius: 6)
                        )
                )
                .contentShape(Rectangle())
            }

            // 5. Dual Horn (Standard Horn 'H' + Air Horn 'N')
            InstantHoldButton(button: .horn, coordinator: coordinator) {
                VStack(spacing: 2) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("HORN")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                }
                .foregroundColor(coordinator.activeButtons.contains(.horn) ? .black : .white)
                .frame(width: 98, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(coordinator.activeButtons.contains(.horn) ? Color.purple : Color(white: 0.12).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(coordinator.activeButtons.contains(.horn) ? Color.purple : Color.cyan.opacity(0.7), lineWidth: 1.2)
                                .shadow(color: coordinator.activeButtons.contains(.horn) ? Color.purple.opacity(0.8) : .clear, radius: 6)
                        )
                )
                .contentShape(Rectangle())
            }
        }
    }

    // =========================================================================
    // MARK: - 5. Bottom Gameplay Action Dock (Horizontal Toolbar)
    // =========================================================================

    private var bottomGameplayDock: some View {
        HStack(spacing: 7) {
            // 1. Engine Start / Stop (Large Glowing Green Pill)
            let isRunning = coordinator.activeButtons.contains(.engineStart)
            Button {
                coordinator.toggleButton(.engineStart)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .black))
                    Text(isRunning ? "STOP" : "START")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundColor(isRunning ? .black : .white)
                .frame(minWidth: 84)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(isRunning ? Color.green : Color(white: 0.14))
                        .overlay(Capsule().stroke(isRunning ? Color.green : Color.green.opacity(0.6), lineWidth: 1.5))
                        .shadow(color: isRunning ? Color.green.opacity(0.8) : .clear, radius: 8)
                )
            }

            // 2. Park Quick Action
            dockPillButton(
                icon: "p.circle.fill",
                title: "PARK",
                isActive: coordinator.activeButtons.contains(.parkingBrake),
                activeColor: .red
            ) {
                coordinator.toggleButton(.parkingBrake)
            }

            // 3. Automatic Transmission Toggle (AUTO / MAN)
            let isAuto = coordinator.transmissionMode == .automatic
            Button {
                coordinator.toggleTransmissionMode()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isAuto ? "gearshape.2.fill" : "slider.vertical.3")
                        .font(.system(size: 13, weight: .bold))
                    Text(isAuto ? "AUTO" : "MAN")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundColor(isAuto ? .black : .white)
                .frame(minWidth: 68)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(isAuto ? Color.green : Color.orange)
                        .overlay(Capsule().stroke(isAuto ? Color.green : Color.orange, lineWidth: 1.5))
                        .shadow(color: (isAuto ? Color.green : Color.orange).opacity(0.6), radius: 6)
                )
            }

            // 4. Enter / Exit (Tolls, Ferries, Jobs, Resting, Fuel)
            dockPillButton(
                icon: "arrow.turn.down.left",
                title: "ENTER / EXIT",
                isActive: false,
                activeColor: .cyan
            ) {
                coordinator.pressButton(.enter)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    coordinator.releaseButton(.enter)
                }
            }

            // 5. Trailer Attach / Detach
            dockPillButton(
                icon: "trailer",
                title: "TRAILER",
                isActive: coordinator.activeButtons.contains(.trailerAttach),
                activeColor: .orange
            ) {
                coordinator.pressButton(.trailerAttach)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    coordinator.releaseButton(.trailerAttach)
                }
            }

            // 6. Cabin Controls / Interior Camera 1
            dockPillButton(
                icon: "steeringwheel",
                title: "CABIN",
                isActive: false,
                activeColor: .blue
            ) {
                coordinator.pressButton(.cabinView)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    coordinator.releaseButton(.cabinView)
                }
            }

            // 7. Route Advisor (F3)
            dockPillButton(
                icon: "location.north.line.fill",
                title: "ADVISOR (F3)",
                isActive: coordinator.activeButtons.contains(.routeAdvisor),
                activeColor: .cyan
            ) {
                coordinator.pressButton(.routeAdvisor)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    coordinator.releaseButton(.routeAdvisor)
                }
            }

            // 8. Navigation Map Zoom (F5)
            dockPillButton(
                icon: "viewfinder.circle.fill",
                title: "MAP VIEW (F5)",
                isActive: coordinator.activeButtons.contains(.mapZoom),
                activeColor: .cyan
            ) {
                coordinator.pressButton(.mapZoom)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    coordinator.releaseButton(.mapZoom)
                }
            }

            // 9. World Map (M)
            dockPillButton(
                icon: "map.fill",
                title: "MAP (M)",
                isActive: coordinator.activeButtons.contains(.worldMap),
                activeColor: .blue
            ) {
                coordinator.pressButton(.worldMap)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    coordinator.releaseButton(.worldMap)
                }
            }
        }
    }

    private func dockPillButton(
        icon: String,
        title: String,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
            }
            .foregroundColor(isActive ? .black : .white)
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background(
                Capsule()
                    .fill(isActive ? activeColor : Color(white: 0.12).opacity(0.85))
                    .overlay(
                        Capsule()
                            .stroke(isActive ? activeColor : Color.cyan.opacity(0.4), lineWidth: 1.2)
                            .shadow(color: isActive ? activeColor.opacity(0.6) : .clear, radius: 5)
                    )
            )
            .contentShape(Rectangle())
        }
    }

    // =========================================================================
    // MARK: - Specialized Button Styles & Other HUD Profile Layouts
    // =========================================================================

    private var recenterButton: some View {
        Button {
            coordinator.recenter()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.system(size: 16, weight: .bold))
                Text("0°")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
            }
            .foregroundColor(.white)
            .frame(width: 48, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.16))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1.2))
            )
            .contentShape(Rectangle())
        }
    }

    // MARK: - Asphalt Arcade Layout
    private var asphaltArcadeCockpitLayout: some View {
        HStack(alignment: .center, spacing: 10) {
            // --- LEFT ZONE: Brake Pedal & Drift Control ---
            HStack(spacing: 8) {
                // Large Vertical Brake / Reverse Pedal (Down Arrow + S)
                VerticalSlider(
                    title: "BRAKE",
                    subtitle: "REVERSE",
                    accentColor: Color(red: 1.0, green: 0.16, blue: 0.28),
                    iconName: "arrow.down.circle.fill",
                    displayMode: coordinator.buttonDisplayMode,
                    value: $coordinator.brake
                )

                // Dedicated Quick Drift Button (Shift + Down Arrow)
                VStack(spacing: 8) {
                    InstantHoldButton(button: .gearDown, coordinator: coordinator) {
                        VStack(spacing: 4) {
                            Image(systemName: "skew")
                                .font(.system(size: 20, weight: .black))
                            Text("DRIFT")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .frame(width: 68, height: 68)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(coordinator.activeButtons.contains(.gearDown) ? Color.cyan : Color.blue.opacity(0.4))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan, lineWidth: 1.5))
                                .shadow(color: Color.cyan.opacity(0.6), radius: 6)
                        )
                    }

                    recenterButton
                }
            }

            Spacer(minLength: 4)

            // --- CENTRAL ZONE: Steering Wheel & Respawn ---
            VStack(spacing: 6) {
                SteeringWheelGauge(
                    degrees: coordinator.motionManager.currentDegrees,
                    normalizedSteering: coordinator.motionManager.normalizedSteering,
                    maxLockAngle: coordinator.motionManager.maxLockAngleDegrees,
                    isCentered: abs(coordinator.motionManager.normalizedSteering) < 0.01,
                    profile: .asphalt,
                    onCalibrate: {
                        coordinator.recenter()
                    }
                )

                // Bottom Arcade Action: Respawn (R)
                Button {
                    coordinator.pressButton(.trailerAttach) // R key in Asphalt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        coordinator.releaseButton(.trailerAttach)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("RESPAWN (R)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.16))
                            .overlay(Capsule().stroke(Color.orange.opacity(0.6), lineWidth: 1.2))
                    )
                }
            }

            Spacer(minLength: 4)

            // --- RIGHT ZONE: Nitro & Throttle Pedal ---
            HStack(spacing: 8) {
                // Dedicated Quick Nitro Button (Spacebar + N)
                VStack(spacing: 8) {
                    InstantHoldButton(button: .parkingBrake, coordinator: coordinator) {
                        VStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 24, weight: .black))
                            Text("NITRO")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .frame(width: 68, height: 68)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [Color.purple, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.pink, lineWidth: 1.5))
                                .shadow(color: Color.purple.opacity(0.8), radius: coordinator.activeButtons.contains(.parkingBrake) ? 12 : 5)
                        )
                    }

                    // Camera View Cycle Button
                    Button {
                        coordinator.pressButton(.cameraView)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            coordinator.releaseButton(.cameraView)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("CAM")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .frame(width: 68, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(white: 0.16))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1.2))
                        )
                    }
                }

                // Large Vertical Throttle Pedal (Up Arrow + W)
                VerticalSlider(
                    title: "THROTTLE",
                    subtitle: "BOOST",
                    accentColor: Color(red: 0.0, green: 1.0, blue: 0.53),
                    iconName: "bolt.fill",
                    displayMode: coordinator.buttonDisplayMode,
                    value: $coordinator.throttle
                )
            }
        }
    }

    // MARK: - Formula 1 Sim Layout
    private var f1SimCockpitLayout: some View {
        HStack(spacing: 8) {
            Button {
                coordinator.pressButton(.gearDown)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    coordinator.releaseButton(.gearDown)
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                    Text("DOWN")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white)
                .frame(width: 50, height: 100)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.14)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.6), lineWidth: 1.5)))
            }

            VStack(spacing: 6) {
                SteeringWheelGauge(
                    degrees: coordinator.motionManager.currentDegrees,
                    normalizedSteering: coordinator.motionManager.normalizedSteering,
                    maxLockAngle: coordinator.motionManager.maxLockAngleDegrees,
                    isCentered: abs(coordinator.motionManager.normalizedSteering) < 0.01,
                    profile: .f1Sim,
                    onCalibrate: {
                        coordinator.recenter()
                    }
                )

                HStack(spacing: 8) {
                    dockPillButton(icon: "wind", title: "DRS", isActive: coordinator.activeButtons.contains(.parkingBrake), activeColor: .green) {
                        coordinator.toggleButton(.parkingBrake)
                    }
                    dockPillButton(icon: "speedometer", title: "PIT", isActive: coordinator.activeButtons.contains(.cruiseControl), activeColor: .yellow) {
                        coordinator.toggleButton(.cruiseControl)
                    }
                    recenterButton
                }
            }

            Button {
                coordinator.pressButton(.gearUp)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    coordinator.releaseButton(.gearUp)
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                    Text("UP")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white)
                .frame(width: 50, height: 100)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.14)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.6), lineWidth: 1.5)))
            }
        }
    }
}

// MARK: - Instant Hold Button Helper for Horn
private struct InstantHoldButton<Label: View>: View {
    let button: SteeringButtons
    @ObservedObject var coordinator: TransmissionCoordinator
    let label: () -> Label

    var body: some View {
        Button {
            coordinator.pressButton(button)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                coordinator.releaseButton(button)
            }
        } label: {
            label()
        }
        .buttonStyle(InstantHoldStyle(button: button, coordinator: coordinator))
    }
}

private struct InstantHoldStyle: ButtonStyle {
    let button: SteeringButtons
    @ObservedObject var coordinator: TransmissionCoordinator

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 17.0, *) {
            configuration.label
                .opacity(configuration.isPressed ? 0.8 : 1.0)
                .onChange(of: configuration.isPressed) { _, isPressed in
                    if isPressed {
                        coordinator.pressButton(button)
                    } else {
                        coordinator.releaseButton(button)
                    }
                }
        } else {
            configuration.label
                .opacity(configuration.isPressed ? 0.8 : 1.0)
                .onChange(of: configuration.isPressed) { isPressed in
                    if isPressed {
                        coordinator.pressButton(button)
                    } else {
                        coordinator.releaseButton(button)
                    }
                }
        }
    }
}
