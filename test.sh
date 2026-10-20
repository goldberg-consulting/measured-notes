#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
STAGING=$(mktemp -d /tmp/measured-notes-tests.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
for CHECK in ActionChecks CollectionChecks SubitemChecks TableChecks; do
  if [ "$CHECK" = TableChecks ]; then SOURCE=Source/Tables.swift; else SOURCE=Source/Model.swift; fi
  xcrun swiftc -module-cache-path "$STAGING/module-cache" -target arm64-apple-macos26.0 "$SOURCE" "Tests/$CHECK.swift" -o "$STAGING/$CHECK" -framework FoundationModels -framework UserNotifications
  "$STAGING/$CHECK"
done
