// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI
import Carbon.HIToolbox
import UniformTypeIdentifiers

/// Panel flotante de la bandeja (⌃⌥⌘B). No se cierra al perder el foco, para poder arrastrar hacia otras apps.
@MainActor
final class ShelfPanelController {
    static let shared = ShelfPanelController()

    private var panel: FloatingPanel?
    private var store: ShelfStore?
    private var installed = false

    var window: NSWindow? { panel }

    func install(store: ShelfStore) {
        self.store = store
        guard !installed else { return }
        installed = true
        Hotkeys.shared.register(keyCode: kVK_ANSI_B, modifiers: cmdKey | optionKey | controlKey) { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
    }

    func toggle() {
        if panel?.isVisible == true { close() } else { show() }
    }

    func show(store override: ShelfStore? = nil) {
        guard let store = override ?? store else { return }
        if let panel, panel.isVisible { panel.makeKeyAndOrderFront(nil); return }
        let host = NSHostingView(rootView: ShelfPanelView(store: store, onClose: { [weak self] in self?.close() })
            .environmentObject(Appearance.shared).tint(Appearance.shared.accent))
        host.wantsLayer = true
        host.layer?.cornerRadius = 28
        host.layer?.cornerCurve = .continuous
        host.layer?.masksToBounds = true
        let size = host.fittingSize
        let p = FloatingPanel(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.hasShadow = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = host
        if !p.setFrameUsingName("FaroShelf") {
            let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            p.setFrameOrigin(CGPoint(x: area.maxX - size.width - 16, y: area.midY - size.height / 2))
        }
        p.setFrameAutosaveName("FaroShelf")
        panel = p
        p.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { p.invalidateShadow() }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

/// Lee las rutas de lo soltado. `loadItem` sobre `public.file-url` funciona con cualquier tipo de archivo (PDF, imágenes, carpetas…).
enum ShelfDrop {
    static func load(_ providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
        let type = UTType.fileURL.identifier
        let group = DispatchGroup()
        let lock = NSLock()
        var found: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(type) {
            group.enter()
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let u = item as? URL { url = u }
                else if let ns = item as? NSURL { url = ns as URL }
                if let url { lock.lock(); found.append(url); lock.unlock() }
                group.leave()
            }
        }
        group.notify(queue: .main) { Task { @MainActor in completion(found) } }
    }
}

struct ShelfPanelView: View {
    @ObservedObject var store: ShelfStore
    var onClose: () -> Void

    @State private var targeted = false
    @State private var confirmClear = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        VStack(spacing: 10) {
            header
            ZStack {
                if store.items.isEmpty { emptyState } else { grid }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(targeted ? Theme.accent : Theme.stroke, lineWidth: targeted ? 2 : 1))
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                ShelfDrop.load(providers) { urls in store.add(urls) }
                return !providers.isEmpty
            }
        }
        .padding(14)
        .frame(width: 380, height: 330)
        .glassSurface(radius: 28)
        .onExitCommand { onClose() }
        .animation(.easeOut(duration: 0.15), value: targeted)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.full.fill").foregroundStyle(Theme.accent)
            Text("Bandeja").font(.system(size: 16, weight: .semibold))
            if !store.items.isEmpty {
                Text("\(store.items.count)").font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.fill))
            }
            Spacer()
            Button { store.airDrop(store.items) } label: { Image(systemName: "square.and.arrow.up") }
                .buttonStyle(IconButtonStyle(size: 30)).instantTip("Enviar todo por AirDrop", anchor: .bottom)
                .disabled(store.items.isEmpty)
            Button { confirmClear = true } label: { Image(systemName: "trash") }
                .buttonStyle(IconButtonStyle(size: 30)).instantTip("Vaciar la bandeja (los archivos no se borran)", anchor: .bottom)
                .disabled(store.items.isEmpty)
            Button(action: onClose) { Image(systemName: "xmark") }
                .buttonStyle(IconButtonStyle(size: 30)).instantTip("Cerrar", anchor: .bottomTrailing)
        }
        .confirmationDialog("¿Vaciar la bandeja?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Vaciar", role: .destructive) { store.clear() }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Solo se quitan de la bandeja. Los archivos originales no se tocan.") }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: targeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                .font(.system(size: 32, weight: .light)).foregroundStyle(targeted ? Theme.accent : Color.secondary)
            Text("Suelta archivos aquí").font(.callout.weight(.medium))
            Text("Llévalos de una app a otra. También puedes soltarlos sobre el ícono de faro.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.items) { item in ShelfTile(store: store, item: item) }
            }
            .padding(10)
        }
    }
}

private struct ShelfTile: View {
    @ObservedObject var store: ShelfStore
    let item: ShelfItem
    @State private var hovering = false

    var body: some View {
        let available = store.exists(item)
        VStack(spacing: 6) {
            Image(nsImage: store.icon(for: item))
                .resizable().scaledToFit().frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .opacity(available ? 1 : 0.35)
            Text(item.name).font(.caption).lineLimit(2).multilineTextAlignment(.center)
            if !available { Text("No disponible").font(.caption2).foregroundStyle(Theme.warning) }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(hovering ? Theme.fill : Color.clear))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { store.remove(item.id) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).padding(4).instantTip("Quitar de la bandeja", anchor: .topTrailing)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { if let url = store.resolve(item) { NSWorkspace.shared.open(url) } }
        .onDrag { dragProvider() }
        .contextMenu {
            Button("Abrir") { if let url = store.resolve(item) { NSWorkspace.shared.open(url) } }
            Button("Mostrar en Finder") { store.reveal(item) }
            Button("Enviar por AirDrop") { store.airDrop([item]) }
            Divider()
            if let url = store.resolve(item) {
                if ShelfTools.isImage(url) {
                    Menu("Convertir imagen a") {
                        ForEach(ShelfTools.ImageFormat.allCases, id: \.self) { format in
                            Button(format.label) { store.convert(item, to: format) }
                        }
                    }
                }
                if ShelfTools.isArchive(url) {
                    Button("Descomprimir") { store.unzip(item) }
                } else {
                    Button("Comprimir en zip") { store.zip([item]) }
                }
                if store.items.count > 1 { Button("Comprimir toda la bandeja en zip") { store.zip(store.items) } }
                Divider()
            }
            Button("Quitar de la bandeja") { store.remove(item.id) }
        }
    }

    private func dragProvider() -> NSItemProvider {
        guard let url = store.resolve(item), let provider = NSItemProvider(contentsOf: url) else { return NSItemProvider() }
        provider.suggestedName = url.lastPathComponent
        return provider
    }
}

/// Vista transparente sobre el ícono de la barra: recibe archivos soltados y deja pasar los clics.
final class StatusDropView: NSView {
    var onDrop: (([URL]) -> Void)?
    var onClick: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }

    override func mouseUp(with event: NSEvent) { onClick?() }
}
