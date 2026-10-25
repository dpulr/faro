// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import IOKit

/// Un puerto físico del Mac (USB-C, MagSafe) y lo que macOS informa de él.
struct PortInfo: Identifiable, Equatable {
    var number: Int
    var kind: String                 // "USB-C", "MagSafe 3"
    var connected: Bool
    var activeTransports: [String]   // "USB2", "USB3", "CIO", "DisplayPort"…
    var supportedTransports: [String]
    var plugCount: Int
    var liquidDetected: Bool
    var overcurrentCount: Int
    var activeCable: Bool
    var opticalCable: Bool
    var cable: CableInfo?
    var partner: PartnerInfo?
    var devices: [PortDevice] = []
    var id: String { "\(kind)-\(number)" }

    var isMagSafe: Bool { kind.lowercased().contains("magsafe") }

    var title: String { isMagSafe ? kind : "\(kind) \(number)" }

    /// Lo máximo que el puerto permite, en palabras: Thunderbolt/USB4, USB 3 o solo carga.
    var capability: String {
        if isMagSafe { return tr("Solo carga") }
        if supportedTransports.contains("CIO") { return "Thunderbolt / USB4" }
        if supportedTransports.contains("USB3") { return "USB 3" }
        return "USB 2"
    }

    /// Lo que pasa por el puerto ahora mismo: "USB 3 + DisplayPort".
    var activity: String {
        guard connected else { return tr("Libre") }
        let names = activeTransports.compactMap { PortInventory.transportName($0) }
        return names.isEmpty ? tr("Conectado") : names.joined(separator: " + ")
    }
}

/// Lo que el chip (e-marker) del cable dice de sí mismo.
struct CableInfo: Equatable {
    var active: Bool
    var vendorID: Int
    var speedCode: Int       // 0 USB 2.0, 1 USB 3.2 Gen 1, 2 Gen 2, 3 USB4 Gen 3, 4 USB4 Gen 4
    var currentAmps: Double
    var maxVolts: Int

    var maxWatts: Int { Int(currentAmps * Double(maxVolts)) }

    /// Velocidad máxima de datos en Mb/s.
    var speedMbps: Int {
        switch speedCode { case 0: 480; case 1: 5_000; case 2: 10_000; case 3: 40_000; default: 80_000 }
    }

    var speedName: String {
        switch speedCode { case 0: "USB 2.0"; case 1: "USB 3.2 Gen 1 (5 Gb/s)"; case 2: "USB 3.2 Gen 2 (10 Gb/s)"; case 3: "USB4 / Thunderbolt (40 Gb/s)"; default: "USB4 80 Gb/s" }
    }

    var vendor: String { PortInventory.vendorName(vendorID) ?? String(format: "0x%04X", vendorID) }

    /// Decodifica los VDO que el cable publica: [encabezado, certificación, producto, cable…].
    static func decode(vdos: [UInt32], productType: Int) -> CableInfo? {
        guard productType == 3 || productType == 4, vdos.count >= 4 else { return nil }
        let cable = vdos[3]
        let current: Double
        switch (cable >> 5) & 3 { case 1: current = 3; case 2: current = 5; default: current = 1.5 }
        let volts = [20, 30, 40, 50][Int((cable >> 9) & 3)]
        return CableInfo(active: productType == 4, vendorID: Int(vdos[0] & 0xFFFF), speedCode: Int(cable & 7), currentAmps: current, maxVolts: volts)
    }
}

/// El otro extremo (concentrador, base, cargador) cuando se identifica por Power Delivery.
struct PartnerInfo: Equatable {
    var kind: String
    var vendorID: Int
}

/// Un dispositivo USB colgado de un puerto.
struct PortDevice: Identifiable, Equatable {
    var name: String
    var vendor: String?
    var speedMbps: Int
    var id: String { "\(vendor ?? "")-\(name)-\(speedMbps)" }

    var speedName: String {
        switch speedMbps {
        case 0..<100: String(format: "%.1f Mb/s", Double(speedMbps))
        case 100..<1000: "\(speedMbps) Mb/s"
        default: "\(speedMbps / 1000) Gb/s"
        }
    }
}

/// Lo que se concluye de un puerto con algo conectado.
struct LinkVerdict: Equatable {
    enum Level { case ok, limited }
    var level: Level
    var title: String
    var detail: String
}

enum LinkAnalysis {
    /// Compara lo que permiten el puerto y el cable con la velocidad real del enlace.
    static func verdict(for port: PortInfo) -> LinkVerdict? {
        guard port.connected, !port.isMagSafe, let device = port.devices.max(by: { $0.speedMbps < $1.speedMbps }) else { return nil }
        let portMax = port.supportedTransports.contains("CIO") ? 40_000 : (port.supportedTransports.contains("USB3") ? 10_000 : 480)
        if let cable = port.cable, cable.speedMbps < portMax, device.speedMbps <= cable.speedMbps {
            return LinkVerdict(level: .limited, title: String(format: tr("El cable limita a %@"), device.speedName),
                               detail: String(format: tr("Es un cable %@ (%@) y el puerto admite hasta %lld Gb/s. Con un cable USB 3 o Thunderbolt, %@ podría ir más rápido."),
                                              cable.active ? tr("activo") : tr("pasivo"), cable.speedName, portMax / 1000, device.name))
        }
        if port.cable == nil, device.speedMbps <= 480, portMax > 480 {
            return LinkVerdict(level: .limited, title: String(format: tr("%@ va a USB 2"), device.name),
                               detail: tr("El puerto admite mucho más. Puede ser el cable (muchos no llevan datos rápidos) o el propio dispositivo."))
        }
        return LinkVerdict(level: .ok, title: String(format: tr("%@ a %@"), device.name, device.speedName),
                           detail: tr("El puerto, el cable y el dispositivo no se estorban."))
    }
}

enum PortInventory {
    nonisolated static func transportName(_ code: String) -> String? {
        switch code {
        case "USB2": "USB 2"
        case "USB3": "USB 3"
        case "CIO": "Thunderbolt"
        case "DisplayPort", "DP": "DisplayPort"
        case "CC": nil   // canal de configuración del cable, no es un dato para el usuario
        default: code
        }
    }

    nonisolated static func vendorName(_ id: Int) -> String? {
        switch id { case 0x05AC: "Apple"; case 0x22B8: "Motorola"; case 0x0781: "SanDisk"; default: nil }
    }

    /// Lee los puertos desde los controladores `AppleHPMInterface*` (clases públicas del registro de E/S).
    nonisolated static func read() -> [PortInfo] {
        var ports: [PortInfo] = []
        for className in [
            "AppleTCControllerType10", "AppleTCControllerType11", "AppleTCControllerType12",
            "AppleHPMInterfaceType10", "AppleHPMInterfaceType11", "AppleHPMInterfaceType12",
            "AppleHPMInterfaceType16", "AppleHPMInterfaceType18"
        ] {
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }
            var service = IOIteratorNext(iterator)
            while service != 0 {
                func property(_ key: String) -> Any? { IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() }
                if var port = port(from: { property($0) }) {
                    attachPower(service, to: &port)
                    ports.append(port)
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
        }
        let devices = usbDevicesByPort()
        for i in ports.indices where !ports[i].isMagSafe { ports[i].devices = devices[ports[i].number] ?? [] }
        return ports.sorted { ($0.isMagSafe ? 1 : 0, $0.number) < ($1.isMagSafe ? 1 : 0, $1.number) }
    }

    /// Separado de la lectura real para poder probarlo con datos de ejemplo.
    nonisolated static func port(from property: (String) -> Any?) -> PortInfo? {
        guard let kind = property("PortTypeDescription") as? String,
              let number = (property("PortNumber") as? NSNumber)?.intValue else { return nil }
        func flag(_ key: String) -> Bool { (property(key) as? NSNumber)?.boolValue ?? false }
        func count(_ key: String) -> Int { (property(key) as? NSNumber)?.intValue ?? 0 }
        return PortInfo(number: number, kind: kind, connected: flag("ConnectionActive"),
                        activeTransports: property("TransportsActive") as? [String] ?? [],
                        supportedTransports: property("TransportsSupported") as? [String] ?? [],
                        plugCount: count("Plug Event Count"), liquidDetected: flag("LDCM_LiquidDetected"),
                        overcurrentCount: count("Overcurrent Count"), activeCable: flag("ActiveCable"), opticalCable: flag("OpticalCable"))
    }

    // MARK: Registro de E/S

    /// Hijos de una entrada del registro (el que llama libera cada uno).
    private nonisolated static func children(of entry: io_registry_entry_t) -> [io_registry_entry_t] {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var out: [io_registry_entry_t] = []
        var child = IOIteratorNext(iterator)
        while child != 0 { out.append(child); child = IOIteratorNext(iterator) }
        return out
    }

    private nonisolated static func name(of entry: io_registry_entry_t) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        IORegistryEntryGetName(entry, &buffer)
        return String(cString: buffer)
    }

    private nonisolated static func property(_ key: String, of entry: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    /// Cable y extremo remoto: salen de los nodos SOP' y SOP debajo del canal de configuración (CC) del puerto.
    private nonisolated static func attachPower(_ service: io_registry_entry_t, to port: inout PortInfo) {
        for child in children(of: service) {
            defer { IOObjectRelease(child) }
            guard name(of: child) == "CC" else { continue }
            for node in children(of: child) {
                defer { IOObjectRelease(node) }
                guard let metadata = property("Metadata", of: node) as? [String: Any],
                      let type = (metadata["Product Type"] as? NSNumber)?.intValue,
                      let raw = metadata["VDOs"] as? [Data] else { continue }
                let vdos = raw.map { $0.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * UInt32($1.offset)) } }
                switch name(of: node) {
                case "SOP'": port.cable = CableInfo.decode(vdos: vdos, productType: type)
                case "SOP":
                    port.partner = PartnerInfo(kind: (metadata["Product Type Description"] as? String) ?? "",
                                               vendorID: Int(vdos.first.map { $0 & 0xFFFF } ?? 0))
                default: break
                }
            }
        }
    }

    nonisolated static func speedMbps(code: Int) -> Int {
        switch code { case 0: 2; case 1: 12; case 2: 480; case 3: 5_000; default: 10_000 }
    }

    /// Dispositivos USB por número de puerto USB-C: los puertos del controlador llevan `UsbCPortNumber`.
    nonisolated static func usbDevicesByPort() -> [Int: [PortDevice]] {
        var result: [Int: [PortDevice]] = [:]
        for className in ["AppleUSB20XHCIARMPort", "AppleUSB30XHCIARMPort"] {
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }
            var service = IOIteratorNext(iterator)
            while service != 0 {
                defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
                guard let number = (property("UsbCPortNumber", of: service) as? NSNumber)?.intValue else { continue }
                result[number, default: []] += devices(under: service, depth: 0)
            }
        }
        return result
    }

    private nonisolated static func devices(under entry: io_registry_entry_t, depth: Int) -> [PortDevice] {
        guard depth < 6 else { return [] }
        var out: [PortDevice] = []
        for child in children(of: entry) {
            defer { IOObjectRelease(child) }
            if IOObjectConformsTo(child, "IOUSBHostDevice") != 0,
               let product = property("kUSBProductString", of: child) as? String ?? property("USB Product Name", of: child) as? String {
                let code = (property("Device Speed", of: child) as? NSNumber)?.intValue ?? 2
                out.append(PortDevice(name: product, vendor: property("kUSBVendorString", of: child) as? String, speedMbps: speedMbps(code: code)))
            }
            out += devices(under: child, depth: depth + 1)
        }
        return out
    }
}
