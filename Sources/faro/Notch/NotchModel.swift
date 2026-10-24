// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import Combine
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

enum NotchPanelWidth: String, Codable, CaseIterable, Identifiable {
    case compact, balanced, wide
    var id: String { rawValue }
    var points: CGFloat { switch self { case .compact: 470; case .balanced: 548; case .wide: 680 } }
    var title: String { switch self { case .compact: tr("Reducido"); case .balanced: tr("Equilibrado"); case .wide: tr("Ancho") } }
}

enum NotchPanelDensity: String, Codable, CaseIterable, Identifiable {
    case tight, balanced, roomy
    var id: String { rawValue }
    var title: String { switch self { case .tight: tr("Compacto"); case .balanced: tr("Normal"); case .roomy: tr("Amplio") } }
    var spacing: CGFloat { switch self { case .tight: 7; case .balanced: 12; case .roomy: 16 } }
    var verticalPadding: CGFloat { switch self { case .tight: 10; case .balanced: 18; case .roomy: 26 } }
}

enum NotchPanelStyle: String, Codable, CaseIterable, Identifiable {
    case black, tinted, glass, liquid
    var id: String { rawValue }
    var title: String { switch self { case .black: tr("Negro"); case .tinted: tr("Tinte"); case .glass: tr("Cristal"); case .liquid: tr("Liquid crystal") } }
}

enum NotchDockPlacement: String, Codable, CaseIterable, Identifiable {
    case tab, bottom
    var id: String { rawValue }
    var title: String { self == .tab ? tr("En su pestaña") : tr("Siempre abajo") }
}

enum NotchDockScale: String, Codable, CaseIterable, Identifiable {
    case compact, regular, large
    var id: String { rawValue }
    var title: String { switch self { case .compact: tr("Reducido"); case .regular: tr("Normal"); case .large: tr("Grande") } }
    var height: CGFloat { switch self { case .compact: 42; case .regular: 52; case .large: 64 } }
    var iconSize: CGFloat { switch self { case .compact: 12; case .regular: 15; case .large: 18 } }
}

enum NotchToolButtonStyle: String, Codable, CaseIterable, Identifiable {
    case rounded, circle, plain
    var id: String { rawValue }
    var title: String {
        switch self { case .rounded: tr("Rectángulo"); case .circle: tr("Círculo"); case .plain: tr("Sin fondo") }
    }
}

enum NotchSystemMetricScale: String, Codable, CaseIterable, Identifiable {
    case compact, regular
    var id: String { rawValue }
    var title: String { self == .compact ? tr("Compacto") : tr("Normal") }
}

enum NotchCollapsedWidthMode: String, Codable, CaseIterable, Identifiable {
    case adaptive, wide
    var id: String { rawValue }
    var title: String { self == .adaptive ? tr("Automático") : tr("Amplio") }
}

enum NotchLyricsDisplay: String, Codable, CaseIterable, Identifiable {
    case hidden, oneLine, twoLines
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hidden: tr("Ocultas")
        case .oneLine: tr("Una línea")
        case .twoLines: tr("Dos líneas")
        }
    }
}

enum NotchWidgetSize: String, Codable, CaseIterable, Identifiable {
    case compact, regular, featured
    var id: String { rawValue }
    var title: String { switch self { case .compact: tr("1/3 del ancho"); case .regular: tr("2/3 del ancho"); case .featured: tr("Ancho completo") } }
    var columns: Int { switch self { case .compact: 1; case .regular: 2; case .featured: 3 } }

    static func columns(_ value: Int) -> Self {
        switch value { case ...1: .compact; case 2: .regular; default: .featured }
    }
}

enum NotchWidgetHeight: String, Codable, CaseIterable, Identifiable {
    case single, double
    var id: String { rawValue }
    var title: String { self == .single ? tr("Una fila") : tr("Dos filas") }
}

enum NotchCalendarStyle: String, Codable, CaseIterable, Identifiable {
    case event, month
    var id: String { rawValue }
    var title: String { self == .event ? tr("Próximo evento") : tr("Mes completo") }
}

enum NotchWidgetKind: String, Codable, CaseIterable, Identifiable {
    case greeting, timer, music, volume, weather, calendar, devices, eyeBreak, storage
    var id: String { rawValue }
    var title: String {
        switch self {
        case .greeting: tr("Saludo"); case .timer: tr("Temporizador"); case .music: tr("Música"); case .volume: tr("Controles del sistema")
        case .weather: tr("Clima"); case .calendar: tr("Calendario"); case .devices: tr("Dispositivos")
        case .eyeBreak: tr("Descanso visual"); case .storage: tr("Almacenamiento")
        }
    }
    var symbol: String {
        switch self {
        case .greeting: "hand.wave"; case .timer: "timer"; case .music: "music.note"; case .volume: "speaker.wave.2"
        case .weather: "cloud.sun"; case .calendar: "calendar"; case .devices: "airpods"
        case .eyeBreak: "eye"; case .storage: "internaldrive"
        }
    }
}

struct NotchWidgetConfig: Codable, Identifiable, Equatable {
    var kind: NotchWidgetKind
    var enabled: Bool
    var size: NotchWidgetSize
    var height: NotchWidgetHeight
    var showsBackground: Bool
    var id: NotchWidgetKind { kind }

    init(kind: NotchWidgetKind, enabled: Bool, size: NotchWidgetSize,
         height: NotchWidgetHeight = .single, showsBackground: Bool = true) {
        self.kind = kind; self.enabled = enabled; self.size = size
        self.height = height; self.showsBackground = showsBackground
    }

    private enum CodingKeys: String, CodingKey { case kind, enabled, size, height, showsBackground }
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        kind = try box.decode(NotchWidgetKind.self, forKey: .kind)
        enabled = try box.decode(Bool.self, forKey: .enabled)
        size = try box.decode(NotchWidgetSize.self, forKey: .size)
        height = try box.decodeIfPresent(NotchWidgetHeight.self, forKey: .height) ?? .single
        showsBackground = try box.decodeIfPresent(Bool.self, forKey: .showsBackground) ?? true
    }
}

enum NotchToolKind: String, Codable, CaseIterable, Identifiable {
    case clipboard, shelf, timer, microphone, eyedropper, emoji, awake, keyboard, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clipboard: tr("Historial"); case .shelf: tr("Bandeja"); case .timer: tr("Tiempo")
        case .microphone: tr("Micro"); case .eyedropper: tr("Color"); case .emoji: tr("Emoji"); case .awake: tr("Despierto")
        case .keyboard: tr("Teclado"); case .settings: tr("Ajustes")
        }
    }
}

struct NotchToolConfig: Codable, Identifiable, Equatable {
    var kind: NotchToolKind
    var enabled: Bool
    var id: NotchToolKind { kind }
}

/// Estado y ajustes del panel del notch: música, calendario, clima y descanso visual.
@MainActor
final class NotchModel: ObservableObject {
    // MARK: Ajustes (se guardan solos)
    @Published var enabled: Bool { didSet { save("notchEnabled", enabled) } }
    @Published var showMusic: Bool { didSet { save("notchMusic", showMusic); if !showMusic { track = nil; lyrics.reset() } } }
    @Published var showCalendar: Bool { didSet { save("notchCalendar", showCalendar); refreshCalendar() } }
    @Published var showWeather: Bool { didSet { save("notchWeather", showWeather); Task { await refreshWeather() } } }
    @Published var eyeBreak: Bool { didSet { save("notchEyeBreak", eyeBreak); scheduleBreak() } }
    @Published var eyeBreakMinutes: Int { didSet { save("notchEyeMinutes", eyeBreakMinutes); scheduleBreak() } }
    @Published var city: String { didSet { save("notchCity", city) } }
    /// Si es cierto, el panel solo se despliega con un clic sobre el notch (no con solo pasar el cursor).
    @Published var openOnClick: Bool { didSet { save("notchOpenOnClick", openOnClick) } }
    @Published var showVolume: Bool { didSet { save("notchVolume", showVolume) } }
    /// Accesos directos discretos en las orillas, visibles con el notch recogido.
    @Published var showCompactControls: Bool { didSet { save("notchCompactControls", showCompactControls) } }
    @Published var panelWidth: NotchPanelWidth { didSet { save("notchPanelWidth", panelWidth.rawValue) } }
    @Published var panelDensity: NotchPanelDensity { didSet { save("notchPanelDensity", panelDensity.rawValue) } }
    @Published var panelStyle: NotchPanelStyle { didSet { save("notchPanelStyle", panelStyle.rawValue) } }
    @Published var panelTintHex: String { didSet { save("notchPanelTint", panelTintHex) } }
    @Published var panelOpacity: Double { didSet { save("notchPanelOpacity", panelOpacity) } }
    @Published var dockPlacement: NotchDockPlacement { didSet { save("notchDockPlacement", dockPlacement.rawValue) } }
    @Published var dockScale: NotchDockScale { didSet { save("notchDockScale", dockScale.rawValue) } }
    @Published var showExpandedStatus: Bool { didSet { save("notchShowExpandedStatus", showExpandedStatus) } }
    @Published var showTabIcons: Bool { didSet { save("notchShowTabIcons", showTabIcons) } }
    @Published var showSystemItemBackgrounds: Bool { didSet { save("notchSystemItemBackgrounds", showSystemItemBackgrounds) } }
    @Published var toolButtonStyle: NotchToolButtonStyle { didSet { save("notchToolButtonStyle", toolButtonStyle.rawValue) } }
    @Published var showVolumeControl: Bool { didSet { save("notchShowVolumeControl", showVolumeControl) } }
    @Published var showDisplayControl: Bool { didSet { save("notchShowDisplayControl", showDisplayControl) } }
    @Published var showKeyboardControl: Bool { didSet { save("notchShowKeyboardControl", showKeyboardControl) } }
    @Published var calendarStyle: NotchCalendarStyle { didSet { save("notchCalendarStyle", calendarStyle.rawValue) } }
    @Published var greetingText: String { didSet { save("notchGreetingText", greetingText) } }
    @Published var greetingEmoji: String { didSet { save("notchGreetingEmoji", greetingEmoji) } }
    @Published var showGreetingInHeader: Bool { didSet { save("notchGreetingInHeader", showGreetingInHeader) } }
    @Published var systemMetricScale: NotchSystemMetricScale { didSet { save("notchSystemMetricScale", systemMetricScale.rawValue) } }
    @Published var showSystemDescriptions: Bool { didSet { save("notchShowSystemDescriptions", showSystemDescriptions) } }
    @Published var showSystemTitle: Bool { didSet { save("notchShowSystemTitle", showSystemTitle) } }
    @Published var showToolsTitle: Bool { didSet { save("notchShowToolsTitle", showToolsTitle) } }
    @Published var lyricsDisplay: NotchLyricsDisplay {
        didSet {
            save("notchLyricsDisplay", lyricsDisplay.rawValue)
            lyrics.enabled = lyricsDisplay != .hidden
        }
    }
    @Published var collapsedWidthMode: NotchCollapsedWidthMode { didSet { save("notchCollapsedWidthMode", collapsedWidthMode.rawValue) } }
    @Published var widgetLayout: [NotchWidgetConfig] { didSet { saveCodable("notchWidgetLayout", widgetLayout) } }
    @Published var toolLayout: [NotchToolConfig] { didSet { saveCodable("notchToolLayout", toolLayout) } }
    @Published var showBluetooth: Bool {
        didSet {
            save("notchBluetooth", showBluetooth)
            if showBluetooth { bluetooth.start() } else { bluetooth.stop() }
        }
    }

    // MARK: Estado
    @Published var expanded = false { didSet { if expanded { mascot.wake() } } }
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

    /// Letras sincronizadas de lo que suena.
    var lyrics = LyricsProvider()
    private var lyricsObserver: AnyCancellable?
    /// La mascota: despierta mientras usas el notch y se duerme sola.
    var mascot = MascotModel()
    private var mascotObserver: AnyCancellable?
    private var timer: Timer?
    private var toastTask: Task<Void, Never>?
    private let bluetooth = BluetoothWatcher()
    private var counter = 0
    private let store = EKEventStore()
    private var lastArtworkKey = ""

    var hasLive: Bool { (showMusic && track?.playing == true) || breakRemaining != nil || lowDiskGB != nil }

    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }
    private func saveCodable<T: Encodable>(_ key: String, _ value: T) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }

    init() {
        let d = UserDefaults.standard
        func flag(_ key: String, _ fallback: Bool) -> Bool { d.object(forKey: key) as? Bool ?? fallback }
        enabled = flag("notchEnabled", true)
        showMusic = flag("notchMusic", true)
        showCalendar = flag("notchCalendar", false)
        showWeather = flag("notchWeather", true)
        openOnClick = flag("notchOpenOnClick", false)
        showVolume = flag("notchVolume", true)
        showCompactControls = flag("notchCompactControls", true)
        panelWidth = NotchPanelWidth(rawValue: d.string(forKey: "notchPanelWidth") ?? "") ?? .balanced
        panelDensity = NotchPanelDensity(rawValue: d.string(forKey: "notchPanelDensity") ?? "") ?? .tight
        panelStyle = NotchPanelStyle(rawValue: d.string(forKey: "notchPanelStyle") ?? "") ?? .black
        panelTintHex = d.string(forKey: "notchPanelTint") ?? Appearance.defaultAccent
        panelOpacity = d.object(forKey: "notchPanelOpacity") as? Double ?? 0.82
        dockPlacement = NotchDockPlacement(rawValue: d.string(forKey: "notchDockPlacement") ?? "") ?? .tab
        dockScale = NotchDockScale(rawValue: d.string(forKey: "notchDockScale") ?? "") ?? .compact
        showExpandedStatus = flag("notchShowExpandedStatus", true)
        showTabIcons = flag("notchShowTabIcons", true)
        showSystemItemBackgrounds = flag("notchSystemItemBackgrounds", true)
        toolButtonStyle = NotchToolButtonStyle(rawValue: d.string(forKey: "notchToolButtonStyle") ?? "") ?? .rounded
        showVolumeControl = flag("notchShowVolumeControl", true)
        showDisplayControl = flag("notchShowDisplayControl", true)
        showKeyboardControl = flag("notchShowKeyboardControl", true)
        calendarStyle = NotchCalendarStyle(rawValue: d.string(forKey: "notchCalendarStyle") ?? "") ?? .event
        greetingText = d.string(forKey: "notchGreetingText") ?? tr("Hola")
        greetingEmoji = d.string(forKey: "notchGreetingEmoji") ?? "👋"
        showGreetingInHeader = flag("notchGreetingInHeader", false)
        systemMetricScale = NotchSystemMetricScale(rawValue: d.string(forKey: "notchSystemMetricScale") ?? "") ?? .compact
        showSystemDescriptions = flag("notchShowSystemDescriptions", false)
        showSystemTitle = flag("notchShowSystemTitle", true)
        showToolsTitle = flag("notchShowToolsTitle", true)
        lyricsDisplay = NotchLyricsDisplay(rawValue: d.string(forKey: "notchLyricsDisplay") ?? "")
            ?? (flag("lyricsEnabled", true) ? .oneLine : .hidden)
        collapsedWidthMode = NotchCollapsedWidthMode(rawValue: d.string(forKey: "notchCollapsedWidthMode") ?? "") ?? .adaptive
        widgetLayout = (d.data(forKey: "notchWidgetLayout").flatMap { try? JSONDecoder().decode([NotchWidgetConfig].self, from: $0) }) ?? [
            .init(kind: .greeting, enabled: false, size: .featured, showsBackground: false),
            .init(kind: .timer, enabled: true, size: .featured), .init(kind: .music, enabled: true, size: .regular),
            .init(kind: .volume, enabled: true, size: .compact), .init(kind: .weather, enabled: true, size: .compact),
            .init(kind: .calendar, enabled: true, size: .compact), .init(kind: .devices, enabled: true, size: .compact),
            .init(kind: .eyeBreak, enabled: true, size: .compact), .init(kind: .storage, enabled: true, size: .compact),
        ]
        toolLayout = (d.data(forKey: "notchToolLayout").flatMap { try? JSONDecoder().decode([NotchToolConfig].self, from: $0) })
            ?? NotchToolKind.allCases.map { .init(kind: $0, enabled: true) }
        showBluetooth = flag("notchBluetooth", true)
        eyeBreak = flag("notchEyeBreak", false)
        eyeBreakMinutes = d.integer(forKey: "notchEyeMinutes") == 0 ? 20 : d.integer(forKey: "notchEyeMinutes")
        let zone = TimeZone.current.identifier.split(separator: "/").last.map(String.init)?
            .replacingOccurrences(of: "_", with: " ") ?? "Bogota"
        city = d.string(forKey: "notchCity") ?? zone
        for kind in NotchWidgetKind.allCases where !widgetLayout.contains(where: { $0.kind == kind }) {
            widgetLayout.append(.init(kind: kind, enabled: kind == .greeting ? false : true,
                                      size: kind == .greeting ? .featured : .compact,
                                      showsBackground: kind != .greeting))
        }
        for kind in NotchToolKind.allCases where !toolLayout.contains(where: { $0.kind == kind }) {
            toolLayout.append(.init(kind: kind, enabled: true))
        }
        lyrics.enabled = lyricsDisplay != .hidden
        lyricsObserver = lyrics.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.objectWillChange.send() } }
        mascotObserver = mascot.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.objectWillChange.send() } }
    }

    func compactPanelWidth(notchWidth: CGFloat, metricCount: Int, hasActivity: Bool) -> CGFloat {
        if collapsedWidthMode == .wide { return min(540, notchWidth + 320) }
        let metricsPerSide = Int(ceil(Double(metricCount) / 2))
        let wing = CGFloat(metricsPerSide * 36 + (showCompactControls ? 30 : 0) + (hasActivity ? 30 : 0) + (mascot.enabled ? 30 : 0) + 4)
        return min(540, max(notchWidth + 16, notchWidth + wing * 2))
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
                self?.mascot.react(.bluetooth, seconds: 8)
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
        mascot.dancing = showMusic && track?.playing == true
        if expanded { mascot.wake() }
        mascot.tick()
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
                return {name of current track, artist of current track, (player state as string)\(urlPart)\(app == "Spotify" ? "" : ", \"\""), player position}
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
                let position = Double((result.atIndex(5)?.stringValue ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
                lyrics.sync(title: current.title, artist: current.artist, position: position, playing: state == "playing")
                if state == "playing" { return }
            }
        }
        if let t = track, NSRunningApplication.runningApplications(
            withBundleIdentifier: t.source == "Music" ? "com.apple.Music" : "com.spotify.client").isEmpty {
            track = nil
            artwork = nil
            lyrics.reset()
        }
    }

    /// Trae al frente la app desde la que suena la música (Música o Spotify) y recoge el panel.
    func openPlayer() {
        guard let source = track?.source else { return }
        let bundle = source == "Music" ? "com.apple.Music" : "com.spotify.client"
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first {
            running.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        collapse?()
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
