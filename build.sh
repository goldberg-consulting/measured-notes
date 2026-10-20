#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(tr -d '\n' < VERSION)
STAGING=$(mktemp -d /tmp/measured-notes-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Measured Notes.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist
xcrun swiftc -module-cache-path "$STAGING/module-cache" Source/*.swift -o "$APP/Contents/MacOS/MeasuredNotes" -target arm64-apple-macos26.0 -O -framework SwiftUI -framework AppKit -framework Carbon -framework FoundationModels -framework UserNotifications
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MeasuredNotes</string>
<key>CFBundleIdentifier</key><string>one.measured.notes</string>
<key>CFBundleName</key><string>Measured Notes</string>
<key>CFBundleDisplayName</key><string>measured.one Notes</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  : "${SIGNING_IDENTITY:?Notarization requires a Developer ID signing identity}"
  COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$APP" "$STAGING/submission.zip"
  xcrun notarytool submit "$STAGING/submission.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  codesign --verify --strict "$APP"
  spctl --assess --type execute --verbose "$APP"
fi
rm -rf "dist/Measured Notes.app"
ditto --norsrc "$APP" "dist/Measured Notes.app"
# Archive from staging to keep Finder metadata out of the release.
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$APP" "dist/measured-notes-$VERSION-arm64.zip"
echo "Built Measured Notes $VERSION"
