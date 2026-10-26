#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DESTINATION=${1:?Pass the app bundle path}
xcrun swift build --package-path "$ROOT/Tools/MeasuredDiarizer" -c release --product MeasuredDiarizer
HELPER_BIN=$(xcrun swift build --package-path "$ROOT/Tools/MeasuredDiarizer" -c release --show-bin-path)
mkdir -p "$DESTINATION/Contents/MacOS" "$DESTINATION/Contents/Resources"
cp "$HELPER_BIN/MeasuredDiarizer" "$DESTINATION/Contents/MacOS/MeasuredDiarizer"
cp -R "$ROOT/Resources/Licenses" "$DESTINATION/Contents/Resources/"
if [[ -n "${SIGNING_IDENTITY:-}" && "$SIGNING_IDENTITY" != "-" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$DESTINATION/Contents/MacOS/MeasuredDiarizer"
else
  codesign --force --sign - "$DESTINATION/Contents/MacOS/MeasuredDiarizer"
fi
