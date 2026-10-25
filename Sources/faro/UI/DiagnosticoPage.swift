// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Qué le está frenando al Mac ahora mismo y cómo van el cargador y los dispositivos conectados.
struct DiagnosticoPage: View {
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var extras: NotchExtras
    private var model: DiagnosticsModel { extras.diagnostics }
    private var volumes: ConnectedVolumes { extras.volumesList }
    @AppStorage("page") private var page = Page.fondos.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Diagnóstico", subtitle: "Qué frena a tu Mac ahora mismo y cómo van el cargador y tus dispositivos.")
            verdictCard
            if model.findings.count > (model.topIssue == nil ? 0 : 1) { findingsList }
            chargerCard
            if !model.ports.isEmpty { portsCard }
            volumesCard
            if !model.fans.isEmpty { fansCard }
            devicesCard
        }
        .task {
            while !Task.isCancelled {
                model.refresh(monitor: monitor)
                extras.devices.refresh()
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    // MARK: Veredicto

    private var verdictCard: some View {
        let top = model.topIssue
        return Card {
            HStack(spacing: 14) {
                Image(systemName: top?.symbol ?? "checkmark.circle.fill").font(.title2)
                    .foregroundStyle(top.map { tint($0.severity) } ?? Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(top?.title ?? tr("Todo en orden")).font(.title3.weight(.semibold))
                    Text(top?.detail ?? tr("Memoria, procesador, disco, temperatura y energía están bien.")).foregroundStyle(.secondary)
                    if let when = model.analyzed {
                        Text(String(format: tr("Analizado %@"), Format.relative(when))).font(.caption).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if let action = top?.action { Button(label(action)) { run(action) }.buttonStyle(PillButtonStyle(prominent: true)) }
                Button { model.refresh(monitor: monitor) } label: {
                    if model.running { ProgressView().controlSize(.small) } else { Label("Analizar", systemImage: "arrow.clockwise") }
                }
                .buttonStyle(PillButtonStyle()).disabled(model.running)
            }
        }
    }

    private var findingsList: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Otros avisos").font(.callout.weight(.semibold))
                ForEach(model.findings.filter { $0.id != model.topIssue?.id }) { finding in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: finding.symbol).foregroundStyle(tint(finding.severity)).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(finding.title).font(.callout.weight(.medium))
                            Text(finding.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let action = finding.action { Button(label(action)) { run(action) }.buttonStyle(.link).font(.caption) }
                    }
                }
            }
        }
    }

    // MARK: Cargador

    private var chargerCard: some View {
        let charger = model.charger
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: charger.connected ? "bolt.fill" : "bolt.slash").foregroundStyle(charger.connected ? Theme.accent : .secondary)
                    Text("Cargador").font(.callout.weight(.semibold))
                    Spacer()
                    if let name = charger.adapterName, charger.connected { Text(name).font(.caption).foregroundStyle(.secondary) }
                }
                if charger.connected {
                    HStack(spacing: 0) {
                        flow("Cargador", charger.adapterWatts.map { "\($0)" }, "W")
                        flow("Llegan al Mac", charger.systemIn.map { String(format: "%.0f", $0) }, "W")
                        flow("A la batería", charger.battery.map { String(format: "%.0f", max($0, 0)) }, "W")
                        flow("Gasta el Mac", charger.systemLoad.map { String(format: "%.0f", $0) }, "W")
                    }
                    if !charger.options.isEmpty { offers(charger) }
                    if let verdict = model.verdict {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verdict.title).font(.callout.weight(.medium)).foregroundStyle(tint(verdict.severity, quiet: true))
                            Text(verdict.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(monitor.hasBattery ? "Sin cargador conectado. Enchúfalo y te digo cuánta energía le llega a tu Mac."
                                            : "Este Mac no tiene batería, así que no hay cargador que analizar.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Las potencias que ofrece el cargador, con la que negoció el Mac resaltada.
    private func offers(_ charger: ChargerReading) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Potencias que ofrece el cargador").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Array(charger.options.enumerated()), id: \.offset) { index, option in
                    let chosen = index == charger.selected
                    Text(String(format: "%.0f V · %.0f W", option.volts, option.watts)).font(.caption.monospacedDigit())
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(chosen ? Theme.accent.opacity(0.2) : Color.primary.opacity(0.06)))
                        .overlay(Capsule().strokeBorder(chosen ? Theme.accent : Color.clear))
                }
            }
            Text("Resaltada, la que negoció tu Mac. macOS actualiza estos datos más o menos cada minuto.").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func flow(_ title: LocalizedStringKey, _ value: String?, _ unit: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value ?? "—").font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                if value != nil { Text(unit).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Puertos

    private var portsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Puertos").font(.callout.weight(.semibold))
                ForEach(model.ports) { port in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Image(systemName: port.isMagSafe ? "powerplug" : "cable.connector").frame(width: 22)
                                .foregroundStyle(port.connected ? Theme.accent : Color.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(port.title).font(.callout)
                                Text(port.capability).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if port.liquidDetected {
                                Label("Humedad", systemImage: "drop.fill").font(.caption).foregroundStyle(Theme.critical)
                            }
                            Text(port.activity).font(.callout).foregroundStyle(port.connected ? Color.primary : Color.secondary)
                        }
                        if port.connected { portDetail(port) }
                    }
                    if port.id != model.ports.last?.id { Divider() }
                }
            }
        }
    }

    @ViewBuilder private func portDetail(_ port: PortInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(port.devices) { device in
                detailLine("externaldrive", "\(device.name) · \(device.speedName)")
            }
            if let cable = port.cable {
                detailLine("cable.connector.horizontal", String(format: tr("Cable %@ · %@ · %@ A / %lld V (%lld W) · %@"),
                                                                cable.active ? tr("activo") : tr("pasivo"), cable.speedName,
                                                                cable.currentAmps == cable.currentAmps.rounded() ? String(Int(cable.currentAmps)) : String(cable.currentAmps),
                                                                cable.maxVolts, cable.maxWatts, cable.vendor))
            } else if !port.devices.isEmpty {
                detailLine("cable.connector.horizontal", tr("El cable no se identifica (sin chip)."))
            }
            if let partner = port.partner, !partner.kind.isEmpty { detailLine("link", partner.kind) }
            if let link = LinkAnalysis.verdict(for: port) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(link.title).font(.callout.weight(.medium)).foregroundStyle(link.level == .limited ? Color.orange : Theme.accent)
                    Text(link.detail).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.leading, 34)
    }

    private func detailLine(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.caption).foregroundStyle(.secondary).frame(width: 14)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Discos

    private var volumesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Discos y volúmenes").font(.callout.weight(.semibold))
                    Spacer()
                    if volumes.volumes.count > 1 {
                        Button("Expulsar todos") { volumes.ejectAll() }.buttonStyle(.link).font(.caption)
                    }
                }
                if volumes.volumes.isEmpty {
                    Text("Conecta un disco, una memoria o una tarjeta SD y aparecerá aquí para expulsarlo.").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(volumes.volumes) { volume in
                    HStack(spacing: 12) {
                        Image(systemName: volume.symbol).frame(width: 22).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(volume.name).font(.callout)
                            Text([volume.connection, volume.model].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(String(format: tr("%@ libres de %@"), Format.bytes(volume.free), Format.bytes(volume.total)))
                                .font(.caption).foregroundStyle(.secondary)
                            UsageBar(value: volume.usedFraction, tint: volume.usedFraction > 0.9 ? Theme.critical : Theme.accent).frame(width: 150)
                        }
                        if volumes.ejecting.contains(volume.url) {
                            ProgressView().controlSize(.small).frame(width: 72)
                        } else {
                            Button("Expulsar") { volumes.eject(volume) }.buttonStyle(PillButtonStyle()).frame(width: 90)
                        }
                    }
                }
                if let result = volumes.lastResult {
                    if let error = result.error {
                        Label(String(format: tr("No se pudo expulsar %@. %@"), result.name, error), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Theme.critical)
                    } else {
                        Label(String(format: tr("Ya puedes desconectar %@"), result.name), systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    // MARK: Ventiladores

    private var fansCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Ventiladores").font(.callout.weight(.semibold))
                    Spacer()
                    Text(thermalName).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.fans) { fan in
                    HStack(spacing: 12) {
                        Image(systemName: "fan").frame(width: 22).foregroundStyle(.secondary)
                        Text(String(format: tr("Ventilador %lld"), fan.index + 1)).font(.callout)
                        Spacer()
                        UsageBar(value: fan.load, tint: fan.load > 0.8 ? Theme.critical : Theme.accent).frame(width: 150)
                        Text("\(Int(fan.rpm.rounded())) rpm").font(.callout.weight(.semibold).monospacedDigit()).frame(width: 90, alignment: .trailing)
                    }
                }
                Text("Solo lectura: faro muestra los ventiladores pero no los controla.").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private var thermalName: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: tr("Temperatura normal")
        case .fair: tr("Algo caliente")
        case .serious: tr("Caliente: el Mac baja su velocidad")
        case .critical: tr("Muy caliente")
        @unknown default: ""
        }
    }

    // MARK: Dispositivos

    private var devicesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dispositivos conectados").font(.callout.weight(.semibold))
                if extras.devices.devices.isEmpty {
                    Text("Conecta AirPods, un teclado, un ratón o un trackpad para ver su carga.").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(extras.devices.devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: device.symbol).frame(width: 22).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(device.name).font(.callout)
                            if let detail = device.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        UsageBar(value: Double(device.percent) / 100, tint: device.percent <= 20 ? Theme.critical : Theme.accent).frame(width: 90)
                        if device.charging { Image(systemName: "bolt.fill").font(.caption).foregroundStyle(Theme.accent) }
                        Text("\(device.percent)%").font(.callout.weight(.semibold).monospacedDigit()).frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: Ayudas

    private func tint(_ severity: Finding.Severity, quiet: Bool = false) -> Color {
        switch severity {
        case .critical: Theme.critical
        case .warning: Color.orange
        case .info: quiet ? Color.primary : Theme.accent
        }
    }

    private func label(_ action: Finding.Action) -> LocalizedStringKey {
        switch action {
        case .storage: "Liberar espacio"
        case .activityMonitor: "Monitor de Actividad"
        case .energy: "Ver energía"
        }
    }

    private func run(_ action: Finding.Action) {
        switch action {
        case .storage: page = Page.almacenamiento.rawValue
        case .energy: page = Page.energia.rawValue
        case .activityMonitor: NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
        }
    }
}
