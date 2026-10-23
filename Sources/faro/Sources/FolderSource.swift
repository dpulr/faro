// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Imágenes de una carpeta local. Se usan en su sitio: no se copian a la caché.
struct FolderSource: ImageSource {
    private static let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "webp", "tiff"]

    func candidates(query: String, filter: ImageFilter) async throws -> [ImageCandidate] {
        try Self.scan(query)
    }

    private static func scan(_ query: String) throws -> [ImageCandidate] {
        let root = URL(fileURLWithPath: (query as NSString).expandingTildeInPath)
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            throw URLError(.fileDoesNotExist, userInfo: [NSLocalizedDescriptionKey: String(format: tr("No existe la carpeta %@"), query)])
        }
        var found: [ImageCandidate] = []
        for case let file as URL in walker where extensions.contains(file.pathExtension.lowercased()) {
            found.append(ImageCandidate(
                id: "folder:\(file.path)", url: file, source: .folder,
                title: file.deletingPathExtension().lastPathComponent, author: "",
                pageURL: nil, width: 0, height: 0))
        }
        return Array(found.shuffled().prefix(40))
    }
}
