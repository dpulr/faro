// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import IOBluetooth

/// Avisa cuando un dispositivo Bluetooth ya emparejado se conecta (audífonos, teclado, ratón…).
final class BluetoothWatcher: NSObject {
    /// (nombre, símbolo SF)
    var onConnect: ((String, String) -> Void)?
    private var registration: IOBluetoothUserNotification?

    func start() {
        guard registration == nil else { return }
        registration = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
    }

    func stop() {
        registration?.unregister()
        registration = nil
    }

    @objc private func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let name = device.name ?? "Bluetooth"
        let symbol = Self.symbol(for: name, major: device.deviceClassMajor)
        DispatchQueue.main.async { [weak self] in self?.onConnect?(name, symbol) }
    }

    /// Igual, pero con el tipo que informa `system_profiler` ("Keyboard", "Mouse", "Headphones"…).
    static func symbol(for name: String, minor: String?) -> String {
        let byName = symbol(for: name, major: 0)
        if byName != "wave.3.right" { return byName }
        switch (minor ?? "").lowercased() {
        case "keyboard": return "keyboard"
        case "mouse", "magic trackpad", "trackpad": return "computermouse"
        case "headphones", "headset": return "headphones"
        case "gamepad": return "gamecontroller"
        case "speaker": return "hifispeaker"
        default: return byName
        }
    }

    /// Elige un ícono por el nombre y, si no basta, por la clase del dispositivo.
    static func symbol(for name: String, major: BluetoothDeviceClassMajor) -> String {
        let n = name.lowercased()
        if n.contains("airpods") { return "airpods" }
        if n.contains("keyboard") || n.contains("teclado") { return "keyboard" }
        if n.contains("mouse") || n.contains("trackpad") || n.contains("ratón") { return "computermouse" }
        if n.contains("controller") || n.contains("mando") || n.contains("dualsense") { return "gamecontroller" }
        if n.contains("watch") { return "applewatch" }
        switch Int(major) {
        case 4: return "headphones"          // audio y video
        case 5: return "keyboard"            // periféricos
        default: return "wave.3.right"
        }
    }
}
