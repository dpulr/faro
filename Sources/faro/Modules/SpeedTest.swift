// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Usa `networkQuality`, que ya viene con macOS. Guarda su propio historial y puede medir solo cada cierto tiempo.
@MainActor
final class SpeedTest: ObservableObject {
    @Published var running = false
    @Published var error: String?
    @Published var history: [SpeedResult] = [] { didSet { save() } }
    /// 0 = solo manual.
    @Published var autoMinutes = 0 { didSet { save() } }

    private var timer: Timer?

    private struct Stored: Codable {
        var history: [SpeedResult]
        var autoMinutes: Int
    }

    private static var file: URL { Paths.support.appendingPathComponent("speed.json") }

    var last: SpeedResult? { history.first }

    init() {
        if let data = try? Data(contentsOf: Self.file),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            history = stored.history
            autoMinutes = stored.autoMinutes
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = 20
        tick()
    }

    private func tick() {
        guard autoMinutes > 0, !running else { return }
        if let last, Date().timeIntervalSince(last.date) < Double(autoMinutes) * 60 { return }
        run()
    }

    func run() {
        guard !running else { return }
        running = true
        error = nil
        Task {
            let result = await Task.detached { Self.measure() }.value
            running = false
            switch result {
            case .success(let r):
                history.insert(r, at: 0)
                if history.count > 200 { history.removeLast(history.count - 200) }
            case .failure(let e):
                error = e.localizedDescription
            }
        }
    }

    func clearHistory() { history = [] }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(Stored(history: history, autoMinutes: autoMinutes)) {
            try? data.write(to: Self.file, options: .atomic)
        }
    }

    nonisolated private static func measure() -> Result<SpeedResult, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        process.arguments = ["-c", "-M", "20"] // máximo 20 s para gastar poco ancho de banda
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dl = json["dl_throughput"] as? Double, let ul = json["ul_throughput"] as? Double
            else { throw URLError(.notConnectedToInternet, userInfo: [NSLocalizedDescriptionKey: "No hay conexión para medir"]) }
            let rtt = (json["base_rtt"] as? Double) ?? 0
            return .success(SpeedResult(date: Date(), downMbps: dl / 1_000_000, upMbps: ul / 1_000_000, latencyMs: rtt))
        } catch {
            return .failure(error)
        }
    }
}
