#!/bin/bash
# Build, install and launch on the simulator in one step.
#
# Xcode is installed but `xcode-select` still points at the Command Line Tools,
# so DEVELOPER_DIR is set here rather than requiring a sudo switch.
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
BUNDLE_ID="com.roomfinderai.app"
cd "$(dirname "$0")"

echo "==> Building"
xcodebuild -project RoomFinderAI.xcodeproj \
           -scheme RoomFinderAI \
           -sdk iphonesimulator \
           -destination "platform=iOS Simulator,name=$SIM_NAME" \
           -configuration Debug \
           CODE_SIGNING_ALLOWED=NO \
           build 2>&1 | grep -E "error:|warning: .*(deprecat|unused|never)|BUILD" || true

APP=$(find ~/Library/Developer/Xcode/DerivedData/RoomFinderAI-*/Build/Products/Debug-iphonesimulator \
      -maxdepth 1 -name "RoomFinderAI.app" 2>/dev/null | head -1)
[ -n "$APP" ] || { echo "No build product found"; exit 1; }

SIM_ID=$(xcrun simctl list devices available -j \
         | python3 -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next(x['udid'] for v in d.values() for x in v if x['name']=='$SIM_NAME'))")

xcrun simctl boot "$SIM_ID" 2>/dev/null || true
open -a Simulator

echo "==> Installing to $SIM_NAME ($SIM_ID)"
xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIM_ID" "$APP"
xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"
