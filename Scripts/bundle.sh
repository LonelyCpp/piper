#!/usr/bin/env bash
#
# Assemble Piper.app from the SwiftPM executable.
#
#   Scripts/bundle.sh [debug|release]      # default: release
#
# Prints the path of the built bundle on stdout so callers can capture it.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Piper"
APP="$ROOT/build/$APP_NAME.app"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG"

BIN="$BIN_DIR/$APP_NAME"
if [[ ! -x "$BIN" ]]; then
	echo "error: expected executable at $BIN" >&2
	exit 1
fi

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' >"$APP/Contents/PkgInfo"

# Bundle any extra resources (icons, sounds, asset catalogs) when present.
shopt -s nullglob
for extra in "$ROOT"/Resources/*; do
	[[ "$(basename "$extra")" == "Info.plist" ]] && continue
	cp -R "$extra" "$APP/Contents/Resources/"
done
shopt -u nullglob

# Ad-hoc signature. Enough for local runs; replace with a Developer ID identity
# to distribute without Gatekeeper friction.
echo "==> Signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 ||
	echo "    warning: ad-hoc codesign failed — the app may not launch" >&2

codesign --verify --verbose=1 "$APP" >/dev/null 2>&1 ||
	echo "    warning: signature verification failed" >&2

echo "$APP"
