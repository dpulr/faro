// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Art Institute of Chicago: obras de dominio público, sin clave. Las imágenes se piden por IIIF al ancho de la pantalla.
struct ArticSource: ImageSource {
    func candidates(query: String, filter: ImageFilter) async throws -> [ImageCandidate] {
        let found = try await page(query: query, filter: filter, number: Int.random(in: 1...6))
        return found.isEmpty ? try await page(query: query, filter: filter, number: 1) : found
    }

    private func page(query: String, filter: ImageFilter, number: Int) async throws -> [ImageCandidate] {
        var c = URLComponents(string: "https://api.artic.edu/api/v1/artworks/search")!
        c.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "query[term][is_public_domain]", value: "true"),
            URLQueryItem(name: "limit", value: "40"),
            URLQueryItem(name: "page", value: "\(number)"),
            URLQueryItem(name: "fields", value: "id,title,artist_display,image_id,thumbnail"),
        ]
        guard let root = try await Net.json(c.url!) as? [String: Any], let data = root["data"] as? [[String: Any]] else { return [] }
        let iiif = ((root["config"] as? [String: Any])?["iiif_url"] as? String) ?? "https://www.artic.edu/iiif/2"

        return data.compactMap { art in
            guard let imageID = art["image_id"] as? String, let id = art["id"] as? Int,
                  let thumb = art["thumbnail"] as? [String: Any],
                  let w = thumb["width"] as? Int, let h = thumb["height"] as? Int, h > 0,
                  Double(w) / Double(h) >= 1.25 else { return nil }
            let width = min(filter.targetWidth, w) // IIIF no agranda: se pide como máximo el ancho original
            guard let url = URL(string: "\(iiif)/\(imageID)/full/\(width),/0/default.jpg") else { return nil }
            let artist = (art["artist_display"] as? String)?.split(separator: "\n").first.map(String.init) ?? ""
            return ImageCandidate(
                id: "artic:\(id)", url: url, source: .artic, title: art["title"] as? String ?? "Obra \(id)", author: artist,
                pageURL: URL(string: "https://www.artic.edu/artworks/\(id)"), width: w, height: h)
        }
        .filter(filter.accepts)
        .shuffled()
    }
}
