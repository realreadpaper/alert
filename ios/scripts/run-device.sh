#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE_ID="${DEVICE_ID:-00008101-000575411430001E}"
DEVICECTL_ID="${DEVICECTL_ID:-67C1404D-0644-489C-9014-879E44FFFBEA}"
BUNDLE_ID="${BUNDLE_ID:-com.deviceguard.ios}"
BUILD_DIR="${BUILD_DIR:-/tmp/deviceguard-ios-device-build}"

if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
    echo "DEVELOPMENT_TEAM is required. Example:" >&2
    echo "  DEVELOPMENT_TEAM=ABCDE12345 ios/scripts/run-device.sh" >&2
    exit 2
fi

xcodebuild \
    -project "$ROOT_DIR/ios/DeviceGuard.xcodeproj" \
    -scheme DeviceGuard \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    build

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Debug-iphoneos/DeviceGuard.app"
xcrun devicectl device install app --device "$DEVICECTL_ID" "$APP_PATH"
xcrun devicectl device process launch --device "$DEVICECTL_ID" --terminate-existing "$BUNDLE_ID"
