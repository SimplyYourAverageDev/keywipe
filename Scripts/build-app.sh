#!/bin/zsh
# Builds Keywipe in release mode and assembles build/Keywipe.app.
#
# The bundle is put together by hand so that the Command Line Tools are enough; no Xcode
# project is involved. Builds are signed with the project's own self-signed certificate
# (see signing-identity.sh) so the keyboard permission survives rebuilds. Set
# CODESIGN_IDENTITY to sign with a certificate from your keychain instead.

set -euo pipefail

cd "${0:A:h}/.."

app="build/Keywipe.app"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    signing=(--sign "$CODESIGN_IDENTITY")
else
    signing=(--keychain "$PWD/.signing/keywipe.keychain-db" --sign "$(Scripts/signing-identity.sh)")
fi

swift build --configuration release
binary="$(swift build --configuration release --show-bin-path)/Keywipe"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Keywipe"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

codesign --force --options runtime "${signing[@]}" "$app"
codesign --verify --strict "$app"

echo "Built $app"
