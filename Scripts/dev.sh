#!/usr/bin/env bash
#
# Build a debug Piper.app and launch it.
#
# Always goes through the bundle rather than `swift run`, because a bare
# SwiftPM executable has no Info.plist — which means no LSUIElement, so you
# get a Dock icon, and no bundle identifier for launch-at-login.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="$("$ROOT/Scripts/bundle.sh" debug | tail -1)"

echo "==> Launching $APP"
open "$APP"
