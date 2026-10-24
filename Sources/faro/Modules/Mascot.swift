// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI

enum MascotShape: String, CaseIterable, Identifiable {
    case blob, bean, cloud, cube, sun
    var id: String { rawValue }
    var title: String {
        switch self {
        case .blob: return tr("Gota")
        case .bean: return tr("Frijol")
        case .cloud: return tr("Nube")
        case .cube: return tr("Cubo")
        case .sun: return tr("Sol")
        }
    }
}

enum MascotEyes: String, CaseIterable, Identifiable {
    case oval, round, wide, dot, star
    var id: String { rawValue }
    var title: String {
        switch self {
        case .oval: return tr("Ovalados")
        case .round: return tr("Redondos")
        case .wide: return tr("Anchos")
        case .dot: return tr("Puntos")
        case .star: return tr("Estrellas")
        }
    }
}

enum MascotAccessory: String, CaseIterable, Identifiable {
    case none, antenna, bow, headphones
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return tr("Nada")
        case .antenna: return tr("Antena")
        case .bow: return tr("Moño")
        case .headphones: return tr("Audífonos")
        }
    }
}

enum MascotMood: Equatable {
    case sleeping, idle, dancing, hearts, bluetooth, celebrate, sad
}

/// La mascota del notch: un personaje pequeño que sigue el cursor y reacciona a lo que pasa.
/// Solo está despierta mientras alguien usa el notch (o un aviso la despierta); pasado un rato sin tocarlo se duerme
/// y deja de animarse, así que dormida no consume nada.
@MainActor
final class MascotModel: ObservableObject {
    @Published var enabled: Bool { didSet { save("mascotEnabled", enabled); if !enabled { awake = false; refresh() } } }
    @Published var shape: MascotShape { didSet { save("mascotShape", shape.rawValue) } }
    @Published var colorHex: String { didSet { save("mascotColor", colorHex) } }
    @Published var eyes: MascotEyes { didSet { save("mascotEyes", eyes.rawValue) } }
    @Published var blush: Bool { didSet { save("mascotBlush", blush) } }
    @Published var accessory: MascotAccessory { didSet { save("mascotAccessory", accessory.rawValue) } }
    /// Segundos sin usar el notch antes de que se duerma.
    @Published var sleepAfter: Int { didSet { save("mascotSleepAfter", sleepAfter) } }

    @Published private(set) var mood: MascotMood = .sleeping
    @Published private(set) var awake = false
    /// Hacia dónde mira, de -1 a 1 en cada eje.
    @Published private(set) var gaze = CGPoint.zero
    /// Cuándo empezó la reacción actual (para animar corazones y confeti).
    private(set) var reactionStart = Date.distantPast

    /// La música suena: la mascota baila mientras está despierta.
    var dancing = false { didSet { if dancing != oldValue { refresh() } } }

    private var awakeUntil = Date.distantPast
    private var reaction: MascotMood?
    private var reactionUntil = Date.distantPast

    static let defaultColor = "#F2B24F"

    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }

    init() {
        let d = UserDefaults.standard
        enabled = d.object(forKey: "mascotEnabled") as? Bool ?? true
        shape = MascotShape(rawValue: d.string(forKey: "mascotShape") ?? "") ?? .blob
        colorHex = d.string(forKey: "mascotColor") ?? Self.defaultColor
        eyes = MascotEyes(rawValue: d.string(forKey: "mascotEyes") ?? "") ?? .oval
        blush = d.object(forKey: "mascotBlush") as? Bool ?? true
        accessory = MascotAccessory(rawValue: d.string(forKey: "mascotAccessory") ?? "") ?? .none
        sleepAfter = d.integer(forKey: "mascotSleepAfter") == 0 ? 30 : d.integer(forKey: "mascotSleepAfter")
    }

    // MARK: Despertar y dormir

    /// Despierta a la mascota (al abrir el notch, tocarla o recibir un aviso) y la mantiene así `seconds` segundos.
    func wake(for seconds: Double? = nil, now: Date = Date()) {
        guard enabled else { return }
        awakeUntil = now.addingTimeInterval(seconds ?? Double(sleepAfter))
        if !awake { awake = true }
        refresh(now: now)
    }

    /// Cada segundo: se duerme si pasó el tiempo y termina las reacciones.
    func tick(now: Date = Date()) {
        if awake, now >= awakeUntil { awake = false }
        refresh(now: now)
    }

    func react(_ mood: MascotMood, seconds: Double, now: Date = Date()) {
        guard enabled else { return }
        reaction = mood
        reactionStart = now
        reactionUntil = now.addingTimeInterval(seconds)
        wake(for: max(Double(sleepAfter), seconds + 5), now: now)
    }

    /// Para probar desde ajustes: muestra ese ánimo en la mascota real del notch unos segundos
    /// (dormir la manda a dormir al instante).
    func demo(_ mood: MascotMood, now: Date = Date()) {
        guard enabled else { return }
        if mood == .sleeping {
            reaction = nil
            awakeUntil = .distantPast
            awake = false
            refresh(now: now)
        } else {
            react(mood, seconds: mood == .dancing ? 10 : 6, now: now)
        }
    }

    /// Una caricia: salen corazones.
    func pet() { react(.hearts, seconds: 2.8) }

    /// Hacia dónde mirar (se llama con el cursor, solo si está despierta).
    func look(_ target: CGPoint) {
        guard awake else { return }
        if abs(target.x - gaze.x) > 0.04 || abs(target.y - gaze.y) > 0.04 { gaze = target }
    }

    func refresh(now: Date = Date()) {
        if reaction != nil, now >= reactionUntil { reaction = nil }
        let next: MascotMood
        if !enabled || !awake { next = .sleeping }
        else if let reaction { next = reaction }
        else if dancing { next = .dancing }
        else { next = .idle }
        if next != mood { mood = next }
    }

    /// Lo que se ve en la vista previa de ajustes, que siempre está despierta.
    func resetAppearance() {
        shape = .blob; colorHex = Self.defaultColor; eyes = .oval; blush = true; accessory = .none; sleepAfter = 30
    }
}
