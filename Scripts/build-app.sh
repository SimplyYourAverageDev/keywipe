#!/bin/zsh
# Builds Keywipe in release mode and assembles build/Keywipe.app.
#
# The bundle is put together by hand so that the Command Line Tools are enough; no Xcode
# project is involved. Set CODESIGN_IDENTITY to sign with a real certificate instead of
# the default ad hoc signature.

set -euo pipefail

cd "${0:A:h}/.."

app="build/Keywipe.app"
identity="${CODESIGN_IDENTITY:--}"

swift build --configuration release
binary="$(swift build --configuration release --show-bin-path)/Keywipe"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Keywipe"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

codesign --force --options runtime --sign "$identity" "$app"
codesign --verify --strict "$app"

echo "Built $app"
