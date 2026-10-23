// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI
import Carbon.HIToolbox

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Panel que aparece junto al cursor con ⌃⌥⌘V. No activa faro, así la app donde estabas sigue al frente y el pegado llega ahí.
@MainActor
final class ClipboardPanelController {
    static let shared = ClipboardPanelController()

    private var panel: FloatingPanel?
    private var store: ClipboardStore?
    private var resignObserver: NSObjectProtocol?
    private var installed = false

    func install(store: ClipboardStore) {
        self.store = store
        guard !installed else { return }
        installed = true
        Hotkeys.shared.register(keyCode: kVK_ANSI_V, modifiers: cmdKey | optionKey | controlKey) { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
    }

    func toggle() {
        if panel?.isVisible == true { close() } else { show() }
    }

    func show() {
        guard let store else { return }
        close()
        let size = CGSize(width: 400, height: 500)
        let p = FloatingPanel(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                              backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.hasShadow = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: ClipboardPanelView(
            store: store,
            onPaste: { [weak self] entry in self?.paste(entry) },
            onClose: { [weak self] in self?.close() }))
        p.setFrameOrigin(origin(for: size))
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: p, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
        panel = p
        p.makeKeyAndOrderFront(nil)
    }

    func close() {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func origin(for size: CGSize) -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let x = min(max(mouse.x - size.width / 2, area.minX + 8), area.maxX - size.width - 8)
        let y = min(max(mouse.y - size.height - 12, area.minY + 8), area.maxY - size.height - 8)
        return CGPoint(x: x, y: y)
    }

    private func paste(_ entry: ClipEntry) {
        close()
        guard let store else { return }
        store.copyBack(entry)
        guard store.settings.autoPaste else { return }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return } // queda copiado: se pega con ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { Self.sendPaste() }
    }

    private static func sendPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: down)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}

struct ClipboardPanelView: View {
    @ObservedObject var store: ClipboardStore
    var onPaste: (ClipEntry) -> Void
    var onClose: () -> Void

    @State private var query = ""
    @State private var selection: UUID?
    @FocusState private var searching: Bool

    private var results: [ClipEntry] { store.search(query) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar en el portapapeles", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 15))
                    .focused($searching)
                    .onSubmit { pasteSelected() }
                if store.settings.paused {
                    Text("En pausa").font(.caption2.weight(.semibold)).foregroundStyle(Theme.warning)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.warning.opacity(0.15)))
                }
            }
            .padding(14)
            Divider()
            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 28)).foregroundStyle(.tertiary)
                    Text(query.isEmpty ? "Todavía no has copiado nada" : "Sin resultados").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(results.prefix(150)) { entry in row(entry).id(entry.id) }
                        }
                        .padding(8)
                    }
                    .onChange(of: selection) { if let id = selection { proxy.scrollTo(id) } }
                }
            }
            Divider()
            HStack(spacing: 14) {
                hint("↑↓", "elegir"); hint("↵", "pegar"); hint("esc", "cerrar")
                Spacer()
                Text("\(store.entries.count) guardados").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .frame(width: 400, height: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.stroke))
        .onAppear { searching = true; selection = results.first?.id }
        .onChange(of: query) { selection = results.first?.id }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onExitCommand { onClose() }
    }

    private func row(_ entry: ClipEntry) -> some View {
        HStack(spacing: 10) {
            if entry.kind == .image {
                Group {
                    if let image = store.image(for: entry) {
                        Image(nsImage: image).resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Theme.fill)
                    }
                }
                .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "text.alignleft").foregroundStyle(.secondary).frame(width: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind == .image ? "Imagen \(entry.width)×\(entry.height)" : entry.preview)
                    .font(.callout).lineLimit(2)
                Text([entry.app, Format.relative(entry.date)].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if entry.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(Theme.accent) }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(selection == entry.id ? Theme.accent.opacity(0.2) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { onPaste(entry) }
        .onHover { if $0 { selection = entry.id } }
        .contextMenu {
            Button(entry.pinned ? "Quitar fijado" : "Fijar arriba") { store.togglePin(entry.id) }
            Button("Eliminar", role: .destructive) { store.delete(entry.id) }
        }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key).font(.caption2.weight(.semibold).monospaced())
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.fill))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selection } ?? (delta > 0 ? -1 : results.count)
        selection = results[min(max(current + delta, 0), results.count - 1)].id
    }

    private func pasteSelected() {
        if let entry = results.first(where: { $0.id == selection }) ?? results.first { onPaste(entry) }
    }
}
