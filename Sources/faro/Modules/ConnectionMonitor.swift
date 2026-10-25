// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import Network
import CoreWLAN

/// Vigila la conexión: si hay red, por dónde sale (Wi‑Fi, cable), si hay una VPN, qué tan fuerte es la señal y cuánto
/// tarda en responder internet. Avisa de lo que importa (se cayó, volvió, se puso lenta, la VPN se desconectó).
@MainActor
final class ConnectionMonitor: ObservableObject {
    enum Link: String { case wifi, ethernet, other, none }

    struct Reading: Equatable {
        var online = true
        var link: Link = .other
        var vpn = false
        var rssi: Int?
        var latencyMs: Double?
    }

    enum Issue: Equatable {
        case offline, vpnDropped, slow, weakWiFi
    }

    enum Alert: Equatable {
        case lost, restored, vpnDropped, slow, weakWiFi
    }

    @Published private(set) var reading = Reading()
    @Published private(set) var issue: Issue?
    @Published private(set) var latencyHistory: [Double] = []
    @Published var alertsEnabled: Bool { didSet { UserDefaults.standard.set(alertsEnabled, forKey: "connectionAlerts") } }
    var onAlert: ((Alert) -> Void)?

    // Umbrales: una lectura mala suelta no avisa, hace falta que se repita.
    static let slowMs = 300.0
    static let weakDbm = -78
    static let confirmations = 3
    static let vpnGrace: TimeInterval = 600

    private let pathMonitor = NWPathMonitor()
    private var path: NWPath?
    private var timer: Timer?
    private var failedProbes = 0, slowStreak = 0, weakStreak = 0
    private var vpnDropAt: Date?
    private var started = false

    init() {
        alertsEnabled = UserDefaults.standard.object(forKey: "connectionAlerts") as? Bool ?? true
    }

    func start() {
        guard !started else { return }
        started = true
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.path = path; self?.sample() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "faro.connection"))
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        timer?.tolerance = 5
        sample()
    }

    func stop() {
        pathMonitor.cancel()
        timer?.invalidate()
        started = false
    }

    // MARK: Lectura

    private func sample() {
        let satisfied = path?.status != .unsatisfied
        let link: Link = !satisfied ? .none : (path?.usesInterfaceType(.wifi) == true ? .wifi
                         : path?.usesInterfaceType(.wiredEthernet) == true ? .ethernet : .other)
        let vpn = Self.hasVPN()
        let rssi = link == .wifi ? Self.wifiRSSI() : nil
        guard satisfied else {
            apply(Reading(online: false, link: .none, vpn: vpn, rssi: nil, latencyMs: nil), probeFailed: false)
            return
        }
        Self.probe { [weak self] ms in
            Task { @MainActor in
                self?.apply(Reading(online: true, link: link, vpn: vpn, rssi: rssi, latencyMs: ms), probeFailed: ms == nil)
            }
        }
    }

    /// Une la lectura nueva con lo anterior y decide si hay un problema y si vale la pena avisar.
    func apply(_ new: Reading, probeFailed: Bool, now: Date = Date()) {
        var next = new
        failedProbes = probeFailed ? failedProbes + 1 : 0
        // Una sonda que falla una vez puede ser ruido; dos seguidas es que no hay internet.
        if probeFailed, failedProbes < 2 { next.online = reading.online }
        else if probeFailed { next.online = false }
        if let ms = next.latencyMs {
            latencyHistory.append(ms)
            if latencyHistory.count > 40 { latencyHistory.removeFirst(latencyHistory.count - 40) }
        }
        slowStreak = (next.latencyMs ?? 0) > Self.slowMs ? slowStreak + 1 : 0
        weakStreak = (next.rssi.map { $0 != 0 && $0 < Self.weakDbm } ?? false) ? weakStreak + 1 : 0
        if reading.vpn, !next.vpn, next.online { vpnDropAt = now }
        if next.vpn { vpnDropAt = nil }
        let dropRecent = vpnDropAt.map { now.timeIntervalSince($0) < Self.vpnGrace } ?? false
        let found = Self.issue(online: next.online, slow: slowStreak >= Self.confirmations,
                               weak: weakStreak >= Self.confirmations, vpnDropped: dropRecent)
        let alert = Self.alert(from: issue, to: found)
        reading = next
        issue = found
        if let alert, alertsEnabled { onAlert?(alert) }
    }

    /// El problema más importante, si lo hay.
    nonisolated static func issue(online: Bool, slow: Bool, weak: Bool, vpnDropped: Bool) -> Issue? {
        if !online { return .offline }
        if vpnDropped { return .vpnDropped }
        if slow { return .slow }
        if weak { return .weakWiFi }
        return nil
    }

    /// Qué avisar al pasar de un estado a otro: solo cuando algo cambia, no cada 15 segundos.
    nonisolated static func alert(from old: Issue?, to new: Issue?) -> Alert? {
        guard old != new else { return nil }
        switch (old, new) {
        case (_, .offline?): return .lost
        case (.offline?, nil): return .restored
        case (_, .vpnDropped?): return .vpnDropped
        case (_, .slow?): return .slow
        case (_, .weakWiFi?): return .weakWiFi
        default: return nil
        }
    }

    // MARK: Datos del sistema

    /// Una VPN crea una interfaz `utun` con dirección IPv4; las `utun` solo con IPv6 son del propio sistema.
    nonisolated static func hasVPN() -> Bool {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return false }
        defer { freeifaddrs(head) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
                  Int32(ifa.ifa_flags) & IFF_UP != 0 else { continue }
            if String(cString: ifa.ifa_name).hasPrefix("utun") { return true }
        }
        return false
    }

    /// Señal del Wi‑Fi en dBm (0 o nula si no está conectado).
    nonisolated static func wifiRSSI() -> Int? {
        guard let interface = CWWiFiClient.shared().interface(), interface.powerOn() else { return nil }
        let value = interface.rssiValue()
        return value == 0 ? nil : value
    }

    /// Tiempo en abrir una conexión con 1.1.1.1:443; `nil` si no responde en 3 s.
    nonisolated static func probe(_ done: @escaping @Sendable (Double?) -> Void) {
        let connection = NWConnection(host: "1.1.1.1", port: 443, using: .tcp)
        let start = DispatchTime.now()
        let finished = LockedFlag()
        @Sendable func finish(_ value: Double?) {
            guard finished.setOnce() else { return }
            connection.cancel()
            done(value)
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready: finish(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
            case .failed, .cancelled: finish(nil)
            default: break
            }
        }
        connection.start(queue: .global(qos: .utility))
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { finish(nil) }
    }

    // MARK: Para mostrar

    var linkName: String {
        switch reading.link {
        case .wifi: return "Wi‑Fi"
        case .ethernet: return tr("Cable")
        case .other: return tr("Red")
        case .none: return tr("Sin conexión")
        }
    }

    var signalName: String? {
        guard let rssi = reading.rssi else { return nil }
        switch rssi {
        case (-60)...: return tr("señal excelente")
        case (-70)..<(-60): return tr("señal buena")
        case (-78)..<(-70): return tr("señal regular")
        default: return tr("señal débil")
        }
    }

    var headline: String {
        switch issue {
        case .offline: return tr("Sin internet")
        case .vpnDropped: return tr("La VPN se desconectó")
        case .slow: return tr("Internet va lento")
        case .weakWiFi: return tr("Wi‑Fi con señal débil")
        case nil: return reading.latencyMs.map { String(format: tr("%@ · %lld ms"), linkName, Int($0.rounded())) } ?? linkName
        }
    }

    var detail: String {
        switch issue {
        case .offline: return tr("Revisa el router o el cable.")
        case .vpnDropped: return tr("Tu tráfico sale sin la VPN.")
        case .slow: return String(format: tr("Responde en %lld ms."), Int((reading.latencyMs ?? 0).rounded()))
        case .weakWiFi: return tr("Acércate al router.")
        case nil: return ([signalName, reading.vpn ? "VPN" : nil].compactMap { $0 }).joined(separator: " · ")
        }
    }

    /// Mensaje corto del aviso del notch.
    func message(for alert: Alert) -> (symbol: String, text: String) {
        switch alert {
        case .lost: return ("wifi.slash", tr("Se perdió la conexión a internet"))
        case .restored: return ("wifi", tr("Internet volvió"))
        case .vpnDropped: return ("lock.open", tr("La VPN se desconectó"))
        case .slow: return ("tortoise", tr("Internet va lento"))
        case .weakWiFi: return ("wifi.exclamationmark", tr("Wi‑Fi con señal débil"))
        }
    }
}

/// Bandera de un solo uso, segura entre hilos.
final class LockedFlag: @unchecked Sendable {
    private var done = false
    private let lock = NSLock()
    func setOnce() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
}
