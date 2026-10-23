#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Daniel Pulgarín
# Compila en release y empaqueta faro.app (firmado con tu identidad de Apple Development si existe).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="build/faro.app"
VERSION="$(cat VERSION)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
cp ".build/release/faro" "$APP/Contents/MacOS/faro"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>faro</string>
  <key>CFBundleDisplayName</key><string>faro</string>
  <key>CFBundleIdentifier</key><string>co.soyholistico.faro</string>
  <key>CFBundleExecutable</key><string>faro</string>
  <key>CFBundleDevelopmentRegion</key><string>es</string>
  <key>CFBundleLocalizations</key><array><string>es</string><string>en</string></array>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>faro controla Finder (vaciar la Papelera) y lee lo que suena en Música y Spotify para mostrarlo en el notch.</string>
  <key>NSBluetoothAlwaysUsageDescription</key><string>faro avisa en el notch cuando se conecta uno de tus dispositivos Bluetooth.</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>faro muestra tu próximo evento en el panel del notch.</string>
  <key>NSCalendarsUsageDescription</key><string>faro muestra tu próximo evento en el panel del notch.</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Firma con una identidad estable si existe: así macOS conserva los permisos (Accesibilidad) entre compilaciones.
IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk '{print $2}')
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "Aviso: no hay identidad de firma; se firma sin identidad y macOS pedirá los permisos tras cada compilación."
    codesign --force --sign - "$APP"
fi
# Instala en un solo lugar (dos copias con el mismo identificador confunden a macOS con los permisos).
pkill -x faro 2>/dev/null || true
pkill -x Mirador 2>/dev/null || true
# La app se llamó Mirador: se retira su copia para no dejar dos.
rm -rf "/Applications/Mirador.app" "$HOME/Applications/Mirador.app"
if [ -d "/Applications/faro.app" ] || [ -w "/Applications" ]; then
    DEST="/Applications/faro.app"
    rm -rf "$HOME/Applications/faro.app"
else
    mkdir -p "$HOME/Applications"
    DEST="$HOME/Applications/faro.app"
fi
rm -rf "$DEST"
cp -R "$APP" "$DEST"
echo "Listo: $DEST"
