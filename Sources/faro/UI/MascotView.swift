// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Dibuja la mascota con trazos vectoriales. Dormida es una imagen fija (sin temporizador); despierta se anima
/// a unos 24 fotogramas por segundo.
struct MascotView: View {
    @ObservedObject var model: MascotModel
    var size: CGFloat
    /// Fuerza un ánimo (vista previa de ajustes); `nil` usa el real.
    var forcedMood: MascotMood?
    /// Para mostrar variantes (selectores de ajustes) sin cambiar la elegida.
    var shape: MascotShape?
    var eyes: MascotEyes?

    var body: some View {
        let mood = forcedMood ?? model.mood
        let style = MascotStyle(shape: shape ?? model.shape, color: Color(hex: model.colorHex) ?? Theme.accent, eyes: eyes ?? model.eyes,
                                blush: model.blush, accessory: model.accessory)
        Group {
            if mood == .sleeping {
                Canvas { context, canvasSize in
                    MascotPainter.draw(&context, size: canvasSize, style: style, mood: .sleeping, gaze: .zero, time: 0, age: 0)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    Canvas { context, canvasSize in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        MascotPainter.draw(&context, size: canvasSize, style: style, mood: mood, gaze: model.gaze,
                                           time: t, age: timeline.date.timeIntervalSince(model.reactionStart))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct MascotStyle {
    var shape: MascotShape
    var color: Color
    var eyes: MascotEyes
    var blush: Bool
    var accessory: MascotAccessory
}

enum MascotPainter {
    private static let ink = Color(red: 0.07, green: 0.08, blue: 0.1)
    /// Color claro para accesorios finos: se ven sobre el fondo negro de la pastilla y del panel.
    private static let rim = Color(red: 0.93, green: 0.95, blue: 0.98)

    private static func mix(_ color: Color, with other: Color, _ amount: Double) -> Color {
        let a = NSColor(color).usingColorSpace(.sRGB) ?? .gray, b = NSColor(other).usingColorSpace(.sRGB) ?? .gray
        return Color(nsColor: a.blended(withFraction: CGFloat(amount), of: b) ?? a)
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, style: MascotStyle, mood: MascotMood,
                     gaze: CGPoint, time t: Double, age: Double) {
        let s = min(size.width, size.height)
        // Movimiento del cuerpo según el ánimo.
        var lift = 0.0, squash = 1.0, tilt = 0.0
        switch mood {
        case .dancing:
            let beat = abs(sin(t * 6)); lift = -beat * 0.14; squash = 1 + 0.07 * (1 - beat); tilt = sin(t * 3) * 0.12
        case .celebrate:
            let beat = abs(sin(t * 8)); lift = -beat * 0.2; tilt = sin(t * 4) * 0.18
        case .hearts:
            lift = -abs(sin(t * 3)) * 0.04
        case .idle:
            squash = 1 + sin(t * 2) * 0.012
        case .bluetooth:
            lift = -abs(sin(t * 4)) * 0.03
        case .sad, .sleeping:
            break
        }
        var body = style.color
        if mood == .bluetooth { body = mix(style.color, with: Color(red: 0.23, green: 0.51, blue: 0.97), 0.78) }
        if mood == .sad { body = mix(style.color, with: .gray, 0.45) }

        context.translateBy(x: s * 0.5, y: s * (0.56 + lift))
        context.rotate(by: .radians(tilt))
        context.scaleBy(x: squash, y: 2 - squash)
        context.translateBy(x: -s * 0.5, y: -s * 0.5)

        // Cuerpo
        let fill = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [mix(body, with: .white, 0.22), body, mix(body, with: .black, 0.18)]),
            startPoint: CGPoint(x: s * 0.3, y: s * 0.05), endPoint: CGPoint(x: s * 0.7, y: s * 0.95))
        let shape = bodyPath(style.shape, s)
        context.fill(shape, with: fill)
        var shine = context
        shine.clip(to: shape)
        shine.fill(Path(ellipseIn: CGRect(x: s * 0.2, y: s * 0.17, width: s * 0.22, height: s * 0.12)), with: .color(.white.opacity(0.22)))

        // Accesorio
        drawAccessory(&context, s: s, style: style, body: body, t: t)

        // Cachetes
        if style.blush {
            for x in [0.2, 0.8] {
                context.fill(Path(ellipseIn: CGRect(x: s * (x - 0.07), y: s * 0.6, width: s * 0.14, height: s * 0.08)),
                             with: .color(Color(red: 1, green: 0.45, blue: 0.5).opacity(mood == .sleeping ? 0.25 : 0.4)))
            }
        }

        // Ojos
        let gx = gaze.x * s * 0.045, gy = gaze.y * s * 0.035
        let blink = blinkAmount(t)
        let eyeY = s * 0.46
        for (index, x) in [0.36, 0.64].enumerated() {
            let center = CGPoint(x: s * x + gx, y: eyeY + gy)
            switch mood {
            case .sleeping:
                var arc = Path(); arc.addArc(center: CGPoint(x: center.x, y: center.y - s * 0.02), radius: s * 0.06, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                context.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: max(1.2, s * 0.035), lineCap: .round))
            case .dancing, .hearts, .celebrate:
                var arc = Path(); arc.addArc(center: CGPoint(x: center.x, y: center.y + s * 0.03), radius: s * 0.065, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                context.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: max(1.4, s * 0.04), lineCap: .round))
            case .sad:
                drawEye(&context, style.eyes, center: center, s: s, blink: 0.45, tilt: index == 0 ? 0.35 : -0.35, mood: mood)
            default:
                drawEye(&context, style.eyes, center: center, s: s, blink: blink, tilt: index == 0 ? 0.1 : -0.1, mood: mood)
            }
        }

        // Boca
        if mood == .hearts || mood == .celebrate || mood == .dancing {
            var smile = Path(); smile.addArc(center: CGPoint(x: s * 0.5 + gx * 0.5, y: s * 0.6 + gy), radius: s * 0.05, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            context.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: max(1, s * 0.03), lineCap: .round))
        } else if mood == .sad {
            var frown = Path(); frown.addArc(center: CGPoint(x: s * 0.5, y: s * 0.7), radius: s * 0.045, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            context.stroke(frown, with: .color(ink), style: StrokeStyle(lineWidth: max(1, s * 0.03), lineCap: .round))
        }

        // Efectos: se dibujan sin la transformación del cuerpo.
        context.transform = .identity
        switch mood {
        case .sleeping: drawZ(&context, s: s)
        case .hearts: drawHearts(&context, s: s, age: age)
        case .celebrate: drawConfetti(&context, s: s, age: age, base: style.color)
        case .bluetooth: drawBluetoothBadge(&context, s: s, t: t)
        case .sad: drawTear(&context, s: s, t: t)
        default: break
        }
    }

    // MARK: Piezas

    private static func bodyPath(_ shape: MascotShape, _ s: CGFloat) -> Path {
        switch shape {
        case .blob:
            return Path(ellipseIn: CGRect(x: s * 0.1, y: s * 0.16, width: s * 0.8, height: s * 0.72))
        case .bean:
            return Path(roundedRect: CGRect(x: s * 0.2, y: s * 0.08, width: s * 0.6, height: s * 0.84), cornerRadius: s * 0.3)
        case .cube:
            return Path(roundedRect: CGRect(x: s * 0.12, y: s * 0.14, width: s * 0.76, height: s * 0.74), cornerRadius: s * 0.2)
        case .cloud:
            var p = Path()
            p.addEllipse(in: CGRect(x: s * 0.08, y: s * 0.4, width: s * 0.84, height: s * 0.46))
            p.addEllipse(in: CGRect(x: s * 0.14, y: s * 0.22, width: s * 0.38, height: s * 0.4))
            p.addEllipse(in: CGRect(x: s * 0.4, y: s * 0.12, width: s * 0.44, height: s * 0.5))
            return p
        case .sun:
            var p = Path()
            p.addEllipse(in: CGRect(x: s * 0.2, y: s * 0.24, width: s * 0.6, height: s * 0.6))
            for i in 0..<10 {
                let a = Double(i) / 10 * 2 * .pi
                p.addEllipse(in: CGRect(x: s * (0.5 + 0.34 * cos(a)) - s * 0.075, y: s * (0.54 + 0.34 * sin(a)) - s * 0.075, width: s * 0.15, height: s * 0.15))
            }
            return p
        }
    }

    /// Parpadeo cada ~4 s, de unos 0,2 s.
    private static func blinkAmount(_ t: Double) -> Double {
        let phase = (t + 1.3).truncatingRemainder(dividingBy: 4.1)
        if phase > 3.9 { return 1 - abs((phase - 4.0) / 0.1) }
        return 0
    }

    private static func drawEye(_ context: inout GraphicsContext, _ style: MascotEyes, center: CGPoint, s: CGFloat, blink: Double, tilt: Double, mood: MascotMood) {
        let open = max(0.08, 1 - blink * 0.92)
        switch style {
        case .oval:
            let r = CGRect(x: -s * 0.045, y: -s * 0.1, width: s * 0.09, height: s * 0.2)
            var local = context
            local.translateBy(x: center.x, y: center.y); local.rotate(by: .radians(tilt)); local.scaleBy(x: 1, y: open)
            local.fill(Path(roundedRect: r, cornerRadius: s * 0.045), with: .color(ink))
        case .round:
            var local = context
            local.translateBy(x: center.x, y: center.y); local.scaleBy(x: 1, y: open)
            local.fill(Path(ellipseIn: CGRect(x: -s * 0.065, y: -s * 0.065, width: s * 0.13, height: s * 0.13)), with: .color(ink))
            local.fill(Path(ellipseIn: CGRect(x: -s * 0.03, y: -s * 0.04, width: s * 0.04, height: s * 0.04)), with: .color(.white.opacity(0.9)))
        case .wide:
            var local = context
            local.translateBy(x: center.x, y: center.y); local.scaleBy(x: 1, y: open)
            local.fill(Path(roundedRect: CGRect(x: -s * 0.075, y: -s * 0.05, width: s * 0.15, height: s * 0.1), cornerRadius: s * 0.04), with: .color(ink))
        case .dot:
            var local = context
            local.translateBy(x: center.x, y: center.y); local.scaleBy(x: 1, y: open)
            local.fill(Path(ellipseIn: CGRect(x: -s * 0.035, y: -s * 0.035, width: s * 0.07, height: s * 0.07)), with: .color(ink))
        case .star:
            var local = context
            local.translateBy(x: center.x, y: center.y); local.scaleBy(x: 1, y: open)
            local.fill(sparkle(radius: s * 0.085), with: .color(ink))
        }
    }

    private static func sparkle(radius r: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: r * 0.18, y: -r * 0.18))
        p.addQuadCurve(to: CGPoint(x: 0, y: r), control: CGPoint(x: r * 0.18, y: r * 0.18))
        p.addQuadCurve(to: CGPoint(x: -r, y: 0), control: CGPoint(x: -r * 0.18, y: r * 0.18))
        p.addQuadCurve(to: CGPoint(x: 0, y: -r), control: CGPoint(x: -r * 0.18, y: -r * 0.18))
        return p
    }

    private static func drawAccessory(_ context: inout GraphicsContext, s: CGFloat, style: MascotStyle, body: Color, t: Double) {
        switch style.accessory {
        case .none: break
        case .antenna:
            var stem = Path(); stem.move(to: CGPoint(x: s * 0.5, y: s * 0.16)); stem.addQuadCurve(to: CGPoint(x: s * 0.58, y: s * 0.02), control: CGPoint(x: s * 0.5, y: s * 0.06))
            context.stroke(stem, with: .color(rim), style: StrokeStyle(lineWidth: max(1, s * 0.03), lineCap: .round))
            let glow = 0.7 + 0.3 * sin(t * 4)
            context.fill(Path(ellipseIn: CGRect(x: s * 0.54, y: -s * 0.02, width: s * 0.09, height: s * 0.09)), with: .color(Color(red: 1, green: 0.85, blue: 0.4).opacity(glow)))
        case .bow:
            let c = mix(body, with: Color(red: 1, green: 0.3, blue: 0.45), 0.85)
            var left = Path(); left.move(to: CGPoint(x: s * 0.72, y: s * 0.2)); left.addLine(to: CGPoint(x: s * 0.6, y: s * 0.1)); left.addLine(to: CGPoint(x: s * 0.6, y: s * 0.3)); left.closeSubpath()
            var right = Path(); right.move(to: CGPoint(x: s * 0.72, y: s * 0.2)); right.addLine(to: CGPoint(x: s * 0.86, y: s * 0.1)); right.addLine(to: CGPoint(x: s * 0.86, y: s * 0.3)); right.closeSubpath()
            context.fill(left, with: .color(c)); context.fill(right, with: .color(c))
            context.fill(Path(ellipseIn: CGRect(x: s * 0.69, y: s * 0.17, width: s * 0.06, height: s * 0.06)), with: .color(mix(c, with: .black, 0.25)))
        case .headphones:
            var band = Path(); band.addArc(center: CGPoint(x: s * 0.5, y: s * 0.5), radius: s * 0.43, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            context.stroke(band, with: .color(rim), style: StrokeStyle(lineWidth: max(1.5, s * 0.05), lineCap: .round))
            for x in [0.09, 0.91] {
                let cup = CGRect(x: s * (x - 0.065), y: s * 0.35, width: s * 0.13, height: s * 0.24)
                context.fill(Path(roundedRect: cup, cornerRadius: s * 0.055), with: .color(rim))
                context.fill(Path(roundedRect: cup.insetBy(dx: s * 0.028, dy: s * 0.04), cornerRadius: s * 0.03), with: .color(mix(body, with: .black, 0.35)))
            }
        }
    }

    private static func drawZ(_ context: inout GraphicsContext, s: CGFloat) {
        let a = context.resolve(Text("z").font(.system(size: s * 0.22, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.85)))
        let b = context.resolve(Text("z").font(.system(size: s * 0.15, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.55)))
        context.draw(a, at: CGPoint(x: s * 0.86, y: s * 0.2))
        context.draw(b, at: CGPoint(x: s * 0.96, y: s * 0.06))
    }

    private static func heart(_ r: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r * 0.9))
        p.addCurve(to: CGPoint(x: -r, y: -r * 0.2), control1: CGPoint(x: -r * 0.2, y: r * 0.6), control2: CGPoint(x: -r, y: r * 0.3))
        p.addArc(center: CGPoint(x: -r * 0.5, y: -r * 0.2), radius: r * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: r * 0.5, y: -r * 0.2), radius: r * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: r * 0.9), control1: CGPoint(x: r, y: r * 0.3), control2: CGPoint(x: r * 0.2, y: r * 0.6))
        return p
    }

    private static func drawHearts(_ context: inout GraphicsContext, s: CGFloat, age: Double) {
        for i in 0..<5 {
            let p = (age - Double(i) * 0.2) / 1.7
            guard p > 0, p < 1 else { continue }
            var local = context
            local.translateBy(x: s * (0.5 + sin(Double(i) * 2.3) * 0.3), y: s * (0.3 - p * 0.28))
            let scale = 0.7 + 0.5 * (1 - p)
            local.scaleBy(x: scale, y: scale)
            local.fill(heart(s * 0.11), with: .color(Color(red: 1, green: 0.35, blue: 0.5).opacity(1 - p * p)))
        }
    }

    private static func drawConfetti(_ context: inout GraphicsContext, s: CGFloat, age: Double, base: Color) {
        let colors: [Color] = [base, Color(red: 0.3, green: 0.85, blue: 0.8), Color(red: 1, green: 0.4, blue: 0.5), Color(red: 0.5, green: 0.55, blue: 1)]
        for i in 0..<12 {
            let p = (age - Double(i % 4) * 0.08) / 1.8
            guard p > 0, p < 1 else { continue }
            let angle = Double(i) / 12 * 2 * .pi
            let r = s * (0.18 + p * 0.5)
            let x = s * 0.5 + cos(angle) * r, y = s * 0.45 + sin(angle) * r * 0.8 + p * p * s * 0.25
            context.fill(Path(ellipseIn: CGRect(x: x - s * 0.025, y: y - s * 0.025, width: s * 0.05, height: s * 0.05)), with: .color(colors[i % 4].opacity(1 - p)))
        }
    }

    private static func drawBluetoothBadge(_ context: inout GraphicsContext, s: CGFloat, t: Double) {
        let pulse = 0.8 + 0.2 * sin(t * 6)
        let symbol = context.resolve(Image(systemName: "dot.radiowaves.left.and.right"))
        var local = context
        local.opacity = pulse
        local.draw(symbol, in: CGRect(x: s * 0.68, y: -s * 0.02, width: s * 0.3, height: s * 0.26))
    }

    private static func drawTear(_ context: inout GraphicsContext, s: CGFloat, t: Double) {
        let p = (t * 0.7).truncatingRemainder(dividingBy: 1)
        context.fill(Path(ellipseIn: CGRect(x: s * 0.28, y: s * (0.55 + p * 0.14), width: s * 0.05, height: s * 0.07)), with: .color(Color(red: 0.5, green: 0.75, blue: 1).opacity(1 - p)))
    }
}
