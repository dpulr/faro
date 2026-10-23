// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI
import Carbon.HIToolbox

enum EngineError: LocalizedError {
    case noImages
    var errorDescription: String? { "Ninguna fuente del canal devolvió imágenes" }
}

@MainActor
final class WallpaperEngine: ObservableObject {
    @Published var state: AppState { didSet { Persistence.save(state) } }
    @Published var busy = false
    @Published var lastError: String?
    @Published var preview: NSImage?
    @Published var cacheBytes: Int64 = 0
    @Published var notice: String?
    private var noticeTask: Task<Void, Never>?

    private var pools: [UUID: [ImageCandidate]] = [:]
    private var timer: Timer?

    var channel: Channel {
        state.channels.first { $0.id == state.currentChannelID } ?? state.channels[0]
    }

    var current: ImageCandidate? { state.history.first }

    init() {
        state = Persistence.load()
        Cache.prune(keeping: Array(state.currentFiles.values))
        refreshCacheSize()
        loadPreview()
        reapplyCurrentWallpapers()
        registerHotkeys()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = 10
        tick()
        if ProcessInfo.processInfo.environment["FARO_SELFTEST"] != nil { Task { await selfTest() } }
    }

    /// Cambia el fondo varias veces e imprime el resultado; sirve para verificar fuentes y caché.
    private func selfTest() async {
        for _ in 0..<8 {
            while busy { try? await Task.sleep(nanoseconds: 300_000_000) }
            await next()
            let files = (try? FileManager.default.contentsOfDirectory(atPath: Paths.cache.path))?.count ?? 0
            let c = current
            print("\(c?.source.rawValue ?? "-") | \(c?.title.prefix(40) ?? "-") | \(c?.width ?? 0)x\(c?.height ?? 0)"
                  + " | cache: \(files) archivo(s), \(Format.bytes(Cache.size()))"
                  + (lastError.map { " | ERROR: \($0)" } ?? ""))
        }
        exit(0)
    }

    // MARK: Acciones

    /// Muestra una confirmación corta y la quita sola.
    func flash(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { notice = text }
        noticeTask?.cancel()
        noticeTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.2)) { notice = nil } }
        }
    }

    func next() async {
        guard !busy else { return }
        busy = true
        defer { busy = false; refreshCacheSize() }
        var failure: Error?
        for _ in 0..<3 {
            do {
                let screens = NSScreen.screens
                let count = state.differentPerScreen ? max(screens.count, 1) : 1
                var picks: [ImageCandidate] = []
                for _ in 0..<count { picks.append(try await pick()) }
                try await apply(picks, to: screens)
                push(picks[0])
                lastError = nil
                return
            } catch {
                failure = error
            }
        }
        lastError = failure?.localizedDescription
    }

    func previous() async {
        guard !busy, state.history.count > 1 else { return }
        busy = true
        defer { busy = false; refreshCacheSize() }
        do {
            try await apply([state.history[1]], to: NSScreen.screens)
            state.history.removeFirst()
            state.lastChange = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func hideCurrent() async {
        if let c = current { state.hidden.insert(c.id) }
        flash("Listo: esa foto no volverá a salir")
        await next()
    }

    func saveCurrent() {
        guard let c = current, let main = NSScreen.main,
              let path = state.currentFiles[main.displayKey] else { return }
        let src = URL(fileURLWithPath: path)
        guard !c.url.isFileURL else { return } // ya es un archivo tuyo
        try? FileManager.default.createDirectory(at: Paths.saved, withIntermediateDirectories: true)
        let name = c.title.replacingOccurrences(of: "[^A-Za-z0-9 _-]", with: "", options: .regularExpression)
            .prefix(60)
        let dest = Paths.saved.appendingPathComponent("\(c.source.rawValue)-\(name)-\(Int(Date().timeIntervalSince1970)).jpg")
        try? FileManager.default.copyItem(at: src, to: dest)
        flash("Guardada en Imágenes/faro")
        NSWorkspace.shared.activateFileViewerSelecting([dest])
    }

    func select(channel id: UUID) {
        state.currentChannelID = id
        if let name = state.channels.first(where: { $0.id == id })?.name { flash("Canal activo: \(name)") }
        pools.removeAll()
        Task { await next() }
    }

    func channelsEdited() { pools.removeAll() }

    func clearCache() {
        Cache.prune(keeping: Array(state.currentFiles.values))
        refreshCacheSize()
    }

    // MARK: Selección

    private func pick() async throws -> ImageCandidate {
        var specs = effectiveSources(of: channel).filter { $0.weight > 0 && ($0.kind == .bing || !$0.query.isEmpty) }
        var lastError: Error?
        while !specs.isEmpty {
            let spec = weighted(specs)
            if pools[spec.id, default: []].isEmpty {
                do { pools[spec.id] = try await fetch(spec) } catch { lastError = error }
            }
            if var pool = pools[spec.id], let candidate = pool.popLast() {
                pools[spec.id] = pool
                return candidate
            }
            specs.removeAll { $0.id == spec.id }
        }
        throw lastError ?? EngineError.noImages
    }

    /// Una mezcla se reduce a las fuentes de sus canales, con el peso de cada una repartido según el del canal.
    private func effectiveSources(of channel: Channel) -> [SourceSpec] {
        guard channel.isCombo else { return channel.sources }
        var result: [SourceSpec] = []
        for member in channel.members where member.weight > 0 {
            guard let sub = state.channels.first(where: { $0.id == member.channelID && !$0.isCombo }) else { continue }
            let active = sub.sources.filter { $0.weight > 0 }
            let total = active.reduce(0) { $0 + $1.weight }
            guard total > 0 else { continue }
            for var spec in active {
                spec.weight = max(member.weight * spec.weight * 100 / total, 1)
                result.append(spec)
            }
        }
        return result
    }

    private func weighted(_ specs: [SourceSpec]) -> SourceSpec {
        var roll = Int.random(in: 0..<specs.reduce(0) { $0 + $1.weight })
        for s in specs {
            if roll < s.weight { return s }
            roll -= s.weight
        }
        return specs[0]
    }

    private func fetch(_ spec: SourceSpec) async throws -> [ImageCandidate] {
        let filter = currentFilter()
        let recent = Set(state.history.map(\.id))
        return try await Sources.make(spec.kind).candidates(query: spec.query, filter: filter)
            .filter { !state.hidden.contains($0.id) && !recent.contains($0.id) && filter.accepts($0) }
    }

    private func currentFilter() -> ImageFilter {
        let px = NSScreen.main.map { Int($0.frame.width * $0.backingScaleFactor) } ?? 2560
        let py = NSScreen.main.map { Int($0.frame.height * $0.backingScaleFactor) } ?? 1440
        return ImageFilter(minWidth: Int(Double(px) * state.minResolution),
                           minHeight: Int(Double(py) * state.minResolution),
                           targetWidth: px)
    }

    // MARK: Aplicar

    private func apply(_ picks: [ImageCandidate], to screens: [NSScreen]) async throws {
        var downloads: [String: URL] = [:]
        defer { downloads.values.forEach { try? FileManager.default.removeItem(at: $0) } }

        for (i, screen) in screens.enumerated() {
            let c = picks[min(i, picks.count - 1)]
            let file: URL
            if c.url.isFileURL {
                file = c.url
            } else {
                if downloads[c.id] == nil { downloads[c.id] = try await Net.download(c.url) }
                file = try Imaging.prepare(downloads[c.id]!, maxPixel: screen.maxPixel)
            }
            try NSWorkspace.shared.setDesktopImageURL(file, for: screen, options: [
                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                .allowClipping: true,
            ])
            let old = state.currentFiles[screen.displayKey]
            state.currentFiles[screen.displayKey] = file.path
            if let old, old != file.path, old.hasPrefix(Paths.cache.path) {
                try? FileManager.default.removeItem(atPath: old)
            }
            if screen == NSScreen.main || i == 0 { preview = Imaging.thumbnail(of: file) }
        }
        // Un monitor desconectado no debe dejar archivos en la caché.
        let active = Set(screens.map(\.displayKey))
        for (key, path) in state.currentFiles where !active.contains(key) {
            if path.hasPrefix(Paths.cache.path) { try? FileManager.default.removeItem(atPath: path) }
            state.currentFiles[key] = nil
        }
    }

    private func push(_ c: ImageCandidate) {
        state.history.insert(c, at: 0)
        if state.history.count > 50 { state.history.removeLast(state.history.count - 50) }
        state.lastChange = Date()
    }

    // MARK: Utilidades

    private func tick() {
        guard state.intervalMinutes > 0, !busy else { return }
        if Date().timeIntervalSince(state.lastChange) >= Double(state.intervalMinutes) * 60 {
            Task { await next() }
        }
    }

    func refreshCacheSize() { cacheBytes = Cache.size() }

    /// Al arrancar vuelve a poner la foto actual: si la carpeta de la caché cambió de lugar (p. ej. al renombrar la app),
    /// macOS seguiría apuntando a la ruta vieja y el escritorio se quedaría sin imagen.
    private func reapplyCurrentWallpapers() {
        for screen in NSScreen.screens {
            guard let path = state.currentFiles[screen.displayKey], path.hasPrefix(Paths.cache.path),
                  FileManager.default.fileExists(atPath: path) else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [
                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                .allowClipping: true,
            ])
        }
    }

    private func loadPreview() {
        if let main = NSScreen.main, let path = state.currentFiles[main.displayKey] {
            preview = Imaging.thumbnail(of: URL(fileURLWithPath: path))
        }
    }

    private func registerHotkeys() {
        let mods = cmdKey | optionKey | controlKey
        let hk = Hotkeys.shared
        hk.register(keyCode: kVK_RightArrow, modifiers: mods) { [weak self] in Task { await self?.next() } }
        hk.register(keyCode: kVK_LeftArrow, modifiers: mods) { [weak self] in Task { await self?.previous() } }
        hk.register(keyCode: kVK_ANSI_H, modifiers: mods) { [weak self] in Task { await self?.hideCurrent() } }
        hk.register(keyCode: kVK_ANSI_S, modifiers: mods) { [weak self] in self?.saveCurrent() }
    }
}
