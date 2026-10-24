// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import UserNotifications

/// Avisa cuando hay una versión nueva. Pide un solo archivo público (`latest.json` del sitio de faro) una vez al día:
/// no envía identificadores ni datos del Mac, y nunca instala nada por su cuenta.
@MainActor
final class UpdateChecker: ObservableObject {
    struct Release: Equatable {
        var version: String
        var notes: String
        var url: URL
    }

    enum State: Equatable {
        case idle, checking, upToDate, available(Release), failed
    }

    /// El dominio oficial sirve el feed; `FARO_UPDATE_FEED` permite sustituirlo solo durante pruebas.
    static let feed = URL(string: ProcessInfo.processInfo.environment["FARO_UPDATE_FEED"] ?? "https://faro.conectalab.co/download/latest.json")!

    @Published var automatic: Bool {
        didSet {
            UserDefaults.standard.set(automatic, forKey: "updatesAutomatic")
            if automatic { Task { await check(manual: false) } }
        }
    }
    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheck: Date?

    let current: String
    var feed = UpdateChecker.feed
    private var timer: Timer?
    /// Las pruebas no deben lanzar notificaciones.
    var silent = false

    private var canNotify: Bool { Bundle.main.bundleIdentifier != nil }

    init(current: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0") {
        self.current = current
        automatic = UserDefaults.standard.object(forKey: "updatesAutomatic") as? Bool ?? true
        lastCheck = UserDefaults.standard.object(forKey: "updatesLastCheck") as? Date
    }

    /// Primera comprobación poco después de arrancar y luego una vez al día.
    func start() {
        Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            await check(manual: false)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check(manual: false) }
        }
    }

    /// `true` si `candidate` es una versión posterior a `base` (compara número a número: 1.10 > 1.9).
    static func isNewer(_ candidate: String, than base: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = base.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    func check(manual: Bool) async {
        if !manual {
            guard automatic else { return }
            // Automático: como mucho una vez cada 20 horas.
            if let last = lastCheck, Date().timeIntervalSince(last) < 20 * 3600 { return }
        }
        state = .checking
        do {
            var request = URLRequest(url: feed, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("faro/\(current)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let feed = try JSONDecoder().decode(Feed.self, from: data)
            lastCheck = Date()
            UserDefaults.standard.set(lastCheck, forKey: "updatesLastCheck")
            if Self.isNewer(feed.version, than: current), let url = feed.pageURL(language: AppLanguage.activeCode) {
                let release = Release(version: feed.version, notes: feed.notes(language: AppLanguage.activeCode), url: url)
                state = .available(release)
                notifyOnce(release)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed
        }
    }

    private func notifyOnce(_ release: Release) {
        let defaults = UserDefaults.standard
        guard canNotify, !silent, defaults.string(forKey: "updatesNotified") != release.version else { return }
        defaults.set(release.version, forKey: "updatesNotified")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(format: tr("faro %@ está disponible"), release.version)
            content.body = tr("Abre faro → General para descargarla.")
            content.userInfo = ["page": Page.general.rawValue]
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "faro.update", content: content, trigger: nil))
        }
    }

    /// Formato de `latest.json` (lo genera `site/build.mjs`).
    private struct Feed: Decodable {
        var version: String
        var page: [String: String]?
        var notes: [String: String]?

        func pageURL(language: String) -> URL? {
            let key = language.hasPrefix("en") ? "en" : "es"
            return (page?[key] ?? page?["es"]).flatMap(URL.init(string:))
        }

        func notes(language: String) -> String {
            let key = language.hasPrefix("en") ? "en" : "es"
            return notes?[key] ?? notes?["es"] ?? ""
        }
    }
}
