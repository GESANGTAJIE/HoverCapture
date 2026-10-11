#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/HoverCapture.app"
SDK="$(xcrun --show-sdk-path)"
mkdir -p "$BUILD/module-cache" "$APP/Contents/MacOS" "$APP/Contents/Resources"
for ARCH in arm64 x86_64; do
    xcrun swiftc -swift-version 5 -O -sdk "$SDK" -target "$ARCH-apple-macos14.2" \
        -module-cache-path "$BUILD/module-cache" \
        -framework AppKit -framework Carbon -framework ScreenCaptureKit -framework ServiceManagement \
        "$ROOT"/Sources/*.swift -o "$BUILD/HoverCapture-$ARCH"
done
lipo -create "$BUILD/HoverCapture-arm64" "$BUILD/HoverCapture-x86_64" -output "$APP/Contents/MacOS/HoverCapture"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
xcrun swiftc -sdk "$SDK" -module-cache-path "$BUILD/module-cache" \
    "$ROOT/scripts/make-icon.swift" -o "$BUILD/make-icon"
"$BUILD/make-icon" "$BUILD/AppIcon.iconset" "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
# Clear metadata from this generated build artifact before signing.
xattr -cr "$APP"
# For a notarized release, set SIGNING_IDENTITY to a Developer ID Application identity.
codesign --force --options runtime --sign "${SIGNING_IDENTITY:--}" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
lipo -archs "$APP/Contents/MacOS/HoverCapture"
printf 'Built %s\n' "$APP"
