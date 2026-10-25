// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Widget de conexión del notch: solo aparece cuando hay algo que decir (sin internet, lento, VPN caída, señal débil).
struct ConnectionNotchWidget: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var connection: ConnectionMonitor
    @ObservedObject var speed: SpeedTest

    private var symbol: String {
        switch connection.issue {
        case .offline: "wifi.slash"
        case .vpnDropped: "lock.open"
        case .slow: "tortoise"
        case .weakWiFi: "wifi.exclamationmark"
        case nil: "wifi"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                Text(connection.headline).font(.system(size: 16, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            Text(connection.detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            Spacer(minLength: 0)
            if speed.running { ProgressView().controlSize(.small) }
            else if connection.issue == .offline { pill(tr("Abrir")) { open() } }
            else { pill(tr("Medir velocidad"), prominent: true) { speed.run() } }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
    }

    private func open() { model.collapse?(); AppController.shared.openMain(.internet) }

    private func pill(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .foregroundStyle(prominent ? Color.black : Color.white)
                .background(Capsule().fill(prominent ? Theme.accent : Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}
