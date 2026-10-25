#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
STAGING=$(mktemp -d /tmp/measured-notes-tests.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
for CHECK in ActionChecks CollectionChecks SubitemChecks RelationshipChecks TableChecks; do
  if [ "$CHECK" = TableChecks ]; then SOURCE=Source/Tables.swift; else SOURCE=Source/Model.swift; fi
  xcrun swiftc -module-cache-path "$STAGING/module-cache" -target arm64-apple-macos26.0 "$SOURCE" "Tests/$CHECK.swift" -o "$STAGING/$CHECK" -framework FoundationModels -framework UserNotifications
  "$STAGING/$CHECK"
done
xcrun swiftc -module-cache-path "$STAGING/module-cache" -target arm64-apple-macos26.0 Source/Model.swift Source/Export.swift Tests/ExportChecks.swift -o "$STAGING/ExportChecks" -framework FoundationModels -framework UserNotifications -lsqlite3
"$STAGING/ExportChecks"
xcrun swiftc -module-cache-path "$STAGING/module-cache" -target arm64-apple-macos26.0 Source/Model.swift Source/Images.swift Tests/ImageChecks.swift -o "$STAGING/ImageChecks" -framework FoundationModels -framework UserNotifications -framework AppKit -framework SwiftUI
"$STAGING/ImageChecks"
xcrun swiftc -module-cache-path "$STAGING/module-cache" -target arm64-apple-macos26.0 Source/Model.swift Source/Meetings.swift Tests/MeetingChecks.swift -o "$STAGING/MeetingChecks" -framework FoundationModels -framework UserNotifications -framework AppKit -framework SwiftUI -framework ScreenCaptureKit -framework Speech -framework AVFoundation
"$STAGING/MeetingChecks"
xcrun swiftc -module-cache-path "$STAGING/module-cache" -target arm64-apple-macos26.0 Source/Model.swift Source/Images.swift Source/Documents.swift Tests/DocumentChecks.swift -o "$STAGING/DocumentChecks" -framework FoundationModels -framework UserNotifications -framework AppKit -framework SwiftUI
"$STAGING/DocumentChecks"
xcrun swiftc -module-cache-path "$STAGING/module-cache" -target arm64-apple-macos26.0 Source/ConnectMenu.swift Tests/ConnectMenuChecks.swift -o "$STAGING/ConnectMenuChecks" -framework AppKit -framework SwiftUI
"$STAGING/ConnectMenuChecks"

xcrun swiftc -module-cache-path "$STAGING/module-cache" -target arm64-apple-macos26.0 Source/Model.swift Source/SyncReplica.swift Source/ICloudSync.swift Tests/SyncChecks.swift -o "$STAGING/SyncChecks" -framework FoundationModels -framework UserNotifications
"$STAGING/SyncChecks"
