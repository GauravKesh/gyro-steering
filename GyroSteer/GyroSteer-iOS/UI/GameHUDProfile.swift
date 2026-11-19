//
//  GameHUDProfile.swift
//  GyroSteer - iOS Transmitter UI
//
//  Multi-Game Cockpit HUD Profiles and Dynamic UI layouts.
//

import SwiftUI

public enum GameHUDProfile: String, CaseIterable, Identifiable, Codable {
    case ets2 = "ets2"          // 🚛 Euro Truck Simulator 2 / Heavy Truck
    case asphalt = "asphalt"    // 🏎️ Asphalt 8 & 9 / Arcade Racer
    case f1Sim = "f1"           // 🏁 Formula 1 & Sim Racing

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ets2: return "Euro Truck Simulator 2"
        case .asphalt: return "Asphalt 8 (Arcade)"
        case .f1Sim: return "F1 & Sim Racing"
        }
    }

    public var shortName: String {
        switch self {
        case .ets2: return "🚛 ETS2"
        case .asphalt: return "🏎️ ASPHALT"
        case .f1Sim: return "🏁 F1 SIM"
        }
    }

    public var subtitle: String {
        switch self {
        case .ets2: return "Heavy Commercial Truck Switchboard"
        case .asphalt: return "High-Speed Neon Arcade & Nitro"
        case .f1Sim: return "Carbon Fiber Wheel & Rev Shift Lights"
        }
    }

    public var iconName: String {
        switch self {
        case .ets2: return "box.truck.fill"
        case .asphalt: return "flame.fill"
        case .f1Sim: return "steeringwheel"
        }
    }

    public var accentColor: Color {
        switch self {
        case .ets2: return Color.orange
        case .asphalt: return Color.purple
        case .f1Sim: return Color.red
        }
    }

    public var defaultLockAngle: Double {
        switch self {
        case .ets2: return 45.0
        case .asphalt: return 20.0
        case .f1Sim: return 30.0
        }
    }

    public var backgroundGradient: [Color] {
        switch self {
        case .ets2:
            return [Color(white: 0.08), Color(white: 0.03)]
        case .asphalt:
            return [Color(red: 0.10, green: 0.03, blue: 0.16), Color(red: 0.03, green: 0.01, blue: 0.06)]
        case .f1Sim:
            return [Color(red: 0.04, green: 0.05, blue: 0.07), Color(red: 0.01, green: 0.02, blue: 0.03)]
        }
    }
}

/// Cockpit button appearance mode (Icons Only vs Icons + Text)
public enum ButtonDisplayMode: String, CaseIterable, Identifiable, Codable {
    case iconOnly = "iconOnly"           // 🎯 Clean & Large (Big automotive icons, zero clutter)
    case iconAndText = "iconAndText"     // 🏷️ Detailed (Icons + subtext labels)

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .iconOnly: return "Icons Only (Clean)"
        case .iconAndText: return "Icons + Text"
        }
    }

    public var iconName: String {
        switch self {
        case .iconOnly: return "circle.grid.2x2.fill"
        case .iconAndText: return "text.alignleft"
        }
    }
}

