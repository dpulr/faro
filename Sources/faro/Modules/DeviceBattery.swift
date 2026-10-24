// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

/// Carga de los dispositivos Bluetooth conectados (AirPods con estuche, teclado, ratón, trackpad…).
/// Lee lo que macOS ya sabe con `system_profiler`; no necesita permisos.
@MainActor
final class DeviceBattery: ObservableObject {
    struct Device: Equatable, Identifiable {
        var name: String
        var symbol: String
        /// Porcentaje que se muestra: el más bajo entre los auriculares, o el único del dispositivo.
        var percent: Int
        /// Detalle como "I 80 · D 78 · Estuche 52" (solo AirPods).
        var detail: String?
        var id: String { name }
    }

    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "deviceBatteryEnabled"); if enabled { refresh(force: true) } } }
    @Published private(set) var devices: [Device] = []

    private var lastRefresh = Date.distantPast
    private var loading = false

    init() { enabled = UserDefaults.standard.object(forKey: "deviceBatteryEnabled") as? Bool ?? true }

    /// Vuelve a leer como mucho una vez por minuto (tarda un par de segundos), salvo que se pida a la fuerza.
    func refresh(force: Bool = false) {
        guard enabled, !loading, force || Date().timeIntervalSince(lastRefresh) > 60 else { return }
        loading = true
        Task {
            let data = await Task.detached(priority: .utility) { Self.readProfiler() }.value
            devices = data.map(Self.parse) ?? devices
            lastRefresh = Date()
            loading = false
        }
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
