// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

private enum SceneApplySource { case manual, automatic, schedule, history }
private struct SceneRuntimeSnapshot {
    var volume: Double
    var screenBrightness: Double
    var keyboardBrightness: Double
    var microphoneMuted: Bool
    var timerWasActive: Bool
}
private struct SceneTransfer: Codable {
    var format = "faro-scenes"
    var version = 1
    var scenes: [Profile]
}

/// Dueño de todo lo que vive fuera de las ventanas: ícono de la barra, menú propio y ventana principal.
@MainActor
final class AppController: NSObject, UNUserNotificationCenterDelegate, NSWindowDelegate {
    static let shared = AppController()

    let engine = WallpaperEngine()
    let monitor = SystemMonitor()
    let speed = SpeedTest()
    let awake = KeepAwake()
    let storage = StorageModel()
    let diskHistory = DiskHistory()
    let clipboard = ClipboardStore()
    let cleaning = CleaningMode()
    let notch = NotchModel()
    let diskAlert = DiskAlert()
    let updates = UpdateChecker()
    let extras = NotchExtras()
    let mixer = AudioMixer()
    let sceneDisplay = DisplayControls()
    let shelf = ShelfStore(file: Paths.support.appendingPathComponent("shelf.json"), registerShortcut: true)
    let appearance = Appearance.shared

    private var statusItem: NSStatusItem?
    private var popover: FloatingPanel?
    private var mainWindow: NSWindow?
    private var appResignObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    private var lastClosed = Date.distantPast
    private var labelSubscription: AnyCancellable?
    private var diskSubscription: AnyCancellable?
    private var scheduleTimer: Timer?
    private var lastScheduleKey = ""
    private var contextObservers: [NSObjectProtocol] = []
    private var contextSubscriptions: Set<AnyCancellable> = []
    private var automaticProfileID: UUID?
    private var automaticReturnProfileID: UUID?
    private var automaticReturnScene: Profile?
    private var automaticRuntimeSnapshot: SceneRuntimeSnapshot?
    private var lastContextApplication: SceneApplication?
    private var applyingScene = false

    func start() {
        upgradeSceneAutomationIfNeeded()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.sendAction(on: [.leftMouseUp])
        statusItem = item
        if let button = item.button {
            // Soltar archivos sobre el ícono los manda a la bandeja.
            let drop = StatusDropView(frame: button.bounds)
            drop.autoresizingMask = [.width, .height]
            drop.onClick = { [weak self] in self?.togglePopover() }
            drop.onDrop = { [weak self] urls in
                self?.shelf.add(urls)
                self?.showShelf()
            }
            button.addSubview(drop)
        }
        notch.onFilesDropped = { [weak self] urls in
            guard let self, !urls.isEmpty else { return }
            self.shelf.add(urls)
            self.notch.showToast(symbol: "tray.and.arrow.down.fill",
                                 text: String(format: tr("Guardado en la bandeja (%d)"), self.shelf.items.count))
        }
        extras.start(notch: notch, shelf: shelf, monitor: monitor)
        NotchController.shared.start(model: notch, mixer: mixer, extras: extras, engine: engine,
                                     monitor: monitor, speed: speed, awake: awake)
        CommandCenterController.shared.install()
        if Bundle.main.bundleIdentifier != nil { UNUserNotificationCenter.current().delegate = self }
        if diskAlert.enabled { diskAlert.requestAuthorization() }
        diskHistory.onFillSoon = { [weak self] days in self?.diskAlert.notifyFillSoon(days: days) }
        updates.start()
        diskSubscription = monitor.$diskFree
            .removeDuplicates { abs($0 - $1) < 100_000_000 } // cambios de menos de 0,1 GB no cuentan
            .sink { [weak self] free in
                guard let self else { return }
                self.diskAlert.check(free: free)
                self.diskHistory.record(free: free, total: self.monitor.diskTotal)
                self.notch.lowDiskGB = self.diskAlert.low ? Int(free / 1_000_000_000) : nil
            }
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkSchedule(); self?.evaluateSceneContext() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        contextObservers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                       object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   let context = self?.sceneApplication(for: app) {
                    self?.lastContextApplication = context
                }
                self?.evaluateSceneContext()
            }
        })
        contextObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                        object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.evaluateSceneContext() }
        })
        monitor.$onAC.removeDuplicates().dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.evaluateSceneContext() }
        }.store(in: &contextSubscriptions)
        monitor.$batteryPercent.removeDuplicates().dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.evaluateSceneContext() }
        }.store(in: &contextSubscriptions)
        extras.devices.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.evaluateSceneContext() }
        }.store(in: &contextSubscriptions)
        updateLabel()
        labelSubscription = Publishers.MergeMany(
            engine.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            monitor.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            speed.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            awake.objectWillChange.map { _ in () }.eraseToAnyPublisher())
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.updateLabel() }
    }

    /// Si falta el permiso de Accesibilidad, abre la página del teclado para pedirlo.
    func startCleaning() {
        closePopover()
        if !cleaning.start() { openMain(.teclado) }
    }

    /// Salir porque el usuario lo pidió expresamente (botón de apagar): no se pregunta.
    func quit() {
        AppDelegate.forceQuit = true
        NSApp.terminate(nil)
    }

    var mainWindowVisible: Bool { mainWindow?.isVisible ?? false }

    /// Oculta la ventana de escritorio; faro sigue funcionando en la barra de menú.
    func closeMainWindow() {
        mainWindow?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    /// Vuelve a abrir faro (a veces macOS solo aplica un permiso nuevo al reiniciar la app).
    func relaunch() {
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "sleep 1; open \"\(Bundle.main.bundlePath)\""]
        try? shell.run()
        quit()
    }

    func showShelf() {
        closePopover()
        ShelfPanelController.shared.show()
    }

    // MARK: Escenas Faro

    /// Aplica de golpe todo lo que guarda una Escena Faro.
    func apply(_ profile: Profile) {
        prepareManualSceneChange()
        apply(profile, source: .manual, reason: tr("Activada manualmente"))
    }

    private func prepareManualSceneChange() {
        if automaticProfileID != nil { endAutomaticScene(reason: tr("Elegiste otra escena")) }
    }

    private func apply(_ profile: Profile, source: SceneApplySource, reason: String) {
        guard !applyingScene else { return }
        if engine.state.activeProfileID == profile.id, source == .automatic || source == .schedule { return }
        applyingScene = true
        defer { applyingScene = false }

        let shouldRecord: Bool
        switch source { case .manual, .schedule: shouldRecord = true; case .automatic, .history: shouldRecord = false }
        if shouldRecord, engine.state.activeProfileID != profile.id {
            let previous = profileFromCurrentSettings(named: String(format: tr("Antes de %@"), profile.name),
                                                      symbol: "clock.arrow.circlepath")
            engine.state.sceneHistory.insert(SceneHistoryEntry(reason: profile.name, snapshot: previous), at: 0)
            engine.state.sceneHistory = Array(engine.state.sceneHistory.prefix(20))
        }
        if let channel = profile.channelID, engine.state.channels.contains(where: { $0.id == channel }),
           engine.state.currentChannelID != channel {
            engine.select(channel: channel)
        }
        engine.state.intervalMinutes = profile.intervalMinutes
        engine.state.menuBarMetrics = profile.menuBarMetrics
        engine.state.menuBarShowIcon = profile.menuBarShowIcon
        if profile.keepAwake { if !awake.active { awake.enable(hours: nil) } } else { awake.disable() }
        notch.eyeBreak = profile.eyeBreak
        if let settings = profile.notch {
            notch.apply(settings)
            extras.timer.enabled = settings.widgetLayout.first(where: { $0.kind == .timer })?.enabled == true
            extras.devices.enabled = settings.widgetLayout.first(where: { $0.kind == .devices })?.enabled == true
            NotchController.shared.apply()
        }
        if source != .history { performSceneActions(profile.actions) }
        engine.state.activeProfileID = profile.id
        if source == .manual {
            automaticProfileID = nil; automaticReturnProfileID = nil
            automaticReturnScene = nil; automaticRuntimeSnapshot = nil
        }
        if source != .history {
            let automatic: Bool
            switch source { case .automatic, .schedule: automatic = true; case .manual, .history: automatic = false }
            engine.state.lastSceneActivation = SceneActivationRecord(profileID: profile.id, profileName: profile.name,
                                                                       reason: reason, automatic: automatic)
            if automatic { notch.showToast(symbol: profile.symbol, text: "\(tr(profile.name)) · \(reason)", seconds: 5) }
        }
        engine.flash(String(format: tr("Escena: %@"), tr(profile.name)))
    }

    /// Una escena nueva con todos los ajustes actuales, incluido el notch.
    func profileFromCurrentSettings(named name: String, symbol: String = "star") -> Profile {
        Profile(name: name, symbol: symbol, channelID: engine.state.currentChannelID,
                intervalMinutes: engine.state.intervalMinutes, keepAwake: awake.active,
                menuBarMetrics: engine.state.menuBarMetrics, menuBarShowIcon: engine.state.menuBarShowIcon,
                eyeBreak: notch.eyeBreak, notch: notch.sceneSettings())
    }

    var currentApplication: SceneApplication? {
        if let app = NSWorkspace.shared.frontmostApplication,
           let current = sceneApplication(for: app) {
            lastContextApplication = current
            return current
        }
        return lastContextApplication
    }

    private func sceneApplication(for app: NSRunningApplication) -> SceneApplication? {
        guard let bundle = app.bundleIdentifier, bundle != Bundle.main.bundleIdentifier else { return nil }
        let ignored = ["com.apple.loginwindow", "com.apple.dock", "com.apple.systemuiserver",
                       "com.apple.controlcenter", "com.apple.notificationcenterui"]
        guard !ignored.contains(bundle.lowercased()) else { return nil }
        return SceneApplication(bundleIdentifier: bundle, name: app.localizedName ?? bundle)
    }

    /// También detecta un monitor como externo cuando es la única pantalla activa (MacBook cerrado o Mac de escritorio).
    var hasExternalDisplay: Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return NSScreen.screens.contains { screen in
            guard let number = screen.deviceDescription[key] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) == 0
        }
    }

    var frontmostApplicationIsFullScreen: Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        return raw.contains { info in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
            return NSScreen.screens.contains { screen in
                abs(frame.width - screen.frame.width) < 4 && abs(frame.height - screen.frame.height) < 4
            }
        }
    }

    /// Evalúa reglas continuas. La app al frente es más específica que pantalla y energía;
    /// dentro del mismo tipo gana la prioridad elegida por el usuario.
    func evaluateSceneContext() {
        guard engine.state.sceneAutomationEnabled, !sceneAutomationPaused, !applyingScene else { return }
        if engine.state.profiles.contains(where: \.meetingTrigger) { notch.refreshCalendar(force: true) }
        if engine.state.profiles.contains(where: { !$0.bluetoothDevices.isEmpty }) { extras.devices.refresh() }
        let currentBundle = currentApplication?.bundleIdentifier
        let external = hasExternalDisplay
        let onAC = monitor.onAC
        let now = Date()
        let candidates: [(profile: Profile, specificity: Int, reason: String)] = engine.state.profiles.compactMap { profile in
            var specificity = 0
            var reason = ""
            func match(_ score: Int, _ text: String) {
                if score > specificity { specificity = score; reason = text }
            }
            if let currentBundle, profile.applications.contains(where: { $0.bundleIdentifier == currentBundle }) {
                match(6, String(format: tr("%@ está al frente"), currentApplication?.name ?? tr("Una aplicación")))
            }
            if profile.meetingTrigger, let event = notch.event, !event.allDay,
               event.start <= now.addingTimeInterval(10 * 60), event.end > now {
                match(5, String(format: tr("La reunión «%@» está por comenzar"), event.title))
            }
            if profile.fullScreenTrigger, frontmostApplicationIsFullScreen {
                match(5, tr("La aplicación está en pantalla completa"))
            }
            if !profile.bluetoothDevices.isEmpty,
               let device = extras.devices.devices.first(where: { connected in
                   profile.bluetoothDevices.contains { $0.caseInsensitiveCompare(connected.name) == .orderedSame }
               }) {
                match(5, String(format: tr("%@ está conectado"), device.name))
            }
            if profile.externalDisplay, external { match(4, tr("Se conectó un monitor externo")) }
            if let threshold = profile.batteryBelow, let percent = monitor.batteryPercent, !onAC, percent <= threshold {
                match(4, String(format: tr("La batería bajó a %lld%%"), percent))
            }
            if profile.powerTrigger == .pluggedIn, onAC { match(3, tr("El Mac está conectado a la corriente")) }
            if profile.powerTrigger == .battery, monitor.hasBattery, !onAC { match(3, tr("El Mac está usando la batería")) }
            return specificity == 0 ? nil : (profile, specificity, reason)
        }
        let winner = candidates.sorted {
            $0.specificity == $1.specificity ? $0.profile.priority > $1.profile.priority : $0.specificity > $1.specificity
        }.first

        if let winner {
            guard winner.profile.id != engine.state.activeProfileID else { return }
            if automaticProfileID == nil {
                automaticReturnProfileID = engine.state.activeProfileID
                automaticReturnScene = profileFromCurrentSettings(named: tr("Configuración anterior"), symbol: "arrow.uturn.backward")
                automaticRuntimeSnapshot = captureRuntime()
            }
            automaticProfileID = winner.profile.id
            apply(winner.profile, source: .automatic, reason: winner.reason)
        } else if automaticProfileID != nil {
            endAutomaticScene(reason: tr("Terminó el contexto automático"))
        }
    }

    /// Revisa cada pocos segundos si le toca empezar a algún perfil con horario.
    func checkSchedule() {
        guard engine.state.sceneAutomationEnabled, !sceneAutomationPaused else { return }
        let now = Date()
        let parts = Calendar.current.dateComponents([.weekday, .hour, .minute], from: now)
        let stamp = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let key = "\(stamp.year ?? 0)-\(stamp.month ?? 0)-\(stamp.day ?? 0)-\(stamp.hour ?? 0)-\(stamp.minute ?? 0)"
        guard key != lastScheduleKey else { return }
        for profile in engine.state.profiles where profile.autoStart
            && profile.days.contains(parts.weekday ?? 0) && profile.hour == parts.hour && profile.minute == parts.minute {
            lastScheduleKey = key
            automaticProfileID = nil; automaticReturnProfileID = nil
            apply(profile, source: .schedule, reason: String(format: tr("Horario: %@"), scheduleText(profile)))
            break
        }
    }

    func restore(_ entry: SceneHistoryEntry) {
        apply(entry.snapshot, source: .history, reason: tr("Restaurada desde el historial"))
        engine.state.sceneHistory.removeAll { $0.id == entry.id }
        engine.state.activeProfileID = nil
        engine.flash(tr("Configuración restaurada"))
    }

    var sceneAutomationPaused: Bool {
        engine.state.sceneAutomationPauseUntil.map { $0 > Date() } ?? false
    }

    func pauseSceneAutomation(until: Date) {
        if automaticProfileID != nil { endAutomaticScene(reason: tr("Automatización pausada")) }
        engine.state.sceneAutomationPauseUntil = until
        engine.flash(tr("Automatización pausada"))
    }

    func resumeSceneAutomation() {
        engine.state.sceneAutomationPauseUntil = nil
        engine.flash(tr("Automatización reanudada"))
        evaluateSceneContext()
    }

    func sceneAutomationSettingChanged(_ enabled: Bool) {
        if enabled {
            evaluateSceneContext()
        } else if automaticProfileID != nil {
            endAutomaticScene(reason: tr("Cambio automático desactivado"))
        }
    }

    private func endAutomaticScene(reason: String) {
        let previous = automaticReturnScene
        let previousID = automaticReturnProfileID
        let runtime = automaticRuntimeSnapshot
        automaticProfileID = nil; automaticReturnProfileID = nil
        automaticReturnScene = nil; automaticRuntimeSnapshot = nil
        if let previous {
            apply(previous, source: .history, reason: reason)
            engine.state.activeProfileID = previousID
        }
        if let runtime { restoreRuntime(runtime) }
        engine.state.lastSceneActivation = SceneActivationRecord(
            profileID: previousID ?? UUID(),
            profileName: previousID.flatMap { id in engine.state.profiles.first { $0.id == id }?.name }
                ?? tr("Configuración anterior"),
            reason: reason, automatic: true)
        notch.showToast(symbol: "arrow.uturn.backward", text: reason, seconds: 4)
    }

    private func captureRuntime() -> SceneRuntimeSnapshot {
        mixer.refresh(); sceneDisplay.refresh(); extras.mic.refresh()
        return SceneRuntimeSnapshot(volume: mixer.volume, screenBrightness: sceneDisplay.screenBrightness,
                                    keyboardBrightness: sceneDisplay.keyboardBrightness,
                                    microphoneMuted: extras.mic.muted, timerWasActive: extras.timer.active)
    }

    private func restoreRuntime(_ snapshot: SceneRuntimeSnapshot) {
        mixer.setVolume(snapshot.volume)
        sceneDisplay.setScreenBrightness(snapshot.screenBrightness)
        sceneDisplay.setKeyboardBrightness(snapshot.keyboardBrightness)
        _ = extras.mic.setMuted(snapshot.microphoneMuted)
        if !snapshot.timerWasActive, extras.timer.active { extras.timer.reset() }
    }

    private func performSceneActions(_ actions: SceneActions) {
        if let value = actions.volume { mixer.setVolume(Double(value) / 100) }
        if let value = actions.screenBrightness { sceneDisplay.setScreenBrightness(Double(value) / 100) }
        if let value = actions.keyboardBrightness { sceneDisplay.setKeyboardBrightness(Double(value) / 100) }
        switch actions.microphone {
        case .unchanged: break
        case .mute: _ = extras.mic.setMuted(true)
        case .unmute: _ = extras.mic.setMuted(false)
        }
        if let minutes = actions.focusMinutes, !extras.timer.active {
            extras.timer.enabled = true
            extras.timer.begin(.focus, minutes: minutes)
        }
        for app in actions.launchApplications {
            guard NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).isEmpty,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else { continue }
            let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
        let text = actions.openURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let normalized = text.contains("://") ? text : "https://\(text)"
            if let url = URL(string: normalized) { NSWorkspace.shared.open(url) }
        }
    }

    func duplicate(_ profile: Profile) {
        var copy = profile
        copy.id = UUID(); copy.name = String(format: tr("Copia de %@"), profile.name)
        copy.autoStart = false; copy.applications = []; copy.externalDisplay = false; copy.powerTrigger = .any
        copy.meetingTrigger = false; copy.fullScreenTrigger = false; copy.bluetoothDevices = []; copy.batteryBelow = nil
        engine.state.profiles.append(copy)
    }

    @discardableResult func exportScene(_ profile: Profile) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = profile.name.replacingOccurrences(of: "/", with: "-") + ".faro-scene.json"
        panel.title = tr("Exportar escena")
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(SceneTransfer(scenes: [profile])) else { return false }
        do { try data.write(to: url, options: .atomic); return true } catch { return false }
    }

    @discardableResult func importScenes() -> Int {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = true
        panel.title = tr("Importar escenas")
        guard panel.runModal() == .OK else { return 0 }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var imported = 0
        for url in panel.urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let decoded = (try? decoder.decode(SceneTransfer.self, from: data))?.scenes
                ?? (try? decoder.decode([Profile].self, from: data))
                ?? (try? decoder.decode(Profile.self, from: data)).map { [$0] }
                ?? []
            for var scene in decoded {
                if engine.state.profiles.contains(where: { $0.id == scene.id }) { scene.id = UUID() }
                engine.state.profiles.append(scene); imported += 1
            }
        }
        if imported > 0 { engine.flash(String(format: tr("%lld escenas importadas"), imported)) }
        return imported
    }

    /// Crea una colección corta basada en el equipo actual. No reemplaza escenas editadas por el usuario.
    func installRecommendedScenes() {
        let base = notch.sceneSettings()
        let currentChannel = engine.state.currentChannelID
        func layout(_ specs: [(NotchWidgetKind, NotchWidgetSize, NotchWidgetHeight, Bool)]) -> [NotchWidgetConfig] {
            var result = specs.map { NotchWidgetConfig(kind: $0.0, enabled: true, size: $0.1, height: $0.2, showsBackground: $0.3) }
            for kind in NotchWidgetKind.allCases where !result.contains(where: { $0.kind == kind }) {
                result.append(.init(kind: kind, enabled: false, size: .compact, showsBackground: false))
            }
            return result
        }
        func scene(_ name: String, _ symbol: String, _ settings: NotchSceneSettings,
                   apps: [SceneApplication] = [], external: Bool = false, priority: Int) -> Profile {
            Profile(name: name, symbol: symbol, channelID: currentChannel, intervalMinutes: engine.state.intervalMinutes,
                    keepAwake: false, menuBarMetrics: engine.state.menuBarMetrics,
                    menuBarShowIcon: engine.state.menuBarShowIcon, eyeBreak: settings.eyeBreak, notch: settings,
                    applications: apps, externalDisplay: external, priority: priority)
        }
        func app(_ bundle: String, _ name: String) -> SceneApplication { .init(bundleIdentifier: bundle, name: name) }

        var work = base
        work.panelWidth = .wide; work.panelDensity = .tight; work.contextualPriority = true
        work.showMusic = false; work.showCalendar = true; work.showWeather = true; work.eyeBreak = true
        work.calendarStyle = .event; work.lyricsDisplay = .hidden
        work.widgetLayout = layout([(.greeting, .featured, .single, false), (.calendar, .regular, .double, true),
                                    (.timer, .compact, .single, false), (.eyeBreak, .compact, .single, false),
                                    (.volume, .featured, .single, false), (.weather, .compact, .single, false)])

        var meeting = work
        meeting.panelWidth = .balanced; meeting.eyeBreak = false; meeting.showWeather = false
        meeting.widgetLayout = layout([(.calendar, .regular, .single, false), (.timer, .compact, .single, false),
                                       (.volume, .featured, .single, false), (.devices, .compact, .single, false)])

        var media = base
        media.panelWidth = .wide; media.panelDensity = .tight; media.showMusic = true; media.showVolume = true
        media.showCalendar = false; media.lyricsDisplay = .oneLine; media.contextualPriority = true
        media.widgetLayout = layout([(.music, .featured, .double, true), (.volume, .featured, .single, false),
                                     (.devices, .compact, .single, false), (.weather, .compact, .single, false)])

        var desk = base
        desk.panelWidth = .wide; desk.panelDensity = .tight; desk.panelStyle = .glass; desk.contextualPriority = true
        desk.widgetLayout = layout([(.volume, .featured, .single, false), (.calendar, .compact, .single, true),
                                    (.weather, .compact, .single, true), (.devices, .compact, .single, true),
                                    (.storage, .compact, .single, true), (.timer, .compact, .single, true)])

        var minimal = base
        minimal.panelWidth = .compact; minimal.panelDensity = .tight; minimal.showExpandedStatus = false
        minimal.toolButtonStyle = .plain; minimal.contextualPriority = true
        minimal.widgetLayout = layout([(.music, .regular, .single, false), (.volume, .compact, .single, false),
                                       (.weather, .compact, .single, false), (.calendar, .compact, .single, false)])

        var meetingScene = scene("Reunión", "video", meeting,
                                 apps: [app("us.zoom.xos", "Zoom"), app("com.microsoft.teams2", "Microsoft Teams"),
                                        app("com.apple.FaceTime", "FaceTime"), app("Cisco-Systems.Spark", "Webex")], priority: 95)
        meetingScene.meetingTrigger = true
        let suggestions = [
            scene("Trabajo", "briefcase", work, priority: 50),
            meetingScene,
            scene("Multimedia", "music.note", media,
                  apps: [app("com.apple.Music", "Música"), app("com.spotify.client", "Spotify")], priority: 80),
            scene("Escritorio", "display.2", desk, external: true, priority: 70),
            scene("Minimal", "rectangle.compress.vertical", minimal, priority: 20),
        ]
        for suggestion in suggestions {
            if let index = engine.state.profiles.firstIndex(where: { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }) {
                if engine.state.profiles[index].notch == nil { engine.state.profiles[index] = suggestion }
            } else {
                engine.state.profiles.append(suggestion)
            }
        }
        engine.state.sceneOnboardingCompleted = true
        engine.flash(tr("Tus Escenas Faro están listas"))
        evaluateSceneContext()
    }

    func skipSceneOnboarding() { engine.state.sceneOnboardingCompleted = true }

    private func upgradeSceneAutomationIfNeeded() {
        guard engine.state.sceneAutomationVersion < 2 else { return }
        for index in engine.state.profiles.indices {
            let scene = engine.state.profiles[index]
            let isRecommendedMeeting = scene.name == "Reunión"
                && scene.applications.contains { ["us.zoom.xos", "com.microsoft.teams2", "com.apple.FaceTime", "Cisco-Systems.Spark"].contains($0.bundleIdentifier) }
            if isRecommendedMeeting { engine.state.profiles[index].meetingTrigger = true }
        }
        engine.state.sceneAutomationVersion = 2
    }

    func sceneURL(_ profile: Profile) -> URL {
        URL(string: "faro://scene/\(profile.id.uuidString)")!
    }

    func copySceneShortcut(_ profile: Profile) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents(); pasteboard.setString(sceneURL(profile).absoluteString, forType: .string)
        engine.flash(tr("Enlace para Atajos copiado"))
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "faro" else { return }
        switch url.host?.lowercased() {
        case "scene":
            let raw = url.pathComponents.dropFirst().first ?? ""
            guard let id = UUID(uuidString: raw), let profile = engine.state.profiles.first(where: { $0.id == id }) else {
                notch.showToast(symbol: "exclamationmark.triangle", text: tr("No encontré esa escena"), seconds: 4)
                return
            }
            prepareManualSceneChange()
            apply(profile, source: .manual, reason: tr("Activada desde Atajos"))
        case "resume": resumeSceneAutomation()
        case "pause": pauseSceneAutomation(until: Date().addingTimeInterval(3600))
        default: break
        }
    }

    func showClipboard() {
        closePopover()
        ClipboardPanelController.shared.show()
    }

    /// Abre el selector de emojis para la aplicación que ya tenía el foco, como el botón de la Touch Bar.
    func showEmojiPicker() {
        closePopover()
        notch.collapse?()
        // No depende del atajo configurable de teclado ni del permiso de Accesibilidad.
        // AppKit se encarga de presentar el visor del sistema incluso desde una app de barra.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            NSApp.orderFrontCharacterPalette(nil)
        }
    }

    // MARK: Notificaciones

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let raw = response.notification.request.content.userInfo["page"] as? String
        await MainActor.run { self.openMain(raw.flatMap(Page.init(rawValue:)) ?? .almacenamiento) }
    }

    // MARK: Depuración

    /// Con `FARO_DEBUG_FEATURES=1`: ejercita el aviso de disco, el mezclador, el aviso de Bluetooth y soltar sobre el notch.
    func debugFeatures() async {
        // 0) Aviso de versiones nuevas: contra un servidor local (FARO_TEST_FEED=http://localhost:PUERTO).
        if let base = ProcessInfo.processInfo.environment["FARO_TEST_FEED"] {
            for (path, current, expected) in [("/nueva/latest.json", "1.0.0", "disponible"), ("/igual/latest.json", "9.9.9", "al día"),
                                              ("/vieja/latest.json", "9.9.9", "al día"), ("/no-existe/latest.json", "1.0.0", "falló"),
                                              ("/nueva/latest.json", "1.10.0", "al día")] { // 1.10 es posterior a 1.5: compara número a número
                let checker = UpdateChecker(current: current)
                checker.silent = true
                checker.feed = URL(string: base + path)!
                await checker.check(manual: true)
                let got: String
                switch checker.state {
                case .available(let release): got = "disponible (\(release.version): \(release.notes))"
                case .upToDate: got = "al día"
                case .failed: got = "falló"
                default: got = "otro"
                }
                print("actualizaciones | \(path) con versión \(current) → \(got) (esperado: \(expected)) \(got.hasPrefix(expected) ? "✓" : "✗")")
            }
            print("actualizaciones | 1.10 > 1.9: \(UpdateChecker.isNewer("1.10", than: "1.9") ? "✓" : "✗") | 1.9 > 1.10: \(!UpdateChecker.isNewer("1.9", than: "1.10") ? "✓" : "✗") | 1.4.0 = 1.4: \(!UpdateChecker.isNewer("1.4.0", than: "1.4") ? "✓" : "✗")")
        }

        // 1) Aviso de poco espacio: la decisión de avisar (sin tocar tu ajuste: se restaura).
        let (savedOn, savedGB) = (diskAlert.enabled, diskAlert.thresholdGB)
        diskAlert.enabled = true; diskAlert.thresholdGB = 20
        let t0 = Date(), gb: (Int64) -> Int64 = { $0 * 1_000_000_000 }
        let steps: [(String, Int64, TimeInterval, Bool)] = [
            ("30 GB (sobra)", 30, 0, false), ("10 GB (primer aviso)", 10, 0, true), ("9 GB, 1 h después (no repite)", 9, 3600, false),
            ("3 GB, 2 h después (mucho peor)", 3, 7200, true), ("40 GB (se recupera)", 40, 7300, false), ("10 GB, 3 h después (vuelve a avisar)", 10, 10800, true),
        ]
        for (name, free, delay, expected) in steps {
            let got = diskAlert.evaluate(free: gb(free), now: t0.addingTimeInterval(delay))
            print("aviso de disco | \(name): avisa=\(got) \(got == expected ? "✓" : "✗ (se esperaba \(expected))")")
        }
        diskAlert.thresholdGB = savedGB; diskAlert.enabled = savedOn
        print("aviso de disco | notificaciones del sistema: \(Bundle.main.bundleIdentifier != nil ? "disponibles" : "no disponibles fuera de la app")")

        // 2) Mezclador: leer, mover el volumen un poco y restaurarlo.
        mixer.refresh()
        print("audio | salida: \(mixer.defaultOutputName) | salidas: \(mixer.outputs.map(\.name)) | volumen: \(Int(mixer.volume * 100))% | silencio: \(mixer.muted) | se puede cambiar: \(mixer.canSetVolume)")
        if mixer.canSetVolume {
            let original = mixer.volume, wasMuted = mixer.muted
            mixer.setVolume(min(original + 0.02, 1)); mixer.refresh()
            let moved = abs(mixer.volume - min(original + 0.02, 1)) < 0.011
            mixer.setVolume(original); mixer.refresh()
            let back = abs(mixer.volume - original) < 0.011
            mixer.setMuted(!wasMuted); mixer.refresh(); let muteWorks = mixer.muted == !wasMuted
            mixer.setMuted(wasMuted); mixer.refresh()
            print("audio | mover volumen: \(moved ? "✓" : "✗") | restaurar: \(back ? "✓" : "✗") | silenciar y quitar: \(muteWorks && mixer.muted == wasMuted ? "✓" : "✗")")
        }
        mixer.refreshApps()
        print("audio | volumen de Música: \(mixer.musicVolume.map { "\(Int($0 * 100))%" } ?? "no abierta") | Spotify: \(mixer.spotifyVolume.map { "\(Int($0 * 100))%" } ?? "no abierta")")

        // 3) Bluetooth: el ícono según el dispositivo y el aviso que cuelga del notch.
        for name in ["AirPods Pro de Ana", "Magic Keyboard", "Magic Trackpad", "DualSense Wireless Controller", "Altavoz de la sala"] {
            print("bluetooth | «\(name)» → \(BluetoothWatcher.symbol(for: name, major: 0))")
        }
        notch.showToast(symbol: "airpods", text: String(format: tr("%@ conectado"), "AirPods Pro de Ana"), seconds: 1)
        let shown = notch.toast != nil
        try? await Task.sleep(nanoseconds: 1_600_000_000)
        print("bluetooth | el aviso aparece: \(shown ? "✓" : "✗") | y se quita solo: \(notch.toast?.text.contains("AirPods Pro de Ana") != true ? "✓" : "✗")")

        // 4) Soltar sobre el notch: los archivos recibidos llegan a la bandeja y aparece el aviso.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("faro-drop-test.txt")
        try? Data("x".utf8).write(to: temp)
        let before = shelf.items.count
        notch.onFilesDropped?([temp])
        let added = shelf.items.count == before + 1
        print("soltar sobre el notch | llegó a la bandeja: \(added ? "✓" : "✗") | aviso: \(notch.toast?.text ?? "ninguno")")
        if let item = shelf.items.first(where: { $0.path.hasSuffix("faro-drop-test.txt") }) { shelf.remove(item.id) }
        try? FileManager.default.removeItem(at: temp)
        notch.toast = nil
        print("soltar sobre el notch | bandeja restaurada: \(shelf.items.count == before ? "✓" : "✗")")
        await debugModules()
        exit(0)
    }

    /// Prueba los módulos de bolsillo del notch (temporizador, baterías, micrófono, descargas, zip, capturas…).
    func debugModules() async {
        func check(_ name: String, _ ok: Bool, _ detail: String = "") { print("módulos | \(name): \(ok ? "✓" : "✗") \(detail)") }
        let manager = FileManager.default
        let tmp = manager.temporaryDirectory.appendingPathComponent("faro-modtest-\(UUID().uuidString)", isDirectory: true)
        try? manager.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: tmp) }

        // Temporizador
        let timer = FocusTimer()
        var events: [String] = []
        timer.onEvent = { _, text in events.append(text) }
        let t0 = Date()
        timer.begin(.focus, minutes: 25, now: t0)
        timer.tick(now: t0.addingTimeInterval(60))
        check("temporizador cuenta", timer.remaining == 24 * 60 && timer.running, "restan \(timer.clock)")
        timer.pause(now: t0.addingTimeInterval(120))
        let paused = timer.remaining
        timer.tick(now: t0.addingTimeInterval(600))
        check("temporizador en pausa no avanza", timer.remaining == paused && !timer.running, "\(timer.clock)")
        timer.resume(now: t0.addingTimeInterval(600))
        timer.tick(now: t0.addingTimeInterval(600 + Double(paused) + 1))
        check("pomodoro pasa de enfoque a descanso", timer.phase == .rest && timer.completed == 1 && events.count == 1, events.first ?? "")
        timer.skip()
        check("saltar el descanso lo deja libre", timer.phase == .idle)
        timer.begin(.timer, minutes: 1, now: t0)
        timer.tick(now: t0.addingTimeInterval(61))
        check("temporizador simple termina", timer.phase == .idle && events.count == 3, events.last ?? "")
        timer.reset()

        // Avisos de batería
        let alerts = BatteryAlerts()
        let saved = (alerts.fullEnabled, alerts.fullLevel, alerts.lowEnabled)
        alerts.fullEnabled = true; alerts.fullLevel = 100; alerts.lowEnabled = true
        let steps: [(Int, Bool, BatteryAlerts.Event?)] = [(60, false, nil), (19, false, .low(19)), (18, false, nil), (9, false, .low(9)),
                                                          (50, true, nil), (99, true, nil), (100, true, .full(100)), (100, true, nil),
                                                          (60, false, nil), (19, false, .low(19))]
        let ok = steps.allSatisfy { alerts.evaluate(percent: $0.0, charging: $0.1) == $0.2 }
        check("avisos de batería (llena y baja, sin repetir)", ok)
        (alerts.fullEnabled, alerts.fullLevel, alerts.lowEnabled) = saved

        // Batería enchufada de más e historial de salud
        let historyFile = tmp.appendingPathComponent("battery.json")
        let guardian = BatteryAlerts(historyFile: historyFile)
        let savedPlugged = (guardian.pluggedEnabled, guardian.pluggedHours)
        guardian.pluggedEnabled = true; guardian.pluggedHours = 3
        let plugStart = Date()
        let plugSteps: [(Int, Bool, TimeInterval, BatteryAlerts.Event?)] = [(100, true, 0, nil), (100, true, 2 * 3600, nil), (100, true, 3 * 3600 + 5, .pluggedLong(3)),
                                                                           (100, true, 4 * 3600, nil), (60, false, 5 * 3600, nil), (100, true, 5 * 3600 + 60, nil), (100, true, 8.5 * 3600 + 120, .pluggedLong(3))]
        let plugOK = plugSteps.allSatisfy { guardian.evaluatePlugged(percent: $0.0, onAC: $0.1, now: plugStart.addingTimeInterval($0.2)) == $0.3 }
        check("aviso de enchufada de más (una vez por conexión)", plugOK)
        (guardian.pluggedEnabled, guardian.pluggedHours) = savedPlugged
        guardian.record(cycles: 100, health: 93, now: plugStart)
        guardian.record(cycles: 101, health: 93, now: plugStart.addingTimeInterval(60))
        guardian.record(cycles: 102, health: 92, now: plugStart.addingTimeInterval(86_400 + 60))
        let reloaded = BatteryAlerts(historyFile: historyFile)
        check("historial de salud (un punto por día, se guarda)", guardian.history.count == 2 && reloaded.history == guardian.history && reloaded.history.last?.health == 92,
              "\(reloaded.history.map { "\($0.day): \($0.health)%" }.joined(separator: ", "))")

        // Micrófono
        let mic = MicMute()
        if mic.available {
            let before = mic.muted
            let muteOK = mic.setMuted(true), mutedNow = mic.muted
            let unmuteOK = mic.setMuted(false), mutedAfter = mic.muted
            if before { _ = mic.setMuted(true) }
            check("silenciar y reactivar el micrófono", muteOK && mutedNow && unmuteOK && !mutedAfter, "estado inicial: \(before ? "silenciado" : "activo")")
        } else {
            check("micrófono controlable", true, "(este micrófono no deja controlar el volumen: se oculta el botón)")
        }

        // Batería de dispositivos (formato de system_profiler)
        let sample = Data("""
        {"SPBluetoothDataType":[{"device_connected":[
          {"AirPods Pro de Ana":{"device_batteryLevelLeft":"80%","device_batteryLevelRight":"72%","device_batteryLevelCase":"55%","device_minorType":"Headphones"}},
          {"Magic Keyboard":{"device_batteryLevelMain":"91%","device_minorType":"Keyboard"}},
          {"Altavoz":{"device_minorType":"Speaker"}}]}]}
        """.utf8)
        let devices = DeviceBattery.parse(sample)
        check("batería de dispositivos", devices.count == 2 && devices.first(where: { $0.name.contains("AirPods") })?.percent == 72
              && devices.first(where: { $0.name.contains("Keyboard") })?.percent == 91 && devices.first?.detail?.contains("55") == true,
              devices.map { "\($0.name) \($0.percent)%" }.joined(separator: ", "))

        // Descargas terminadas
        let downloadsDir = tmp.appendingPathComponent("Descargas", isDirectory: true)
        try? manager.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let watcher = DownloadWatcher(directory: downloadsDir)
        let savedDownloads = UserDefaults.standard.object(forKey: "downloadAlerts")
        watcher.enabled = true
        var finished: [String] = []
        watcher.onFinished = { finished.append($0.lastPathComponent) }
        try? await Task.sleep(nanoseconds: 500_000_000)
        let partial = downloadsDir.appendingPathComponent("informe.pdf.crdownload")
        try? Data(repeating: 1, count: 2048).write(to: partial)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let early = finished.isEmpty
        try? manager.moveItem(at: partial, to: downloadsDir.appendingPathComponent("informe.pdf"))
        for _ in 0..<12 where finished.isEmpty { try? await Task.sleep(nanoseconds: 500_000_000) }
        check("descarga terminada", early && finished == ["informe.pdf"], "aviso: \(finished.first ?? "ninguno") (sin aviso mientras era .crdownload: \(early))")
        watcher.stop()
        if let savedDownloads { UserDefaults.standard.set(savedDownloads, forKey: "downloadAlerts") } else { UserDefaults.standard.removeObject(forKey: "downloadAlerts") }

        // Discos USB
        check("el disco del sistema no se ofrece para expulsar", VolumeWatcher.ejectableName(URL(fileURLWithPath: "/")) == nil)

        // Cámara y micrófono en uso, Bloq Mayús
        print("módulos | cámara en uso: \(PrivacyProbe.cameraInUse()) | micrófono en uso: \(PrivacyProbe.microphoneInUse()) | Bloq Mayús: \(CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift))")

        // Bandeja: convertir y comprimir
        let png = tmp.appendingPathComponent("foto.png")
        let image = NSImage(size: NSSize(width: 64, height: 48), flipped: false) { rect in NSColor.systemTeal.setFill(); rect.fill(); return true }
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: png)
        }
        for format in ShelfTools.ImageFormat.allCases {
            let out = try? ShelfTools.convert(png, to: format)
            let size = out.flatMap { try? manager.attributesOfItem(atPath: $0.path)[.size] as? Int } ?? 0
            check("convertir a \(format.label)", size > 0, out?.lastPathComponent ?? "falló")
            if let out { try? manager.removeItem(at: out) }
        }
        let text = tmp.appendingPathComponent("nota.txt")
        try? "hola".write(to: text, atomically: true, encoding: .utf8)
        if let archive = try? ShelfTools.zip([png, text]), let folder = try? ShelfTools.unzip(archive) {
            let inside = (try? manager.subpathsOfDirectory(atPath: folder.path)) ?? []
            check("comprimir y descomprimir", inside.contains { $0.hasSuffix("foto.png") } && inside.contains { $0.hasSuffix("nota.txt") }, "\(archive.lastPathComponent) → \(inside.count) elementos")
            try? manager.removeItem(at: archive); try? manager.removeItem(at: folder)
        } else {
            check("comprimir y descomprimir", false, "falló")
        }

        // Letras sincronizadas: lógica pura y una consulta real a LRCLIB.
        let lrc = "[00:05.00] Primera línea\n[00:10.50][01:00.00] Estribillo\n[00:15.00]\n[00:20,00] Última"
        let parsed = LyricsProvider.parse(lrc: lrc)
        check("letras: leer LRC (con marcas repetidas)", parsed.count == 5 && parsed[2].time == 15 && parsed.last?.time == 60, "\(parsed.count) líneas")
        let l1 = LyricsProvider.lines(in: parsed, at: 11), l2 = LyricsProvider.lines(in: parsed, at: 16), l0 = LyricsProvider.lines(in: parsed, at: 1)
        check("letras: línea que suena y la siguiente", l1.0 == "Estribillo" && l1.1 == "Última" && l2.0 == nil && l2.1 == "Última" && l0.0 == nil && l0.1 == "Primera línea",
              "t=11 → \(l1.0 ?? "-"), t=16 (pausa) → \(l2.0 ?? "-")")
        check("letras: limpiar el título", LyricsProvider.cleaned("Song - Remastered 2011") == "Song" && LyricsProvider.cleaned("Song (feat. X) [Live]") == "Song")
        let fetched = await LyricsProvider.fetch(title: "Never Gonna Give You Up", artist: "Rick Astley")
        check("letras: LRCLIB devuelve la letra de una canción conocida", fetched.count > 20, "\(fetched.count) líneas; primera: \(fetched.first(where: { !$0.text.isEmpty })?.text ?? "-")")
        let provider = LyricsProvider()
        let savedLyrics = provider.enabled
        provider.enabled = true
        provider.sync(title: "Never Gonna Give You Up", artist: "Rick Astley", position: 45, playing: false)
        for _ in 0..<20 where provider.line == nil { try? await Task.sleep(nanoseconds: 500_000_000) }
        check("letras: el proveedor muestra la línea del segundo 45", provider.line != nil, provider.line ?? "(ninguna)")
        provider.reset(); provider.enabled = savedLyrics

        // Almacenamiento: predicción de llenado, asistente y archivos olvidados
        let cal = Calendar(identifier: .gregorian)
        let base = cal.startOfDay(for: Date()).addingTimeInterval(-9 * 86_400 + 12 * 3600)
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; fmt.locale = Locale(identifier: "en_US_POSIX")
        func series(_ start: Int64, perDay: Int64, days: Int) -> [DiskHistory.Sample] {
            (0..<days).map { DiskHistory.Sample(day: fmt.string(from: base.addingTimeInterval(Double($0) * 86_400)), used: start + Int64($0) * perDay, total: 500_000_000_000) }
        }
        let grow = DiskHistory.forecast(samples: series(400_000_000_000, perDay: 2_000_000_000, days: 10), free: 40_000_000_000)
        check("predicción: disco que crece 2 GB/día con 40 GB libres se llena en ~20 días", grow?.trend == .growing && (grow?.daysLeft ?? 0) >= 19 && (grow?.daysLeft ?? 0) <= 21, "\(grow?.daysLeft ?? -1) días")
        let flat = DiskHistory.forecast(samples: series(400_000_000_000, perDay: 1_000_000, days: 10), free: 40_000_000_000)
        let down = DiskHistory.forecast(samples: series(400_000_000_000, perDay: -3_000_000_000, days: 10), free: 40_000_000_000)
        check("predicción: estable y en descenso", flat?.trend == .stable && flat?.daysLeft == nil && down?.trend == .shrinking)
        check("predicción: con menos de 3 días no predice", DiskHistory.forecast(samples: series(400_000_000_000, perDay: 2_000_000_000, days: 2), free: 40_000_000_000) == nil)
        let histFile = tmp.appendingPathComponent("disk.json")
        let history = DiskHistory(file: histFile)
        var fillAlerts: [Int] = []
        history.onFillSoon = { fillAlerts.append($0) }
        let savedAlert = UserDefaults.standard.object(forKey: "diskForecastAlert")
        UserDefaults.standard.removeObject(forKey: "diskForecastAlert")
        for day in 0..<10 { history.record(free: 500_000_000_000 - (460_000_000_000 + Int64(day) * 2_000_000_000), total: 500_000_000_000, now: base.addingTimeInterval(Double(day) * 86_400)) }
        check("historial del disco: un punto por día y aviso preventivo una sola vez", history.samples.count == 10 && fillAlerts.count >= 1 && fillAlerts.count <= 4, "avisos: \(fillAlerts)")
        history.record(free: 99_000_000_000, total: 500_000_000_000, now: base.addingTimeInterval(9 * 86_400 + 60))
        check("historial del disco: el mismo día se actualiza, no se duplica", history.samples.count == 10)
        if let savedAlert { UserDefaults.standard.set(savedAlert, forKey: "diskForecastAlert") } else { UserDefaults.standard.removeObject(forKey: "diskForecastAlert") }

        func item(_ name: String, _ gb: Double, idle: Int) -> CleanItem {
            CleanItem(url: URL(fileURLWithPath: "/tmp/\(name)"), bytes: Int64(gb * 1e9), modified: Date().addingTimeInterval(-Double(idle) * 86_400), lastUsed: nil)
        }
        let old = item("viejo.mov", 2, idle: 400), recent = item("nuevo.mov", 3, idle: 5)
        check("archivos olvidados: días sin tocar", (old.idleDays() ?? 0) >= 399 && (recent.idleDays() ?? 99) <= 6)
        var safeCat = CleanCategory(spec: CleanupCatalog.specs.first { $0.risk == .safe && $0.preselect && $0.keepNewest == 0 }!)
        safeCat.items = [item("a", 1, idle: 3), item("b", 0.5, idle: 30)]; safeCat.scanned = true
        var reviewCat = CleanCategory(spec: CleanupCatalog.specs.first { $0.risk == .review }!)
        reviewCat.items = [item("avd", 6, idle: 100)]; reviewCat.scanned = true
        let recs = StorageAdvisor.recommendations(categories: [safeCat, reviewCat], trashBytes: 300_000_000, simulatorBytes: nil, forgotten: [old], forgottenDays: 180)
        check("asistente: primero lo seguro y luego lo que hay que revisar", recs.count == 4 && recs.map(\.risk) == [.safe, .safe, .review, .review] && recs.first?.bytes == 1_500_000_000,
              recs.map { "\($0.id) \(Format.bytes($0.bytes))" }.joined(separator: " | "))
        check("asistente: ignora lo pequeño", StorageAdvisor.recommendations(categories: [], trashBytes: 50_000_000, simulatorBytes: 10_000_000, forgotten: [], forgottenDays: 180).isEmpty)
        if ProcessInfo.processInfo.environment["FARO_TEST_SCAN"] == "1" {
            let storage = StorageModel()
            await storage.scan()
            let ideas = storage.recommendations.map { "\($0.title) \(Format.bytes($0.bytes))" }.joined(separator: "; ")
            fputs("módulos | análisis real | seguro: \(Format.bytes(storage.safeBytes)) en \(storage.safeCount) elementos | papelera: \(Format.bytes(storage.trashBytes)) | sugerencias: \(ideas)\n", stderr)
            await storage.scanLarge()
            fputs("módulos | archivos grandes: \(storage.largeFiles.count) | olvidados (>\(storage.forgottenDays) días): \(storage.forgotten.count) | con último uso de Spotlight: \(storage.largeFiles.filter { $0.lastUsed != nil }.count)\n", stderr)
        }

        // Baterías de periféricos (IOKit): lectura de fuentes de energía, unión y avisos de poca batería
        let accessory: [String: Any] = [kIOPSTypeKey as String: "Accessory Source", kIOPSNameKey as String: "Magic Mouse", kIOPSCurrentCapacityKey as String: 85,
                                        kIOPSMaxCapacityKey as String: 100, kIOPSIsChargingKey as String: true, kIOPSTransportTypeKey as String: "Bluetooth"]
        let mouse = PeripheralBattery.device(from: accessory)
        check("periféricos: un accesorio de IOKit se lee con su carga", mouse?.name == "Magic Mouse" && mouse?.percent == 85 && mouse?.charging == true && mouse?.transport == "Bluetooth")
        var internalBattery = accessory; internalBattery[kIOPSTypeKey as String] = kIOPSInternalBatteryType
        check("periféricos: la batería del propio Mac no cuenta como periférico", PeripheralBattery.device(from: internalBattery) == nil)
        var halfScale = accessory; halfScale[kIOPSCurrentCapacityKey as String] = 30; halfScale[kIOPSMaxCapacityKey as String] = 60
        check("periféricos: convierte capacidades que no son sobre 100", PeripheralBattery.device(from: halfScale)?.percent == 50)
        func pod(_ part: String, _ percent: Int, name: String = "AirPods de Daniel") -> [String: Any] {
            [kIOPSTypeKey as String: "Accessory Source", kIOPSNameKey as String: name, kIOPSCurrentCapacityKey as String: percent,
             kIOPSMaxCapacityKey as String: 100, "Part Identifier": part, kIOPSTransportTypeKey as String: "Bluetooth"]
        }
        check("periféricos: de los AirPods solo cuenta la fuente combinada, no el estuche",
              PeripheralBattery.device(from: pod("Combined", 100))?.percent == 100 && PeripheralBattery.device(from: pod("Case", 36)) == nil
              && PeripheralBattery.device(from: pod("Case", 36, name: "Estuche de los AirPods de Daniel")) == nil)
        let merged = DeviceBattery.merge(
            fast: [DeviceBattery.Device(name: "Magic Keyboard", symbol: "keyboard", percent: 40, detail: nil, charging: false, transport: "Bluetooth")],
            slow: [DeviceBattery.Device(name: "AirPods Pro", symbol: "airpods", percent: 72, detail: "I 80 · D 72"),
                   DeviceBattery.Device(name: "magic keyboard", symbol: "keyboard", percent: 35, detail: nil)])
        check("periféricos: une IOKit y system_profiler sin duplicar y con los de menos carga primero",
              merged.count == 2 && merged.first?.name == "Magic Keyboard" && merged.first?.percent == 40, merged.map { "\($0.name) \($0.percent)%" }.joined(separator: ", "))
        let tracker = DeviceBattery()
        let savedLow = tracker.lowAlerts
        tracker.lowAlerts = true
        func probe(_ percent: Int, charging: Bool = false) -> Bool { !tracker.lowCrossings([DeviceBattery.Device(name: "Magic Trackpad", symbol: "computermouse", percent: percent, detail: nil, charging: charging)]).isEmpty }
        let lowSteps: [(Int, Bool, Bool)] = [(60, false, false), (19, false, true), (18, false, false), (9, false, true), (8, false, false), (50, false, false), (19, false, true), (5, true, false), (19, false, true)]
        check("periféricos: aviso de poca batería una vez por nivel y se rearma al cargar", lowSteps.allSatisfy { probe($0.0, charging: $0.1) == $0.2 })
        tracker.lowAlerts = savedLow
        print("módulos | periféricos conectados ahora: \(PeripheralBattery.read().map { "\($0.name) \($0.percent)%" })")

        // Conexión: qué problema se detecta y cuándo se avisa
        check("conexión: sin red es lo primero que se reporta", ConnectionMonitor.issue(online: false, slow: true, weak: true, vpnDropped: true) == .offline)
        check("conexión: VPN caída pesa más que lento o señal débil", ConnectionMonitor.issue(online: true, slow: true, weak: true, vpnDropped: true) == .vpnDropped)
        check("conexión: sin problemas no hay incidencia", ConnectionMonitor.issue(online: true, slow: false, weak: false, vpnDropped: false) == nil)
        check("conexión: avisa al perder y al recuperar, no mientras sigue igual",
              ConnectionMonitor.alert(from: nil, to: .offline) == .lost && ConnectionMonitor.alert(from: .offline, to: nil) == .restored
              && ConnectionMonitor.alert(from: .offline, to: .offline) == nil && ConnectionMonitor.alert(from: nil, to: nil) == nil)
        let link = ConnectionMonitor()
        var heard: [ConnectionMonitor.Alert] = []
        link.onAlert = { heard.append($0) }
        let savedLink = link.alertsEnabled
        link.alertsEnabled = true
        let good = ConnectionMonitor.Reading(online: true, link: .wifi, vpn: false, rssi: -55, latencyMs: 30)
        let slowRead = ConnectionMonitor.Reading(online: true, link: .wifi, vpn: false, rssi: -55, latencyMs: 450)
        link.apply(good, probeFailed: false)
        link.apply(slowRead, probeFailed: false); link.apply(slowRead, probeFailed: false)
        let beforeThird = heard.isEmpty && link.issue == nil
        link.apply(slowRead, probeFailed: false)
        let afterThird = heard == [.slow] && link.issue == .slow
        link.apply(good, probeFailed: false)
        check("conexión: lento solo se avisa tras tres lecturas seguidas y se despeja solo", beforeThird && afterThird && link.issue == nil, "\(heard)")
        heard = []
        let gone = ConnectionMonitor.Reading(online: false, link: .wifi, vpn: false, rssi: nil, latencyMs: nil)
        link.apply(gone, probeFailed: true)
        let firstFail = link.issue == nil
        link.apply(gone, probeFailed: true)
        link.apply(good, probeFailed: false)
        check("conexión: dos sondas fallidas = sin internet y al volver avisa", firstFail && heard == [.lost, .restored], "\(heard)")
        heard = []
        let vpnOn = ConnectionMonitor.Reading(online: true, link: .wifi, vpn: true, rssi: -55, latencyMs: 30)
        link.apply(vpnOn, probeFailed: false)
        link.apply(good, probeFailed: false)
        check("conexión: avisa si la VPN se cae y se despeja al volver", heard == [.vpnDropped] && link.issue == .vpnDropped, "\(heard)")
        link.apply(vpnOn, probeFailed: false)
        check("conexión: la VPN de vuelta limpia el aviso", link.issue == nil)
        link.alertsEnabled = false
        heard = []
        link.apply(gone, probeFailed: true); link.apply(gone, probeFailed: true)
        check("conexión: con los avisos apagados no suena nada pero el estado sí cambia", heard.isEmpty && link.issue == .offline)
        link.alertsEnabled = savedLink
        print("módulos | conexión ahora: \(ConnectionMonitor.hasVPN() ? "con VPN" : "sin VPN") | señal \(ConnectionMonitor.wifiRSSI().map { "\($0) dBm" } ?? "—")")

        // Diagnóstico: cuellos de botella y análisis del cargador
        var diagBase = DiagnosticInput()
        diagBase.diskTotal = 500_000_000_000; diagBase.diskFree = 200_000_000_000
        check("diagnóstico: un Mac sano no reporta nada", Diagnostics.findings(diagBase).isEmpty)
        var memory = diagBase; memory.memoryPressure = 4; memory.topMemory = ProcessUse(name: "Chrome", cpu: 5, memory: 3_000_000_000)
        let memoryFinding = Diagnostics.findings(memory).first
        check("diagnóstico: presión de memoria crítica es lo primero y nombra a la app", memoryFinding?.kind == .memory && memoryFinding?.severity == .critical && memoryFinding?.detail.contains("Chrome") == true)
        var swapOnly = diagBase; swapOnly.swapBytes = 3_000_000_000
        check("diagnóstico: mucho swap avisa aunque la presión sea normal", Diagnostics.findings(swapOnly).first?.kind == .memory)
        var busy = diagBase; busy.cpuAverage = 92; busy.topCPU = ProcessUse(name: "Xcode", cpu: 340, memory: 0)
        check("diagnóstico: CPU saturada nombra al proceso", Diagnostics.findings(busy).first.map { $0.kind == .cpu && $0.severity == .critical && $0.detail.contains("Xcode") } == true)
        var full = diagBase; full.diskFree = 20_000_000_000
        check("diagnóstico: disco con 4% libre es crítico y manda a Almacenamiento", Diagnostics.findings(full).first.map { $0.kind == .disk && $0.severity == .critical && $0.action == .storage } == true)
        var hot = diagBase; hot.thermal = .serious
        check("diagnóstico: estado térmico serio avisa", Diagnostics.findings(hot).first?.kind == .thermal)
        var several = diagBase; several.diskFree = 20_000_000_000; several.thermal = .fair; several.memoryPressure = 2
        let ordered = Diagnostics.findings(several).map(\.severity)
        check("diagnóstico: va de lo más grave a lo menos", ordered == ordered.sorted(by: >) && ordered.count == 3, "\(ordered)")
        let psOutput = """
          12.5 204800 Google Chrome
           3.0 512000 Google Chrome Helper (Renderer)
           1.0 102400 Finder
        """
        let grouped = Diagnostics.parse(ps: psOutput)
        let chrome = grouped.first { $0.name == "Google Chrome" }
        check("diagnóstico: suma los procesos auxiliares bajo su app", grouped.count == 2 && chrome?.cpu == 15.5 && chrome?.memory == (204800 + 512000) * 1024, "\(grouped)")
        func charger(_ edit: (inout ChargerReading) -> Void) -> ChargerReading { var r = ChargerReading(connected: true, charging: true, percent: 50, adapterWatts: 96, systemIn: 62, systemLoad: 24, battery: 38); edit(&r); return r }
        check("cargador: sin cargador no hay veredicto", ChargerAnalysis.verdict(ChargerReading()) == nil)
        let normal = ChargerAnalysis.verdict(charger { _ in })
        check("cargador: llegar menos que la potencia del cargador es normal si el Mac pide menos", normal?.severity == .info && normal?.title.contains("normal") == true, normal?.title ?? "")
        let short = ChargerAnalysis.verdict(charger { $0.battery = -8; $0.systemIn = 60; $0.adapterWatts = 60; $0.systemLoad = 68 })
        check("cargador: enchufado pero la batería baja = el cargador no alcanza", short?.severity == .warning && short?.detail.contains("68 W") == true, short?.detail ?? "")
        let chargerLimit = ChargerAnalysis.verdict(charger { $0.adapterWatts = 30; $0.systemIn = 29; $0.battery = 8; $0.systemLoad = 21 })
        check("cargador: cargador chico al tope y batería baja = es el límite", chargerLimit?.severity == .warning && chargerLimit?.title.contains("límite") == true)
        let done = ChargerAnalysis.verdict(charger { $0.charging = false; $0.fullyCharged = true; $0.percent = 100; $0.battery = 0 })
        check("cargador: batería llena toma solo lo que gasta", done?.title.contains("completa") == true)
        let slowCharge = ChargerAnalysis.verdict(charger { $0.slowReason = 4 })
        check("cargador: razón de carga lenta se explica", slowCharge?.title.contains("despacio") == true)
        let fromRegistry = ChargerAnalysis.reading(from: { key in
            switch key {
            case "ExternalConnected", "IsCharging": return true
            case "CurrentCapacity": return NSNumber(value: 64)
            case "AdapterDetails": return ["Watts": NSNumber(value: 96), "Name": "pd charger"] as [String: Any]
            case "PowerTelemetryData": return ["SystemPowerIn": NSNumber(value: 71_000), "SystemLoad": NSNumber(value: 20_000), "BatteryPower": NSNumber(value: 51_000)] as [String: Any]
            default: return nil
            }
        })
        check("cargador: lee vatios de milivatios del registro", fromRegistry.adapterWatts == 96 && fromRegistry.systemIn == 71 && fromRegistry.battery == 51 && fromRegistry.systemLoad == 20 && fromRegistry.connected)
        let realCharger = ChargerAnalysis.reading(from: { key in
            switch key {
            case "ExternalConnected", "IsCharging": return true
            case "CurrentCapacity": return NSNumber(value: 69)
            case "AdapterDetails": return ["Watts": NSNumber(value: 68), "Name": "70W USB-C Power Adapter ", "Manufacturer": "Apple Inc.", "UsbHvcHvcIndex": NSNumber(value: 3),
                "UsbHvcMenu": [["MaxCurrent": 2960, "MaxVoltage": 5000], ["MaxCurrent": 2970, "MaxVoltage": 9000], ["MaxCurrent": 2980, "MaxVoltage": 15000], ["MaxCurrent": 3390, "MaxVoltage": 20000]]] as [String: Any]
            case "PowerTelemetryData": return ["SystemPowerIn": NSNumber(value: 67_100), "SystemLoad": NSNumber(value: 92_200), "BatteryPower": NSNumber(value: -25_000)] as [String: Any]
            default: return nil
            }
        })
        check("cargador: lee el contrato y la lista de potencias de un Apple de 70 W", realCharger.options.count == 4 && realCharger.selected == 3 && realCharger.options[3].watts > 67 && realCharger.options[3].watts < 68 && realCharger.adapterName == "70W USB-C Power Adapter")
        let realVerdict = ChargerAnalysis.verdict(realCharger)
        check("cargador: 92 W de consumo con un 70 W al tope = no alcanza y está al máximo", realVerdict?.severity == .warning && realVerdict?.detail.contains("al máximo") == true && realVerdict?.detail.contains("92 W") == true, realVerdict?.detail ?? "")
        let realReading = ChargerAnalysis.read()
        print("módulos | cargador real: conectado=\(realReading.connected) adaptador=\(realReading.adapterWatts.map { "\($0) W" } ?? "—") entra=\(realReading.systemIn.map { String(format: "%.1f W", $0) } ?? "—") batería=\(realReading.battery.map { String(format: "%.1f W", $0) } ?? "—") gasta=\(realReading.systemLoad.map { String(format: "%.1f W", $0) } ?? "—")")
        print("módulos | presión de memoria real: \(Diagnostics.memoryPressure()) | swap: \(Format.bytes(Int64(Diagnostics.swapBytes()))) | top procesos: \(Diagnostics.readProcesses().sorted { $0.memory > $1.memory }.prefix(3).map { "\($0.name) \(Format.bytes(Int64($0.memory)))" })")

        // Discos externos y ventiladores
        check("discos: el protocolo se traduce a algo legible", ConnectedVolumes.connectionName("USB") == "USB" && ConnectedVolumes.connectionName("Secure Digital") == tr("Tarjeta SD") && ConnectedVolumes.connectionName(nil) == tr("Externo"))
        check("discos: un disco USB que macOS no marca como expulsable cuenta como externo; el del sistema y los internos no",
              ConnectedVolumes.isExternal(internal: false, local: true, path: "/Volumes/DRPR") && !ConnectedVolumes.isExternal(internal: true, local: true, path: "/Volumes/Interno")
              && !ConnectedVolumes.isExternal(internal: false, local: true, path: "/") && !ConnectedVolumes.isExternal(internal: false, local: false, path: "/Volumes/Red"))
        check("discos: un disco medio lleno marca 50%", ExternalVolume(url: URL(fileURLWithPath: "/Volumes/X"), name: "X", total: 1000, free: 500, connection: "USB").usedFraction == 0.5)
        check("ventiladores: decodifica float, entero y punto fijo del SMC",
              FanReader.decode([0, 0, 0x80, 0x3f], type: 0x666c7420) == 1.0 && FanReader.decode([7], type: 0x75693820) == 7 && FanReader.decode([0x12, 0xc0], type: 0x66706532) == 1200)
        check("ventiladores: la carga va de 0 a 1 entre mínimo y máximo", Fan(index: 0, rpm: 3000, minimum: 1000, maximum: 5000).load == 0.5 && Fan(index: 0, rpm: 100, minimum: 1000, maximum: 5000).load == 0)
        print("módulos | discos externos ahora: \(ConnectedVolumes.read().map { "\($0.name) [\($0.connection)] \(Format.bytes($0.free)) libres" })")
        print("módulos | ventiladores reales: \(FanReader.read().map { "F\($0.index) \(Int($0.rpm)) rpm (\(Int($0.minimum))–\(Int($0.maximum)))" })")

        // Puertos
        let usbC = PortInventory.port(from: { key in
            ["PortTypeDescription": "USB-C", "PortNumber": NSNumber(value: 2), "ConnectionActive": true, "TransportsActive": ["CC", "USB3", "DisplayPort"],
             "TransportsSupported": ["CC", "USB2", "USB3", "CIO", "DisplayPort"], "Plug Event Count": NSNumber(value: 5), "LDCM_LiquidDetected": false][key]
        })
        check("puertos: un USB-C con Thunderbolt y actividad se describe bien", usbC?.title == "USB-C 2" && usbC?.capability == "Thunderbolt / USB4" && usbC?.activity == "USB 3 + DisplayPort", "\(usbC?.activity ?? "")")
        let idlePort = PortInventory.port(from: { key in ["PortTypeDescription": "MagSafe 3", "PortNumber": NSNumber(value: 1), "ConnectionActive": false][key] })
        check("puertos: un MagSafe libre solo carga y está libre", idlePort?.isMagSafe == true && idlePort?.capability == tr("Solo carga") && idlePort?.activity == tr("Libre"))
        var wetInput = DiagnosticInput(); wetInput.diskTotal = 500_000_000_000; wetInput.diskFree = 200_000_000_000
        var wetPort = usbC!; wetPort.liquidDetected = true; wetInput.ports = [wetPort]
        check("puertos: humedad en un puerto es crítico", Diagnostics.findings(wetInput).first.map { $0.kind == .port && $0.severity == .critical && $0.detail.contains("USB-C 2") } == true)
        let realVDOs: [UInt32] = [0x180022b8, 0x00001518, 0x80100000, 0x21082840]
        let cable = CableInfo.decode(vdos: realVDOs, productType: 3)
        check("cables: decodifica el chip de un cable real (pasivo, USB 2, 5 A, 20 V, 100 W)",
              cable?.active == false && cable?.speedCode == 0 && cable?.currentAmps == 5 && cable?.maxVolts == 20 && cable?.maxWatts == 100 && cable?.vendor == "Motorola", "\(String(describing: cable))")
        check("cables: un dispositivo que no es cable no se decodifica", CableInfo.decode(vdos: realVDOs, productType: 2) == nil)
        var withDisk = usbC!; withDisk.cable = cable; withDisk.devices = [PortDevice(name: "Extreme SSD", vendor: "SanDisk", speedMbps: 480)]
        let slowLink = LinkAnalysis.verdict(for: withDisk)
        check("cables: un cable USB 2 en un puerto Thunderbolt limita al disco y lo dice", slowLink?.level == .limited && slowLink?.title.contains("480 Mb/s") == true, slowLink?.title ?? "")
        var fastDisk = withDisk; fastDisk.cable = CableInfo(active: false, vendorID: 0x05AC, speedCode: 3, currentAmps: 5, maxVolts: 20); fastDisk.devices = [PortDevice(name: "Extreme SSD", vendor: nil, speedMbps: 10_000)]
        check("cables: cable rápido y disco a 10 Gb/s no se estorban", LinkAnalysis.verdict(for: fastDisk)?.level == .ok)
        var noChip = withDisk; noChip.cable = nil
        check("cables: sin chip y a USB 2 avisa que puede ser el cable o el disco", LinkAnalysis.verdict(for: noChip)?.level == .limited)
        check("cables: puerto libre no tiene veredicto", LinkAnalysis.verdict(for: idlePort!) == nil)
        check("dispositivos USB: nombra la velocidad", PortDevice(name: "X", vendor: nil, speedMbps: 5_000).speedName == "5 Gb/s" && PortDevice(name: "X", vendor: nil, speedMbps: 480).speedName == "480 Mb/s")
        print("módulos | puertos reales: \(PortInventory.read().map { "\($0.title) [\($0.capability)] \($0.activity) cable=\($0.cable.map { "\($0.speedName) \($0.maxWatts)W \($0.vendor)" } ?? "—") dispositivos=\($0.devices.map { "\($0.name) \($0.speedName)" }) veredicto=\(LinkAnalysis.verdict(for: $0)?.title ?? "—")" })")

        // Mascota: despierta al usar el notch, se duerme sola y reacciona
        let pet = MascotModel()
        let n0 = Date()
        pet.look(CGPoint(x: 1, y: 1))
        check("mascota: nace dormida y no sigue el cursor dormida", pet.mood == .sleeping && pet.gaze == .zero)
        pet.wake(now: n0)
        check("mascota: despierta al abrir el notch", pet.mood == .idle && pet.awake)
        pet.look(CGPoint(x: 0.5, y: -0.5))
        check("mascota: despierta sigue el cursor", pet.gaze == CGPoint(x: 0.5, y: -0.5))
        let limit = Double(pet.sleepAfter)   // el tiempo que tengas configurado en ajustes
        pet.tick(now: n0.addingTimeInterval(limit - 1))
        let before = pet.mood
        pet.tick(now: n0.addingTimeInterval(limit + 1))
        check("mascota: se duerme tras el tiempo configurado sin uso", before == .idle && pet.mood == .sleeping && !pet.awake)
        pet.wake(now: n0.addingTimeInterval(limit + 10)); pet.dancing = true
        check("mascota: baila con la música mientras está despierta", pet.mood == .dancing)
        pet.react(.bluetooth, seconds: 8, now: n0.addingTimeInterval(limit + 11))
        let blue = pet.mood
        pet.tick(now: n0.addingTimeInterval(limit + 20))
        check("mascota: se pone azul con Bluetooth y vuelve a bailar", blue == .bluetooth && pet.mood == .dancing)
        pet.pet()
        let loved = pet.mood
        pet.dancing = false
        check("mascota: una caricia saca corazones", loved == .hearts)
        pet.demo(.celebrate)
        let party = pet.mood
        pet.demo(.sleeping)
        check("mascota: probar desde ajustes (fiesta y dormir al instante)", party == .celebrate && pet.mood == .sleeping && !pet.awake)
        pet.tick(now: Date().addingTimeInterval(120))
        check("mascota: sin uso vuelve a dormir y deja de animarse", pet.mood == .sleeping)

        // Capturas de pantalla: carpeta temporal; un archivo con la marca de captura entra, uno sin marca no.
        let shotsDir = tmp.appendingPathComponent("Capturas", isDirectory: true)
        try? manager.createDirectory(at: shotsDir, withIntermediateDirectories: true)
        let shots = ScreenshotWatcher(directory: shotsDir)
        let savedShots = UserDefaults.standard.object(forKey: "screenshotShelf")
        shots.enabled = true
        var got: [String] = []
        shots.onScreenshot = { got.append($0.lastPathComponent) }
        try? await Task.sleep(nanoseconds: 500_000_000)
        let plain = shotsDir.appendingPathComponent("foto-normal.png"), marked = shotsDir.appendingPathComponent("Captura 1.png")
        try? manager.copyItem(at: png, to: plain)
        try? manager.copyItem(at: png, to: marked)
        let marker = Process()
        marker.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        marker.arguments = ["-w", "-x", "com.apple.metadata:kMDItemIsScreenCapture",
                            "62706c697374303009080000000000000101000000000000000100000000000000000000000000000009", marked.path]
        try? marker.run(); marker.waitUntilExit()
        for _ in 0..<12 where got.isEmpty { try? await Task.sleep(nanoseconds: 500_000_000) }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        check("captura de pantalla detectada (y la foto normal no)", got == ["Captura 1.png"], got.joined(separator: ", "))
        shots.stop()
        if let savedShots { UserDefaults.standard.set(savedShots, forKey: "screenshotShelf") } else { UserDefaults.standard.removeObject(forKey: "screenshotShelf") }
    }

    /// Con `FARO_DEBUG_SOURCES=1`: pide lotes a cada fuente nueva y descarga y reduce una foto de cada una.
    static func debugSources() async {
        let filter = ImageFilter(minWidth: 2400, minHeight: 1500, targetWidth: 3024)
        let tests: [(SourceKind, String)] = [(.artic, "landscape"), (.artic, "impressionism"), (.nasa, "nebula"), (.nasa, "earth from space"), (.picsum, "")]
        for (kind, query) in tests {
            let started = Date()
            do {
                let found = try await Sources.make(kind).candidates(query: query, filter: filter)
                var line = "\(kind.rawValue) «\(query)»: \(found.count) fotos en \(String(format: "%.1f", Date().timeIntervalSince(started))) s"
                if let first = found.first {
                    line += " | \(first.title.prefix(34)) · \(first.author.prefix(24))"
                    let begin = Date()
                    let file = try await Net.download(first.url)
                    let bytes = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
                    let prepared = try Imaging.prepare(file, maxPixel: 3024)
                    let small = (try? FileManager.default.attributesOfItem(atPath: prepared.path)[.size] as? Int) ?? 0
                    line += " | bajó \(bytes / 1024) KB y quedó en \(small / 1024) KB (\(String(format: "%.1f", Date().timeIntervalSince(begin))) s)"
                    try? FileManager.default.removeItem(at: file); try? FileManager.default.removeItem(at: prepared)
                }
                print(line)
            } catch { print("\(kind.rawValue) «\(query)»: ERROR en la búsqueda o la descarga: \(error.localizedDescription)") }
        }
        exit(0)
    }

    /// Con `FARO_DEBUG_PERMS=<archivo>` escribe qué permisos ve esta app y si el bloqueo retiene teclas de verdad.
    static func debugPermissions(to file: String) async {
        var out = "ruta=\(Bundle.main.bundlePath)\n"
        out += "Accesibilidad (AXIsProcessTrusted)=\(AXIsProcessTrusted())\n"
        out += "Monitoreo de entrada (ListenEvent)=\(CGPreflightListenEventAccess())\n"
        let cleaning = CleaningMode()
        cleaning.start(seconds: 4)
        try? await Task.sleep(nanoseconds: 900_000_000)
        out += "bloqueo activo=\(cleaning.active) | modo completo=\(cleaning.fullLock)\n"
        out += "app activa=\(NSApp.isActive) | ventana de bloqueo es la principal=\(cleaning.overlayWindow?.isKeyWindow ?? false)\n"
        out += "modo quiosco (sin ⌘Tab)=\(NSApp.presentationOptions.contains(.disableProcessSwitching))\n"
        // Teclas simuladas dentro de la app: a, ⌘Q y Esc deben quedar retenidas.
        for (chars, code, flags) in [("a", 0, NSEvent.ModifierFlags()), ("q", 12, NSEvent.ModifierFlags.command), ("\u{1b}", 53, NSEvent.ModifierFlags())] {
            if let e = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                        windowNumber: cleaning.overlayWindow?.windowNumber ?? 0, context: nil,
                                        characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: UInt16(code)) {
                NSApp.sendEvent(e)
            }
        }
        out += "teclas retenidas (de 3 enviadas)=\(cleaning.swallowed)\n"
        cleaning.stop()
        out += "tras detener: activo=\(cleaning.active) | quiosco=\(NSApp.presentationOptions.contains(.disableProcessSwitching))\n"
        try? out.write(toFile: file, atomically: true, encoding: .utf8)
        exit(0)
    }

    /// Con `FARO_DEBUG_SHOT=<carpeta>` abre el menú y la ventana, captura sus propias ventanas (ya con el cristal) y sale.
    func debugCapture(to dir: String) async {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        let w = statusItem?.button?.window
        print("barra: ventana del ícono=\(w.map { "\($0.frame)" } ?? "ninguna") | visible=\(w?.isVisible ?? false) | en pantalla=\(w?.screen != nil) | estado visible=\(statusItem?.isVisible ?? false)")
        showPopover()
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        capture(popover, name: "popover", dir: dir, withShadow: true)
        closePopover()

        // Bandeja: guarda, no duplica y recuerda tras reiniciar.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("shelf-test-\(UUID().uuidString).json")
        // Archivos de ejemplo propios de la prueba (en una carpeta temporal), para no depender de nada del usuario.
        let sampleDir = FileManager.default.temporaryDirectory.appendingPathComponent("faro-shelf-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: sampleDir, withIntermediateDirectories: true)
        let files = ["informe.pdf", "foto.png", "notas.txt"].map { sampleDir.appendingPathComponent($0) }
        files.forEach { try? Data("x".utf8).write(to: $0) }
        let first = ShelfStore(file: tmp)
        first.add(files); first.add([files[0]]) // el repetido no debe duplicarse
        let second = ShelfStore(file: tmp)       // otra instancia lee lo guardado
        print("bandeja: guardados=\(first.items.count) | tras reiniciar=\(second.items.count) | todos existen=\(second.items.allSatisfy { second.exists($0) })")
        try? FileManager.default.removeItem(at: tmp)

        // Soltar: PDF, imagen, documento y carpeta deben llegar todos.
        let dropDir = FileManager.default.temporaryDirectory.appendingPathComponent("shelf-drop-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dropDir, withIntermediateDirectories: true)
        var dropped = ["a.pdf", "b.png", "c.docx"].map { dropDir.appendingPathComponent($0) }
        dropped.forEach { try? Data("x".utf8).write(to: $0) }
        let folder = dropDir.appendingPathComponent("carpeta")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        dropped.append(folder)
        let providers = dropped.map { NSItemProvider(object: $0 as NSURL) }
        let received: [URL] = await withCheckedContinuation { cont in ShelfDrop.load(providers) { cont.resume(returning: $0) } }
        print("soltar: enviados=\(dropped.count) recibidos=\(received.count) pdf=\(received.contains { $0.pathExtension == "pdf" })")
        try? FileManager.default.removeItem(at: dropDir)

        // Bloqueo de teclado (solo si este proceso tiene permiso de Accesibilidad).
        print("accesibilidad concedida: \(cleaning.trusted)")
        if cleaning.trusted {
            let started = cleaning.start(seconds: 4, prompt: false)
            try? await Task.sleep(nanoseconds: 600_000_000)
            for down in [true, false] { CGEvent(keyboardEventSource: nil, virtualKey: 90, keyDown: down)?.post(tap: .cghidEventTap) } // F20: inocua
            try? await Task.sleep(nanoseconds: 500_000_000)
            print("bloqueo: iniciado=\(started) retenidos=\(cleaning.swallowed)")
            capture(cleaning.overlayWindow, name: "cleaning", dir: dir)
            cleaning.stop()
            print("tras detener: activo=\(cleaning.active)")
        }

        let demo = ShelfStore(file: nil)
        demo.add(files + [URL(fileURLWithPath: "/Applications/faro.app"), URL(fileURLWithPath: "/System/Library/Desktop Pictures")])
        ShelfPanelController.shared.show(store: demo)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        capture(ShelfPanelController.shared.window, name: "shelf", dir: dir, withShadow: true)
        ShelfPanelController.shared.close()

        // Perfiles: aplicar uno cambia intervalo, despierto, barra y descanso; el horario lo dispara a su hora. Luego se restaura todo.
        print("perfiles de fábrica: \(engine.state.profiles.map(\.name))")
        let saved = (engine.state.intervalMinutes, engine.state.menuBarMetrics, engine.state.menuBarShowIcon,
                     awake.active, notch.eyeBreak, engine.state.activeProfileID)
        var test = profileFromCurrentSettings(named: "Prueba")
        test.intervalMinutes = 360; test.keepAwake = true; test.menuBarMetrics = [.disk, .speed]
        test.eyeBreak = true; test.menuBarShowIcon = false
        apply(test)
        print("perfil aplicado: intervalo=\(engine.state.intervalMinutes) despierto=\(awake.active) barra=\(engine.state.menuBarMetrics.map(\.rawValue).sorted()) descanso=\(notch.eyeBreak) activo=\(engine.state.activeProfileID == test.id)")
        engine.state.activeProfileID = nil
        let now = Calendar.current.dateComponents([.weekday, .hour, .minute], from: Date())
        var timed = profileFromCurrentSettings(named: "Horario")
        timed.autoStart = true; timed.days = [now.weekday ?? 1]; timed.hour = now.hour ?? 0; timed.minute = now.minute ?? 0
        engine.state.profiles.append(timed)
        lastScheduleKey = ""
        checkSchedule()
        print("horario dispara el perfil: \(engine.state.activeProfileID == timed.id)")
        engine.state.profiles.removeAll { $0.id == timed.id }
        engine.state.intervalMinutes = saved.0; engine.state.menuBarMetrics = saved.1; engine.state.menuBarShowIcon = saved.2
        if !saved.3 { awake.disable() }
        notch.eyeBreak = saved.4; engine.state.activeProfileID = saved.5
        print("restaurado: intervalo=\(engine.state.intervalMinutes) despierto=\(awake.active) descanso=\(notch.eyeBreak)")

        // Notch: llevar el cursor arriba al centro debe desplegarlo, y alejarlo debe recogerlo.
        let notchController = NotchController.shared
        notch.loadDemo()
        if let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main {
            let original = CGEvent(source: nil)?.location ?? .zero
            let primaryTop = NSScreen.screens[0].frame.maxY
            func warp(toNotch: Bool) {
                let y = toNotch ? primaryTop - screen.frame.maxY + 3 : primaryTop - screen.frame.midY
                CGWarpMouseCursorPosition(CGPoint(x: screen.frame.midX, y: y))
            }
            print("notch: \(notchController.summary)")
            warp(toNotch: true)
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            print("notch tras acercar el cursor: desplegado=\(notch.expanded) altura=\(Int(notch.expandedHeight))")
            capture(notchController.window, name: "notch-expanded", dir: dir)
            warp(toNotch: false)
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            print("notch tras alejarlo: desplegado=\(notch.expanded)")
            notch.track?.playing = true
            capture(notchController.window, name: "notch-live", dir: dir)
            CGWarpMouseCursorPosition(original)
        }

        for (page, name) in [(Page.fondos, "main-fondos"), (Page.sistema, "main-sistema")] {
            openMain(page)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            capture(mainWindow, name: name, dir: dir)
        }
        exit(0)
    }

    private func capture(_ window: NSWindow?, name: String, dir: String, withShadow: Bool = false) {
        typealias Fn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let window, window.windowNumber > 0, let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return }
        let create = unsafeBitCast(sym, to: Fn.self)
        // optionIncludingWindow = 8; bestResolution = 8; boundsIgnoreFraming = 1 (deja fuera la sombra)
        guard let cg = create(.null, 8, UInt32(window.windowNumber), withShadow ? 8 : 9)?.takeRetainedValue() else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    // MARK: Ícono de la barra

    /// El ícono con datos en vivo se dibuja como imagen de plantilla para que macOS lo tiñe según el modo claro/oscuro.
    private func updateLabel() {
        statusItem?.isVisible = engine.state.menuBarEnabled
        guard engine.state.menuBarEnabled else { return }
        guard let button = statusItem?.button else { return }
        let label = MenuBarLabel(engine: engine, monitor: monitor, speed: speed, awake: awake)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.black)
            .frame(height: 18)
        let renderer = ImageRenderer(content: label)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return }
        image.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
    }

    // MARK: Menú propio

    @objc private func togglePopover() {
        if popover?.isVisible == true {
            closePopover()
        } else if Date().timeIntervalSince(lastClosed) > 0.25 {
            showPopover()
        }
    }

    private func showPopover() {
        guard let buttonWindow = statusItem?.button?.window else { return }
        let host = NSHostingView(rootView: PopoverRoot()
            .environmentObject(engine).environmentObject(monitor).environmentObject(speed)
            .environmentObject(awake).environmentObject(appearance))
        host.wantsLayer = true
        host.layer?.cornerRadius = 32
        host.layer?.cornerCurve = .continuous
        host.layer?.masksToBounds = true
        let size = host.fittingSize
        let panel = FloatingPanel(contentRect: CGRect(origin: .zero, size: size),
                                  styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = host

        let anchor = buttonWindow.frame
        let screen = buttonWindow.screen ?? NSScreen.main
        let area = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let x = min(max(anchor.midX - size.width / 2, area.minX + 8), area.maxX - size.width - 8)
        panel.setFrameOrigin(CGPoint(x: x, y: anchor.minY - size.height - 6))

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }
        popover = panel
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { panel.invalidateShadow() }
    }

    func closePopover() {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        if popover != nil { lastClosed = Date() }
        popover?.orderOut(nil)
        popover = nil
    }

    // MARK: Ventana principal

    func openMain(_ page: Page? = nil) {
        if let page { UserDefaults.standard.set(page.rawValue, forKey: "page") }
        closePopover()
        if mainWindow == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1060, height: 740),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "faro"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.level = .normal
            window.collectionBehavior = [.managed, .participatesInCycle]
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.minSize = CGSize(width: 920, height: 640)
            window.contentView = NSHostingView(rootView: MainRoot()
                .environmentObject(engine).environmentObject(monitor).environmentObject(speed)
                .environmentObject(awake).environmentObject(storage).environmentObject(diskHistory).environmentObject(clipboard)
                .environmentObject(cleaning).environmentObject(notch).environmentObject(diskAlert).environmentObject(updates).environmentObject(extras).environmentObject(mixer).environmentObject(appearance))
            window.center()
            mainWindow = window
            appResignObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let window = self?.mainWindow, window.isVisible else { return }
                    window.orderBack(nil)
                }
            }
        }
        // Una app de barra usa normalmente `.accessory`, pero su ventana de escritorio debe comportarse
        // como cualquier app nativa: aparecer en el Dock, activar su grupo de ventanas y subir al frente.
        NSApp.setActivationPolicy(.regular)
        mainWindow?.level = .normal
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === mainWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Raíz del menú: cristal con esquinas muy redondeadas y el color de resalte elegido.
struct PopoverRoot: View {
    @EnvironmentObject var appearance: Appearance

    var body: some View {
        MenuView()
            .id(appearance.revision)
            .tint(appearance.accent)
            .glassSurface(radius: 32)
    }
}

/// Raíz de la ventana principal: color fijo (el del sistema, o el que elijas en General).
struct MainRoot: View {
    @EnvironmentObject var appearance: Appearance

    var body: some View {
        MainWindow()
            .id(appearance.revision)
            .tint(appearance.accent)
            .background { appearance.windowColor.ignoresSafeArea() }
    }
}
