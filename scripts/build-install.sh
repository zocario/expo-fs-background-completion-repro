#!/usr/bin/env bash
# Builds the Release app for the simulator and installs it. Usage: scripts/build-install.sh <simulator udid>
set -euo pipefail
UDID=${1:?simulator udid}
cd "$(dirname "$0")/.."
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
xcodebuild -workspace ios/BgCompletionRepro.xcworkspace -scheme BgCompletionRepro -configuration Release \
  -destination "id=$UDID" -derivedDataPath build/DerivedData build -quiet
xcrun simctl install "$UDID" build/DerivedData/Build/Products/Release-iphonesimulator/BgCompletionRepro.app
echo "installed"
