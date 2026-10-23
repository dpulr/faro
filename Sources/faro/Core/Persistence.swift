// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Todo lo que la app escribe en disco vive aquí. Las cachés van en ~/Library/Caches
/// (macOS puede vaciarlas) y solo lo que el usuario guarda va a ~/Pictures/faro.
enum Paths {
    /// El proyecto se llamó Tapiz y luego Mirador: mueve sus datos y su caché a la carpeta de faro (una sola vez).
    private static func migrate(_ dir: FileManager.SearchPathDirectory) {
        let base = FileManager.default.urls(for: dir, in: .userDomainMask)[0]
        let new = base.appendingPathComponent("faro")
        guard !FileManager.default.fileExists(atPath: new.path) else { return }
        for legacy in ["Mirador", "Tapiz"] {
            let old = base.appendingPathComponent(legacy)
            if FileManager.default.fileExists(atPath: old.path) {
                try? FileManager.default.moveItem(at: old, to: new)
                return
            }
        }
    }

    static let support: URL = {
        migrate(.applicationSupportDirectory)
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("faro", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Se vuelve a crear en cada acceso: si algo la borra con la app abierta, no se rompe el cambio de fondo.
    static var cache: URL {
        migrate(.cachesDirectory)
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("faro/current", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static let saved: URL = {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("faro", isDirectory: true)
    }()

    static var stateFile: URL { support.appendingPathComponent("state.json") }
}

enum Persistence {
    static func load() -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // debe coincidir con `save`, o el estado nunca se lee
        guard let data = try? Data(contentsOf: Paths.stateFile),
              var state = try? decoder.decode(AppState.self, from: data),
              state.channels.contains(where: { $0.id == state.currentChannelID })
        else { return .makeDefault() }
        state.currentFiles = state.currentFiles.mapValues {
            $0.replacingOccurrences(of: "/Caches/Tapiz/", with: "/Caches/faro/")
                .replacingOccurrences(of: "/Caches/Mirador/", with: "/Caches/faro/")
        }
        state.seedCatalogIfNeeded()
        state.seedProfilesIfNeeded()
        return state
    }

    static func save(_ state: AppState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: Paths.stateFile, options: .atomic)
    }
}

enum Cache {
    /// Borra de la caché todo lo que no sea un fondo en uso.
    static func prune(keeping files: [String]) {
        let keep = Set(files)
        let items = (try? FileManager.default.contentsOfDirectory(at: Paths.cache, includingPropertiesForKeys: nil)) ?? []
        for item in items where !keep.contains(item.path) {
            try? FileManager.default.removeItem(at: item)
        }
    }

    static func size() -> Int64 {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: Paths.cache, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return items.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
}
