#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Daniel Pulgarín
# Genera build/faro-<versión>.dmg firmado con Developer ID y notarizado por Apple.
# Requisitos y pasos previos: docs/DISTRIBUCION.md
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
PROFILE="${NOTARY_PROFILE:-faro}"
DMG="build/faro-${VERSION}.dmg"

FARO_RELEASE=1 ./scripts/build-app.sh

STAGE="$(mktemp -d)"
cp -R build/faro.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "faro ${VERSION}" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}')}"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [ "${SKIP_NOTARIZE:-0}" = "1" ]; then
    echo "Sin notarizar (SKIP_NOTARIZE=1): $DMG"
    exit 0
fi
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG" || true
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "Listo: $DMG"
