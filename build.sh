#!/bin/bash
# Builds ClaudeMeter and wraps the binary in a proper .app bundle so it runs as a
# menu-bar agent (no Dock icon) and can be added to Login Items.
set -euo pipefail
cd "$(dirname "$0")"

APP="ClaudeMeter.app"
CONTENTS="${APP}/Contents"

echo "==> Building release binary"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/ClaudeMeter"

echo "==> Assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${CONTENTS}/MacOS"
cp "${BIN}" "${CONTENTS}/MacOS/ClaudeMeter"
cp Info.plist "${CONTENTS}/Info.plist"

echo "==> Ad-hoc code signing"
codesign --force --sign - --identifier com.local.claudemeter "${APP}"

echo "Built ${APP}"
echo
echo "Run it:        open ${APP}"
echo "Add to Login:  menu-bar dropdown -> Launch at Login"
echo "Install:       mv ${APP} /Applications/"
