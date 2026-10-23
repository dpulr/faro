// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

struct SistemaPage: View {
    @EnvironmentObject var monitor: SystemMonitor
    @AppStorage("page") private var page = Page.fondos.rawValue

    var body: some View {
        let health = monitor.health
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Sistema", subtitle: "Cómo está tu Mac en este momento, actualizado cada pocos segundos.")

            Card {
                HStack(spacing: 12) {
                    Circle().fill(Theme.color(health.level)).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(health.title).font(.title3.weight(.semibold))
                        Text(health.detail).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if health.level != .ok {
                        Button("Liberar espacio") { page = Page.almacenamiento.rawValue }.buttonStyle(PillButtonStyle())
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                metricCard("Procesador", value: "\(Int(monitor.cpu.rounded()))%", note: "del procesador en uso",
                           tint: Theme.usage(monitor.cpu / 100), series: monitor.cpuHistory, top: 1)
                metricCard("Memoria", value: "\(Int((monitor.memFraction * 100).rounded()))%",
                           note: "\(Format.memory(monitor.memUsed)) de \(Format.memory(monitor.memTotal))",
                           tint: Theme.usage(monitor.memFraction), series: monitor.memHistory, top: 1)
                storageCard
                networkCard
                if monitor.hasBattery { batteryCard }
            }
        }
    }

    private func metricCard(_ title: String, value: String, note: String, tint: Color,
                            series: [Double], top: Double) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.callout).foregroundStyle(.secondary)
                Text(value).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(note).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Sparkline(values: series, tint: tint, maxValue: top).frame(height: 54)
            }
            .frame(height: 190, alignment: .topLeading)
        }
    }

    private var storageCard: some View {
        let tint = Theme.usage(monitor.diskUsedFraction)
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Almacenamiento").font(.callout).foregroundStyle(.secondary)
                Text(Format.bytes(monitor.diskFree)).font(.system(size: 34, weight: .semibold, design: .rounded))
                Text("libres de \(Format.bytes(monitor.diskTotal))").font(.caption).foregroundStyle(.secondary)
                UsageBar(value: monitor.diskUsedFraction, tint: tint).padding(.top, 14)
                Spacer(minLength: 0)
                Button("Analizar y liberar espacio") { page = Page.almacenamiento.rawValue }
                    .buttonStyle(.link).font(.caption)
            }
            .frame(height: 190, alignment: .topLeading)
        }
    }

    private var networkCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Red en vivo").font(.callout).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    Label(Format.rate(monitor.netDown), systemImage: "arrow.down")
                    Label(Format.rate(monitor.netUp), systemImage: "arrow.up")
                }
                .font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                .padding(.top, 6)
                Text("Lo que tu Mac descarga y envía ahora").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Sparkline(values: monitor.netDownHistory, tint: Theme.accent, maxValue: nil).frame(height: 54)
            }
            .frame(height: 190, alignment: .topLeading)
        }
    }

    private var batteryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Batería").font(.callout).foregroundStyle(.secondary)
                Text("\(monitor.batteryPercent ?? 0)%").font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(monitor.batteryCharging ? "Cargando" : "Usando la batería").font(.caption).foregroundStyle(.secondary)
                UsageBar(value: Double(monitor.batteryPercent ?? 0) / 100,
                         tint: (monitor.batteryPercent ?? 100) <= 20 ? Theme.critical : Theme.accent).padding(.top, 14)
                HStack {
                    if let cycles = monitor.batteryCycles { Text("\(cycles) ciclos de carga") }
                    Spacer()
                    if let health = monitor.batteryHealth { Text("Salud \(health)%") }
                }
                .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                Spacer(minLength: 0)
            }
            .frame(height: 190, alignment: .topLeading)
        }
    }
}
