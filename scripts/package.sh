#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/HoverCapture.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
NAME="HoverCapture-$VERSION-universal"
if [[ "${1:-}" != "" && "${1:-}" != "--zip-only" ]]; then
    printf 'Usage: %s [--zip-only]\n' "$0" >&2
    exit 2
fi
if [[ ! -d "$APP" ]]; then bash "$ROOT/scripts/build.sh"; fi
xattr -cr "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p "$ROOT/dist"
ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ROOT/dist/$NAME.zip"
if [[ "${1:-}" == "--zip-only" ]]; then
    (cd "$ROOT/dist" && shasum -a 256 "$NAME.zip" > SHA256SUMS.txt)
    printf 'Packaged %s\n' "$ROOT/dist/$NAME.zip"
    exit 0
fi
STAGING="$(mktemp -d "$ROOT/build/dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto --norsrc --noextattr --noacl "$APP" "$STAGING/HoverCapture.app"
xattr -cr "$STAGING/HoverCapture.app"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT/README.md" "$ROOT/README.zh-CN.md" "$ROOT/LICENSE" "$ROOT/CONTRIBUTING.md" "$STAGING/"
mkdir -p "$STAGING/docs"
cp "$ROOT/docs/TESTING.md" "$STAGING/docs/TESTING.md"
hdiutil create -volname HoverCapture -srcfolder "$STAGING" -ov -format UDZO "$ROOT/dist/$NAME.dmg"
cd "$ROOT/dist"
shasum -a 256 "$NAME.dmg" "$NAME.zip" > SHA256SUMS.txt
hdiutil verify "$NAME.dmg"
printf 'Packaged %s\n' "$ROOT/dist/$NAME.dmg"
