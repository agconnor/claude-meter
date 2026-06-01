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

# Sign with a STABLE identity if available, so macOS keeps your keychain
# "Always Allow" decision across rebuilds. Ad-hoc signatures change every build
# (new cdhash → new identity → repeated keychain prompts).
#
# One-time setup for a stable identity (no Apple account needed):
#   Keychain Access > Certificate Assistant > Create a Certificate…
#     Name: "ClaudeMeter Local Signing",  Identity Type: Self Signed Root,
#     Certificate Type: Code Signing
# Then rebuilds are signed with the same identity and the prompt won't return.
SIGN_ID="${CLAUDE_METER_SIGN_ID:-ClaudeMeter Local Signing}"
if security find-identity -v -p codesigning 2>/dev/null | grep -qF "${SIGN_ID}"; then
    echo "==> Code signing with stable identity: ${SIGN_ID}"
    codesign --force --sign "${SIGN_ID}" --identifier com.local.claudemeter "${APP}"
else
    echo "==> Ad-hoc code signing (no stable identity '${SIGN_ID}' found)"
    echo "    Tip: create one to stop repeated keychain prompts — see comments in build.sh."
    codesign --force --sign - --identifier com.local.claudemeter "${APP}"
fi

echo "Built ${APP}"
echo
echo "Run it:        open ${APP}"
echo "Add to Login:  menu-bar dropdown -> Launch at Login"
echo "Install:       mv ${APP} /Applications/"
