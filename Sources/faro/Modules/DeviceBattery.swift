// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import IOKit
import IOKit.ps

/// Carga de los dispositivos Bluetooth conectados (AirPods con estuche, teclado, ratón, trackpad…).
/// Lee lo que macOS ya sabe con `system_profiler`; no necesita permisos.
@MainActor
final class DeviceBattery: ObservableObject {
    struct Device: Equatable, Hashable, Identifiable {
        var name: String
        var symbol: String
        /// Porcentaje que se muestra: el más bajo entre los auriculares, o el único del dispositivo.
        var percent: Int
        /// Detalle como "I 80 · D 78 · Estuche 52" (solo AirPods).
        var detail: String?
        /// Se está cargando ahora (solo lo informan los periféricos que macOS expone por IOKit).
        var charging = false
        /// "Bluetooth" o "USB" cuando se sabe.
        var transport: String?
        var id: String { name }
    }

    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "deviceBatteryEnabled"); if enabled { refresh(force: true) } } }
    @Published private(set) var devices: [Device] = []
    /// Avisar cuando un teclado, ratón o trackpad llega a poca batería.
    @Published var lowAlerts: Bool { didSet { UserDefaults.standard.set(lowAlerts, forKey: "deviceLowAlerts") } }
    /// Se llama con cada dispositivo que cruza el 20 % o el 10 % sin estar cargando.
    var onLow: ((Device) -> Void)?
    private var firedLow: [String: Set<Int>] = [:]
    private var powerSource: CFRunLoopSource?

    private var lastRefresh = Date.distantPast
    private var loading = false

    init() {
        enabled = UserDefaults.standard.object(forKey: "deviceBatteryEnabled") as? Bool ?? true
        lowAlerts = UserDefaults.standard.object(forKey: "deviceLowAlerts") as? Bool ?? true
    }

    /// Datos de muestra para capturas y pruebas.
    func loadDemo() {
        devices = Self.merge(fast: [
            Device(name: "Magic Keyboard", symbol: "keyboard", percent: 18, detail: nil, charging: false, transport: "Bluetooth"),
            Device(name: "Magic Mouse", symbol: "computermouse", percent: 64, detail: nil, charging: true, transport: "Bluetooth"),
        ], slow: [Device(name: "AirPods Pro", symbol: "airpods", percent: 72, detail: "I 80 · D 72 · Estuche 55")])
    }

    /// macOS avisa cuando cambia la carga de un accesorio: se actualiza al momento, sin sondear.
    func startWatching() {
        guard powerSource == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let battery = Unmanaged<DeviceBattery>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { battery.refreshFast() }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        powerSource = source
        refreshFast()
    }

    /// Lectura rápida por IOKit (milisegundos): periféricos que macOS expone como fuentes de energía.
    func refreshFast() {
        guard enabled else { return }
        let fast = PeripheralBattery.read()
        devices = Self.merge(fast: fast, slow: devices.filter { $0.transport == nil })
        checkLow()
    }

    /// Vuelve a leer como mucho una vez por minuto (tarda un par de segundos), salvo que se pida a la fuerza.
    func refresh(force: Bool = false) {
        guard enabled, !loading, force || Date().timeIntervalSince(lastRefresh) > 60 else { return }
        loading = true
        Task {
            let data = await Task.detached(priority: .utility) { Self.readProfiler() }.value
            let slow = data.map(Self.parse) ?? []
            devices = Self.merge(fast: PeripheralBattery.read(), slow: slow)
            lastRefresh = Date()
            loading = false
            checkLow()
        }
    }

    /// Une las dos fuentes: lo que da IOKit (en vivo, con carga) manda sobre lo que dice `system_profiler`
    /// para el mismo dispositivo. Los de menos batería van primero.
    static func merge(fast: [Device], slow: [Device]) -> [Device] {
        var byName: [String: Device] = [:]
        for device in slow { byName[device.name.lowercased()] = device }
        for device in fast {
            var merged = device
            if let known = byName[device.name.lowercased()] { merged.detail = known.detail; merged.symbol = known.symbol }
            byName[device.name.lowercased()] = merged
        }
        return byName.values.sorted { ($0.percent, $0.name) < ($1.percent, $1.name) }
    }

    /// Dispositivos que acaban de cruzar el 20 % o el 10 % (una vez por descenso; se rearma al cargar).
    func lowCrossings(_ list: [Device]) -> [Device] {
        var out: [Device] = []
        for device in list {
            if device.charging || device.percent > 25 { firedLow[device.id] = nil; continue }
            let crossed = [20, 10].filter { device.percent <= $0 && !(firedLow[device.id]?.contains($0) ?? false) }
            guard let level = crossed.min() else { continue }
            firedLow[device.id, default: []].formUnion([20, 10].filter { $0 >= level })
            out.append(device)
        }
        return out
    }

    private func checkLow() {
        guard lowAlerts else { return }
        for device in lowCrossings(devices) { onLow?(device) }
    }

    nonisolated private static func readProfiler() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }

    private static func percent(_ info: [String: Any], _ key: String) -> Int? {
        (info[key] as? String).flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "% "))) }
    }

    /// Convierte la salida de `system_profiler SPBluetoothDataType -json` en la lista de dispositivos con carga.
    static func parse(_ data: Data) -> [Device] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let section = (root["SPBluetoothDataType"] as? [[String: Any]])?.first,
              let connected = section["device_connected"] as? [[String: Any]] else { return [] }
        var out: [Device] = []
        for entry in connected {
            for (name, value) in entry {
                guard let info = value as? [String: Any] else { continue }
                let left = percent(info, "device_batteryLevelLeft"), right = percent(info, "device_batteryLevelRight")
                let box = percent(info, "device_batteryLevelCase"), main = percent(info, "device_batteryLevelMain")
                let symbol = BluetoothWatcher.symbol(for: name, minor: info["device_minorType"] as? String)
                if left != nil || right != nil {
                    let buds = [left, right].compactMap { $0 }
                    var parts: [String] = []
                    if let left { parts.append("\(tr("I")) \(left)") }
                    if let right { parts.append("\(tr("D")) \(right)") }
                    if let box { parts.append("\(tr("Estuche")) \(box)") }
                    out.append(Device(name: name, symbol: symbol, percent: buds.min() ?? 0, detail: parts.joined(separator: " · ")))
                } else if let level = main ?? box {
                    out.append(Device(name: name, symbol: symbol, percent: level, detail: nil))
                }
            }
        }
        return out.sorted { $0.name < $1.name }
    }
}
