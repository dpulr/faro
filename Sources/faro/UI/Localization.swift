// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Traduce un texto de la interfaz. Los textos de SwiftUI escritos como literales se traducen solos;
/// esta función sirve para los que se calculan (etiquetas, avisos, mensajes).
func tr(_ spanish: String) -> String {
    NSLocalizedString(spanish, comment: "")
}

/// Idioma de la interfaz: automático (el del sistema), español o inglés.
/// macOS lee `AppleLanguages` al arrancar, por eso cambiarlo reinicia faro.
enum AppLanguage: String, CaseIterable {
    case auto, es, en

    static var current: AppLanguage {
        guard let first = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])?.first,
              UserDefaults.standard.bool(forKey: "faro.languageOverride") else { return .auto }
        return first.hasPrefix("en") ? .en : .es
    }

    static func apply(_ language: AppLanguage) {
        let defaults = UserDefaults.standard
        switch language {
        case .auto:
            defaults.removeObject(forKey: "AppleLanguages")
            defaults.set(false, forKey: "faro.languageOverride")
        case .es, .en:
            defaults.set([language.rawValue], forKey: "AppleLanguages")
            defaults.set(true, forKey: "faro.languageOverride")
        }
    }

    /// Código del idioma que la interfaz está usando ahora mismo.
    static var activeCode: String {
        Bundle.main.preferredLocalizations.first ?? "es"
    }

    static var isEnglish: Bool { activeCode.hasPrefix("en") }

    var title: String {
        switch self {
        case .auto: return tr("Automático")
        case .es: return "Español"
        case .en: return "English"
        }
    }
}
