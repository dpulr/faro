// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI
import UniformTypeIdentifiers

struct PortapapelesPage: View {
    @EnvironmentObject var store: ClipboardStore
    @State private var query = ""
    @State private var confirmClear = false
    @State private var trusted = AXIsProcessTrusted()

    private let retentions: [(String, Int)] = [("24 horas", 1), ("7 días", 7), ("30 días", 30), ("Sin límite", 0)]
    private let limits = [100, 300, 1000]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Portapapeles",
                       subtitle: "Todo lo que copias queda guardado para que no se pierda.")
            status
            settingsCard
            excludedCard
            history
        }
    }

    // MARK: Estado

    private var status: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: store.settings.paused ? "pause.circle" : "doc.on.clipboard")
                    .font(.system(size: 22)).foregroundStyle(store.settings.paused ? Theme.warning : Theme.accent)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill((store.settings.paused ? Theme.warning : Theme.accent).opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.settings.paused ? "Guardado en pausa" : "Guardando tu portapapeles")
                        .font(.title3.weight(.semibold))
                    Text("\(store.entries.count) elementos · abre el historial en cualquier momento con ⌃⌥⌘V")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(store.settings.paused ? "Reanudar" : "Pausar") { store.settings.paused.toggle() }
                    .buttonStyle(PillButtonStyle())
                Button { ClipboardPanelController.shared.show() } label: { Text("Abrir historial") }
                    .buttonStyle(PillButtonStyle(prominent: true))
            }
        }
    }

    // MARK: Ajustes

    private var settingsCard: some View {
        Card(padding: 4) {
            VStack(spacing: 0) {
                row("Conservar el historial", "Lo más viejo se borra solo. Lo que fijes nunca se borra.") {
                    Choice(selection: $store.settings.retentionDays, options: retentions)
                }
                Divider().padding(.horizontal, 12)
                row("Máximo de elementos", "Cuando se llena, salen los más antiguos.") {
                    Choice(selection: $store.settings.maxItems, options: limits.map { ("\($0)", $0) })
                }
                Divider().padding(.horizontal, 12)
                row("Guardar imágenes", "Capturas de pantalla y fotos que copies.") {
                    Toggle("", isOn: $store.settings.saveImages).toggleStyle(MiniSwitchStyle()).labelsHidden()
                }
                Divider().padding(.horizontal, 12)
                row("Pegar automáticamente", trusted
                    ? "Al elegir un elemento, faro lo pega por ti."
                    : "Necesita el permiso de Accesibilidad; sin él solo se copia y pegas tú con ⌘V.") {
                    HStack(spacing: 10) {
                        if !trusted {
                            Button("Dar permiso") {
                                _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { trusted = AXIsProcessTrusted() }
                            }
                            .buttonStyle(PillButtonStyle())
                        }
                        Toggle("", isOn: $store.settings.autoPaste).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                }
            }
        }
    }

    private var excludedCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apps que nunca se guardan").font(.callout.weight(.semibold))
                        Text("Lo que copies desde ellas se ignora. faro también ignora lo que los gestores de contraseñas marcan como secreto.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Agregar app…") { addExcluded() }.buttonStyle(PillButtonStyle())
                }
                FlowRow(items: store.settings.excludedBundles) { id in
                    HStack(spacing: 6) {
                        Text(displayName(id)).font(.caption)
                        Button { store.settings.excludedBundles.removeAll { $0 == id } } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Theme.fill))
                }
            }
        }
    }

    // MARK: Historial

    private var history: some View {
        let results = store.search(query)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historial").font(.title3.weight(.semibold))
                Spacer()
                TextField("Buscar", text: $query).textFieldStyle(.roundedBorder).frame(width: 220)
                Button("Borrar todo") { confirmClear = true }
                    .buttonStyle(PillButtonStyle()).disabled(store.entries.isEmpty)
            }
            if results.isEmpty {
                Text(query.isEmpty ? "Cuando copies algo, aparecerá aquí." : "Sin resultados.").foregroundStyle(.secondary)
            } else {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(results.prefix(80).enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Divider() }
                            entryRow(entry)
                        }
                    }
                }
            }
        }
        .confirmationDialog("¿Borrar el historial?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Borrar todo menos lo fijado", role: .destructive) { store.clear(keepPinned: true) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borran \(store.entries.filter { !$0.pinned }.count) elementos. No se puede deshacer.")
        }
    }

    private func entryRow(_ entry: ClipEntry) -> some View {
        HStack(spacing: 12) {
            if entry.kind == .image, let image = store.image(for: entry) {
                Image(nsImage: image).resizable().scaledToFill()
                    .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: entry.kind == .image ? "photo" : "text.alignleft")
                    .foregroundStyle(.secondary).frame(width: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind == .image ? "Imagen \(entry.width)×\(entry.height)" : entry.preview)
                    .font(.callout).lineLimit(2)
                Text([entry.app, Format.relative(entry.date)].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button { store.copyBack(entry) } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(IconButtonStyle()).instantTip("Copiar otra vez")
            Button { store.togglePin(entry.id) } label: { Image(systemName: entry.pinned ? "pin.slash" : "pin") }
                .buttonStyle(IconButtonStyle()).instantTip(entry.pinned ? "Quitar fijado" : "Fijar arriba")
            Button { store.delete(entry.id) } label: { Image(systemName: "trash") }
                .buttonStyle(IconButtonStyle()).instantTip("Eliminar", anchor: .topTrailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    // MARK: Utilidades

    private func row<Control: View>(_ title: String, _ detail: String,
                                    @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(12)
    }

    private static let knownNames = [
        "com.1password": "1Password", "com.agilebits": "1Password (clásico)", "com.bitwarden": "Bitwarden",
        "com.apple.keychainaccess": "Acceso a Llaveros", "com.apple.Passwords": "Contraseñas",
        "org.keepassxc": "KeePassXC", "com.lastpass": "LastPass", "com.dashlane": "Dashlane",
    ]

    private func displayName(_ bundlePrefix: String) -> String {
        if let known = Self.knownNames[bundlePrefix] { return known }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundlePrefix) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundlePrefix
    }

    private func addExcluded() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Elige la app cuyas copias no quieres guardar"
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier,
              !store.settings.excludedBundles.contains(id) else { return }
        store.settings.excludedBundles.append(id)
    }
}

/// Acomoda elementos de ancho variable en filas que se parten solas.
struct FlowRow<Item: Hashable, Content: View>: View {
    var items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: 8) { ForEach(items, id: \.self) { content($0) } }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 600, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placement = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in placement.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
