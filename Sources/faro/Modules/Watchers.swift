// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import CoreAudio
import CoreMediaIO

// MARK: - Batería llena y baja

/// Decide cuándo avisar de que la carga llegó al nivel elegido (para desenchufar) o de que queda poca.
@MainActor
final class BatteryAlerts: ObservableObject {
    enum Event: Equatable { case full(Int), low(Int) }

    @Published var fullEnabled: Bool { didSet { save("batteryFullEnabled", fullEnabled) } }
    @Published var fullLevel: Int { didSet { save("batteryFullLevel", fullLevel); firedFull = false } }
    @Published var lowEnabled: Bool { didSet { save("batteryLowEnabled", lowEnabled) } }

    static let lowLevels = [20, 10]
    private var firedFull = false
    private var firedLow: Set<Int> = []

    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }

    init() {
        let d = UserDefaults.standard
        fullEnabled = d.object(forKey: "batteryFullEnabled") as? Bool ?? true
        fullLevel = d.integer(forKey: "batteryFullLevel") == 0 ? 100 : d.integer(forKey: "batteryFullLevel")
        lowEnabled = d.object(forKey: "batteryLowEnabled") as? Bool ?? true
    }

    /// Devuelve el aviso que toca (si toca) para esta lectura. Cada aviso sale una sola vez por carga o descarga.
    func evaluate(percent: Int, charging: Bool) -> Event? {
        if charging {
            firedLow = []
            if percent < fullLevel - 3 { firedFull = false }
            if fullEnabled, percent >= fullLevel, !firedFull { firedFull = true; return .full(percent) }
            return nil
        }
        firedFull = false
        for level in Self.lowLevels where percent > level + 4 { firedLow.remove(level) }
        guard lowEnabled else { return nil }
        // El nivel más bajo que se cruzó y aún no se avisó.
        if let level = Self.lowLevels.filter({ percent <= $0 && !firedLow.contains($0) }).min() {
            firedLow.formUnion(Self.lowLevels.filter { $0 >= level })
            return .low(percent)
        }
        return nil
    }
}

// MARK: - Descargas terminadas

/// Avisa cuando termina una descarga en la carpeta Descargas (con cualquier navegador, sin extensiones).
@MainActor
final class DownloadWatcher: ObservableObject {
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "downloadAlerts"); enabled ? start() : stop() }
    }
    var onFinished: ((URL) -> Void)?

    private let directory: URL
    private var known: Set<String> = []
    private var pending: [String: (size: Int, stable: Int)] = [:]
    private var source: DispatchSourceFileSystemObject?
    private var poll: Timer?
    private static let temporary = ["crdownload", "download", "part", "opdownload", "tmp", "partial"]

    init(directory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]) {
        self.directory = directory
        enabled = UserDefaults.standard.object(forKey: "downloadAlerts") as? Bool ?? false
    }

    func start() {
        guard enabled, source == nil else { return }
        known = Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        s.setEventHandler { [weak self] in Task { @MainActor in self?.scan() } }
        s.setCancelHandler { close(fd) }
        s.resume()
        source = s
    }

    func stop() {
        source?.cancel()
        source = nil
        poll?.invalidate()
        pending = [:]
    }

    private func scan() {
        let names = Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        for name in names.subtracting(known) where !name.hasPrefix(".") {
            if pending[name] == nil { pending[name] = (-1, 0) }
        }
        known.formUnion(names)
        if !pending.isEmpty, poll == nil {
            poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.checkPending() } }
        }
    }

    /// Una descarga está lista cuando su nombre ya no es temporal y su tamaño no cambia durante 2 lecturas.
    private func checkPending() {
        for (name, state) in pending {
            let url = directory.appendingPathComponent(name)
            guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) else {
                pending[name] = nil // desapareció: era un nombre temporal renombrado
                continue
            }
            if Self.temporary.contains(url.pathExtension.lowercased()) { pending[name] = (size, 0); continue }
            if size == state.size { pending[name] = (size, state.stable + 1) } else { pending[name] = (size, 0) }
            if (pending[name]?.stable ?? 0) >= 2 {
                pending[name] = nil
                onFinished?(url)
            }
        }
        if pending.isEmpty { poll?.invalidate(); poll = nil }
    }
}

// MARK: - Capturas de pantalla

/// Detecta las capturas de pantalla nuevas y las manda a la bandeja. Vigila la carpeta donde macOS las guarda
/// (el Escritorio, o la que hayas elegido) y reconoce una captura por la marca que el propio sistema le pone al archivo.
@MainActor
final class ScreenshotWatcher: ObservableObject {
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "screenshotShelf"); enabled ? start() : stop() }
    }
    var onScreenshot: ((URL) -> Void)?

    private let directory: URL
    private var known: Set<String> = []
    private var source: DispatchSourceFileSystemObject?

    init(directory: URL? = nil) {
        self.directory = directory ?? Self.systemLocation()
        enabled = UserDefaults.standard.object(forKey: "screenshotShelf") as? Bool ?? false
    }

    /// Carpeta de capturas de macOS (`defaults read com.apple.screencapture location`) o el Escritorio.
    static func systemLocation() -> URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    /// `true` si el archivo lleva la marca de captura de pantalla que escribe macOS.
    static func isScreenCapture(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, XATTR_NOFOLLOW) >= 0
    }

    func start() {
        guard enabled, source == nil else { return }
        known = Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        s.setEventHandler { [weak self] in Task { @MainActor in self?.scan() } }
        s.setCancelHandler { close(fd) }
        s.resume()
        source = s
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func scan() {
        let names = Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        let added = names.subtracting(known).filter { !$0.hasPrefix(".") }
        known = names
        for name in added { confirm(directory.appendingPathComponent(name), attempt: 0) }
    }

    /// macOS escribe la imagen y un instante después le pone la marca: se mira un par de veces.
    private func confirm(_ url: URL, attempt: Int) {
        if Self.isScreenCapture(url) { onScreenshot?(url); return }
        guard attempt < 3 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            MainActor.assumeIsolated { self?.confirm(url, attempt: attempt + 1) }
        }
    }
}

// MARK: - Discos USB

/// Avisa cuando se conecta una memoria o un disco externo y permite expulsarlo con seguridad.
@MainActor
final class VolumeWatcher: ObservableObject {
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "usbAlerts"); enabled ? start() : stop() }
    }
    /// (nombre, carpeta del volumen)
    var onMount: ((String, URL) -> Void)?

    private var observer: NSObjectProtocol?

    init() { enabled = UserDefaults.standard.object(forKey: "usbAlerts") as? Bool ?? true }

    func start() {
        guard enabled, observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] note in
            guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            MainActor.assumeIsolated {
                guard let self, let name = Self.ejectableName(url) else { return }
                self.onMount?(name, url)
            }
        }
    }

    func stop() {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
    }

    /// Nombre del volumen si es externo y se puede expulsar (memorias, discos, imágenes de disco).
    static func ejectableName(_ url: URL) -> String? {
        let keys: Set<URLResourceKey> = [.volumeIsInternalKey, .volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsLocalKey, .volumeNameKey]
        guard let values = try? url.resourceValues(forKeys: keys),
              values.volumeIsInternal != true, values.volumeIsLocal != false,
              values.volumeIsEjectable == true || values.volumeIsRemovable == true else { return nil }
        return values.volumeName ?? url.lastPathComponent
    }

    static func eject(_ url: URL) -> Bool {
        (try? NSWorkspace.shared.unmountAndEjectDevice(at: url)) != nil
    }
}

// MARK: - Cámara y micrófono en uso

/// Dice si alguna app tiene la cámara o el micrófono activos (lo mismo que los puntos verde y naranja de macOS).
enum PrivacyProbe {
    static func cameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else { return false }
        var ids = [CMIODeviceID](repeating: 0, count: Int(size) / MemoryLayout<CMIODeviceID>.size)
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &size, &ids) == noErr else { return false }
        for id in ids {
            var running = UInt32(0)
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            var a = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                                              mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                              mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            if CMIOObjectGetPropertyData(id, &a, 0, nil, runSize, &runSize, &running) == noErr, running != 0 { return true }
        }
        return false
    }

    static func microphoneInUse() -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else { return false }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return false }
        for id in ids {
            // Solo dispositivos con entrada.
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                                     mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr, streamSize > 0 else { continue }
            var running = UInt32(0)
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                               mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            if AudioObjectGetPropertyData(id, &a, 0, nil, &runSize, &running) == noErr, running != 0 { return true }
        }
        return false
    }
}

// MARK: - Gotero de color

enum ColorEyedropper {
    /// Abre la lupa del sistema; entrega el color elegido como "#RRGGBB" (no pide permiso de grabación de pantalla).
    @MainActor
    static func pick(_ completion: @escaping (String, NSColor) -> Void) {
        let sampler = NSColorSampler()
        Self.keepAlive = sampler
        sampler.show { color in
            Self.keepAlive = nil
            guard let color, let rgb = color.usingColorSpace(.sRGB) else { return }
            let hex = String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()),
                             Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
            completion(hex, color)
        }
    }

    @MainActor private static var keepAlive: NSColorSampler?
}
