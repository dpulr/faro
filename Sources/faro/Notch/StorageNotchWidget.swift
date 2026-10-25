// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Widget de almacenamiento del notch: avisa de poco espacio o de que el disco se llena, y deja analizar y limpiar
/// lo seguro desde el propio panel (con una confirmación de un paso).
struct StorageNotchWidget: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var storage: StorageModel
    @ObservedObject var history: DiskHistory
    @ObservedObject var monitor: SystemMonitor

    @State private var confirming = false
    @State private var confirmTask: Task<Void, Never>?

    private var forecast: DiskHistory.Forecast? { history.forecast(free: monitor.diskFree) }

    private var headline: String {
        if let gb = model.lowDiskGB { return String(format: tr("Quedan %d GB"), gb) }
        if let days = forecast?.daysLeft { return String(format: tr("Se llena en ~%lld días"), days) }
        return String(format: tr("%@ libres"), Format.bytes(monitor.diskFree))
    }

    private var detail: String {
        if storage.scanning { return tr("Analizando tu Mac…") }
        if storage.working { return tr("Limpiando…") }
        if let message = storage.message, storage.didScan, !confirming, storage.safeBytes == 0 { return message }
        if !storage.didScan { return tr("Analiza para ver qué se puede limpiar.") }
        if storage.safeBytes > 0 { return String(format: tr("Puedes liberar %@ sin riesgo."), Format.bytes(storage.safeBytes)) }
        return tr("No hay nada seguro que limpiar.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive").font(.system(size: 11, weight: .semibold))
                Text("Almacenamiento").font(.system(size: 10, weight: .semibold)).textCase(.uppercase)
            }
            .foregroundStyle(.white.opacity(0.55))
            Text(headline).font(.system(size: 17, weight: .semibold)).lineLimit(1)
            Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
            Spacer(minLength: 0)
            HStack(spacing: 6) { buttons }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
    }

    @ViewBuilder private var buttons: some View {
        if storage.scanning || storage.working {
            ProgressView().controlSize(.small)
        } else if confirming {
            pill(String(format: tr("Confirmar · %@"), Format.bytes(storage.safeBytes)), prominent: true) {
                confirmTask?.cancel()
                confirming = false
                Task { await storage.cleanSafe() }
            }
            pill(tr("Cancelar")) { confirmTask?.cancel(); confirming = false }
        } else if !storage.didScan {
            pill(tr("Analizar"), prominent: true) { Task { await storage.scan() } }
            pill(tr("Abrir")) { open() }
        } else if storage.safeBytes > 0 {
            pill(String(format: tr("Limpiar · %@"), Format.bytes(storage.safeBytes)), prominent: true) { askToConfirm() }
            pill(tr("Abrir")) { open() }
        } else {
            pill(tr("Abrir")) { open() }
        }
    }

    private func pill(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                .padding(.horizontal, 11).padding(.vertical, 5)
                .foregroundStyle(prominent ? Color.black : Color.white)
                .background(Capsule().fill(prominent ? Theme.accent : Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }

    /// Un primer toque pide confirmar; si no se confirma en 6 segundos se cancela solo.
    private func askToConfirm() {
        confirming = true
        confirmTask?.cancel()
        confirmTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if !Task.isCancelled { confirming = false }
        }
    }

    private func open() {
        model.collapse?()
        AppController.shared.openMain(.almacenamiento)
    }
}
