//
//  InputInjectorProtocol.swift
//  GyroSteer - macOS Receiver
//
//  Protocol for injecting virtual controller and keyboard inputs into macOS.
//

import Foundation

#if canImport(GyroSteerShared)
import GyroSteerShared
#endif

public enum OutputMode: String, CaseIterable, Identifiable, Sendable {
    case virtualGamepad = "Virtual Gamepad (ETS2)"
    case keyboardEmulation = "Keyboard Emulation (Zero-Driver)"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .virtualGamepad: return "gamecontroller.fill"
        case .keyboardEmulation: return "keyboard.fill"
        }
    }

    public var description: String {
        switch self {
        case .virtualGamepad:
            return "Native 16-bit analog steering wheel for Euro Truck Simulator 2, ATS, and racing sims."
        case .keyboardEmulation:
            return "Pulse-Width Modulated (PWM) key pulsing for instant zero-setup play without driver prompts."
        }
    }
}

public protocol InputInjector: AnyObject, Sendable {
    var outputMode: OutputMode { get }
    var isRunning: Bool { get }

    func start() -> Bool
    func stop()
    func inject(packet: SteeringPacket)
}
