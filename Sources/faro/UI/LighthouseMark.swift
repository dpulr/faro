// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// El símbolo de faro: techo, linterna y torre con una franja. Con `lit` suma los rayos de luz.
/// Está dibujado solo con trazos, así sirve igual en la barra de menú (plantilla) y en el ícono.
struct LighthouseMark: Shape {
    var lit = true

    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var p = Path()

        // techo
        p.move(to: pt(0.35, 0.24)); p.addLine(to: pt(0.50, 0.05)); p.addLine(to: pt(0.65, 0.24)); p.closeSubpath()
        // linterna
        p.addRect(CGRect(x: r.minX + 0.40 * r.width, y: r.minY + 0.24 * r.height, width: 0.20 * r.width, height: 0.16 * r.height))
        // galería
        p.move(to: pt(0.35, 0.40)); p.addLine(to: pt(0.65, 0.40))
        // torre
        p.move(to: pt(0.38, 0.40)); p.addLine(to: pt(0.30, 1.0))
        p.move(to: pt(0.62, 0.40)); p.addLine(to: pt(0.70, 1.0))
        // franja
        p.move(to: pt(0.348, 0.64)); p.addLine(to: pt(0.652, 0.64))
        // suelo
        p.move(to: pt(0.18, 1.0)); p.addLine(to: pt(0.82, 1.0))

        if lit {
            for side in [1.0, -1.0] as [CGFloat] {
                func x(_ v: CGFloat) -> CGFloat { side > 0 ? v : 1 - v }
                p.move(to: pt(x(0.26), 0.28)); p.addLine(to: pt(x(0.11), 0.19))
                p.move(to: pt(x(0.26), 0.32)); p.addLine(to: pt(x(0.06), 0.32))
                p.move(to: pt(x(0.26), 0.36)); p.addLine(to: pt(x(0.11), 0.45))
            }
        }
        return p
    }
}

extension LighthouseMark {
    /// Trazo estándar del símbolo para un tamaño dado.
    static func stroked(lit: Bool, height: CGFloat, color: Color? = nil) -> some View {
        let line = max(height * 0.085, 1.2)
        let style = StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
        return Group {
            if let color { LighthouseMark(lit: lit).stroke(color, style: style) }
            else { LighthouseMark(lit: lit).stroke(style: style) }
        }
        .frame(width: height * 0.95, height: height)
    }
}
