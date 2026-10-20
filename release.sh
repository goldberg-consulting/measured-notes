#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# Public releases must be signed and notarized; build.sh supports local builds.
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a saved notarytool Keychain profile}"
./test.sh
./build.sh
VERSION=$(tr -d '\n' < VERSION)
cd dist
shasum -a 256 "measured-notes-$VERSION-arm64.zip" > SHA256SUMS
cat SHA256SUMS
