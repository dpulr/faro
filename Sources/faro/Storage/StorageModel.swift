// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

struct FolderEntry: Identifiable {
    var url: URL
    var bytes: Int64
    var isDirectory: Bool
    var id: String { url.path }
}

enum CheckState { case none, some, all }

@MainActor
final class StorageModel: ObservableObject {
    @Published var categories = CleanupCatalog.specs.map { CleanCategory(spec: $0) }
    @Published var selected: Set<String> = []
    @Published var scanning = false
    @Published var working = false
    @Published var simulatorBytes: Int64?
    @Published var trashedBytes: Int64 = 0
    @Published var message: String?
    @Published var didScan = false

    @Published var largeFiles: [CleanItem] = []
    @Published var scanningLarge = false
    @Published var largeScanned = false

    @Published var path = DiskTools.home
    @Published var folderEntries: [FolderEntry] = []
    @Published var folderTotal: Int64 = 0
    @Published var browsing = false
    @Published var folderLoaded = false
    private var folderCache: [String: ([FolderEntry], Int64)] = [:]
    private var folderGeneration = 0

    var selectedBytes: Int64 {
        categories.flatMap(\.items).filter { selected.contains($0.id) }.reduce(0) { $0 + $1.bytes }
    }

    var selectedCount: Int { categories.flatMap(\.items).filter { selected.contains($0.id) }.count }

    // MARK: Limpieza

    func scan() async {
        guard !scanning else { return }
        scanning = true
        didScan = true
        defer { scanning = false }
        for index in categories.indices {
            let spec = categories[index].spec
            let items = await Task.detached { CleanupCatalog.discover(spec) }.value
            categories[index].items = items
            categories[index].scanned = true
            preselect(index)
        }
        simulatorBytes = await Task.detached {
            DiskTools.size(of: DiskTools.home.appendingPathComponent("Library/Developer/CoreSimulator"))
        }.value
    }

    private func preselect(_ index: Int) {
        let category = categories[index]
        category.items.forEach { selected.remove($0.id) }
        guard category.spec.preselect else { return }
        let ordered = category.items.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
        ordered.dropFirst(category.spec.keepNewest).forEach { selected.insert($0.id) }
    }

    func state(of category: CleanCategory) -> CheckState {
        let count = category.items.filter { selected.contains($0.id) }.count
        return count == 0 ? .none : count == category.items.count ? .all : .some
    }

    func toggle(category: CleanCategory) {
        let on = state(of: category) != .all
        category.items.forEach { if on { selected.insert($0.id) } else { selected.remove($0.id) } }
    }

    func toggle(item: CleanItem) {
        if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
    }

    func cleanSelected(mode: DeleteMode) async {
        let items = categories.flatMap(\.items).filter { selected.contains($0.id) }
        guard !items.isEmpty, !working else { return }
        working = true
        defer { working = false }
        let urls = items.map(\.url)
        let done = Set(await Task.detached { Cleaner.remove(urls, mode: mode, kind: .catalogItem) }.value.map(\.path))
        let freed = items.filter { done.contains($0.id) }.reduce(0) { $0 + $1.bytes }
        for index in categories.indices { categories[index].items.removeAll { done.contains($0.id) } }
        done.forEach { selected.remove($0) }
        folderCache.removeAll()
        if mode == .trash {
            trashedBytes += freed
            message = String(format: tr("Se movieron %@ a la Papelera. Vacíala para recuperar el espacio."), Format.bytes(freed))
        } else {
            message = String(format: tr("Se liberaron %@."), Format.bytes(freed))
        }
        if done.count < items.count { message! += " " + String(format: tr("%lld elementos no se pudieron quitar."), items.count - done.count) }
    }

    func emptyTrash() async {
        working = true
        defer { working = false }
        _ = await Task.detached {
            DiskTools.run("/usr/bin/osascript", ["-e", "tell application \"Finder\" to empty trash"])
        }.value
        message = "Papelera vaciada\(trashedBytes > 0 ? ": se liberaron \(Format.bytes(trashedBytes))" : "")."
        trashedBytes = 0
    }

    func removeUnavailableSimulators() async {
        working = true
        defer { working = false }
        let before = simulatorBytes ?? 0
        _ = await Task.detached { DiskTools.run("/usr/bin/xcrun", ["simctl", "delete", "unavailable"]) }.value
        let after = await Task.detached {
            DiskTools.size(of: DiskTools.home.appendingPathComponent("Library/Developer/CoreSimulator"))
        }.value
        simulatorBytes = after
        message = after < before ? String(format: tr("Se liberaron %@ de simuladores."), Format.bytes(before - after)) : tr("No había simuladores sin usar.")
    }

    // MARK: Archivos grandes

    func scanLarge() async {
        guard !scanningLarge else { return }
        scanningLarge = true
        defer { scanningLarge = false }
        largeFiles = await Task.detached { DiskTools.largeFiles(minMB: 300) }.value
        largeScanned = true
    }

    func trashLarge(_ item: CleanItem) async {
        let done = await Task.detached { Cleaner.remove([item.url], mode: .trash, kind: .userFile) }.value
        guard !done.isEmpty else { message = String(format: tr("No se pudo mover %@ a la Papelera."), item.name); return }
        largeFiles.removeAll { $0.id == item.id }
        trashedBytes += item.bytes
        folderCache.removeAll()
        message = String(format: tr("%@ está en la Papelera. Vacíala para recuperar %@."), item.name, Format.bytes(item.bytes))
    }

    // MARK: Carpetas

    func openFolder(_ url: URL) async {
        folderGeneration += 1
        let generation = folderGeneration
        path = url
        folderLoaded = true
        browsing = true
        let result: ([FolderEntry], Int64)
        if let cached = folderCache[url.path] {
            result = cached
        } else {
            result = await Task.detached {
                let listing = DiskTools.childSizes(of: url)
                let entries = listing.children.filter { $0.bytes > 0 }.map {
                    FolderEntry(url: $0.url, bytes: $0.bytes,
                                isDirectory: (try? $0.url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
                }
                return (entries, listing.total)
            }.value
            folderCache[url.path] = result
        }
        guard generation == folderGeneration else { return }
        folderEntries = result.0
        folderTotal = result.1
        browsing = false
    }

    func goUp() async {
        guard path.path != DiskTools.home.path else { return }
        await openFolder(path.deletingLastPathComponent())
    }
}
