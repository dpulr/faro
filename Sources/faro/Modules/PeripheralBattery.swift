// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import IOKit
import IOKit.ps

/// Batería de teclados, ratones y trackpads (Apple y otros que macOS trate como accesorios con batería).
/// Lee las "fuentes de energía" que publica IOKit y, como respaldo, el registro de dispositivos HID.
enum PeripheralBattery {
    /// Convierte la descripción de una fuente de energía en un dispositivo, si es un accesorio y no la batería del Mac.
    static func device(from description: [String: Any]) -> DeviceBattery.Device? {
        let type = description[kIOPSTypeKey] as? String ?? ""
        guard type != kIOPSInternalBatteryType, type != kIOPSUPSType else { return nil }
        // Los AirPods publican una fuente por pieza (estuche, izquierdo, derecho, combinada): solo cuenta la combinada.
        if let part = description["Part Identifier"] as? String, part != "Combined" { return nil }
        guard let name = (description[kIOPSNameKey] as? String)?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
              let capacity = description[kIOPSCurrentCapacityKey] as? Int else { return nil }
        let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
        let percent = maximum > 0 && maximum != 100 ? Int((Double(capacity) / Double(maximum) * 100).rounded()) : capacity
        guard (0...100).contains(percent) else { return nil }
        let transport = description[kIOPSTransportTypeKey] as? String
        return DeviceBattery.Device(name: name, symbol: symbol(for: name), percent: percent, detail: nil,
                                    charging: description[kIOPSIsChargingKey] as? Bool ?? false,
                                    transport: transport == nil ? "Bluetooth" : (transport?.lowercased().contains("usb") == true ? "USB" : "Bluetooth"))
    }

    static func symbol(for name: String) -> String { BluetoothWatcher.symbol(for: name, minor: nil) }

    /// `IOPSCopyPowerSourcesInfo` solo trae la batería del Mac; la variante por tipo 0 incluye también los accesorios.
    private static func allSources() -> CFTypeRef? {
        typealias ByType = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?
        if let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
           let symbol = dlsym(handle, "IOPSCopyPowerSourcesByType"),
           let info = unsafeBitCast(symbol, to: ByType.self)(0) { return info.takeRetainedValue() }
        return IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
    }

    /// Todos los accesorios con batería que macOS informa ahora mismo.
    static func read() -> [DeviceBattery.Device] {
        var found: [DeviceBattery.Device] = []
        if let info = allSources(),
           let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in list {
                if let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                   let device = device(from: description) { found.append(device) }
            }
        }
        // Un mismo dispositivo puede aparecer por varios transportes: se queda con la lectura más baja.
        var lowest: [String: DeviceBattery.Device] = [:]
        var order: [String] = []
        for device in found {
            let key = device.name.lowercased()
            if let known = lowest[key] { if device.percent < known.percent { lowest[key] = device } }
            else { lowest[key] = device; order.append(key) }
        }
        found = order.compactMap { lowest[$0] }
        // Respaldo: dispositivos HID que publican BatteryPercent (teclados y trackpads Magic, por ejemplo).
        for device in hidDevices() where !found.contains(where: { $0.name.lowercased() == device.name.lowercased() }) {
            found.append(device)
        }
        return found
    }

    private static func hidDevices() -> [DeviceBattery.Device] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS
        else { return [] }
        defer { IOObjectRelease(iterator) }
        var out: [DeviceBattery.Device] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            func property(_ key: String) -> Any? { IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() }
            if let percent = (property("BatteryPercent") as? NSNumber)?.intValue, (0...100).contains(percent),
               let name = property("Product") as? String, !name.contains("Internal") {
                let transport = (property("Transport") as? String)?.lowercased().contains("usb") == true ? "USB" : "Bluetooth"
                out.append(DeviceBattery.Device(name: name, symbol: symbol(for: name), percent: percent, detail: nil,
                                                charging: false, transport: transport))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return out
    }
}
