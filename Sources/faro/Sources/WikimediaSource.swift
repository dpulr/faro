// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Wikimedia Commons, limitado a Featured Pictures (P6731 = Q63348069).
/// Pide la miniatura ya reducida al ancho de pantalla para no bajar originales enormes.
struct WikimediaSource: ImageSource {
    func candidates(query: String, filter: ImageFilter) async throws -> [ImageCandidate] {
        let found = try await page(query: query, filter: filter, offset: Int.random(in: 0..<60))
        return found.isEmpty ? try await page(query: query, filter: filter, offset: 0) : found
    }

    private func page(query: String, filter: ImageFilter, offset: Int) async throws -> [ImageCandidate] {
        var c = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        c.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "\(query) filetype:bitmap haswbstatement:P6731=Q63348069"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "30"),
            URLQueryItem(name: "gsroffset", value: "\(offset)"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|size|extmetadata"),
            URLQueryItem(name: "iiurlwidth", value: "\(filter.targetWidth)"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let root = try await Net.json(c.url!) as? [String: Any],
              let query = root["query"] as? [String: Any],
              let pages = query["pages"] as? [String: [String: Any]] else { return [] }

        return pages.values.compactMap { p in
            guard let info = (p["imageinfo"] as? [[String: Any]])?.first,
                  let w = info["width"] as? Int, let h = info["height"] as? Int,
                  let urlString = (info["thumburl"] as? String) ?? (info["url"] as? String),
                  let url = URL(string: urlString) else { return nil }
            let meta = info["extmetadata"] as? [String: [String: Any]]
            let title = Self.clean(p["title"] as? String ?? "")
                .replacingOccurrences(of: "File:", with: "")
            let author = Self.clean(meta?["Artist"]?["value"] as? String ?? "")
            return ImageCandidate(
                id: "wikimedia:\(p["pageid"] as? Int ?? 0)", url: url, source: .wikimedia,
                title: title, author: author,
                pageURL: (info["descriptionurl"] as? String).flatMap(URL.init(string:)),
                width: w, height: h)
        }
        .filter(filter.accepts)
        .shuffled()
    }

    private static func clean(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
