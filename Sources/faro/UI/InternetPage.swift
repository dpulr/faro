// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI
import Charts

struct InternetPage: View {
    @EnvironmentObject var speed: SpeedTest
    @EnvironmentObject var extras: NotchExtras

    private let autoOptions: [(String, Int)] = [
        ("Nunca", 0), ("Cada 30 minutos", 30), ("Cada hora", 60), ("Cada 3 horas", 180),
        ("Cada 6 horas", 360), ("Cada 12 horas", 720), ("Cada día", 1440),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Internet", subtitle: "Mide tu conexión y mira cómo cambia a lo largo del día.")
            status
            latest
            automation
            if speed.history.count > 1 { chart }
            if !speed.history.isEmpty { log }
        }
    }

    private var latest: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(speed.last.map { quality($0.downMbps) } ?? tr("Sin mediciones"))
                            .font(.title3.weight(.semibold))
                        Text(speed.last.map { String(format: tr("Medido %@"), Format.relative($0.date)) } ?? tr("Haz tu primera medición"))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { speed.run() } label: {
                        if speed.running {
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Midiendo…") }
                        } else {
                            Label("Medir ahora", systemImage: "speedometer")
                        }
                    }
                    .buttonStyle(PillButtonStyle(prominent: true)).disabled(speed.running)
                }
                if let last = speed.last {
                    HStack(spacing: 0) {
                        stat("Bajada", String(format: "%.0f", last.downMbps), "Mb/s")
                        stat("Subida", String(format: "%.0f", last.upMbps), "Mb/s")
                        stat("Respuesta", String(format: "%.0f", last.latencyMs), "ms")
                    }
                }
                if let error = speed.error { Text(error).font(.callout).foregroundStyle(Theme.critical) }
            }
        }
    }

    private var status: some View {
        let connection = extras.connection
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: connection.issue == .offline ? "wifi.slash" : "wifi")
                        .font(.title3).foregroundStyle(connection.issue == nil ? Theme.accent : Theme.critical)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(connection.headline).font(.title3.weight(.semibold))
                        if !connection.detail.isEmpty { Text(connection.detail).font(.callout).foregroundStyle(.secondary) }
                    }
                    Spacer()
                }
                if connection.latencyHistory.count > 2 {
                    Chart(Array(connection.latencyHistory.enumerated()), id: \.offset) { point in
                        LineMark(x: .value("n", point.offset), y: .value("ms", point.element))
                            .interpolationMethod(.monotone).foregroundStyle(Theme.accent)
                    }
                    .chartXAxis(.hidden).chartYAxisLabel("ms").frame(height: 70)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avisar de problemas de conexión").font(.callout.weight(.medium))
                        Text("Un aviso en el notch si se cae internet, se pone lento, la VPN se desconecta o el Wi‑Fi se debilita.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { connection.alertsEnabled }, set: { connection.alertsEnabled = $0 }))
                        .toggleStyle(MiniSwitchStyle()).labelsHidden()
                }
            }
        }
    }

    private func stat(_ title: LocalizedStringKey, _ value: String, _ unit: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.callout).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 36, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(unit).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var automation: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Medir automáticamente").font(.callout.weight(.semibold))
                    Text("Cada medición usa algunos cientos de MB y dura menos de 20 segundos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Choice(selection: $speed.autoMinutes, options: autoOptions)
            }
        }
    }

    private var chart: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Velocidad de bajada").font(.callout.weight(.semibold))
                Chart(speed.history.prefix(60).reversed()) { r in
                    AreaMark(x: .value("Fecha", r.date), y: .value("Mb/s", r.downMbps))
                        .interpolationMethod(.monotone).foregroundStyle(Theme.accent.opacity(0.15))
                    LineMark(x: .value("Fecha", r.date), y: .value("Mb/s", r.downMbps))
                        .interpolationMethod(.monotone).foregroundStyle(Theme.accent)
                    PointMark(x: .value("Fecha", r.date), y: .value("Mb/s", r.downMbps))
                        .foregroundStyle(Theme.accent).symbolSize(24)
                }
                .chartYAxisLabel("Mb/s")
                .frame(height: 180)
            }
        }
    }

    private var log: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Historial").font(.callout.weight(.semibold))
                    Spacer()
                    Button("Borrar") { speed.clearHistory() }.buttonStyle(.link).font(.caption)
                }
                ForEach(speed.history.prefix(8)) { r in
                    HStack {
                        Text(r.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "↓ %.0f   ↑ %.0f   %.0f ms", r.downMbps, r.upMbps, r.latencyMs))
                            .monospacedDigit()
                    }
                    .font(.callout)
                    Divider()
                }
            }
        }
    }

    private func quality(_ down: Double) -> String {
        switch down {
        case 100...: return tr("Conexión excelente")
        case 25..<100: return tr("Conexión buena")
        case 10..<25: return tr("Conexión aceptable")
        default: return "Conexión lenta"
        }
    }
}
