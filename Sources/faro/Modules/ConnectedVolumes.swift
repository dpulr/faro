// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import DiskArbitration

/// Un disco o volumen externo que se puede expulsar.
struct ExternalVolume: Identifiable, Equatable {
    var url: URL
    var name: String
    var total: Int64
    var free: Int64
    var connection: String   // "USB", "Thunderbolt", "Tarjeta SD", "Imagen de disco"…
    var model: String?
    var id: URL { url }

    var symbol: String {
        switch connection {
        case tr("Tarjeta SD"): "sdcard"
        case tr("Imagen de disco"): "opticaldiscdrive"
        default: "externaldrive"
        }
    }
    var usedFraction: Double { total > 0 ? Double(total - free) / Double(total) : 0 }
}

/// Lista los volúmenes externos conectados y los expulsa a pedido.
@MainActor
final class ConnectedVolumes: ObservableObject {
    @Published private(set) var volumes: [ExternalVolume] = []
    @Published private(set) var ejecting: Set<URL> = []
    /// Resultado del último intento de expulsar: (nombre, error o nil si salió bien).
    @Published private(set) var lastResult: (name: String, error: String?)?

    private var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    deinit { observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) } }

    /// Volumen de ejemplo para documentación y capturas.
    func loadDemo() {
        volumes = [ExternalVolume(url: URL(fileURLWithPath: "/Volumes/Proyecto Faro"),
                                  name: "Proyecto Faro", total: 1_000_000_000_000,
                                  free: 638_000_000_000, connection: "USB", model: "SSD externo")]
    }

    func refresh() { volumes = Self.read() }

    /// Expulsa un volumen. Si macOS se niega (archivos abiertos), lo explica en `lastResult`.
    func eject(_ volume: ExternalVolume) {
        ejecting.insert(volume.url)
        Task {
            let error: String? = await Task.detached {
                do { try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url); return nil }
                catch { return Self.explain(error) }
            }.value
            ejecting.remove(volume.url)
            lastResult = (volume.name, error)
            refresh()
        }
    }

    func ejectAll() { volumes.forEach(eject) }

    /// El error de macOS es técnico; se traduce al motivo habitual.
    nonisolated static func explain(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSFileWriteVolumeReadOnlyError || ns.code == 256 || ns.code == 4 {
            return tr("Alguna app lo está usando. Ciérrala y vuelve a intentarlo.")
        }
        return tr("Alguna app lo está usando o macOS no pudo expulsarlo.")
    }

    nonisolated static func read() -> [ExternalVolume] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey,
                                      .volumeIsInternalKey, .volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsLocalKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]),
              let session = DASessionCreate(kCFAllocatorDefault) else { return [] }
        var out: [ExternalVolume] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  isExternal(internal: values.volumeIsInternal, local: values.volumeIsLocal, path: url.path) else { continue }
            var protocolName: String?, model: String?
            if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
               let description = DADiskCopyDescription(disk) as? [String: Any] {
                protocolName = description[kDADiskDescriptionDeviceProtocolKey as String] as? String
                model = (description[kDADiskDescriptionDeviceModelKey as String] as? String)?.trimmingCharacters(in: .whitespaces)
            }
            out.append(ExternalVolume(url: url, name: values.volumeName ?? url.lastPathComponent,
                                      total: Int64(values.volumeTotalCapacity ?? 0),
                                      free: values.volumeAvailableCapacityForImportantUsage.flatMap { $0 > 0 ? $0 : nil } ?? Int64(values.volumeAvailableCapacity ?? 0),
                                      connection: connectionName(protocolName), model: model?.isEmpty == true ? nil : model))
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Un disco USB o Thunderbolt suele figurar como "no expulsable" aunque Finder sí lo expulse, así que
    /// lo que cuenta es que no sea interno, sea local y no sea el disco del sistema.
    nonisolated static func isExternal(internal isInternal: Bool?, local: Bool?, path: String) -> Bool {
        isInternal != true && local != false && path != "/" && !path.hasPrefix("/System/Volumes")
    }

    /// Traduce el protocolo que informa DiskArbitration a algo legible.
    nonisolated static func connectionName(_ protocolName: String?) -> String {
        switch (protocolName ?? "").lowercased() {
        case "usb": return "USB"
        case "thunderbolt": return "Thunderbolt"
        case "secure digital", "sd": return tr("Tarjeta SD")
        case "virtual interface", "disk image": return tr("Imagen de disco")
        case "sata", "sas": return "SATA"
        case "pci-express", "nvme": return "NVMe"
        case "": return tr("Externo")
        default: return protocolName ?? tr("Externo")
        }
    }
}
