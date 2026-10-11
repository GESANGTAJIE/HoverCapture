#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" \
    "$ROOT/Sources/CaptureSelection.swift" "$ROOT/Tests/SelectionTests.swift" \
    -o "$ROOT/build/selection-tests"
"$ROOT/build/selection-tests"
