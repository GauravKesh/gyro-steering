#!/bin/bash
set -e

#
# generate_xcodeproj.sh - Generates GyroSteer.xcodeproj
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$WORKSPACE_ROOT"

if command -v xcodegen &> /dev/null; then
    echo "• Found XcodeGen in PATH. Generating project from project.yml..."
    xcodegen generate
    echo "✔ GyroSteer.xcodeproj generated with XcodeGen!"
else
    echo "• XcodeGen CLI not found. Generating clean native GyroSteer.xcodeproj via generator script..."
    python3 "$SCRIPT_DIR/generate_xcodeproj.py"
fi
