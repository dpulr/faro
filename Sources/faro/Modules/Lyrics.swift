// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Letras sincronizadas de lo que suena (Música o Spotify), de LRCLIB: gratis y sin clave.
/// Se consulta con el título y el artista de la canción; el resultado se recuerda mientras faro está abierto.
@MainActor
final class LyricsProvider: ObservableObject {
    struct Line: Equatable { var time: Double; var text: String }

    enum Status: Equatable { case idle, loading, synced, notFound }

    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "lyricsEnabled")
            if !enabled { reset() }
        }
    }
    /// Línea que suena ahora (nil si no hay letra o es un silencio instrumental).
    @Published private(set) var line: String?
    @Published private(set) var next: String?
    @Published private(set) var status: Status = .idle

    private var lines: [Line] = []
    private var currentKey = ""
    private var cache: [String: [Line]] = [:]
    private var anchorPosition = 0.0
    private var anchorDate = Date()
    private var playing = false
    private var clock: Timer?
    private var fetchTask: Task<Void, Never>?

    /// La letra suele ir un instante por delante del reproductor, así se lee antes de que se cante.
    private let lead = 0.25

    init() { enabled = UserDefaults.standard.object(forKey: "lyricsEnabled") as? Bool ?? true }

    /// Línea de muestra para capturas y pruebas.
    func loadDemo() { line = "Lighthouse in the dark, keep the harbor lit"; next = "Every wave that finds the shore" }

    // MARK: Entrada desde el notch

    /// Se llama en cada lectura del reproductor (cada par de segundos): canción, posición y si suena.
    func sync(title: String, artist: String, position: Double, playing: Bool) {
        guard enabled, !title.isEmpty else { reset(); return }
        let key = Self.key(title: title, artist: artist)
        if key != currentKey {
            currentKey = key
            lines = []
            publish(nil, nil)
            if let cached = cache[key] {
                lines = cached
                status = cached.isEmpty ? .notFound : .synced
            } else {
                status = .loading
                fetchTask?.cancel()
                fetchTask = Task { [weak self] in
                    let found = await Self.fetch(title: title, artist: artist)
                    guard !Task.isCancelled, let self, self.currentKey == key else { return }
                    self.cache[key] = found
                    self.lines = found
                    self.status = found.isEmpty ? .notFound : .synced
                    self.refreshLine()
                }
            }
        }
        anchorPosition = position
        anchorDate = Date()
        self.playing = playing
        refreshLine()
        updateClock()
    }

    func reset() {
        fetchTask?.cancel()
        currentKey = ""
        lines = []
        status = .idle
        publish(nil, nil)
        clock?.invalidate()
        clock = nil
        playing = false
    }

    // MARK: Línea actual

    private func updateClock() {
        let needed = playing && !lines.isEmpty
        if needed, clock == nil {
            let t = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in Task { @MainActor in self?.refreshLine() } }
            t.tolerance = 0.1
            RunLoop.main.add(t, forMode: .common)
            clock = t
        } else if !needed {
            clock?.invalidate()
            clock = nil
        }
    }

    private func refreshLine(now: Date = Date()) {
        guard !lines.isEmpty else { publish(nil, nil); return }
        let t = anchorPosition + (playing ? now.timeIntervalSince(anchorDate) : 0) + lead
        let (current, following) = Self.lines(in: lines, at: t)
        publish(current, following)
    }

    private func publish(_ current: String?, _ following: String?) {
        if line != current { line = current }
        if next != following { next = following }
    }

    // MARK: Lógica pura (se prueba sin red)

    static func key(title: String, artist: String) -> String { (title + "|" + artist).lowercased() }

    /// La línea que suena en el segundo `t` y la siguiente. Un renglón vacío es una pausa instrumental.
    static func lines(in lines: [Line], at t: Double) -> (String?, String?) {
        guard let first = lines.first, t >= first.time else { return (nil, lines.first(where: { !$0.text.isEmpty })?.text) }
        var index = 0
        for (i, l) in lines.enumerated() where l.time <= t { index = i }
        let current = lines[index].text
        let following = lines.dropFirst(index + 1).first(where: { !$0.text.isEmpty })?.text
        return (current.isEmpty ? nil : current, following)
    }

    /// Convierte el texto LRC ("[01:23.45] letra") en líneas con su segundo; admite varias marcas por renglón.
    static func parse(lrc: String) -> [Line] {
        var out: [Line] = []
        for raw in lrc.split(whereSeparator: \.isNewline) {
            var rest = Substring(raw)
            var times: [Double] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                let parts = tag.split(separator: ":")
                if parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1].replacingOccurrences(of: ",", with: ".")) {
                    times.append(minutes * 60 + seconds)
                }
                rest = rest[rest.index(after: close)...]
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            for time in times { out.append(Line(time: time, text: text)) }
        }
        return out.sorted { $0.time < $1.time }
    }

    /// "Canción - Remastered 2011" y "Canción (feat. X)" se buscan también como "Canción".
    static func cleaned(_ title: String) -> String {
        var t = title
        if let r = t.range(of: " - ") { t = String(t[..<r.lowerBound]) }
        while let open = t.firstIndex(where: { $0 == "(" || $0 == "[" }), let close = t[open...].firstIndex(where: { $0 == ")" || $0 == "]" }) {
            t.removeSubrange(open...close)
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Red (LRCLIB)

    static func fetch(title: String, artist: String) async -> [Line] {
        var attempts = [title]
        let short = cleaned(title)
        if !short.isEmpty, short.lowercased() != title.lowercased() { attempts.append(short) }
        for name in attempts {
            if let found = await search(title: name, artist: artist), !found.isEmpty { return found }
        }
        return []
    }

    private static func search(title: String, artist: String) async -> [Line]? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("faro (https://github.com/dpulr/faro)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let results = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        let synced = results.filter { ($0["syncedLyrics"] as? String)?.isEmpty == false }
        // Mejor coincidencia: mismo título y un artista que contenga al buscado; si no, la primera con letra sincronizada.
        let wantedTitle = title.lowercased(), wantedArtist = artist.lowercased()
        let best = synced.first {
            ($0["trackName"] as? String)?.lowercased() == wantedTitle
                && (wantedArtist.isEmpty || (($0["artistName"] as? String)?.lowercased().contains(wantedArtist) ?? false))
        } ?? synced.first
        guard let lrc = best?["syncedLyrics"] as? String else { return [] }
        return parse(lrc: lrc)
    }
}
