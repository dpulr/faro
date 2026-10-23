// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Cambiar el identificador de la app deja los ajustes en el dominio anterior: se copian al nuevo, una sola vez.
enum LegacyMigration {
    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "migratedFromLegacyIdentifier") else { return }
        defaults.set(true, forKey: "migratedFromLegacyIdentifier")
        for legacy in ["co.soyholistico.mirador", "co.soyholistico.tapiz"] {
            guard let old = defaults.persistentDomain(forName: legacy) else { continue }
            for (key, value) in old where defaults.object(forKey: key) == nil && !key.hasPrefix("NSStatusItem") {
                defaults.set(value, forKey: key)
            }
        }
    }
}
