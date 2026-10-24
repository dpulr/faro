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

# El .dmg lleva el ícono de faro: como ícono del volumen (se ve al abrirlo y viaja dentro del archivo)
# y, en este Mac, también como ícono del archivo .dmg.
STAGE="$(mktemp -d)"
cp -R build/faro.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp assets/AppIcon.icns "$STAGE/.VolumeIcon.icns"
RW="$(mktemp -d)/faro-rw.dmg"
VOLUME="faro ${VERSION}"
rm -f "$DMG"
hdiutil create -volname "$VOLUME" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW" >/dev/null
MOUNT="$(hdiutil attach "$RW" -nobrowse -noverify -noautoopen | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)"
SetFile -a C "$MOUNT"          # marca el volumen para que use su .VolumeIcon.icns
sync
hdiutil detach "$MOUNT" >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -rf "$STAGE" "$(dirname "$RW")"
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
# Ícono del archivo .dmg (solo en este Mac: al subirlo a la web no viaja, el del volumen sí).
ICON_TOOL="$(mktemp -d)/seticon.swift"
cat > "$ICON_TOOL" <<'SWIFT'
import AppKit
let args = CommandLine.arguments
if let image = NSImage(contentsOfFile: args[2]) { _ = NSWorkspace.shared.setIcon(image, forFile: args[1], options: []) }
SWIFT
swift "$ICON_TOOL" "$DMG" assets/AppIcon.icns || true
rm -rf "$(dirname "$ICON_TOOL")"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "Listo: $DMG"
