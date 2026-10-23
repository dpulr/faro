// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

// Controles propios de faro: más simples y consistentes que los del sistema.

struct PlusMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

struct CrossMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.move(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        return p
    }
}

struct ChevronMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

private let stroke = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)

private struct DismissDropdownKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var dismissDropdown: () -> Void {
        get { self[DismissDropdownKey.self] }
        set { self[DismissDropdownKey.self] = newValue }
    }
}

struct CheckMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY + 1)); p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

/// Lista desplegable propia (reemplaza al menú del sistema, que descarta el diseño de su etiqueta).
struct Dropdown<Label: View, Content: View>: View {
    @State private var open = false
    @ViewBuilder var label: Label
    @ViewBuilder var content: Content

    var body: some View {
        Button { open.toggle() } label: { label }
            .buttonStyle(.plain)
            .popover(isPresented: $open, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 2) { content }
                    .padding(6)
                    .frame(minWidth: 180, alignment: .leading)
                    .environment(\.dismissDropdown, { open = false })
            }
    }
}

struct DropdownRow: View {
    var title: String
    var selected = false
    var action: () -> Void
    @Environment(\.dismissDropdown) private var dismiss
    @State private var hovering = false

    var body: some View {
        Button { action(); dismiss() } label: {
            HStack(spacing: 10) {
                Text(title).font(.callout)
                Spacer(minLength: 18)
                if selected { CheckMark().stroke(Theme.accent, style: stroke).frame(width: 11, height: 8) }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hovering ? Theme.fill : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Selector en forma de cápsula con flecha dibujada a mano.
struct MenuChip<Content: View>: View {
    var text: String
    @ViewBuilder var content: Content

    var body: some View {
        Dropdown {
            HStack(spacing: 7) {
                Text(text).font(.callout.weight(.medium)).lineLimit(1)
                ChevronMark().stroke(Color.secondary, style: stroke).frame(width: 8, height: 4.5)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(Theme.fill))
        } content: { content }
        .fixedSize()
    }
}

/// Elegir un valor de una lista corta: muestra el elegido y despliega el resto.
struct Choice<T: Hashable>: View {
    @Binding var selection: T
    var options: [(String, T)]

    var body: some View {
        MenuChip(text: options.first { $0.1 == selection }?.0 ?? "—") {
            ForEach(options.indices, id: \.self) { i in
                DropdownRow(title: options[i].0, selected: options[i].1 == selection) { selection = options[i].1 }
            }
        }
    }
}

/// Segmentos con cápsula que se desliza (reemplaza al control segmentado del sistema).
struct Segments<T: Hashable>: View {
    @Binding var selection: T
    var options: [(String, T)]
    @Namespace private var slide

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let on = options[i].1 == selection
                Text(options[i].0)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(on ? Color.white : Color.secondary)
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background {
                        if on { Capsule().fill(Theme.accent).matchedGeometryEffect(id: "pill", in: slide) }
                    }
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { selection = options[i].1 } }
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.fill))
        .fixedSize()
    }
}

/// Poco / Normal / Mucho sobre el peso numérico de una fuente o canal.
struct LevelControl: View {
    @Binding var weight: Int

    var body: some View {
        Segments(selection: Binding(get: { Level.from(weight: weight) }, set: { weight = $0.rawValue }),
                 options: Level.allCases.map { ($0.label, $0) })
    }
}

/// Interruptor propio: pista con perilla, del color de resalte.
struct MiniSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Button { withAnimation(.easeOut(duration: 0.15)) { configuration.isOn.toggle() } } label: {
                Capsule().fill(configuration.isOn ? Theme.accent : Theme.fill)
                    .frame(width: 38, height: 22)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(Color.white).frame(width: 18, height: 18).padding(2)
                            .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                    }
            }
            .buttonStyle(.plain)
        }
    }
}

/// Quitar un elemento de una lista: una equis fina.
struct CloseButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            CrossMark().stroke(Color.secondary, style: stroke).frame(width: 9, height: 9).padding(8)
        }
        .buttonStyle(.plain)
    }
}

/// «+ Agregar …» como texto con un más dibujado a mano.
struct AddLabel: View {
    var text: String
    var body: some View {
        HStack(spacing: 7) {
            PlusMark().stroke(Theme.accent, style: stroke).frame(width: 10, height: 10)
            Text(text).font(.callout.weight(.medium))
        }
        .foregroundStyle(Theme.accent)
    }
}

/// Línea inferior en lugar del recuadro del campo de texto del sistema.
struct UnderlinedField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder))
            .textFieldStyle(.plain).font(.callout)
            .padding(.vertical, 5)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }
}
