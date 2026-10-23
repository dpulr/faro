// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI
import IOKit.pwr_mgt

/// Bloquea teclado (y opcionalmente trackpad y mouse) para poder limpiarlos sin escribir nada por accidente.
/// Usa un filtro de eventos de sesión, que necesita el permiso de Accesibilidad.
@MainActor
final class CleaningMode: ObservableObject {
    @Published private(set) var active = false
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 60
    @Published var needsPermission = false
    @Published var duration: Int { didSet { UserDefaults.standard.set(duration, forKey: "cleanDuration") } }
    @Published var lockPointer: Bool { didSet { UserDefaults.standard.set(lockPointer, forKey: "cleanLockPointer") } }

    /// Eventos retenidos en la sesión actual (para comprobar que el bloqueo funciona).
    private(set) var swallowed = 0

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var endDate = Date()
    private var escDownSince: Date?
    private var windows: [FloatingPanel] = []
    private var softMonitor: Any?
    /// `true` si el bloqueo usa el filtro del sistema (completo); `false` si es el básico, sin permisos.
    @Published private(set) var fullLock = false
    private var assertion: IOPMAssertionID = 0

    var overlayWindow: NSWindow? { windows.first }

    init() {
        let saved = UserDefaults.standard.integer(forKey: "cleanDuration")
        duration = saved == 0 ? 60 : saved
        lockPointer = UserDefaults.standard.bool(forKey: "cleanLockPointer")
    }

    var trusted: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Empieza a bloquear. Con el permiso de Accesibilidad usa el filtro del sistema (completo); sin él, el bloqueo básico:
    /// faro ocupa la pantalla, se queda con el teclado y descarta todo lo que se pulse.
    @discardableResult
    func start(seconds: Int? = nil, prompt: Bool = false) -> Bool {
        guard !active else { return true }
        if trusted, startFull(seconds: seconds) { return true }
        needsPermission = true
        startBasic(seconds: seconds)
        return true
    }

    private func startFull(seconds: Int?) -> Bool {
        var types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, CGEventType(rawValue: 14)!] // 14 = teclas de sistema (volumen, brillo…)
        if lockPointer {
            types += [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
                      .scrollWheel, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        }
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: mask, callback: cleaningTapCallback, userInfo: refcon) else {
            return false
        }
        needsPermission = false
        tap = port
        source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        fullLock = true
        begin(seconds: seconds)
        return true
    }

    private func startBasic(seconds: Int?) {
        fullLock = false
        begin(seconds: seconds)
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
        // Todo lo que se teclee llega a faro y se descarta aquí.
        softMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            MainActor.assumeIsolated { self?.basicKey(event) }
            return nil
        }
        // Modo quiosco: sin Dock, sin barra de menú y sin cambiar de app con ⌘Tab.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.active, !self.fullLock else { return }
            NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableForceQuit,
                                         .disableHideApplication, .disableAppleMenu]
        }
    }

    /// Lo común de los dos modos: cuenta regresiva, pantalla oscura y pantalla encendida.
    private func begin(seconds: Int?) {
        swallowed = 0
        escDownSince = nil
        total = TimeInterval(seconds ?? duration)
        remaining = total
        endDate = Date().addingTimeInterval(total)
        active = true
        IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    "faro: limpiando el teclado" as CFString, &assertion)
        showOverlay()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Tecla recibida en el modo básico: se descarta y se vigila la salida de emergencia (mantener Esc 3 segundos).
    private func basicKey(_ event: NSEvent) {
        swallowed += 1
        guard event.keyCode == 53 else { return }
        if event.type == .keyDown {
            if let since = escDownSince {
                if Date().timeIntervalSince(since) >= 3 { stop() }
            } else {
                escDownSince = Date()
            }
        } else if event.type == .keyUp {
            escDownSince = nil
        }
    }

    func stop() {
        guard active else { return }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        if let softMonitor { NSEvent.removeMonitor(softMonitor) }
        softMonitor = nil
        if !fullLock { NSApp.presentationOptions = [] }
        fullLock = false
        timer?.invalidate()
        timer = nil
        if assertion != 0 { IOPMAssertionRelease(assertion); assertion = 0 }
        windows.forEach { $0.orderOut(nil) }
        windows = []
        active = false
    }

    private func tick() {
        remaining = max(endDate.timeIntervalSinceNow, 0)
        if remaining <= 0 { stop() }
    }

    /// Se llama para cada tecla: la retiene y vigila la salida de emergencia (mantener Esc 3 segundos).
    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        swallowed += 1
        if (type == .keyDown || type == .keyUp), event.getIntegerValueField(.keyboardEventKeycode) == 53 {
            if type == .keyDown {
                if let since = escDownSince {
                    if Date().timeIntervalSince(since) >= 3 { DispatchQueue.main.async { self.stop() } }
                } else {
                    escDownSince = Date()
                }
            } else {
                escDownSince = nil
            }
        }
        return nil
    }

    private func showOverlay() {
        windows = NSScreen.screens.map { screen in
            let panel = FloatingPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                      backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(rootView: CleaningOverlay(mode: self).environmentObject(Appearance.shared))
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            return panel
        }
    }
}

/// El filtro no puede capturar nada: solo recibe el evento y el modo que lo creó.
private let cleaningTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let mode = Unmanaged<CleaningMode>.fromOpaque(refcon).takeUnretainedValue()
    return MainActor.assumeIsolated { mode.handle(type: type, event: event) }
}

struct CleaningOverlay: View {
    @ObservedObject var mode: CleaningMode

    private var clock: String {
        let s = Int(mode.remaining.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
            VStack(spacing: 22) {
                Image(systemName: "keyboard").font(.system(size: 46, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.9))
                Text(mode.lockPointer ? "Teclado y trackpad bloqueados" : "Teclado bloqueado")
                    .font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                Text(clock).font(.system(size: 72, weight: .light, design: .rounded))
                    .monospacedDigit().foregroundStyle(.white)
                UsageBar(value: mode.total > 0 ? 1 - mode.remaining / mode.total : 0, tint: Theme.accent)
                    .frame(width: 280)
                Text("Límpialo con calma. Se desbloquea solo al llegar a cero.\nPara salir antes, mantén presionada la tecla Esc durante 3 segundos.")
                    .font(.callout).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.6))
                if !mode.lockPointer {
                    Button("Terminar ahora") { mode.stop() }.buttonStyle(PillButtonStyle(prominent: true))
                }
            }
        }
        .ignoresSafeArea()
    }
}
