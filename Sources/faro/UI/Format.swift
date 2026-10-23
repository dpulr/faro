// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

enum Format {
    static func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }

    static func bytes(_ n: UInt64) -> String { bytes(Int64(n)) }

    /// La RAM se anuncia en GiB (24 GB), no en potencias de 10.
    static func memory(_ n: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .memory)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        let bits = bytesPerSecond * 8
        if bits >= 1_000_000 { return String(format: "%.1f Mb/s", bits / 1_000_000) }
        return String(format: "%.0f kb/s", bits / 1000)
    }

    static func compactRate(_ bytesPerSecond: Double) -> String {
        let bits = bytesPerSecond * 8
        if bits >= 1_000_000 { return String(format: "%.1fM", bits / 1_000_000) }
        return String(format: "%.0fk", bits / 1000)
    }

    static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: AppLanguage.activeCode)
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    static func interval(_ minutes: Int) -> String {
        switch minutes {
        case 0: return tr("Solo manual")
        case ..<60: return String(format: tr("Cada %lld min"), minutes)
        case 60: return tr("Cada hora")
        case 1440: return tr("Cada día")
        default: return String(format: tr("Cada %lld horas"), minutes / 60)
        }
    }
}
