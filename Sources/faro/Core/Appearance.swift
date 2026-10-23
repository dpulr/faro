// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

extension Color {
    init?(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255, opacity: 1)
    }

    var hex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return String(format: "%02X%02X%02X", Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}

/// Color de resalte y tinte del cristal, elegidos por el usuario.
@MainActor
final class Appearance: ObservableObject {
    static let shared = Appearance()
    static let defaultAccent = "3D9485"
    static let presets: [(String, String)] = [
        ("Verde azulado", "3D9485"), ("Azul", "5B7FD1"), ("Violeta", "8B6FC6"), ("Rosa", "D0689A"),
        ("Naranja", "E08A3C"), ("Verde", "5FA85A"), ("Grafito", "8E8E93"),
    ]

    /// Sube cuando el color de resalte cambia (con una pausa) y obliga a las ventanas a redibujarse con el color nuevo.
    @Published private(set) var revision = 0
    private var revisionTask: Task<Void, Never>?

    @Published var accentHex: String {
        didSet {
            UserDefaults.standard.set(accentHex, forKey: "accentHex")
            revisionTask?.cancel()
            revisionTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled { revision += 1 }
            }
        }
    }
    /// Vacío = cristal sin tinte.
    @Published var glassTintHex: String { didSet { UserDefaults.standard.set(glassTintHex, forKey: "glassTintHex") } }
    /// Vacío = el color normal de ventana del sistema.
    @Published var windowColorHex: String { didSet { UserDefaults.standard.set(windowColorHex, forKey: "windowColorHex") } }
    @Published var glassStrength: Double { didSet { UserDefaults.standard.set(glassStrength, forKey: "glassStrength") } }

    var accent: Color { Color(hex: accentHex) ?? Color(hex: Self.defaultAccent)! }
    var windowColor: Color { Color(hex: windowColorHex) ?? Color(nsColor: .windowBackgroundColor) }
    var glassTint: Color? { glassTintHex.isEmpty ? nil : Color(hex: glassTintHex) }

    private init() {
        let d = UserDefaults.standard
        accentHex = d.string(forKey: "accentHex") ?? Self.defaultAccent
        glassTintHex = d.string(forKey: "glassTintHex") ?? ""
        windowColorHex = d.string(forKey: "windowColorHex") ?? ""
        let strength = d.double(forKey: "glassStrength")
        glassStrength = strength == 0 ? 0.25 : strength
    }

    func reset() {
        accentHex = Self.defaultAccent
        glassTintHex = ""
        windowColorHex = ""
        glassStrength = 0.25
    }
}
