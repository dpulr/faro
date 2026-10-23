// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Picsum: fotos al azar de fotógrafos de Unsplash, sin clave ni búsqueda por tema.
struct PicsumSource: ImageSource {
    func candidates(query: String, filter: ImageFilter) async throws -> [ImageCandidate] {
        var c = URLComponents(string: "https://picsum.photos/v2/list")!
        c.queryItems = [URLQueryItem(name: "page", value: "\(Int.random(in: 1...30))"), URLQueryItem(name: "limit", value: "40")]
        guard let list = try await Net.json(c.url!) as? [[String: Any]] else { return [] }
        return list.compactMap { photo in
            guard let id = photo["id"] as? String, let w = photo["width"] as? Int, let h = photo["height"] as? Int, h > 0,
                  Double(w) / Double(h) >= 1.3 else { return nil }
            let width = min(filter.targetWidth, w)
            let height = width * h / w
            guard let url = URL(string: "https://picsum.photos/id/\(id)/\(width)/\(height)") else { return nil }
            return ImageCandidate(id: "picsum:\(id)", url: url, source: .picsum, title: "Foto \(id)",
                                  author: photo["author"] as? String ?? "",
                                  pageURL: (photo["url"] as? String).flatMap(URL.init(string:)), width: w, height: h)
        }
        .filter(filter.accepts)
        .shuffled()
    }
}
