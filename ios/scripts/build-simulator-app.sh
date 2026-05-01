#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="${TMPDIR:-/tmp}/DeviceGuard.app"
EXECUTABLE="$APP_DIR/DeviceGuard"
SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="${IOS_SIMULATOR_TARGET:-arm64-apple-ios17.5-simulator}"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"

cat > "$APP_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.deviceguard.ios</string>
    <key>CFBundleName</key>
    <string>DeviceGuard</string>
    <key>CFBundleDisplayName</key>
    <string>Device Guard</string>
    <key>CFBundleExecutable</key>
    <string>DeviceGuard</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>MinimumOSVersion</key>
    <string>17.5</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
    </array>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
    </dict>
</dict>
</plist>
PLIST

sources=()
while IFS= read -r source; do
    sources+=("$source")
done < <(
    find "$ROOT_DIR/ios/GuardApp" -name "*.swift" \
        ! -name "*Tests.swift" \
        ! -name "SelfTestRunner.swift" \
        | sort
)

xcrun --sdk iphonesimulator swiftc \
    -target "$TARGET" \
    -sdk "$SDK_PATH" \
    -parse-as-library \
    "${sources[@]}" \
    -o "$EXECUTABLE"

chmod +x "$EXECUTABLE"
echo "$APP_DIR"
