// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI
import Charts

enum Theme {
    /// Color de resalte elegido; las ventanas raíz se reconstruyen cuando cambia (ver `Appearance.revision`).
    static var accent: Color { MainActor.assumeIsolated { Appearance.shared.accent } }
    static let warning = Color(red: 0.92, green: 0.60, blue: 0.18)
    static let critical = Color(red: 0.87, green: 0.31, blue: 0.29)

    /// Rellenos translúcidos con color explícito según el modo claro/oscuro.
    private static func adaptive(_ dark: CGFloat, _ light: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1, alpha: dark) : NSColor(white: 0, alpha: light)
        })
    }

    static let fill = adaptive(0.10, 0.07)
    static let fillFaint = adaptive(0.05, 0.035)
    static let stroke = adaptive(0.09, 0.08)
    static let card = adaptive(0.07, 0.05)

    static func usage(_ fraction: Double) -> Color {
        fraction >= 0.9 ? critical : fraction >= 0.75 ? warning : accent
    }

    static func color(_ level: SystemMonitor.Level) -> Color {
        switch level {
        case .ok: return accent
        case .warning: return warning
        case .critical: return critical
        }
    }

    /// Colores para distinguir los canales dentro de una mezcla.
    static var palette: [Color] { [
        accent, Color(red: 0.34, green: 0.48, blue: 0.82), Color(red: 0.84, green: 0.60, blue: 0.24),
        Color(red: 0.74, green: 0.42, blue: 0.70), Color(red: 0.87, green: 0.42, blue: 0.38), Color(red: 0.45, green: 0.66, blue: 0.80),
    ] }

    static func color(for kind: SourceKind) -> Color {
        switch kind {
        case .wallhaven: return accent
        case .wikimedia: return Color(red: 0.84, green: 0.60, blue: 0.24)
        case .bing: return Color(red: 0.34, green: 0.48, blue: 0.82)
        case .folder: return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .artic: return Color(red: 0.74, green: 0.42, blue: 0.70)
        case .nasa: return Color(red: 0.87, green: 0.42, blue: 0.38)
        case .picsum: return Color(red: 0.45, green: 0.66, blue: 0.80)
        }
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke))
    }
}

struct RingGauge: View {
    var value: Double
    var tint: Color
    var title: LocalizedStringKey
    var detail: LocalizedStringKey
    var size: CGFloat = 64

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(tint.opacity(0.16), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: min(max(value, 0.01), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }
            .frame(width: size, height: size)
            VStack(spacing: 1) {
                Text(title).font(.caption.weight(.medium))
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Medidor pequeño: anillo fino con título y valor al lado.
struct MiniGauge: View {
    var value: Double
    var tint: Color
    var title: LocalizedStringKey
    var detail: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().stroke(tint.opacity(0.16), lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: min(max(value, 0.015), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text(detail).font(.caption.weight(.semibold).monospacedDigit()).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct Sparkline: View {
    var values: [Double]
    var tint: Color
    var maxValue: Double?

    var body: some View {
        let top = maxValue ?? max(values.max() ?? 1, 0.0001)
        Chart(Array(values.enumerated()), id: \.offset) { item in
            AreaMark(x: .value("t", item.offset), y: .value("v", item.element))
                .interpolationMethod(.monotone)
                .foregroundStyle(tint.opacity(0.16))
            LineMark(x: .value("t", item.offset), y: .value("v", item.element))
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.6))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...top)
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        PillBody(configuration: configuration, prominent: prominent)
    }
}

private struct PillBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        configuration.label
            .font(.callout.weight(.medium))
            .padding(.horizontal, 14)
            .frame(height: 34)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background {
                ZStack {
                    Capsule().fill(prominent ? Theme.accent : Theme.fill)
                    Capsule().fill(prominent ? Color.white.opacity(hovering ? 0.16 : 0)
                                             : (hovering ? Theme.fill : Color.clear))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(enabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 && enabled }
    }
}

struct IconButtonStyle: ButtonStyle {
    var tint: Color?
    var size: CGFloat
    /// Relleno con el color de resalte (acción principal o función encendida).
    var prominent: Bool

    init(tint: Color? = nil, size: CGFloat = 34, prominent: Bool = false) {
        self.tint = tint
        self.size = size
        self.prominent = prominent
    }

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        IconBody(configuration: configuration, tint: tint, size: size, prominent: prominent)
    }
}

private struct IconBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color?
    let size: CGFloat
    let prominent: Bool
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        configuration.label
            .font(.system(size: size > 32 ? 14 : 13, weight: .medium))
            .foregroundStyle(prominent ? Color.white : (tint ?? Color.primary))
            .frame(width: size, height: size)
            .background {
                ZStack {
                    Circle().fill(prominent ? Theme.accent : (tint?.opacity(0.18) ?? Theme.fill))
                    Circle().fill(hovering ? (prominent ? Color.white.opacity(0.16) : (tint?.opacity(0.18) ?? Theme.fill)) : Color.clear)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(enabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 && enabled }
    }
}

/// Ícono suelto, sin fondo: se aclara al pasar el cursor.
struct QuietIconStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        QuietBody(configuration: configuration, tint: tint)
    }
}

private struct QuietBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color?
    @State private var hovering = false

    var body: some View {
        configuration.label
            .foregroundStyle(tint ?? Color.secondary)
            .opacity(configuration.isPressed ? 0.5 : (hovering ? 1 : 0.75))
            .frame(width: 22, height: 30)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Ayuda que aparece al instante al pasar el cursor (la nativa tarda cerca de un segundo).
extension View {
    func instantTip(_ text: String, anchor: Alignment = .top) -> some View {
        modifier(InstantTip(text: text, anchor: anchor))
    }
}

private struct InstantTip: ViewModifier {
    let text: String
    let anchor: Alignment
    @State private var hovering = false
    private var below: Bool { anchor == .bottom || anchor == .bottomLeading || anchor == .bottomTrailing }

    func body(content: Content) -> some View {
        content
            .onHover { inside in withAnimation(.easeOut(duration: 0.1)) { hovering = inside } }
            .overlay(alignment: anchor) {
                if hovering {
                    Text(LocalizedStringKey(text))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.88)))
                        .fixedSize()
                        .offset(y: below ? 36 : -36)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .zIndex(hovering ? 10 : 0)
    }
}

/// Confirmación breve de una acción ("Guardada en Imágenes").
struct NoticeBar: View {
    var text: String?

    var body: some View {
        if let text {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                Text(LocalizedStringKey(text)).font(.caption.weight(.medium)).foregroundStyle(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color.black.opacity(0.78)))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct MixBar: View {
    var sources: [SourceSpec]
    var height: CGFloat = 8

    var body: some View {
        let total = max(sources.reduce(0) { $0 + $1.weight }, 1)
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(sources.filter { $0.weight > 0 }) { s in
                    Theme.color(for: s.kind)
                        .frame(width: max(geo.size.width * CGFloat(s.weight) / CGFloat(total) - 2, 3))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}

struct PageHeader: View {
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 26, weight: .semibold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }
}

struct UsageBar: View {
    var value: Double
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Capsule().fill(tint).frame(width: max(geo.size.width * min(max(value, 0), 1), 6))
            }
        }
        .frame(height: 8)
    }
}

/// Barra de reparto de una mezcla: un color por canal.
struct MemberBar: View {
    var members: [ChannelMember]
    var height: CGFloat = 8

    var body: some View {
        let total = max(members.reduce(0) { $0 + $1.weight }, 1)
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, m in
                    if m.weight > 0 {
                        Theme.palette[index % Theme.palette.count]
                            .frame(width: max(geo.size.width * CGFloat(m.weight) / CGFloat(total) - 2, 3))
                    }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}
