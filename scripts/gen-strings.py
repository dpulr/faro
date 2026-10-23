#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Daniel Pulgarín
"""Genera Resources/en.lproj/Localizable.strings desde scripts/en.txt.

Formato de en.txt: líneas «español => english». `%#` es un valor interpolado: se expande a las
variantes que SwiftUI usa como clave (%@, %lld, %lf), porque el tipo depende de la expresión.
"""
import itertools, pathlib, sys

root = pathlib.Path(__file__).resolve().parent.parent
pairs = []
for n, line in enumerate((root / "scripts/en.txt").read_text().splitlines(), 1):
    if not line.strip() or line.startswith("#"):
        continue
    if " => " not in line:
        sys.exit(f"en.txt:{n}: falta « => »")
    es, en = line.split(" => ", 1)
    pairs.append((es.replace("\\n", "\n"), en.replace("\\n", "\n")))

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

out, seen = [], set()
for es, en in pairs:
    k = es.count("%#")
    if k != en.count("%#"):
        sys.exit(f"placeholders distintos: {es}")
    for combo in itertools.product(["%@", "%lld", "%lf"], repeat=k):
        a, b = es, en
        for spec in combo:
            a = a.replace("%#", spec, 1)
            b = b.replace("%#", spec, 1)
        if a in seen:
            continue
        seen.add(a)
        out.append(f'"{esc(a)}" = "{esc(b)}";')
header = "/* Generado por scripts/gen-strings.py desde scripts/en.txt: no editar a mano. */\n"
(root / "Resources/en.lproj/Localizable.strings").write_text(header + "\n".join(out) + "\n")
(root / "Resources/es.lproj/Localizable.strings").write_text("/* El español es el idioma de origen: las claves ya están en español. */\n")
print(len(pairs), "textos,", len(out), "entradas")
