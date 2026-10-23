// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

struct ImageFilter {
    var minWidth: Int
    var minHeight: Int
    var targetWidth: Int

    func accepts(_ c: ImageCandidate) -> Bool {
        if c.width == 0 || c.height == 0 { return true } // tamaño desconocido (carpetas)
        return c.width >= minWidth && c.height >= minHeight && Double(c.width) / Double(c.height) >= 1.3
    }
}

protocol ImageSource {
    /// Devuelve un lote de candidatos para la consulta; cada llamada debería dar resultados distintos.
    func candidates(query: String, filter: ImageFilter) async throws -> [ImageCandidate]
}

enum Sources {
    static func make(_ kind: SourceKind) -> ImageSource {
        switch kind {
        case .wallhaven: return WallhavenSource()
        case .wikimedia: return WikimediaSource()
        case .bing: return BingSource()
        case .folder: return FolderSource()
        }
    }
}

enum Net {
    static let userAgent = "faro/0.1 (uso personal; macOS)"

    static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url, timeoutInterval: 30)
        r.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return r
    }

    static func json(_ url: URL) async throws -> Any {
        let (data, resp) = try await URLSession.shared.data(for: request(url))
        try check(resp)
        return try JSONSerialization.jsonObject(with: data)
    }

    static func download(_ url: URL) async throws -> URL {
        let (tmp, resp) = try await URLSession.shared.download(for: request(url))
        do { try check(resp) } catch { try? FileManager.default.removeItem(at: tmp); throw error }
        return tmp
    }

    private static func check(_ resp: URLResponse) throws {
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
    }
}
