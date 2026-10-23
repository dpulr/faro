// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit

struct ShelfItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var path: String
    var bookmark: Data?
    var added: Date

    var name: String { URL(fileURLWithPath: path).lastPathComponent }
}

/// Bandeja de archivos: guarda referencias (no copias) a lo que sueltas, así no gasta espacio.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    private let file: URL?
    private var icons: [String: NSImage] = [:]

    private struct Stored: Codable { var items: [ShelfItem] }

    /// `file == nil` mantiene todo en memoria (vistas previas y pruebas).
    init(file: URL? = nil, registerShortcut: Bool = false) {
        self.file = file
        load()
        if registerShortcut { ShelfPanelController.shared.install(store: self) }
    }

    // MARK: Acciones

    func add(_ urls: [URL]) {
        var changed = false
        for url in urls where url.isFileURL {
            let path = url.standardizedFileURL.path
            guard !items.contains(where: { $0.path == path }) else { continue }
            items.insert(ShelfItem(path: path, bookmark: try? url.bookmarkData(), added: Date()), at: 0)
            changed = true
        }
        if changed { save() }
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clear() {
        items = []
        icons = [:]
        save()
    }

    /// La ruta guardada, o la que dice el marcador si el archivo se movió.
    func resolve(_ item: ShelfItem) -> URL? {
        if FileManager.default.fileExists(atPath: item.path) { return URL(fileURLWithPath: item.path) }
        guard let data = item.bookmark else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        else { return nil }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].path = url.path
            save()
        }
        return url
    }

    func exists(_ item: ShelfItem) -> Bool { resolve(item) != nil }

    func icon(for item: ShelfItem) -> NSImage {
        if let cached = icons[item.path] { return cached }
        let url = URL(fileURLWithPath: item.path)
        let imageTypes: Set<String> = ["jpg", "jpeg", "png", "heic", "gif", "tiff", "webp"]
        let image = imageTypes.contains(url.pathExtension.lowercased())
            ? (Imaging.thumbnail(of: url, maxPixel: 160) ?? NSWorkspace.shared.icon(forFile: item.path))
            : NSWorkspace.shared.icon(forFile: item.path)
        icons[item.path] = image
        return image
    }

    func airDrop(_ targets: [ShelfItem]) {
        let urls = targets.compactMap(resolve)
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: urls)
    }

    func reveal(_ item: ShelfItem) {
        if let url = resolve(item) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    // MARK: Disco

    private func load() {
        guard let file else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: file), let stored = try? decoder.decode(Stored.self, from: data) else { return }
        items = stored.items
    }

    private func save() {
        guard let file else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(Stored(items: items)) { try? data.write(to: file, options: .atomic) }
    }
}
