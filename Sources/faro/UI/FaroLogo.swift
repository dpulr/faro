// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Lee un `d` de SVG con comandos absolutos M, L, H, V, C y Z (los que produce scripts/make-logo.py).
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var path = Path()
        var current = CGPoint.zero
        var command: Character = "M"
        var numbers: [CGFloat] = []

        func flush() {
            switch command {
            case "M" where numbers.count >= 2: current = CGPoint(x: numbers[0], y: numbers[1]); path.move(to: current)
            case "L" where numbers.count >= 2: current = CGPoint(x: numbers[0], y: numbers[1]); path.addLine(to: current)
            case "H" where numbers.count >= 1: current.x = numbers[0]; path.addLine(to: current)
            case "V" where numbers.count >= 1: current.y = numbers[0]; path.addLine(to: current)
            case "C" where numbers.count >= 6:
                current = CGPoint(x: numbers[4], y: numbers[5])
                path.addCurve(to: current, control1: CGPoint(x: numbers[0], y: numbers[1]), control2: CGPoint(x: numbers[2], y: numbers[3]))
            case "Z": path.closeSubpath()
            default: break
            }
            numbers = []
        }

        var token = ""
        func endNumber() { if let n = Double(token) { numbers.append(CGFloat(n)) }; token = "" }

        for ch in d {
            if "MLHVCZ".contains(ch) {
                endNumber(); flush(); command = ch
                if ch == "Z" { flush() }
            } else if ch == " " || ch == "," {
                endNumber()
            } else {
                token.append(ch)
            }
        }
        endNumber(); flush()
        return path
    }
}

/// El logo de faro: un faro con haces de luz y olas. Con `ring` va encerrado en un círculo.
/// `.color` usa los colores de la marca; `.template` es de una sola tinta (barra de menú) y engrosa los detalles finos.
struct FaroLogo: View {
    enum Style { case color, template }

    var style: Style = .color
    var ring = true
    /// Los haces de luz: encendidos mientras el Mac está en modo despierto.
    var lit = true

    var body: some View {
        Canvas { context, size in
            let k = min(size.width, size.height) / 200
            let scale = CGAffineTransform(scaleX: k, y: k)
            let color = style == .color
            func shading(_ hex: String) -> GraphicsContext.Shading {
                color ? .color(Color(hex: hex) ?? .gray) : .foreground
            }

            let disc = Path(ellipseIn: CGRect(x: 6 * k, y: 6 * k, width: 188 * k, height: 188 * k))
            var layers: [(String, String)] = []
            if lit { layers += [(FaroLogoData.beamMid, FaroLogoData.amberHex), (FaroLogoData.beamUp, FaroLogoData.amberHex),
                                (FaroLogoData.beamDown, FaroLogoData.amberHex)] }
            layers += [FaroLogoData.spire, FaroLogoData.finial, FaroLogoData.dome, FaroLogoData.lantern, FaroLogoData.gallery1,
                       FaroLogoData.band, FaroLogoData.gallery2, FaroLogoData.tower].map { ($0, FaroLogoData.blueHex) }
            if color { layers += [(FaroLogoData.glass, FaroLogoData.glassHex), (FaroLogoData.stripe, FaroLogoData.glassHex)] }
            layers += [(FaroLogoData.waveA, FaroLogoData.blueHex), (FaroLogoData.waveB, FaroLogoData.darkHex)]

            // En una sola tinta, un trazo extra evita que los detalles finos desaparezcan a 18 puntos.
            let bold = color ? 0 : 3.2 * k
            context.drawLayer { layer in
                layer.clip(to: disc)
                for (d, hex) in layers {
                    let shape = SVGPath.parse(d).applying(scale)
                    layer.fill(shape, with: shading(hex))
                    if bold > 0 { layer.stroke(shape, with: shading(hex), style: StrokeStyle(lineWidth: bold, lineJoin: .round)) }
                }
            }
            if ring {
                context.stroke(disc, with: shading(FaroLogoData.blueHex), lineWidth: color ? 6 * k : max(13 * k, 1.5))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
