// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// API pública de Wallhaven, sin clave. `purity=100` limita a contenido seguro.
struct WallhavenSource: ImageSource {
    func candidates(query: String, filter: ImageFilter) async throws -> [ImageCandidate] {
        var c = URLComponents(string: "https://wallhaven.cc/api/v1/search")!
        c.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "categories", value: "100"),
            URLQueryItem(name: "purity", value: "100"),
            URLQueryItem(name: "sorting", value: "random"),
            URLQueryItem(name: "atleast", value: "\(filter.minWidth)x\(filter.minHeight)"),
            URLQueryItem(name: "ratios", value: "16x9,16x10"),
        ]
        guard let root = try await Net.json(c.url!) as? [String: Any],
              let data = root["data"] as? [[String: Any]] else { return [] }

        return data.compactMap { d in
            guard let id = d["id"] as? String,
                  let path = d["path"] as? String, let url = URL(string: path) else { return nil }
            return ImageCandidate(
                id: "wallhaven:\(id)", url: url, source: .wallhaven,
                title: query.isEmpty ? "Wallhaven \(id)" : query, author: "",
                pageURL: (d["url"] as? String).flatMap(URL.init(string:)),
                width: d["dimension_x"] as? Int ?? 0, height: d["dimension_y"] as? Int ?? 0)
        }
    }
}
