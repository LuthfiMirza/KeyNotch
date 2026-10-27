#!/usr/bin/env bash
set -e

APP_NAME="KeyNotch"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BINARY_PATH="${MACOS_DIR}/${APP_NAME}"

echo "=================================================="
echo "  🏝️  Building ${APP_NAME} (Zero-Xcode Swift CLI)"
echo "=================================================="

# 1. Clean & Prepare Bundle Structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 2. Generate Info.plist
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>KeyNotch</string>
    <key>CFBundleIdentifier</key>
    <string>com.keynotch.app</string>
    <key>CFBundleName</key>
    <string>KeyNotch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>KeyNotch uses your camera for quick video call framing mirror preview.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>KeyNotch monitors Bluetooth peripheral status for the Control Center widget.</string>
</dict>
</plist>
EOF

# 3. Collect Swift Source Files
SWIFT_FILES=$(find Sources -type f -name "*.swift" | sort)
COUNT=$(echo "${SWIFT_FILES}" | wc -l | tr -d ' ')
echo "-> Found ${COUNT} Swift source files in Sources/"

# Detect Architecture
ARCH=$(uname -m)
TARGET="${ARCH}-apple-macos12.0"
echo "-> Target Architecture: ${TARGET}"

# 4. Compile with swiftc
echo "-> Compiling native binary via swiftc..."
swiftc \
    -O \
    -target "${TARGET}" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework IOKit \
    -framework Carbon \
    -framework Vision \
    -framework CoreWLAN \
    -framework AudioToolbox \
    -framework AVFoundation \
    -framework IOBluetooth \
    ${SWIFT_FILES} \
    -o "${BINARY_PATH}"

# 5. Ad-hoc codesign for local execution
echo "-> Signing app bundle (ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

BINARY_SIZE=$(du -h "${BINARY_PATH}" | cut -f1)
echo "✅ Build Successful!"
echo "   Binary Location : ${BINARY_PATH}"
echo "   Binary Footprint: ${BINARY_SIZE}"
echo "=================================================="

# 6. Run if requested
if [ "$1" = "run" ]; then
    echo "-> Stopping previous instances of ${APP_NAME}..."
    pkill -x "${APP_NAME}" 2>/dev/null || true
    sleep 0.3
    echo "-> Launching ${APP_BUNDLE}..."
    open "${APP_BUNDLE}"
    echo "🏝️ KeyNotch is now active in your menu bar and top notch!"
fi
