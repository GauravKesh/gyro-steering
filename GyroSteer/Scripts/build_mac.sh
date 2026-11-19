#!/bin/bash
set -e

#
# build_mac.sh - GyroSteer macOS Application Build & Test Script
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$WORKSPACE_ROOT/build"
APP_DIR="$BUILD_DIR/GyroSteer.app"
CACHE_DIR="/tmp/gyrosteer-swift-cache"

mkdir -p "$BUILD_DIR"
mkdir -p "$CACHE_DIR"

echo "========================================================"
echo "  GyroSteer macOS Receiver - Build & Packaging Script  "
echo "========================================================"

# Check for Developer Tools
if [ -d "/Library/Developer/CommandLineTools" ]; then
    export DEVELOPER_DIR="/Library/Developer/CommandLineTools"
fi

SDK_PATH="$($DEVELOPER_DIR/usr/bin/xcrun --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")"
echo "• Using SDK: $SDK_PATH"

# Step 1: Run Unit Tests
echo ""
echo "▶ [1/3] Compiling and Running Unit Test Suite..."
swiftc \
    -module-cache-path "$CACHE_DIR" \
    -sdk "$SDK_PATH" \
    -framework Foundation \
    -framework Network \
    -framework CoreBluetooth \
    -framework CoreGraphics \
    -framework IOKit \
    -framework AppKit \
    -framework SwiftUI \
    -I "$WORKSPACE_ROOT/Shared" \
    "$WORKSPACE_ROOT/Shared"/*.swift \
    "$WORKSPACE_ROOT/GyroSteer-Mac/Transports"/*.swift \
    "$WORKSPACE_ROOT/GyroSteer-Mac/Core"/*.swift \
    "$WORKSPACE_ROOT/GyroSteer-Mac/Output"/*.swift \
    "$WORKSPACE_ROOT/GyroSteer-Mac/UI"/*.swift \
    "$WORKSPACE_ROOT/Tests/MacTests"/*.swift \
    "$WORKSPACE_ROOT/Tests/RunAllTests.swift" \
    -emit-executable \
    -o "$BUILD_DIR/gyrosteer-tests"

"$BUILD_DIR/gyrosteer-tests"
echo "✔ Unit tests passed 100%!"

# Step 2: Build Application Bundle Structure
echo ""
echo "▶ [2/3] Constructing GyroSteer.app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$WORKSPACE_ROOT/GyroSteer-Mac/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# Step 3: Compile macOS App Binary
echo ""
echo "▶ [3/3] Compiling macOS Native Receiver Binary..."
swiftc \
    -O \
    -module-cache-path "$CACHE_DIR" \
    -sdk "$SDK_PATH" \
    -framework Foundation \
    -framework Network \
    -framework CoreBluetooth \
    -framework CoreGraphics \
    -framework IOKit \
    -framework AppKit \
    -framework SwiftUI \
    -I "$WORKSPACE_ROOT/Shared" \
    "$WORKSPACE_ROOT/Shared"/*.swift \
    "$WORKSPACE_ROOT/GyroSteer-Mac/Transports"/*.swift \
    "$WORKSPACE_ROOT/GyroSteer-Mac/Core"/*.swift \
    "$WORKSPACE_ROOT/GyroSteer-Mac/Output"/*.swift \
    "$WORKSPACE_ROOT/GyroSteer-Mac/UI"/*.swift \
    "$WORKSPACE_ROOT/GyroSteer-Mac/App"/*.swift \
    -emit-executable \
    -o "$APP_DIR/Contents/MacOS/GyroSteer"

# Step 4: Ad-hoc code signing
if command -v codesign &>/dev/null; then
    echo "• Ad-hoc signing GyroSteer.app with entitlements and stable designated requirement..."
    codesign --force --deep --sign - \
        -r='designated => identifier "com.gyrosteer.receiver"' \
        --entitlements "$WORKSPACE_ROOT/GyroSteer-Mac/Resources/GyroSteer-Mac.entitlements" \
        "$APP_DIR" || true
fi

echo ""
echo "========================================================"
echo "✔ BUILD SUCCESSFUL: $APP_DIR"
echo "To run immediately, execute:"
echo "    open \"$APP_DIR\""
echo "========================================================"
