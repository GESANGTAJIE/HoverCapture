#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/hovercapture-package-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/scripts" "$FIXTURE/Resources"
cp "$ROOT/scripts/package.sh" "$FIXTURE/scripts/package.sh"
cp "$ROOT/Resources/Info.plist" "$FIXTURE/Resources/Info.plist"
# A deliberately failing fresh build must prevent packaging even when an old
# app directory exists. No real signing, image creation, or app changes occur.
cat > "$FIXTURE/scripts/build.sh" <<'BUILD'
#!/bin/bash
touch "$(dirname "$0")/build-attempted"
exit 73
BUILD
for mode in missing stale; do
    if [[ "$mode" == stale ]]; then mkdir -p "$FIXTURE/build/HoverCapture.app"; fi
    rm -f "$FIXTURE/scripts/build-attempted"
    status=0
    bash "$FIXTURE/scripts/package.sh" --zip-only > "$FIXTURE/output" 2>&1 || status=$?
    if [[ "$status" != 73 || ! -f "$FIXTURE/scripts/build-attempted" || -d "$FIXTURE/dist" ]]; then
        cat "$FIXTURE/output" >&2
        printf 'FAIL: %s app must not bypass a failing fresh build (exit %s)\n' "$mode" "$status" >&2
        exit 1
    fi
done
printf 'Packaging regression tests: 2 passed, 0 failed\n'
