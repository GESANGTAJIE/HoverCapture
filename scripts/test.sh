#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" \
    "$ROOT/Sources/CaptureSelection.swift" "$ROOT/Tests/SelectionTests.swift" \
    -o "$ROOT/build/selection-tests"
"$ROOT/build/selection-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" \
    "$ROOT/Sources/CaptureSelection.swift" "$ROOT/Sources/CaptureDiagnostics.swift" \
    "$ROOT/Tests/DiagnosticsTests.swift" -o "$ROOT/build/diagnostics-tests"
"$ROOT/build/diagnostics-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" \
    "$ROOT/Sources/AppLanguage.swift" "$ROOT/Tests/LanguageTests.swift" \
    -o "$ROOT/build/language-tests"
"$ROOT/build/language-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" -framework AppKit \
    "$ROOT/Sources/CaptureBatch.swift" "$ROOT/Tests/BatchTests.swift" \
    -o "$ROOT/build/batch-tests"
"$ROOT/build/batch-tests" "$@"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" -framework ServiceManagement \
    "$ROOT/Sources/LoginItemSettings.swift" "$ROOT/Tests/LoginItemTests.swift" \
    -o "$ROOT/build/login-item-tests"
"$ROOT/build/login-item-tests"
bash "$ROOT/Tests/PackagingTests.sh"
