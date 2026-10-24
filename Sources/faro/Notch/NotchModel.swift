// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import EventKit
import SwiftUI

struct Track: Equatable {
    var title: String
    var artist: String
    var source: String      // "Music" o "Spotify"
    var playing: Bool
    var artworkURL: URL?
}

struct Toast: Equatable {
    var symbol: String
    var text: String
    /// Texto del botón de acción (p. ej. "Expulsar"); la acción vive en `NotchModel.toastAction`.
    var actionLabel: String?
    /// Color de muestra en hexadecimal (gotero).
    var swatch: String?
}

struct EventInfo: Equatable {
    var title: String
    var start: Date
    var end: Date
    var allDay: Bool
}

struct WeatherInfo: Equatable {
    var temperature: Int
    var symbol: String
    var summary: String
    var city: String
}

/// Estado y ajustes del panel del notch: música, calendario, clima y descanso visual.
@MainActor
final class NotchModel: ObservableObject {
    // MARK: Ajustes (se guardan solos)
    @Published var enabled: Bool { didSet { save("notchEnabled", enabled) } }
    @Published var showMusic: Bool { didSet { save("notchMusic", showMusic); if !showMusic { track = nil } } }
    @Published var showCalendar: Bool { didSet { save("notchCalendar", showCalendar); refreshCalendar() } }
    @Published var showWeather: Bool { didSet { save("notchWeather", showWeather); Task { await refreshWeather() } } }
    @Published var eyeBreak: Bool { didSet { save("notchEyeBreak", eyeBreak); scheduleBreak() } }
    @Published var eyeBreakMinutes: Int { didSet { save("notchEyeMinutes", eyeBreakMinutes); scheduleBreak() } }
    @Published var city: String { didSet { save("notchCity", city) } }
    /// Si es cierto, el panel solo se despliega con un clic sobre el notch (no con solo pasar el cursor).
    @Published var openOnClick: Bool { didSet { save("notchOpenOnClick", openOnClick) } }
    @Published var showVolume: Bool { didSet { save("notchVolume", showVolume) } }
    @Published var showBluetooth: Bool {
        didSet {
            save("notchBluetooth", showBluetooth)
            if showBluetooth { bluetooth.start() } else { bluetooth.stop() }
        }
    }

    // MARK: Estado
    @Published var expanded = false
    @Published var expandedHeight: CGFloat = 160
    @Published var track: Track?
    @Published var artwork: NSImage?
    @Published var event: EventInfo?
    @Published var weather: WeatherInfo?
    @Published var calendarDenied = false
    @Published var weatherError: String?
    @Published var breakRemaining: Int?
    @Published var nextBreak: Date?
    /// GB libres mientras el disco esté bajo el límite del aviso; `nil` si todo va bien.
    @Published var lowDiskGB: Int?
    /// Aviso breve que cuelga del notch (p. ej. "AirPods conectados").
    @Published var toast: Toast?
    /// Hay un archivo arrastrándose cerca del notch: se muestra la zona para soltarlo.
    @Published var dropActive = false
    /// Lo que hace el botón del aviso actual.
    var toastAction: (() -> Void)?
    /// Se llama al conectarse un dispositivo Bluetooth (para refrescar su batería).
    var onBluetoothConnect: (() -> Void)?
    /// Recoge el panel desplegado (lo asigna el controlador).
    var collapse: (() -> Void)?
    /// Lo llama la zona de soltar con los archivos recibidos.
    var onFilesDropped: (([URL]) -> Void)?

    private var timer: Timer?
    private var toastTask: Task<Void, Never>?
    private let bluetooth = BluetoothWatcher()
    private var counter = 0
    private let store = EKEventStore()
    private var lastArtworkKey = ""

    var hasLive: Bool { (showMusic && track?.playing == true) || breakRemaining != nil || lowDiskGB != nil }

    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }

    init() {
        let d = UserDefaults.standard
        func flag(_ key: String, _ fallback: Bool) -> Bool { d.object(forKey: key) as? Bool ?? fallback }
        enabled = flag("notchEnabled", true)
        showMusic = flag("notchMusic", true)
        showCalendar = flag("notchCalendar", false)
        showWeather = flag("notchWeather", true)
        openOnClick = flag("notchOpenOnClick", false)
        showVolume = flag("notchVolume", true)
        showBluetooth = flag("notchBluetooth", true)
        eyeBreak = flag("notchEyeBreak", false)
        eyeBreakMinutes = d.integer(forKey: "notchEyeMinutes") == 0 ? 20 : d.integer(forKey: "notchEyeMinutes")
        let zone = TimeZone.current.identifier.split(separator: "/").last.map(String.init)?
            .replacingOccurrences(of: "_", with: " ") ?? "Bogota"
        city = d.string(forKey: "notchCity") ?? zone
    }

    /// Datos de muestra para vistas previas y pruebas (no se guardan).
    func loadDemo() {
        track = Track(title: "Cavalcade", artist: "Black Midi", source: "Music", playing: true, artworkURL: nil)
        weather = WeatherInfo(temperature: 27, symbol: "cloud.sun.fill", summary: "Parcialmente nublado", city: "Madrid")
        event = EventInfo(title: tr("Reunión de equipo"), start: Date().addingTimeInterval(25 * 60),
                          end: Date().addingTimeInterval(85 * 60), allDay: false)
        nextBreak = Date().addingTimeInterval(11 * 60)
    }

    // MARK: Ciclo de vida

    func start() {
        guard timer == nil else { return }
        bluetooth.onConnect = { [weak self] name, symbol in
            Task { @MainActor in
                self?.showToast(symbol: symbol, text: String(format: tr("%@ conectado"), name))
                self?.onBluetoothConnect?()
            }
        }
        if showBluetooth { bluetooth.start() }
        scheduleBreak()
        refreshCalendar()
        Task { await refreshWeather() }
        pollMusic()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = 0.2
    }

    private func tick() {
        counter += 1
        if counter % 2 == 0 { pollMusic() }
        if counter % 60 == 0 { refreshCalendar() }
        if counter % 1200 == 0 { Task { await refreshWeather() } }
        tickBreak()
    }

    /// Muestra un aviso colgando del notch unos segundos.
    func showToast(symbol: String, text: String, seconds: Double = 3.5, actionLabel: String? = nil,
                   swatch: String? = nil, action: (() -> Void)? = nil) {
        toast = Toast(symbol: symbol, text: text, actionLabel: actionLabel, swatch: swatch)
        toastAction = action
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !Task.isCancelled { toast = nil; toastAction = nil }
        }
    }

    // MARK: Descanso visual (regla 20-20-20)

    func scheduleBreak() {
        nextBreak = eyeBreak ? Date().addingTimeInterval(Double(eyeBreakMinutes) * 60) : nil
        if !eyeBreak { breakRemaining = nil }
    }

    func startBreakNow() { breakRemaining = 20 }

    private func tickBreak() {
        if let remaining = breakRemaining {
            if remaining <= 1 {
                breakRemaining = nil
                NSSound(named: "Glass")?.play()
                scheduleBreak()
            } else {
                breakRemaining = remaining - 1
            }
        } else if eyeBreak, let next = nextBreak, Date() >= next {
            breakRemaining = 20
            NSSound(named: "Funk")?.play()
        }
    }

    // MARK: Música (Música y Spotify, solo si ya están abiertas)

    func pollMusic() {
        guard showMusic else { return }
        for (bundle, app) in [("com.apple.Music", "Music"), ("com.spotify.client", "Spotify")]
        where !NSRunningApplication.runningApplications(withBundleIdentifier: bundle).isEmpty {
            let urlPart = app == "Spotify" ? ", artwork url of current track" : ""
            let script = """
            tell application "\(app)"
                if player state is stopped then return {"", "", "stopped", ""}
                return {name of current track, artist of current track, (player state as string)\(urlPart)\(app == "Spotify" ? "" : ", \"\"")}
            end tell
            """
            guard let result = run(script), result.numberOfItems >= 3,
                  let title = result.atIndex(1)?.stringValue, !title.isEmpty else { continue }
            let state = result.atIndex(3)?.stringValue ?? ""
            let url = (result.atIndex(4)?.stringValue).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            let current = Track(title: title, artist: result.atIndex(2)?.stringValue ?? "", source: app,
                                playing: state == "playing", artworkURL: url)
            if state == "playing" || track == nil || track?.source == app {
                if current != track { track = current; loadArtwork(for: current) }
                if state == "playing" { return }
            }
        }
        if let t = track, NSRunningApplication.runningApplications(
            withBundleIdentifier: t.source == "Music" ? "com.apple.Music" : "com.spotify.client").isEmpty {
            track = nil
            artwork = nil
        }
    }

    func musicCommand(_ command: String) {
        guard let app = track?.source else { return }
        _ = run("tell application \"\(app)\" to \(command)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.pollMusic() }
    }

    private func loadArtwork(for track: Track) {
        let key = track.source + track.title + track.artist
        guard key != lastArtworkKey else { return }
        lastArtworkKey = key
        artwork = nil
        if let url = track.artworkURL {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url), let image = NSImage(data: data), key == lastArtworkKey {
                    artwork = image
                }
            }
        } else if track.source == "Music",
                  let result = run("tell application \"Music\" to return raw data of artwork 1 of current track"),
                  let image = NSImage(data: result.data) {
            artwork = image
        }
    }

    private func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }

    // MARK: Calendario

    func refreshCalendar() {
        guard showCalendar else { event = nil; return }
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            calendarDenied = false
            loadEvent()
        case .notDetermined:
            store.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor in
                    self?.calendarDenied = !granted
                    if granted { self?.loadEvent() }
                }
            }
        default:
            calendarDenied = true
        }
    }

    private func loadEvent() {
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(86_400), calendars: nil)
        event = store.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
            .map { EventInfo(title: $0.title ?? "Evento", start: $0.startDate, end: $0.endDate, allDay: $0.isAllDay) }
    }

    // MARK: Clima (Open-Meteo, gratis y sin clave)

    func refreshWeather() async {
        guard showWeather, !city.trimmingCharacters(in: .whitespaces).isEmpty else { weather = nil; return }
        do {
            let place = try await coordinates(for: city)
            var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
            c.queryItems = [
                URLQueryItem(name: "latitude", value: "\(place.lat)"), URLQueryItem(name: "longitude", value: "\(place.lon)"),
                URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"), URLQueryItem(name: "timezone", value: "auto"),
            ]
            guard let root = try await Net.json(c.url!) as? [String: Any], let cur = root["current"] as? [String: Any],
                  let temp = cur["temperature_2m"] as? Double, let code = cur["weather_code"] as? Int else { return }
            let (symbol, text) = Self.describe(code: code, day: (cur["is_day"] as? Int ?? 1) == 1)
            weather = WeatherInfo(temperature: Int(temp.rounded()), symbol: symbol, summary: text, city: place.name)
            weatherError = nil
        } catch {
            weatherError = String(format: tr("No encontré «%@»"), city)
        }
    }

    private func coordinates(for city: String) async throws -> (lat: Double, lon: Double, name: String) {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "weatherCityKey") == city, defaults.object(forKey: "weatherLat") != nil {
            return (defaults.double(forKey: "weatherLat"), defaults.double(forKey: "weatherLon"),
                    defaults.string(forKey: "weatherName") ?? city)
        }
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        c.queryItems = [URLQueryItem(name: "name", value: city), URLQueryItem(name: "count", value: "1"),
                        URLQueryItem(name: "language", value: "es")]
        guard let root = try await Net.json(c.url!) as? [String: Any],
              let first = (root["results"] as? [[String: Any]])?.first,
              let lat = first["latitude"] as? Double, let lon = first["longitude"] as? Double else { throw URLError(.cannotFindHost) }
        let name = first["name"] as? String ?? city
        defaults.set(city, forKey: "weatherCityKey"); defaults.set(lat, forKey: "weatherLat")
        defaults.set(lon, forKey: "weatherLon"); defaults.set(name, forKey: "weatherName")
        return (lat, lon, name)
    }

    static func describe(code: Int, day: Bool) -> (String, String) {
        switch code {
        case 0: return (day ? "sun.max.fill" : "moon.stars.fill", "Despejado")
        case 1, 2: return (day ? "cloud.sun.fill" : "cloud.moon.fill", "Parcialmente nublado")
        case 3: return ("cloud.fill", "Nublado")
        case 45, 48: return ("cloud.fog.fill", "Niebla")
        case 51...57: return ("cloud.drizzle.fill", "Llovizna")
        case 61...67, 80...82: return ("cloud.rain.fill", "Lluvia")
        case 71...77, 85, 86: return ("cloud.snow.fill", "Nieve")
        case 95...99: return ("cloud.bolt.rain.fill", "Tormenta")
        default: return ("cloud.fill", "Nublado")
        }
    }
}
