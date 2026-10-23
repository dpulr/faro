// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

struct BarraPage: View {
    @EnvironmentObject var engine: WallpaperEngine
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var speed: SpeedTest
    @EnvironmentObject var awake: KeepAwake

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Barra de menú",
                       subtitle: "Elige qué datos quieres ver siempre, sin abrir nada.")

            preview

            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(MenuBarMetric.allCases.enumerated()), id: \.element) { index, metric in
                        if index > 0 { Divider().padding(.horizontal, 12) }
                        row(metric)
                    }
                }
            }

            Card {
                Toggle(isOn: $engine.state.menuBarShowIcon) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mostrar el ícono de faro").font(.callout.weight(.medium))
                            Text("Si lo apagas y no eliges datos, el ícono aparece de todos modos.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .toggleStyle(MiniSwitchStyle())
            }
        }
    }

    private var preview: some View {
        HStack {
            Spacer()
            MenuBarLabel(engine: engine, monitor: monitor, speed: speed, awake: awake)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).frame(height: 30)
                .background(Capsule().fill(Color.black.opacity(0.82)))
            Spacer()
        }
        .padding(.vertical, 26)
        .background(RoundedRectangle(cornerRadius: 14).fill(
            LinearGradient(colors: [Theme.accent.opacity(0.35), Color(red: 0.34, green: 0.48, blue: 0.82).opacity(0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)))
    }

    private func row(_ metric: MenuBarMetric) -> some View {
        Toggle(isOn: Binding(
            get: { engine.state.menuBarMetrics.contains(metric) },
            set: { on in
                if on { engine.state.menuBarMetrics.insert(metric) } else { engine.state.menuBarMetrics.remove(metric) }
            })) {
            HStack(spacing: 12) {
                Image(systemName: metric.symbol).frame(width: 24).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(metric.title).font(.callout.weight(.medium))
                    Text(metric.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(MetricValue.text(metric, monitor: monitor, speed: speed))
                    .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(MiniSwitchStyle())
        .padding(12)
    }
}
