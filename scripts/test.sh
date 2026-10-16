#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" \
    "$ROOT/Sources/CaptureSelection.swift" "$ROOT/Sources/WindowHitTest.swift" "$ROOT/Tests/SelectionTests.swift" \
    -o "$ROOT/build/selection-tests"
"$ROOT/build/selection-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" \
    "$ROOT/Sources/CaptureSelection.swift" "$ROOT/Sources/WindowHitTest.swift" \
    "$ROOT/Tests/TahoeDockTests.swift" -o "$ROOT/build/tahoe-dock-tests"
"$ROOT/build/tahoe-dock-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" \
    "$ROOT/Sources/CaptureSelection.swift" "$ROOT/Sources/WindowHitTest.swift" \
    "$ROOT/Tests/NativeTargetTests.swift" -o "$ROOT/build/native-target-tests"
"$ROOT/build/native-target-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/build/module-cache" \
    "$ROOT/Sources/CaptureSelection.swift" "$ROOT/Sources/CaptureDiagnostics.swift" \
    "$ROOT/Sources/WindowHitTest.swift" \
    "$ROOT/Tests/DiagnosticsTests.swift" -o "$ROOT/build/diagnostics-tests"
"$ROOT/build/diagnostics-tests"
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$ROOT/build/module-cache" -framework AppKit \
    "$ROOT/Sources/CaptureSelection.swift" "$ROOT/Sources/WindowHitTest.swift" \
    "$ROOT/Tests/WindowHitNativeTests.swift" -o "$ROOT/build/window-hit-native-tests"
HIT_PREFLIGHT=0
"$ROOT/build/window-hit-native-tests" --preflight || HIT_PREFLIGHT=$?
if [[ "$HIT_PREFLIGHT" == 0 ]]; then
    "$ROOT/build/window-hit-native-tests"
elif [[ "$HIT_PREFLIGHT" == 77 && " $* " != *" --require-window-hit "* ]]; then
    printf 'SKIP native window hit tests: graphical session unavailable\n'
else
    printf 'FAIL native window hit preflight (exit %s)\n' "$HIT_PREFLIGHT" >&2
    exit 1
fi
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
