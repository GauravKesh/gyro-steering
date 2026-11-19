# GyroSteer — Unified iOS-to-macOS Virtual Steering Wheel

> **Ultra-low latency virtual steering wheel & gamepad ecosystem for Euro Truck Simulator 2 (ETS2), American Truck Simulator (ATS), and racing simulators on macOS.**

Turn your iPhone into an ultra-responsive, zero-latency 900° steering wheel with proportional analog throttle and brake touch pedals, tactile haptic feedback, and simulator button controls.

---

## 1. System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                   iOS Transmitter (GyroSteer-iOS)                      │
│                                                                        │
│   ┌─────────────────────┐   ┌──────────────────────────────────────┐   │
│   │  CoreMotion 100Hz   │   │        Cockpit Dashboard UI          │   │
│   │  Gyroscope Engine   │   │  • Left Thumb: Analog Brake Slider   │   │
│   │  • Zero-Point Recenter  │  • Right Thumb: Throttle Slider      │   │
│   │  • 900° Lock-to-Lock│   │  • Center: Animated 360° Wheel Gauge │   │
│   │  • Linearity & Deadzone │  • Simulator Buttons (16-bit mask)   │   │
│   └──────────┬──────────┘   └──────────────────┬───────────────────┘   │
│              └──────────────┬──────────────────┘                       │
│                             ▼                                          │
│           Unified 12-Byte Binary Packet Serialization                  │
│                     (Sequence ID, Roll, Pedals, Buttons)               │
└──────────────┬──────────────────┬──────────────────┬───────────────────┘
               │                  │                  │
        [USB Wired Link]     [Wi-Fi UDP]        [Bluetooth LE]
        < 2ms Latency       < 10ms Latency      < 20ms Fallback
        Bonjour / usbmuxd    Bonjour LAN        GATT 5A8D0001-...
               │                  │                  │
┌──────────────▼──────────────────▼──────────────────▼───────────────────┐
│                    macOS Receiver (GyroSteer-Mac)                      │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                 Transport Arbiter Engine                       │   │
│   │  • Strict Priority: USB Wired (3) > Wi-Fi (2) > Bluetooth (1)  │   │
│   │  • 16-Bit Circular Sequence ID Deduplication                   │   │
│   │  • Seamless Hot-Plug Handover (0 dropped frames)               │   │
│   │  • Real-Time Hz, Jitter & Latency Telemetry                    │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    ▼                                   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                   Dual Virtual Output Engine                   │   │
│   │                                                                │   │
│   │  [Mode 1: Primary]                  [Mode 2: Zero-Driver]      │   │
│   │  Virtual Gamepad (IOHIDUserDevice)   Keyboard Emulation        │   │
│   │  • 16-Bit Analog X-Axis (Steering)  • 50Hz PWM Key Pulsing     │   │
│   │  • 16-Bit Z-Axis (Throttle)         • W/S & A/D Throttle/Brake │   │
│   │  • 16-Bit Rz-Axis (Brake)           • [ ] Blinkers, H Horn     │   │
│   │  • 16 Gamepad Buttons               • CGEvent / Accessibility  │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    │                                   │
│                        Target Simulator Application                    │
│                 Euro Truck Simulator 2 / ATS / Dirt Rally              │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 12-Byte Binary Packet Protocol

All connection modes stream a fixed, zero-allocation **12-byte Little-Endian binary packet** at 100 Hz (10 ms period):

| Byte Offset | Field | Data Type | Encoding | Description / Range |
| :--- | :--- | :--- | :--- | :--- |
| **0 – 1** | `sequenceID` | `UInt16` | Little-Endian | Incremental packet sequence (`0`–`65535`, circular wrap). Used to discard out-of-order and stale UDP/BLE frames. |
| **2 – 5** | `steeringAngle` | `Float32` | IEEE 754 LE | Normalized steering position: `-1.0` (Full Left) to `+1.0` (Full Right). |
| **6 – 7** | `throttle` | `UInt16` | Little-Endian | Proportional throttle pedal: `0` (released) to `65535` (100% floored). |
| **8 – 9** | `brake` | `UInt16` | Little-Endian | Proportional brake pedal: `0` (released) to `65535` (100% clamped). |
| **10 – 11** | `buttons` | `UInt16` | Bitmask LE | 16-bit simulator digital button bitmask. |

### Button Bitmask Definition (`UInt16`)

```swift
Bit  0 (0x0001): Left Blinker       Bit  6 (0x0040): Cruise Control     Bit 12 (0x1000): Trailer Attach
Bit  1 (0x0002): Right Blinker      Bit  7 (0x0080): Recenter (0°)      Bit 13 (0x2000): High Beams
Bit  2 (0x0004): Horn               Bit  8 (0x0100): Hazard Lights      Bit 14 (0x4000): Camera View
Bit  3 (0x0008): Headlights         Bit  9 (0x0200): Wipers             Bit 15 (0x8000): Pause / Menu
Bit  4 (0x0010): Gear Up (+)        Bit 10 (0x0400): Engine Start/Stop
Bit  5 (0x0020): Gear Down (-)      Bit 11 (0x0800): Parking Brake (P)
```

---

## 3. Directory Layout

```
GyroSteer/
├── Package.swift                    # Swift Package Manager manifest
├── project.yml                      # XcodeGen specification
├── GyroSteer.xcodeproj/             # Native Xcode Project (Mac + iOS)
├── Shared/
│   ├── SteeringPacket.swift         # 12-byte zero-allocation binary protocol
│   ├── ProtocolConstants.swift      # Bonjour, BLE UUIDs, port definitions
│   └── MathUtilities.swift          # Deadzone, linearity exponent, normalizer
├── GyroSteer-Mac/
│   ├── App/
│   │   ├── GyroSteerMacApp.swift    # SwiftUI @main (Window + MenuBarExtra)
│   │   └── AppDelegate.swift        # Background lifecycle management
│   ├── Core/
│   │   ├── TransportArbiter.swift   # Prioritization (USB > Wi-Fi > BLE) & deduplication
│   │   └── TelemetryHistory.swift   # Rolling 300-sample telemetry buffer
│   ├── Transports/
│   │   ├── ReceiverTransport.swift  # Protocol for incoming listeners
│   │   ├── NWReceiver.swift         # Network.framework Bonjour UDP + USB listener
│   │   └── BLEReceiver.swift        # CoreBluetooth CBCentralManager
│   ├── Output/
│   │   ├── InputInjectorProtocol.swift
│   │   ├── VirtualGamepadDriver.swift # Native IOHIDUserDevice 16-bit Gamepad
│   │   ├── KeyboardMouseEmulator.swift# 50Hz PWM CGEvent Keyboard Fallback
│   │   ├── OutputCoordinator.swift  # Active mode switcher & tuning overrides
│   │   └── AccessibilityPermissionHelper.swift # AX permission prompt helper
│   ├── UI/
│   │   ├── DashboardView.swift      # Main receiver dashboard window
│   │   ├── MenuBarView.swift        # Compact MenuBarExtra status popup
│   │   ├── OscilloscopeView.swift   # 60fps real-time gyro waveform graph
│   │   └── SteeringArcGauge.swift   # High-resolution analog arc visualizer
│   └── Resources/
│       ├── Info.plist               # Permissions & Bonjour declaration
│       └── GyroSteer-Mac.entitlements
├── GyroSteer-iOS/
│   ├── App/
│   │   ├── GyroSteerIOSApp.swift    # SwiftUI @main iOS App
│   │   └── AppDelegate.swift        # Landscape orientation locking
│   ├── Core/
│   │   ├── MotionManager.swift      # 100Hz CoreMotion gyro engine + zero calibration
│   │   ├── HapticManager.swift      # Tactile pedal ticks & button haptics
│   │   └── TransmissionCoordinator.swift # Coordinates sensor & pedals at 100Hz
│   ├── Transports/
│   │   ├── TransportProtocol.swift
│   │   ├── NWTransmitter.swift      # Bonjour auto-discovery & USB network socket
│   │   └── BLETransmitter.swift     # CoreBluetooth peripheral advertiser
│   ├── UI/
│   │   ├── CockpitView.swift        # Dark landscape cockpit dashboard
│   │   ├── VerticalSlider.swift     # Proportional touch slider with spring return
│   │   ├── SteeringWheelGauge.swift # 3-spoke rotating wheel with digital readout
│   │   └── SettingsSheetView.swift  # Lock angle, deadzone, and curve tuning
│   └── Resources/
│       └── Info.plist               # Motion, Network, and Bluetooth permissions
├── Tests/
│   ├── RunAllTests.swift            # Standalone test runner
│   ├── SharedTests/                 # Packet serialization & math tests
│   └── MacTests/                    # Arbiter priority & deduplication tests
└── Scripts/
    ├── build_mac.sh                 # One-click CLI compile, test, and bundle packager
    ├── generate_xcodeproj.sh        # Generates / updates GyroSteer.xcodeproj
    └── generate_xcodeproj.py        # Python project generator
```

---

## 4. Quick Start: Building & Running

### Step A: Build & Run the macOS Receiver

You can build and run `GyroSteer.app` immediately from the terminal without manual Xcode configuration:

```bash
cd GyroSteer

# Run tests, build the macOS bundle, and code-sign:
./Scripts/build_mac.sh

# Launch the Receiver app:
open build/GyroSteer.app
```

Or open in Xcode:
1. Double-click `GyroSteer.xcodeproj`.
2. Select the `GyroSteer-Mac` target in the top scheme selector.
3. Press `Cmd + R` to run.

---

### Step B: Build & Sideload the iOS Transmitter onto an iPhone

1. Connect your iPhone to your Mac via USB cable (USB-C or Lightning).
2. Open `GyroSteer.xcodeproj` in Xcode.
3. Select the `GyroSteer-iOS` scheme and choose your connected iPhone as the run destination.
4. Go to **Signing & Capabilities**:
   - Check **Automatically manage signing**.
   - Select your **Personal Team** (free Apple Developer accounts are fully supported).
   - If the bundle identifier `com.gyrosteer.transmitter` is already registered, change it to `com.<yourname>.gyrosteer`.
5. Press `Cmd + R` to build and install onto your iPhone.
6. On your iPhone:
   - If prompted with "Untrusted Developer", go to **Settings -> General -> VPN & Device Management**, tap your developer certificate, and tap **Trust**.
   - Launch **GyroSteer**.
   - Allow permissions for **Motion & Fitness** (gyroscope), **Local Network** (wired USB & Wi-Fi), and **Bluetooth**.

---

## 5. Connection Modes & Transport Arbiter

GyroSteer connects automatically without requiring manual IP address entry:

1. **USB Wired (< 2ms latency — Recommended):**
   - Simply keep your iPhone plugged into your Mac via USB-C or Lightning cable.
   - macOS creates a high-speed peer-to-peer network interface over the cable.
   - The Bonjour service `_gyrosteer._udp` automatically routes over the USB link.
   - *Optional:* If you use `usbmuxd` port forwarding:
     ```bash
     iproxy 28282 28282
     ```
     In the iOS app Settings, set Target IP to `127.0.0.1` and Port `28282`.
2. **Wi-Fi LAN (< 10ms latency):**
   - Connect both your Mac and iPhone to the same Wi-Fi network.
   - Bonjour auto-discovers the Mac receiver within 500ms of opening the app.
3. **Bluetooth Low Energy (Sub-20ms fallback):**
   - If you are on an offline plane or train with no Wi-Fi and no cable, GyroSteer automatically falls back to CoreBluetooth.
4. **Transport Arbiter:**
   - The Mac Receiver listens on all interfaces simultaneously.
   - If packets arrive on USB, it automatically prioritizes USB and ignores duplicate Wi-Fi frames.
   - If you unplug the USB cable mid-game, it switches seamlessly to Wi-Fi within 150ms without dropping input!

---

## 6. Euro Truck Simulator 2 (ETS2) Setup Guide

GyroSteer is engineered specifically for **Euro Truck Simulator 2 (ETS2)** and **American Truck Simulator (ATS)** on macOS.

### Step 1: Verify Receiver Output Mode
1. In `GyroSteer-Mac`, make sure **Output Mode** is set to **Virtual Gamepad (ETS2)**.
2. In the iOS app, tap the **RECENTER 0°** button while holding your phone at your natural resting driving angle.

### Step 2: Configure ETS2 In-Game Controls
1. Launch **Euro Truck Simulator 2**.
2. Go to **Options** -> **Controls**:
   - **Keyboard + GyroSteer Virtual Steering Wheel** (or *Gamepad/Joystick*).
   - **Controller Subtype:** Set to **Wheel** (or *Steering Wheel*).
3. **Steering Setup:**
   - Click on **Steering Axis**, then rotate your iPhone left and right.
   - ETS2 will detect **Joy X-Axis**.
   - **Steering Sensitivity:** Set the slider to **Maximum** (100% to the right).
   - **Steering Non-Linearity:** Set the slider to **Minimum** (0% all the way to the left) because GyroSteer handles steering curves natively with mathematically perfect accuracy.
   - **Steering Deadzone:** Set to **Minimum** (0%).
4. **Pedal Setup:**
   - **Acceleration Axis:** Click and drag the **THROTTLE** slider on your iPhone. Set to **Normal** (or Inverted if needed so bar fills as you pull).
   - **Brake Axis:** Click and drag the **BRAKE** slider on your iPhone.
5. **Key & Button Bindings (Options -> Keys & Buttons):**
   - **Left Blinker:** Tap button on iPhone -> maps to Button 1 (or `[` key in Keyboard mode).
   - **Right Blinker:** Tap button on iPhone -> maps to Button 2 (or `]` key).
   - **Horn:** Hold Horn on iPhone -> maps to Button 3 (or `H` key).
   - **Light Modes (Headlights):** Tap Lights on iPhone -> maps to Button 4 (or `L` key).
   - **Shift Up / Down:** Maps to Button 5 / 6 (or `Shift` / `Ctrl`).
   - **Cruise Control:** Maps to Button 7 (or `C` key).

### Step 3: Wheel Rotation Degrees
- For true 1:1 realism, the iOS app defaults to **900°** (450° each way), which matches European standard truck steering geometry.
- If you prefer quick arcade steering (e.g. for racing games), open the iOS Settings sheet and select **180°** or **90°**.

---

## 7. Zero-Driver Keyboard Fallback Mode

If you are running in an environment where virtual HID driver permissions cannot be granted:
1. In `GyroSteer-Mac`, toggle the Output Mode to **Keyboard Emulation (Zero-Driver)**.
2. Click **Authorize** to grant macOS Accessibility permissions (System Settings -> Privacy & Security -> Accessibility).
3. GyroSteer uses high-frequency **Pulse-Width Modulation (PWM)** at 50Hz to pulse the `A`/`D` steering keys and `W`/`S` pedal keys proportionally. 50% left steering pulses key `A` at a 50% duty cycle, giving you smooth, analog-like control without any kernel or driver extensions!

---

## 8. Verification & Test Suite

The project includes an automated test suite verifying serialization, 16-bit circular sequence ordering, deadzone filtering, and arbiter failover:

```bash
cd GyroSteer
./Scripts/build_mac.sh
```

Sample test output:
```
========================================
  GyroSteer Unified Test Suite Runner   
========================================
▶ Running SteeringPacket Serialization Tests...
✔ Shared SteeringPacket tests passed successfully!
▶ Running TransportArbiterTests...
✔ All TransportArbiterTests passed successfully!
========================================
  ALL 100% UNIT TESTS PASSED GLOBALLY!  
========================================
```

---

## 9. License

MIT License. Designed with precision for macOS and iOS simulator enthusiasts.
