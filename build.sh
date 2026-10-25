#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(tr -d '\n' < VERSION)
STAGING=$(mktemp -d /tmp/measured-notes-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Measured Notes.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist
xcrun swiftc -module-cache-path "$STAGING/module-cache" Source/*.swift -o "$APP/Contents/MacOS/MeasuredNotes" -target arm64-apple-macos26.0 -O -framework SwiftUI -framework AppKit -framework Carbon -framework FoundationModels -framework UserNotifications -lsqlite3 -framework ScreenCaptureKit -framework Speech -framework AVFoundation
ICONSET="$STAGING/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MeasuredNotes</string>
<key>CFBundleIdentifier</key><string>one.measured.notes</string>
<key>CFBundleName</key><string>Measured Notes</string>
<key>CFBundleDisplayName</key><string>measured.one Notes</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSMicrophoneUsageDescription</key><string>Include your voice in meeting recordings when you enable the microphone.</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Transcribe your meeting recordings on this Mac.</string>
<key>NSScreenCaptureUsageDescription</key><string>Record the meeting window you select and its audio.</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
SIGNING_ENTITLEMENTS=entitlements.plist
if [[ -n "${ICLOUD_PROFILE:-}" ]]; then
  test -f "$ICLOUD_PROFILE"
  security cms -D -i "$ICLOUD_PROFILE" > "$STAGING/profile.plist"
  python3 - "$STAGING/profile.plist" "$STAGING/iCloud.entitlements" <<'PYPROFILE'
import datetime, plistlib, sys
with open(sys.argv[1], 'rb') as file:
    profile = plistlib.load(file)
values = profile['Entitlements']
if values.get('com.apple.application-identifier') != '97UY84BV45.one.measured.notes':
    raise SystemExit('The iCloud profile does not match Measured Notes.')
if 'iCloud.one.measured.notes' not in values.get('com.apple.developer.ubiquity-container-identifiers', []):
    raise SystemExit('The profile does not include the shared iCloud container.')
services = values.get('com.apple.developer.icloud-services', [])
if services != '*' and '*' not in services and 'CloudDocuments' not in services:
    raise SystemExit('The profile does not enable iCloud Documents.')
if values.get('get-task-allow', False) or profile['ExpirationDate'] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
    raise SystemExit('A valid distribution provisioning profile is required.')
keys = ['com.apple.application-identifier', 'com.apple.developer.team-identifier',
        'com.apple.developer.icloud-container-identifiers', 'com.apple.developer.icloud-container-environment',
        'com.apple.developer.ubiquity-container-identifiers', 'com.apple.developer.icloud-services']
entitlements = {key: values[key] for key in keys if key in values}
entitlements['com.apple.developer.icloud-services'] = ['CloudDocuments']
entitlements['com.apple.security.device.audio-input'] = True
with open(sys.argv[2], 'wb') as file:
    plistlib.dump(entitlements, file)
PYPROFILE
  cp "$ICLOUD_PROFILE" "$APP/Contents/embedded.provisionprofile"
  SIGNING_ENTITLEMENTS="$STAGING/iCloud.entitlements"
fi
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --entitlements "$SIGNING_ENTITLEMENTS" --sign "$SIGNING_IDENTITY" "$APP"
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
