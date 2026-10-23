// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Archivo público de las últimas 8 imágenes del día de Bing, pedidas en UHD.
struct BingSource: ImageSource {
    func candidates(query: String, filter: ImageFilter) async throws -> [ImageCandidate] {
        let url = URL(string: "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-US")!
        guard let root = try await Net.json(url) as? [String: Any],
              let images = root["images"] as? [[String: Any]] else { return [] }

        return images.compactMap { img in
            guard let path = img["url"] as? String,
                  let id = URLComponents(string: path)?.queryItems?.first(where: { $0.name == "id" })?.value,
                  let date = img["startdate"] as? String,
                  let full = URL(string: "https://www.bing.com/th?id=" + id.replacingOccurrences(of: "_1920x1080", with: "_UHD"))
            else { return nil }
            return ImageCandidate(
                id: "bing:\(date)", url: full, source: .bing,
                title: img["title"] as? String ?? "Bing", author: img["copyright"] as? String ?? "",
                pageURL: (img["copyrightlink"] as? String).flatMap(URL.init(string:)),
                width: 0, height: 0)
        }
        .shuffled()
    }
}
