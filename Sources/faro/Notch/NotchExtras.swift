// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import Carbon.HIToolbox
import Combine

/// Los módulos "de bolsillo" del notch (temporizador, micrófono, baterías, descargas, capturas, USB, privacidad…)
/// y el pegamento que los conecta con los avisos del notch y la bandeja.
@MainActor
final class NotchExtras: ObservableObject {
    var timer = FocusTimer()
    var mic = MicMute()
    var devices = DeviceBattery()
    var battery = BatteryAlerts()
    var downloads = DownloadWatcher()
    var screenshots = ScreenshotWatcher()
    var volumes = VolumeWatcher()

    @Published var eyedropperEnabled: Bool { didSet { save("eyedropperEnabled", eyedropperEnabled) } }
    @Published var privacyEnabled: Bool { didSet { save("privacyIndicator", privacyEnabled); if !privacyEnabled { cameraOn = false; micOn = false } } }
    @Published var capsEnabled: Bool { didSet { save("capsLockHUD", capsEnabled) } }
    @Published private(set) var cameraOn = false
    @Published private(set) var micOn = false

    /// Hay algo en marcha que merece verse con el notch recogido.
    var hasLive: Bool { timer.active || cameraOn || micOn }

    private weak var notch: NotchModel?
    private var shelf: ShelfStore?
    private var cancellables: Set<AnyCancellable> = []
    private var clock: Timer?
    private var tick = 0
    private var lastCaps: Bool?

    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }

    init() {
        let d = UserDefaults.standard
        eyedropperEnabled = d.object(forKey: "eyedropperEnabled") as? Bool ?? true
        privacyEnabled = d.object(forKey: "privacyIndicator") as? Bool ?? true
        capsEnabled = d.object(forKey: "capsLockHUD") as? Bool ?? true
        // Que la vista se actualice cuando cambie cualquiera de los módulos.
        forward(timer); forward(mic); forward(devices); forward(battery)
        forward(downloads); forward(screenshots); forward(volumes)
    }

    private func forward<O: ObservableObject>(_ object: O) where O.ObjectWillChangePublisher == ObservableObjectPublisher {
        object.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }.store(in: &cancellables)
    }

    // MARK: Arranque

    func start(notch: NotchModel, shelf: ShelfStore, monitor: SystemMonitor) {
        self.notch = notch
        self.shelf = shelf
        timer.onEvent = { [weak self] symbol, text in self?.notch?.showToast(symbol: symbol, text: text, seconds: 6) }
        notch.onBluetoothConnect = { [weak self] in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000) // a los AirPods les toma unos segundos informar su carga
                self?.devices.refresh(force: true)
            }
        }
        downloads.onFinished = { [weak self] url in self?.downloadFinished(url) }
        screenshots.onScreenshot = { [weak self] url in self?.screenshotTaken(url) }
        volumes.onMount = { [weak self] name, url in self?.volumeMounted(name, url) }
        Publishers.CombineLatest(monitor.$batteryPercent, monitor.$batteryCharging)
            .sink { [weak self] percent, charging in
                guard let self, let percent else { return }
                self.batteryReading(percent: percent, charging: charging)
            }
            .store(in: &cancellables)
        downloads.start()
        screenshots.start()
        volumes.start()
        devices.refresh()
        Hotkeys.shared.register(keyCode: kVK_ANSI_M, modifiers: cmdKey | optionKey | controlKey) { [weak self] in
            Task { @MainActor in self?.toggleMic() }
        }
        clock = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        clock?.tolerance = 0.1
    }

    /// Cada medio segundo: Bloq Mayús; cada 2 s: cámara y micrófono; y las baterías al desplegar el panel.
    private func poll() {
        tick += 1
        if capsEnabled {
            let on = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
            if let last = lastCaps, last != on { capsChanged(on) }
            lastCaps = on
        } else {
            lastCaps = nil
        }
        if privacyEnabled, tick % 4 == 0 {
            let camera = PrivacyProbe.cameraInUse(), microphone = PrivacyProbe.microphoneInUse()
            if camera != cameraOn { cameraOn = camera }
            if microphone != micOn { micOn = microphone }
        }
        if notch?.expanded == true { devices.refresh() }
    }

    // MARK: Acciones

    func toggleMic() {
        guard mic.enabled, mic.available else { return }
        mic.toggle()
        notch?.showToast(symbol: mic.muted ? "mic.slash.fill" : "mic.fill",
                         text: mic.muted ? tr("Micrófono silenciado") : tr("Micrófono activado"), seconds: 2)
    }

    func pickColor() {
        notch?.collapse?()
        ColorEyedropper.pick { [weak self] hex, color in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
            self?.notch?.showToast(symbol: "eyedropper", text: String(format: tr("%@ copiado"), hex), seconds: 4, swatch: hex)
            _ = color
        }
    }

    // MARK: Avisos

    func downloadFinished(_ url: URL) {
        notch?.showToast(symbol: "arrow.down.circle.fill", text: String(format: tr("Descarga lista: %@"), url.lastPathComponent),
                         seconds: 7, actionLabel: tr("Mostrar")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    func screenshotTaken(_ url: URL) {
        shelf?.add([url])
        notch?.showToast(symbol: "camera.viewfinder", text: tr("Captura guardada en la bandeja"), seconds: 4,
                         actionLabel: tr("Abrir")) { AppController.shared.showShelf() }
    }

    func volumeMounted(_ name: String, _ url: URL) {
        notch?.showToast(symbol: "externaldrive.fill", text: String(format: tr("%@ conectado"), name), seconds: 8,
                         actionLabel: tr("Expulsar")) { [weak self] in
            let ok = VolumeWatcher.eject(url)
            self?.notch?.showToast(symbol: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                   text: ok ? String(format: tr("Ya puedes desconectar %@"), name)
                                            : String(format: tr("No se pudo expulsar %@: está en uso"), name), seconds: 5)
        }
    }

    func batteryReading(percent: Int, charging: Bool) {
        switch battery.evaluate(percent: percent, charging: charging) {
        case .full(let level):
            notch?.showToast(symbol: "battery.100percent.bolt", text: String(format: tr("Batería al %lld %%: ya puedes desenchufar"), level), seconds: 6)
        case .low(let level):
            notch?.showToast(symbol: level <= 10 ? "battery.0percent" : "battery.25percent",
                             text: String(format: tr("Batería baja: %lld %%"), level), seconds: 6)
        case nil:
            break
        }
    }

    private func capsChanged(_ on: Bool) {
        notch?.showToast(symbol: on ? "capslock.fill" : "capslock", text: on ? tr("Bloq Mayús activado") : tr("Bloq Mayús desactivado"), seconds: 1.5)
    }
}
