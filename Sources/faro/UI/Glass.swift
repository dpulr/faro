// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Cristal líquido en macOS 26 o superior; en versiones anteriores, un material translúcido parecido.
struct GlassSurface<S: InsettableShape>: ViewModifier {
    var shape: S
    @ObservedObject private var appearance = Appearance.shared

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.fill(appearance.glassTint?.opacity(appearance.glassStrength * 0.6) ?? Color.clear))
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        if let tint = appearance.glassTint { return Glass.regular.tint(tint.opacity(appearance.glassStrength)) }
        return Glass.regular
    }
}

extension View {
    func glassSurface(radius: CGFloat = 30) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }

    func glassCapsule() -> some View { modifier(GlassSurface(shape: Capsule())) }

    func glassFill() -> some View { modifier(GlassSurface(shape: Rectangle())) }
}
