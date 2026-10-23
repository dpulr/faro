// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import Combine
import SwiftUI

/// Dueño de todo lo que vive fuera de las ventanas: ícono de la barra, menú propio y ventana principal.
@MainActor
final class AppController: NSObject {
    static let shared = AppController()

    let engine = WallpaperEngine()
    let monitor = SystemMonitor()
    let speed = SpeedTest()
    let awake = KeepAwake()
    let storage = StorageModel()
    let clipboard = ClipboardStore()
    let cleaning = CleaningMode()
    let notch = NotchModel()
    let shelf = ShelfStore(file: Paths.support.appendingPathComponent("shelf.json"), registerShortcut: true)
    let appearance = Appearance.shared

    private var statusItem: NSStatusItem?
    private var popover: FloatingPanel?
    private var mainWindow: NSWindow?
    private var resignObserver: NSObjectProtocol?
    private var lastClosed = Date.distantPast
    private var labelSubscription: AnyCancellable?
    private var scheduleTimer: Timer?
    private var lastScheduleKey = ""

    func start() {
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
        NotchController.shared.start(model: notch)
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkSchedule() }
        }
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

    /// Vuelve a abrir faro (a veces macOS solo aplica un permiso nuevo al reiniciar la app).
    func relaunch() {
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "sleep 1; open \"\(Bundle.main.bundlePath)\""]
        try? shell.run()
        NSApp.terminate(nil)
    }

    func showShelf() {
        closePopover()
        ShelfPanelController.shared.show()
    }

    // MARK: Perfiles

    /// Aplica de golpe todo lo que guarda un perfil.
    func apply(_ profile: Profile) {
        if let channel = profile.channelID, engine.state.channels.contains(where: { $0.id == channel }),
           engine.state.currentChannelID != channel {
            engine.select(channel: channel)
        }
        engine.state.intervalMinutes = profile.intervalMinutes
        engine.state.menuBarMetrics = profile.menuBarMetrics
        engine.state.menuBarShowIcon = profile.menuBarShowIcon
        if profile.keepAwake { if !awake.active { awake.enable(hours: nil) } } else { awake.disable() }
        notch.eyeBreak = profile.eyeBreak
        engine.state.activeProfileID = profile.id
        engine.flash("Perfil: \(profile.name)")
    }

    /// Un perfil nuevo con los ajustes que tienes ahora mismo.
    func profileFromCurrentSettings(named name: String, symbol: String = "star") -> Profile {
        Profile(name: name, symbol: symbol, channelID: engine.state.currentChannelID,
                intervalMinutes: engine.state.intervalMinutes, keepAwake: awake.active,
                menuBarMetrics: engine.state.menuBarMetrics, menuBarShowIcon: engine.state.menuBarShowIcon,
                eyeBreak: notch.eyeBreak)
    }

    /// Revisa cada pocos segundos si le toca empezar a algún perfil con horario.
    func checkSchedule() {
        let now = Date()
        let parts = Calendar.current.dateComponents([.weekday, .hour, .minute], from: now)
        let stamp = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let key = "\(stamp.year ?? 0)-\(stamp.month ?? 0)-\(stamp.day ?? 0)-\(stamp.hour ?? 0)-\(stamp.minute ?? 0)"
        guard key != lastScheduleKey else { return }
        for profile in engine.state.profiles where profile.autoStart
            && profile.days.contains(parts.weekday ?? 0) && profile.hour == parts.hour && profile.minute == parts.minute {
            lastScheduleKey = key
            apply(profile)
            break
        }
    }

    func showClipboard() {
        closePopover()
        ClipboardPanelController.shared.show()
    }

    // MARK: Depuración

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
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.isReleasedWhenClosed = false
            window.minSize = CGSize(width: 920, height: 640)
            window.contentView = NSHostingView(rootView: MainRoot()
                .environmentObject(engine).environmentObject(monitor).environmentObject(speed)
                .environmentObject(awake).environmentObject(storage).environmentObject(clipboard)
                .environmentObject(cleaning).environmentObject(notch).environmentObject(appearance))
            window.center()
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
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
