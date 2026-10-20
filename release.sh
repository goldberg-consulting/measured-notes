#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./test.sh
./build.sh
VERSION=$(tr -d '\n' < VERSION)
cd dist
shasum -a 256 "measured-notes-$VERSION-arm64.zip" > SHA256SUMS
cat SHA256SUMS
