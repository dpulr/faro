// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import UserNotifications

/// Avisa cuando el espacio libre baja de un límite: una notificación (no más de una cada 12 horas, salvo que empeore mucho)
/// y una señal en el notch mientras siga bajo el límite.
@MainActor
final class DiskAlert: ObservableObject {
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "diskAlertEnabled")
            if enabled { requestAuthorization() }
        }
    }
    /// Límite en GB (decimales, como los muestra macOS).
    @Published var thresholdGB: Int { didSet { UserDefaults.standard.set(thresholdGB, forKey: "diskAlertGB") } }
    @Published private(set) var low = false
    @Published private(set) var notificationsDenied = false

    private var lastNotified: Date?
    private var lastNotifiedFree = Int64.max

    private var canNotify: Bool { Bundle.main.bundleIdentifier != nil } // fuera de un .app no hay centro de notificaciones

    init() {
        let d = UserDefaults.standard
        enabled = d.object(forKey: "diskAlertEnabled") as? Bool ?? true
        thresholdGB = d.integer(forKey: "diskAlertGB") == 0 ? 20 : d.integer(forKey: "diskAlertGB")
    }

    /// Decide si hay que avisar ahora (y recuerda que ya se avisó). Separada de la notificación para poder probarla.
    func evaluate(free: Int64, now: Date = Date()) -> Bool {
        let limit = Int64(thresholdGB) * 1_000_000_000
        guard enabled, free > 0 else { low = false; return false }
        low = free < limit
        guard low else {
            if free > limit * 12 / 10 { lastNotified = nil; lastNotifiedFree = .max } // se recuperó: el próximo descenso vuelve a avisar
            return false
        }
        let longAgo = lastNotified.map { now.timeIntervalSince($0) > 12 * 3600 } ?? true
        let muchPeor = free < lastNotifiedFree / 2
        guard longAgo || muchPeor else { return false }
        lastNotified = now
        lastNotifiedFree = free
        return true
    }

    func check(free: Int64) {
        guard evaluate(free: free) else { return }
        notify(free: free)
    }

    func requestAuthorization() {
        guard canNotify else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor in self.refreshAuthorization() }
        }
    }

    func refreshAuthorization() {
        guard canNotify else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let denied = settings.authorizationStatus == .denied
            Task { @MainActor in self.notificationsDenied = denied }
        }
    }

    /// Aviso preventivo: según el ritmo de los últimos días, el disco se llenaría pronto.
    func notifyFillSoon(days: Int) {
        guard enabled, canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = tr("Tu disco se está llenando")
        content.body = String(format: tr("A este ritmo se llenará en unos %lld días. Abre faro para ver qué puedes limpiar."), days)
        content.sound = .default
        content.userInfo = ["page": Page.almacenamiento.rawValue]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "faro.diskforecast", content: content, trigger: nil))
    }

    private func notify(free: Int64) {
        guard canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = tr("Poco espacio en disco")
        content.body = String(format: tr("Solo quedan %@. Abre faro para ver qué puedes limpiar."), Format.bytes(free))
        content.sound = .default
        content.userInfo = ["page": Page.almacenamiento.rawValue]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "faro.lowdisk", content: content, trigger: nil))
    }
}
