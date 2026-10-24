// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Charts
import SwiftUI

struct EnergiaPage: View {
    @EnvironmentObject var awake: KeepAwake
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var extras: NotchExtras

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
                            Button(LocalizedStringKey(d.0)) { awake.enable(hours: d.1) }
                                .buttonStyle(PillButtonStyle(prominent: false))
                        }
                    }
                }
            }

            if monitor.hasBattery { batteryCard }
        }
    }

    // MARK: Cuidar la batería

    private var batteryCard: some View {
        let alerts = extras.battery
        return Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "battery.75percent").font(.system(size: 22)).foregroundStyle(Theme.accent)
                        .frame(width: 48, height: 48).background(Circle().fill(Theme.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cuidar la batería").font(.title3.weight(.semibold))
                        Text(batterySummary).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(alerts.protecting ? "Protegida al 80%" : "Proteger al 80%") { alerts.protect(!alerts.protecting) }
                        .buttonStyle(PillButtonStyle(prominent: !alerts.protecting))
                }
                Text("Mantener la carga entre 20% y 80% reduce el desgaste. faro te avisa para que desenchufes; no puede limitar la carga por sí mismo.")
                    .font(.callout).foregroundStyle(.secondary)
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avisar al llegar a").font(.callout.weight(.medium))
                        Text("Un aviso en el notch para desenchufar.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if alerts.fullEnabled {
                        MenuChip(text: "\(alerts.fullLevel)%") {
                            ForEach([80, 85, 90, 95, 100], id: \.self) { level in
                                DropdownRow(title: "\(level)%", selected: level == alerts.fullLevel) { alerts.fullLevel = level }
                            }
                        }
                    }
                    Toggle("", isOn: Binding(get: { alerts.fullEnabled }, set: { alerts.fullEnabled = $0 }))
                        .toggleStyle(MiniSwitchStyle()).labelsHidden()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recordar si sigue enchufada").font(.callout.weight(.medium))
                        Text("Un aviso si pasan horas conectada con la batería casi llena.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if alerts.pluggedEnabled {
                        MenuChip(text: String(format: tr("%lld h"), alerts.pluggedHours)) {
                            ForEach([2, 3, 4, 8], id: \.self) { hours in
                                DropdownRow(title: String(format: tr("%lld h"), hours), selected: hours == alerts.pluggedHours) { alerts.pluggedHours = hours }
                            }
                        }
                    }
                    Toggle("", isOn: Binding(get: { alerts.pluggedEnabled }, set: { alerts.pluggedEnabled = $0 }))
                        .toggleStyle(MiniSwitchStyle()).labelsHidden()
                }
                Divider()
                healthHistory(alerts.history)
                HStack(spacing: 10) {
                    Text("Si tu macOS lo incluye, Ajustes del Sistema → Batería puede limitar la carga de verdad.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Abrir ajustes de batería") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") { NSWorkspace.shared.open(url) }
                    }.buttonStyle(PillButtonStyle(prominent: false))
                }
            }
        }
    }

    private var batterySummary: String {
        var parts: [String] = []
        if let health = monitor.batteryHealth { parts.append(String(format: tr("Salud %lld%%"), health)) }
        if let cycles = monitor.batteryCycles { parts.append(String(format: tr("%lld ciclos de carga"), cycles)) }
        if let percent = monitor.batteryPercent { parts.append("\(percent)%") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func healthHistory(_ points: [BatteryAlerts.HealthPoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Salud a lo largo del tiempo").font(.callout.weight(.medium))
            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(x: .value("Día", point.day), y: .value("Salud", point.health)).foregroundStyle(Theme.accent)
                    PointMark(x: .value("Día", point.day), y: .value("Salud", point.health)).foregroundStyle(Theme.accent)
                }
                .chartYScale(domain: ((points.map(\.health).min() ?? 80) - 3)...100)
                .chartXAxis(.hidden)
                .frame(height: 90)
            } else {
                Text("faro anota la salud de tu batería una vez al día; la gráfica aparece en cuanto haya dos días.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var status: String {
        guard awake.active else { return tr("Elige por cuánto tiempo quieres mantenerlo despierto.") }
        if let until = awake.until { return String(format: tr("Hasta las %@."), until.formatted(date: .omitted, time: .shortened)) }
        return tr("Hasta que lo apagues.")
    }
}
