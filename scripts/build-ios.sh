#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_NUMBER=${BUILD_NUMBER:-1}
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo 'BUILD_NUMBER must be a positive integer.' >&2
  exit 1
fi
command -v xcodegen >/dev/null || { echo 'Install XcodeGen before building.' >&2; exit 1; }
xcodegen generate --spec iOS/project.yml
OUTPUT="$PWD/dist/iOS/build-$BUILD_NUMBER"
mkdir -p "$OUTPUT"
xcodebuild -project iOS/MeasuredNotesMobile.xcodeproj -scheme MeasuredNotesMobile \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$OUTPUT/MeasuredNotes.xcarchive" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -allowProvisioningUpdates archive \
  > "$OUTPUT/archive.log" 2>&1 || { tail -60 "$OUTPUT/archive.log" >&2; exit 1; }
xcodebuild -exportArchive -archivePath "$OUTPUT/MeasuredNotes.xcarchive" \
  -exportPath "$OUTPUT/export" -exportOptionsPlist iOS/ExportOptions.plist \
  -allowProvisioningUpdates > "$OUTPUT/export.log" 2>&1 || { tail -60 "$OUTPUT/export.log" >&2; exit 1; }
python3 scripts/check-ios-package.py "$OUTPUT/export/Measured Notes.ipa"
echo "App Store package: $OUTPUT/export/Measured Notes.ipa"
echo 'Export only. Nothing was uploaded to App Store Connect.'
