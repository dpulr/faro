# Fuente única del logo: genera los SVG y el código Swift a partir de estas formas.
# Uso: python3 scripts/make-logo.py [vista-previa.svg]
import json, math, re

def ellipse_path(cx, cy, rx, ry):
    k = 0.5522847498
    return (f"M{cx-rx} {cy} C{cx-rx} {cy-ry*k} {cx-rx*k} {cy-ry} {cx} {cy-ry} "
            f"C{cx+rx*k} {cy-ry} {cx+rx} {cy-ry*k} {cx+rx} {cy} "
            f"C{cx+rx} {cy+ry*k} {cx+rx*k} {cy+ry} {cx} {cy+ry} "
            f"C{cx-rx*k} {cy+ry} {cx-rx} {cy+ry*k} {cx-rx} {cy} Z")

BLUE, DARK, AMBER, GLASS = "#6BA5CE", "#5A809E", "#F2B24F", "#D3E5F2"
X = 0   # desplazamiento horizontal para centrar la composición

def tf(d, s=1.1, tx=-14, ty=2, cx=82, cy=100):
    """Escala y desplaza un path con comandos absolutos (M L H V C Z)."""
    out = []
    for cmd, args in re.findall(r"([MLHVCZ])([^MLHVCZ]*)", d):
        nums = [float(n) for n in re.findall(r"-?\d+\.?\d*", args)]
        fx = lambda x: round(cx + (x - cx) * s + tx, 2)
        fy = lambda y: round(cy + (y - cy) * s + ty, 2)
        if cmd == "H": nums = [fx(n) for n in nums]
        elif cmd == "V": nums = [fy(n) for n in nums]
        elif cmd == "Z": nums = []
        else: nums = [fx(n) if i % 2 == 0 else fy(n) for i, n in enumerate(nums)]
        out.append(cmd + " ".join(str(n) for n in nums))
    return " ".join(out)

parts = {
 # torre y faro (azul)
 "spire":   "M82 24 L84.4 44 L79.6 44 Z",
 "finial":  ellipse_path(82, 46, 3.4, 3.4),
 "dome":    "M62 62 C62 51 71 47 82 47 C93 47 102 51 102 62 Z",
 "lantern": "M67 62 H97 V80 H67 Z",
 "gallery1":"M60 82 H104 C106 82 107 83 107 84.5 C107 86 106 87 104 87 H60 C58 87 57 86 57 84.5 C57 83 58 82 60 82 Z",
 "band":    "M67 87 H97 V103 H67 Z",
 "gallery2":"M56 103 H108 C110.5 103 112 104.5 112 106.5 C112 108.5 110.5 110 108 110 H56 C53.5 110 52 108.5 52 106.5 C52 104.5 53.5 103 56 103 Z",
 "tower":   "M67 110 H97 L103 150 H61 Z",
 # cristales (azul claro)
 "glass":   "M70 65 H73.4 V78 H70 Z M76.3 65 H79.7 V78 H76.3 Z M82.6 65 H86 V78 H82.6 Z M89 65 H92.4 V78 H89 Z",
 "stripe":  "M65 126 H99 L100.2 137 H63.8 Z",
 # olas
 "waveA":   "M6 158 C40 138 78 138 104 148 C132 159 164 170 196 160 C166 180 132 176 104 166 C76 156 40 160 6 178 Z",
 "waveB":   "M4 184 C38 166 76 172 106 184 C134 195 164 196 198 184 L198 204 L4 204 Z",
 # haces de luz (ámbar)
 "beamMid": "M106 71 L174 54 L174 90 Z",
 "beamUp":  "M106 66 L158 36 L165 44 Z",
 "beamDown":"M106 76 L156 100 L150 109 Z",
}
for k in ["spire","finial","dome","lantern","gallery1","band","gallery2","tower","glass","stripe","beamMid","beamUp","beamDown"]:
    parts[k] = tf(parts[k])


def svg(ring=True, size=200, bg=None, tmpl=False):
    c = {"blue":BLUE,"dark":DARK,"amber":AMBER,"glass":GLASS}
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="{size}" height="{size}">',
         '<title>faro</title>',
         '<defs><clipPath id="c"><circle cx="100" cy="100" r="94"/></clipPath></defs>']
    if bg: o.append(f'<circle cx="100" cy="100" r="97" fill="{bg}"/>')
    o.append('<g clip-path="url(#c)">')
    for k in ["beamMid","beamUp","beamDown"]: o.append(f'<path d="{parts[k]}" fill="{c["amber"]}"/>')
    for k in ["spire","finial","dome","lantern","gallery1","band","gallery2","tower"]: o.append(f'<path d="{parts[k]}" fill="{c["blue"]}"/>')
    o.append(f'<path d="{parts["glass"]}" fill="{c["glass"]}"/>')
    o.append(f'<path d="{parts["stripe"]}" fill="{c["glass"]}"/>')
    o.append(f'<path d="{parts["waveA"]}" fill="{c["blue"]}"/>')
    o.append(f'<path d="{parts["waveB"]}" fill="{c["dark"]}"/>')
    o.append('</g>')
    if ring: o.append(f'<circle cx="100" cy="100" r="94" fill="none" stroke="{c["blue"]}" stroke-width="6"/>')
    o.append('</svg>')
    return "\n".join(o)

import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
open(os.path.join(root, "docs/images/logo.svg"), "w").write(svg(ring=True))
open(os.path.join(root, "docs/images/logo-mark.svg"), "w").write(svg(ring=False))
if len(sys.argv) > 1:   # vista previa grande con fondo blanco
    open(sys.argv[1], "w").write(svg(ring=True, size=700, bg="#FFFFFF"))
swift = ["// SPDX-License-Identifier: AGPL-3.0-or-later", "// Copyright (C) 2026 Daniel Pulgarín", "",
         "// Generado por scripts/make-logo.py a partir de docs/images/logo.svg: no editar a mano.", "",
         "enum FaroLogoData {"]
for k, v in parts.items(): swift.append(f'    static let {k} = "{v}"')
for k, v in {"blue": BLUE, "dark": DARK, "amber": AMBER, "glass": GLASS}.items(): swift.append(f'    static let {k}Hex = "{v}"')
swift.append("}")
open(os.path.join(root, "Sources/faro/UI/FaroLogoData.swift"), "w").write("\n".join(swift) + "\n")
print("ok")
