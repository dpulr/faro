// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Pestaña «Equipo» del notch: estado del Mac, conexión, cargador, ventiladores y discos externos con botón de expulsar.
/// Vive aparte para no cargar la pestaña de inicio.
struct EquipoNotchSection: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var extras: NotchExtras
    @ObservedObject var diagnostics: DiagnosticsModel
    @ObservedObject var volumes: ConnectedVolumes
    @ObservedObject var connection: ConnectionMonitor
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) { statusCard; connectionCard }
            HStack(spacing: 8) { chargerCard; fansCard }
            volumesCard
        }
        .task {
            while !Task.isCancelled {
                diagnostics.refresh(monitor: monitor)
                volumes.refresh()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        .onChange(of: volumes.lastResult?.name) { _, _ in
            guard let result = volumes.lastResult else { return }
            model.showToast(symbol: result.error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                            text: result.error == nil ? String(format: tr("Ya puedes desconectar %@"), result.name)
                                                      : String(format: tr("No se pudo expulsar %@: está en uso"), result.name), seconds: 5)
        }
    }

    // MARK: Tarjetas

    private var statusCard: some View {
        let top = diagnostics.topIssue
        return card(symbol: top?.symbol ?? "checkmark.circle", title: tr("Estado"),
                    headline: top?.title ?? tr("Todo en orden"),
                    detail: top?.detail ?? tr("Memoria, procesador, disco y temperatura bien."), warn: top != nil)
    }

    private var connectionCard: some View {
        card(symbol: connection.issue == .offline ? "wifi.slash" : "wifi", title: tr("Conexión"),
             headline: connection.headline, detail: connection.detail, warn: connection.issue != nil)
    }

    @ViewBuilder private var chargerCard: some View {
        let charger = diagnostics.charger
        if charger.connected, let verdict = diagnostics.verdict {
            let into = charger.systemIn.map { String(format: "%.0f W", $0) }
            card(symbol: "bolt.fill", title: tr("Cargador"),
                 headline: [into, charger.adapterWatts.map { String(format: tr("de %lld W"), $0) }].compactMap { $0 }.joined(separator: " "),
                 detail: verdict.title, warn: verdict.severity != .info)
        } else {
            card(symbol: "bolt.slash", title: tr("Cargador"), headline: tr("Sin cargador"),
                 detail: monitor.hasBattery ? String(format: tr("Batería al %lld%%"), monitor.batteryPercent ?? 0) : tr("Este Mac no usa batería"), warn: false)
        }
    }

    @ViewBuilder private var fansCard: some View {
        if diagnostics.analyzed == nil {
            card(symbol: "fan", title: tr("Ventiladores"), headline: "…", detail: tr("Leyendo…"), warn: false)
        } else if diagnostics.fans.isEmpty {
            card(symbol: "fan", title: tr("Ventiladores"), headline: tr("Sin ventiladores"), detail: tr("Este Mac se enfría sin ellos."), warn: false)
        } else {
            let hot = diagnostics.fans.contains { $0.load > 0.8 }
            card(symbol: "fan", title: tr("Ventiladores"),
                 headline: diagnostics.fans.map { "\(Int($0.rpm.rounded()))" }.joined(separator: " · ") + " rpm",
                 detail: hot ? tr("Trabajando fuerte") : tr("Tranquilos"), warn: hot)
        }
    }

    private var volumesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "externaldrive").font(.system(size: 11, weight: .semibold))
                Text("Discos externos").font(.system(size: 10, weight: .semibold)).textCase(.uppercase)
                Spacer()
                if volumes.volumes.count > 1 { pill(tr("Expulsar todos")) { volumes.ejectAll() } }
            }
            .foregroundStyle(.white.opacity(0.55))
            if volumes.volumes.isEmpty {
                Text("Conecta un disco o una memoria y aparecerá aquí.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            ForEach(volumes.volumes.prefix(3)) { volume in
                HStack(spacing: 8) {
                    Image(systemName: volume.symbol).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(volume.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        Text(String(format: tr("%@ libres · %@"), Format.bytes(volume.free), volume.connection))
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if volumes.ejecting.contains(volume.url) { ProgressView().controlSize(.small) }
                    else { pill(tr("Expulsar"), prominent: true) { volumes.eject(volume) } }
                }
            }
            if volumes.volumes.count > 3 {
                Text(String(format: tr("%lld más"), Int64(volumes.volumes.count - 3))).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.055)))
    }

    // MARK: Piezas

    private func card(symbol: String, title: String, headline: String, detail: String, warn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(warn ? Color.orange : .white.opacity(0.55))
                Text(title).font(.system(size: 10, weight: .semibold)).textCase(.uppercase).foregroundStyle(.white.opacity(0.55))
            }
            Text(headline).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            Text(detail).font(.system(size: 10)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.055)))
    }

    private func pill(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .foregroundStyle(prominent ? Color.black : Color.white)
                .background(Capsule().fill(prominent ? Theme.accent : Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}
