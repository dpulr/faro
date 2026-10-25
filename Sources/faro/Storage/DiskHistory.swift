// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Historial diario del espacio usado y una proyección de cuándo se llenaría el disco.
@MainActor
final class DiskHistory: ObservableObject {
    struct Sample: Codable, Equatable, Identifiable {
        var day: String      // aaaa-mm-dd
        var used: Int64
        var total: Int64
        var id: String { day }
    }

    struct Forecast: Equatable {
        enum Trend { case growing, stable, shrinking }
        var trend: Trend
        /// Bytes por día (positivo si el disco se llena).
        var bytesPerDay: Int64
        /// Días hasta llenarse; `nil` si no se llena.
        var daysLeft: Int?
        var sampleDays: Int
    }

    @Published private(set) var samples: [Sample] = []
    /// Se llama (como mucho cada 3 días) cuando el disco se llenaría en menos de dos semanas.
    var onFillSoon: ((Int) -> Void)?

    private let file: URL?
    private var lastAlert: Date?
    private var lastSaved = Date.distantPast

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(file: URL? = Paths.support.appendingPathComponent("disk.json")) {
        self.file = file
        if let file, let data = try? Data(contentsOf: file) { samples = (try? JSONDecoder().decode([Sample].self, from: data)) ?? [] }
        lastAlert = UserDefaults.standard.object(forKey: "diskForecastAlert") as? Date
    }

    /// Anota el espacio de hoy (un punto por día; se actualiza durante el día) y conserva 90 días.
    func record(free: Int64, total: Int64, now: Date = Date()) {
        guard total > 0, free >= 0 else { return }
        let day = Self.formatter.string(from: now)
        let sample = Sample(day: day, used: total - free, total: total)
        if let index = samples.firstIndex(where: { $0.day == day }) {
            guard abs(samples[index].used - sample.used) > 200_000_000 else { return }
            samples[index] = sample
        } else {
            samples.append(sample)
        }
        samples = Array(samples.suffix(90))
        if now.timeIntervalSince(lastSaved) > 600, let file, let data = try? JSONEncoder().encode(samples) {
            try? data.write(to: file, options: .atomic)
            lastSaved = now
        }
        if let forecast = forecast(free: free), forecast.trend == .growing, let days = forecast.daysLeft, days <= 14,
           lastAlert.map({ now.timeIntervalSince($0) > 3 * 86_400 }) ?? true {
            lastAlert = now
            UserDefaults.standard.set(now, forKey: "diskForecastAlert")
            onFillSoon?(days)
        }
    }

    func forecast(free: Int64) -> Forecast? { Self.forecast(samples: samples, free: free) }

    /// Regresión lineal del espacio usado en los últimos 30 días; necesita al menos 3 días distintos.
    static func forecast(samples: [Sample], free: Int64) -> Forecast? {
        let recent = Array(samples.suffix(30))
        guard recent.count >= 3, let first = recent.first.flatMap({ formatter.date(from: $0.day) }) else { return nil }
        let points: [(x: Double, y: Double)] = recent.compactMap { s in
            formatter.date(from: s.day).map { (($0.timeIntervalSince(first)) / 86_400, Double(s.used)) }
        }
        guard let span = points.last?.x, span >= 2 else { return nil }
        let n = Double(points.count)
        let sx = points.reduce(0) { $0 + $1.x }, sy = points.reduce(0) { $0 + $1.y }
        let sxx = points.reduce(0) { $0 + $1.x * $1.x }, sxy = points.reduce(0) { $0 + $1.x * $1.y }
        let denominator = n * sxx - sx * sx
        guard denominator != 0 else { return nil }
        let slope = (n * sxy - sx * sy) / denominator
        let perDay = Int64(slope)
        if slope > 50_000_000 {
            return Forecast(trend: .growing, bytesPerDay: perDay, daysLeft: min(999, Int(Double(free) / slope)), sampleDays: recent.count)
        }
        return Forecast(trend: slope < -50_000_000 ? .shrinking : .stable, bytesPerDay: perDay, daysLeft: nil, sampleDays: recent.count)
    }
}
