// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Una recomendación del asistente de almacenamiento.
struct Recommendation: Identifiable, Equatable {
    enum Action: Equatable {
        case cleanCategory(String)
        case emptyTrash
        case reviewCategory(String)
        case reviewForgotten
        case simulators
    }

    var id: String
    var symbol: String
    var title: String
    var detail: String
    var bytes: Int64
    var risk: Risk
    var action: Action

    /// Primero lo seguro (de más a menos espacio) y después lo que hay que revisar a mano.
    var sortKey: (Int, Int64) { (risk == .safe ? 0 : 1, -bytes) }
}

extension Risk: Equatable {}

enum StorageAdvisor {
    /// Umbral mínimo para recomendar algo (por debajo no vale la pena el ruido).
    static let minimumBytes: Int64 = 150_000_000

    static func recommendations(categories: [CleanCategory], trashBytes: Int64, simulatorBytes: Int64?,
                                forgotten: [CleanItem], forgottenDays: Int) -> [Recommendation] {
        var out: [Recommendation] = []
        for category in categories where category.scanned {
            let bytes = category.spec.risk == .safe ? safeBytes(of: category) : category.total
            guard bytes >= minimumBytes else { continue }
            out.append(Recommendation(
                id: category.id, symbol: category.spec.symbol, title: category.spec.title, detail: category.spec.detail,
                bytes: bytes, risk: category.spec.risk,
                action: category.spec.risk == .safe ? .cleanCategory(category.id) : .reviewCategory(category.id)))
        }
        if trashBytes >= minimumBytes {
            out.append(Recommendation(id: "trash", symbol: "trash", title: tr("Vaciar la Papelera"),
                                      detail: tr("Lo que ya borraste sigue ocupando espacio hasta que la vacías."),
                                      bytes: trashBytes, risk: .safe, action: .emptyTrash))
        }
        let forgottenBytes = forgotten.reduce(0) { $0 + $1.bytes }
        if forgottenBytes >= minimumBytes {
            out.append(Recommendation(id: "forgotten", symbol: "clock.arrow.circlepath",
                                      title: String(format: tr("%lld archivos grandes sin tocar"), forgotten.count),
                                      detail: String(format: tr("Llevan más de %lld meses sin abrirse ni cambiar. Revisa si aún los necesitas."), max(1, forgottenDays / 30)),
                                      bytes: forgottenBytes, risk: .review, action: .reviewForgotten))
        }
        if let simulatorBytes, simulatorBytes >= minimumBytes {
            out.append(Recommendation(id: "sims", symbol: "iphone.gen3", title: tr("Simuladores de iOS"),
                                      detail: tr("Puedo quitar los que ya no funcionan con tu Xcode."),
                                      bytes: simulatorBytes, risk: .review, action: .simulators))
        }
        return out.sorted { $0.sortKey < $1.sortKey }
    }

    /// Lo que se limpia por defecto en una categoría segura (sin los elementos más recientes que se conservan).
    static func safeItems(of category: CleanCategory) -> [CleanItem] {
        guard category.spec.risk == .safe, category.spec.preselect else { return [] }
        let ordered = category.items.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
        return Array(ordered.dropFirst(category.spec.keepNewest))
    }

    static func safeBytes(of category: CleanCategory) -> Int64 { safeItems(of: category).reduce(0) { $0 + $1.bytes } }
}
