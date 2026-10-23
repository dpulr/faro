// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Poco, normal o mucho: tres niveles en vez de porcentajes.
enum Level: Int, CaseIterable, Identifiable {
    case low = 10, normal = 30, high = 60
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .low: return "Poco"
        case .normal: return "Normal"
        case .high: return "Mucho"
        }
    }
    static func from(weight: Int) -> Level { weight <= 18 ? .low : (weight <= 45 ? .normal : .high) }
}

private struct EditTarget: Identifiable { let id: UUID }

struct FondosPage: View {
    @EnvironmentObject var engine: WallpaperEngine
    @State private var editing: UUID?

    private let intervals: [(String, Int)] = [
        ("15 minutos", 15), ("30 minutos", 30), ("1 hora", 60), ("2 horas", 120),
        ("6 horas", 360), ("1 día", 1440), ("Solo a mano", 0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            PageHeader(title: "Fondos", subtitle: "Elige un canal y el fondo cambia solo.")
            nowCard
            channels
        }
        .onChange(of: engine.state.channels) { engine.channelsEdited() }
        .sheet(item: Binding(get: { editing.map(EditTarget.init) }, set: { editing = $0?.id })) { target in
            ChannelSheet(channelID: target.id)
        }
    }

    // MARK: Foto actual

    private var nowCard: some View {
        Card(padding: 14) {
            HStack(spacing: 20) {
                Color.clear
                    .frame(width: 290, height: 182)
                    .overlay {
                        if let image = engine.preview {
                            Image(nsImage: image).resizable().scaledToFill()
                        } else {
                            Rectangle().fill(Theme.fill)
                        }
                    }
                    .overlay(alignment: .top) { NoticeBar(text: engine.notice).padding(10) }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(engine.current?.title ?? "Todavía no hay foto").font(.title3.weight(.semibold)).lineLimit(2)
                        Text([engine.current?.source.label, engine.current?.author]
                            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.callout).foregroundStyle(.secondary).lineLimit(2)
                        if let error = engine.lastError {
                            Text(error).font(.caption).foregroundStyle(Theme.critical)
                        }
                    }
                    HStack(spacing: 8) {
                        Button { Task { await engine.previous() } } label: { Image(systemName: "arrow.uturn.backward") }
                            .buttonStyle(IconButtonStyle(size: 38)).instantTip("Volver a la foto anterior", anchor: .topLeading)
                            .disabled(engine.busy || engine.state.history.count < 2)
                        Button { Task { await engine.next() } } label: {
                            if engine.busy { ProgressView().controlSize(.small).tint(.white) } else { Image(systemName: "forward.fill") }
                        }
                        .buttonStyle(IconButtonStyle(size: 38, prominent: true)).instantTip("Cambiar el fondo ahora")
                        .allowsHitTesting(!engine.busy)
                        Button { engine.saveCurrent() } label: { Image(systemName: "arrow.down.to.line") }
                            .buttonStyle(IconButtonStyle(size: 38)).instantTip("Guardar esta foto en Imágenes")
                            .disabled(engine.busy || (engine.current?.url.isFileURL ?? true))
                        Button { Task { await engine.hideCurrent() } } label: { Image(systemName: "hand.thumbsdown") }
                            .buttonStyle(IconButtonStyle(size: 38)).instantTip("No me gusta: que no vuelva a salir")
                            .disabled(engine.busy)
                    }
                    Spacer(minLength: 0)
                    MenuChip(text: Format.interval(engine.state.intervalMinutes)) {
                        ForEach(intervals, id: \.1) { option in
                            DropdownRow(title: option.0, selected: option.1 == engine.state.intervalMinutes) {
                                engine.state.intervalMinutes = option.1
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Canales

    private var channels: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Canales").font(.title3.weight(.semibold))
                Spacer()
                Dropdown {
                    PlusMark().stroke(Color.primary, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: 12, height: 12).frame(width: 34, height: 34).background(Circle().fill(Theme.fill))
                } content: {
                    DropdownRow(title: "Canal de fuentes") { add(combo: false) }
                    DropdownRow(title: "Mezcla de canales") { add(combo: true) }
                }
                .fixedSize()
                .instantTip("Crear un canal nuevo", anchor: .topTrailing)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(engine.state.channels) { channel in
                    ChannelCard(channel: channel, active: channel.id == engine.state.currentChannelID,
                                onSelect: { engine.select(channel: channel.id) }, onEdit: { editing = channel.id })
                }
            }
        }
    }

    private func add(combo: Bool) {
        let channel: Channel
        if combo {
            let base = engine.state.channels.filter { !$0.isCombo }.prefix(2)
            channel = Channel(name: "Nueva mezcla", members: base.map { ChannelMember(channelID: $0.id, weight: 30) }, isCombo: true)
        } else {
            channel = Channel(name: "Nuevo canal", sources: [SourceSpec(kind: .wallhaven, query: "", weight: 30)])
        }
        engine.state.channels.append(channel)
        editing = channel.id
    }
}

/// Tarjeta de un canal: un clic lo activa; el lápiz (al pasar el cursor) lo edita.
private struct ChannelCard: View {
    let channel: Channel
    let active: Bool
    var onSelect: () -> Void
    var onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(channel.name).font(.callout.weight(.semibold)).lineLimit(1)
                    if channel.isCombo { MemberBar(members: channel.members, height: 6) }
                    else { MixBar(sources: channel.sources, height: 6) }
                    Text(channel.isCombo ? "Mezcla de \(channel.members.count) canales"
                         : "\(channel.sources.count) \(channel.sources.count == 1 ? "fuente" : "fuentes")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(active ? Theme.accent.opacity(0.10) : Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(active ? Theme.accent.opacity(0.7) : Theme.stroke, lineWidth: active ? 1.5 : 1))
            }
            .buttonStyle(TileButtonStyle())

            HStack(spacing: 8) {
                if active { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                if hovering {
                    Button(action: onEdit) { Image(systemName: "pencil") }
                        .buttonStyle(IconButtonStyle(size: 26)).instantTip("Editar este canal", anchor: .topTrailing)
                }
            }
            .padding(10)
        }
        .onHover { hovering = $0 }
    }
}

/// Edición de un canal en una hoja aparte: la página principal se queda limpia.
struct ChannelSheet: View {
    let channelID: UUID
    @EnvironmentObject var engine: WallpaperEngine
    @Environment(\.dismiss) private var dismiss

    private var index: Int? { engine.state.channels.firstIndex { $0.id == channelID } }

    var body: some View {
        if let index {
            let channel = $engine.state.channels[index]
            VStack(alignment: .leading, spacing: 24) {
                TextField("Nombre", text: channel.name).textFieldStyle(.plain).font(.system(size: 22, weight: .semibold))

                VStack(alignment: .leading, spacing: 12) {
                    if channel.wrappedValue.isCombo { combo(channel) } else { sources(channel) }
                }

                HStack {
                    Button("Eliminar") { remove() }.buttonStyle(.plain).font(.callout).foregroundStyle(Theme.critical)
                        .disabled(engine.state.channels.count < 2)
                    Spacer()
                    Button("Listo") { dismiss() }.buttonStyle(PillButtonStyle(prominent: true))
                }
            }
            .padding(28)
            .frame(width: 540)
            .toggleStyle(MiniSwitchStyle())
            .tint(Appearance.shared.accent)
            .onAppear { DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) } } // sin el texto seleccionado
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    // MARK: Fuentes de un canal

    private func sources(_ channel: Binding<Channel>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(channel.sources) { $spec in
                block {
                    HStack(spacing: 12) {
                        Circle().fill(Theme.color(for: spec.kind)).frame(width: 8, height: 8)
                        Choice(selection: $spec.kind, options: SourceKind.allCases.map { ($0.label, $0) })
                        Spacer(minLength: 0)
                        LevelControl(weight: $spec.weight)
                        CloseButton { channel.wrappedValue.sources.removeAll { $0.id == spec.id } }
                            .disabled(channel.wrappedValue.sources.count < 2)
                    }
                    if spec.kind.needsQuery {
                        UnderlinedField(placeholder: spec.kind.queryPlaceholder, text: $spec.query)
                            .padding(.leading, 20)
                    }
                }
            }
            Dropdown { AddLabel(text: "Agregar fuente") } content: {
                ForEach(SourceKind.allCases) { kind in
                    DropdownRow(title: kind.label) {
                        withAnimation { channel.wrappedValue.sources.append(SourceSpec(kind: kind, query: "", weight: 30)) }
                    }
                }
            }
            .fixedSize()
            .padding(.top, 4)
        }
    }

    /// Cada fuente o canal va en un bloque suave.
    private func block<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }

    // MARK: Canales de una mezcla

    private func combo(_ channel: Binding<Channel>) -> some View {
        let candidates = engine.state.channels.filter { !$0.isCombo }
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(channel.members.enumerated()), id: \.element.id) { position, $member in
                block {
                    HStack(spacing: 12) {
                        Circle().fill(Theme.palette[position % Theme.palette.count]).frame(width: 8, height: 8)
                        Choice(selection: $member.channelID, options: candidates.map { ($0.name, $0.id) })
                        Spacer(minLength: 0)
                        LevelControl(weight: $member.weight)
                        CloseButton { channel.wrappedValue.members.removeAll { $0.id == member.id } }
                    }
                }
            }
            Dropdown { AddLabel(text: "Agregar canal") } content: {
                ForEach(candidates) { c in
                    DropdownRow(title: c.name) {
                        withAnimation { channel.wrappedValue.members.append(ChannelMember(channelID: c.id, weight: 30)) }
                    }
                }
            }
            .fixedSize()
        }
    }

    private func remove() {
        guard engine.state.channels.count > 1 else { return }
        engine.state.channels.removeAll { $0.id == channelID }
        for i in engine.state.channels.indices { engine.state.channels[i].members.removeAll { $0.channelID == channelID } }
        if engine.state.currentChannelID == channelID { engine.state.currentChannelID = engine.state.channels[0].id }
        dismiss()
    }
}
