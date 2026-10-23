// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

struct EnergiaPage: View {
    @EnvironmentObject var awake: KeepAwake

    private let durations: [(String, Double?)] = [
        ("30 min", 0.5), ("1 hora", 1), ("2 horas", 2), ("4 horas", 4), ("8 horas", 8), ("Sin límite", nil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Energía", subtitle: "Evita que la pantalla se apague y que tu Mac entre en reposo.")

            Card {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: awake.active ? "cup.and.saucer.fill" : "cup.and.saucer")
                            .font(.system(size: 22)).foregroundStyle(awake.active ? Theme.accent : .secondary)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill((awake.active ? Theme.accent : Theme.fill)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(awake.active ? "Tu Mac se mantiene despierto" : "Reposo normal")
                                .font(.title3.weight(.semibold))
                            Text(status).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if awake.active {
                            Button("Apagar") { awake.disable() }.buttonStyle(PillButtonStyle())
                        }
                    }
                    Divider()
                    Text(awake.active ? "Cambiar duración" : "Mantener despierto durante")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(durations, id: \.0) { d in
                            Button(d.0) { awake.enable(hours: d.1) }
                                .buttonStyle(PillButtonStyle(prominent: false))
                        }
                    }
                }
            }
        }
    }

    private var status: String {
        guard awake.active else { return "Elige por cuánto tiempo quieres mantenerlo despierto." }
        if let until = awake.until { return "Hasta las \(until.formatted(date: .omitted, time: .shortened))." }
        return "Hasta que lo apagues."
    }
}
