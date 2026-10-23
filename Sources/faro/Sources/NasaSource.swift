// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Biblioteca de imágenes de la NASA (images-api.nasa.gov), sin clave. De cada resultado se toma la versión original en JPEG.
struct NasaSource: ImageSource {
    private struct Hit { var id: String; var title: String; var author: String }

    func candidates(query: String, filter: ImageFilter) async throws -> [ImageCandidate] {
        var hits = try await search(query: query, page: Int.random(in: 1...4))
        if hits.isEmpty { hits = try await search(query: query, page: 1) }
        return await withTaskGroup(of: ImageCandidate?.self) { group in
            for hit in hits.prefix(14) { group.addTask { await Self.resolve(hit) } }
            var out: [ImageCandidate] = []
            for await candidate in group { if let candidate { out.append(candidate) } }
            return out.shuffled()
        }
    }

    private func search(query: String, page: Int) async throws -> [Hit] {
        var c = URLComponents(string: "https://images-api.nasa.gov/search")!
        c.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "media_type", value: "image"),
                        URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "page_size", value: "24")]
        guard let root = try await Net.json(c.url!) as? [String: Any],
              let items = (root["collection"] as? [String: Any])?["items"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let d = (item["data"] as? [[String: Any]])?.first, let id = d["nasa_id"] as? String else { return nil }
            let author = (d["photographer"] as? String) ?? (d["secondary_creator"] as? String) ?? (d["center"] as? String) ?? "NASA"
            return Hit(id: id, title: d["title"] as? String ?? id, author: author)
        }
    }

    /// El manifiesto de cada imagen lista sus versiones; se busca la original en JPEG.
    private static func resolve(_ hit: Hit) async -> ImageCandidate? {
        guard let id = hit.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let manifest = URL(string: "https://images-api.nasa.gov/asset/\(id)"),
              let root = try? await Net.json(manifest) as? [String: Any],
              let items = (root["collection"] as? [String: Any])?["items"] as? [[String: Any]],
              let href = items.compactMap({ $0["href"] as? String }).first(where: { $0.hasSuffix("~orig.jpg") }),
              let url = URL(string: href.replacingOccurrences(of: "http://", with: "https://")) else { return nil }
        return ImageCandidate(id: "nasa:\(hit.id)", url: url, source: .nasa, title: hit.title, author: hit.author,
                              pageURL: URL(string: "https://images.nasa.gov/details/\(id)"), width: 0, height: 0)
    }
}
