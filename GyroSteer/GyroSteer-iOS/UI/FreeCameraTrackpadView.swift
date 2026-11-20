//
//  FreeCameraTrackpadView.swift
//  GyroSteer - iOS Transmitter UI
//
//  Movable floating touch mousepad for Euro Truck Simulator 2 Free Camera (0-Cam),
//  Cabin Free Look, and Orbit Chase Camera navigation.
//

import SwiftUI
#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public struct FreeCameraTrackpadView: View {
    @ObservedObject var coordinator: TransmissionCoordinator
    var onClose: () -> Void

    // Drag offset for moving the entire trackpad anywhere on screen
    @State private var dragOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero

    // Touch trackpad tracking
    @State private var lastDragLocation: CGPoint? = nil
    @State private var currentTouchLocation: CGPoint? = nil
    @State private var sensitivity: Float = 1.8
    @State private var activeCamLabel: String = "FREE CAM (0)"

    public init(coordinator: TransmissionCoordinator, onClose: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - 1. Movable Top Handle
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("FREE CAMERA MOUSEPAD")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                // Current Camera Status Pill
                Text(activeCamLabel)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.18))
                    .cornerRadius(4)

                // Dismiss Button
                Button {
                    coordinator.endCameraLook()
                    HapticManager.shared.buttonTap()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .contentShape(Rectangle())
            // Drag gesture to move the trackpad anywhere on screen
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        dragOffset = CGSize(
                            width: accumulatedOffset.width + gesture.translation.width,
                            height: accumulatedOffset.height + gesture.translation.height
                        )
                    }
                    .onEnded { _ in
                        accumulatedOffset = dragOffset
                    }
            )

            // MARK: - 2. Touch Mousepad Surface
            GeometryReader { geo in
                ZStack {
                    // Dark Glass Background with Grid
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.05, green: 0.07, blue: 0.12).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.6), lineWidth: 1.2)
                                .shadow(color: Color.cyan.opacity(0.4), radius: 6)
                        )

                    // Subtle Crosshair in Center
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .ultraLight))
                        .foregroundColor(.cyan.opacity(0.3))

                    // Instruction prompt when not touching
                    if currentTouchLocation == nil {
                        VStack(spacing: 2) {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.cyan.opacity(0.5))
                            Text("DRAG FINGER TO PAN CAMERA")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }

                    // Active Touch Glowing Pointer
                    if let loc = currentTouchLocation {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.cyan, radius: 8)
                            .position(loc)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let currentLoc = gesture.location
                            currentTouchLocation = currentLoc

                            if let last = lastDragLocation {
                                let dx = Float(currentLoc.x - last.x) * sensitivity
                                let dy = Float(currentLoc.y - last.y) * sensitivity
                                coordinator.sendCameraLook(dx: dx, dy: dy)
                            }
                            lastDragLocation = currentLoc
                        }
                        .onEnded { _ in
                            currentTouchLocation = nil
                            lastDragLocation = nil
                            coordinator.endCameraLook()
                        }
                )
            }
            .frame(height: 120)
            .padding(.horizontal, 10)

            // MARK: - 3. Quick Camera Selectors & Fly Controls
            HStack(spacing: 6) {
                // Key 0: Free Camera (ETS2 0-cam)
                cameraModeButton(title: "0 FREE", isActive: activeCamLabel.contains("FREE")) {
                    activeCamLabel = "FREE CAM (0)"
                    triggerButton(.freeCamera)
                }

                // Key 1: Cabin Interior Look
                cameraModeButton(title: "1 CABIN", isActive: activeCamLabel.contains("CABIN")) {
                    activeCamLabel = "CABIN (1)"
                    triggerButton(.cabinView)
                }

                // Key 2: Chase / Orbit Camera
                cameraModeButton(title: "2 CHASE", isActive: activeCamLabel.contains("CHASE")) {
                    activeCamLabel = "CHASE (2)"
                    triggerButton(.cameraView)
                }

                // Fly Forward (W / Up in 0-cam)
                Button {
                    pulseFlyKey(forward: true)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 26)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }

                // Fly Backward (S / Down in 0-cam)
                Button {
                    pulseFlyKey(forward: false)
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 26)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                        .shadow(color: .black.opacity(0.7), radius: 10)
                )
        )
        .offset(dragOffset)
    }

    private func cameraModeButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(isActive ? .black : .white)
                .padding(.horizontal, 6)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.cyan : Color.white.opacity(0.12))
                )
        }
    }

    private func triggerButton(_ button: SteeringButtons) {
        HapticManager.shared.buttonTap()
        coordinator.pressButton(button)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            coordinator.releaseButton(button)
        }
    }

    private func pulseFlyKey(forward: Bool) {
        HapticManager.shared.pedalTick()
        if forward {
            coordinator.throttle = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { coordinator.throttle = 0.0 }
        } else {
            coordinator.brake = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { coordinator.brake = 0.0 }
        }
    }
}
