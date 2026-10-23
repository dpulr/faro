#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Daniel Pulgarín
# Genera y publica el sitio de faro (Firebase Hosting, proyecto conecta-lab, sitio faro-conectalab).
# Antes: ./scripts/release.sh para tener el .dmg de la versión actual en build/.
# Con SITE_REPO_PUBLIC=1 el sitio enlaza al repositorio de GitHub.
set -euo pipefail
cd "$(dirname "$0")/../site"
node build.mjs
if [ "${1:-}" = "--preview" ]; then
    firebase hosting:channel:deploy preview --expires 7d
else
    firebase deploy --only hosting
fi
