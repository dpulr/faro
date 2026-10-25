// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import IOKit

/// Un hallazgo del diagnóstico: qué frena al Mac, qué tan grave es y qué se puede hacer.
struct Finding: Identifiable, Equatable {
    enum Kind: String { case memory, cpu, disk, thermal, power, port }
    enum Severity: Int, Comparable {
        case info, warning, critical
        static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
    }
    enum Action: Equatable { case storage, activityMonitor, energy }

    var kind: Kind
    var severity: Severity
    var title: String
    var detail: String
    var action: Action?
    var id: String { "\(kind.rawValue)-\(title)" }

    var symbol: String {
        switch kind {
        case .memory: "memorychip"; case .cpu: "cpu"; case .disk: "internaldrive"
        case .thermal: "thermometer.medium"; case .power: "bolt.fill"; case .port: "cable.connector"
        }
    }
}

/// Un proceso (o una app con todos sus procesos auxiliares) y lo que consume.
struct ProcessUse: Equatable {
    var name: String
    var cpu: Double      // % de un núcleo
    var memory: UInt64   // bytes
}

/// Lo que se mide del Mac en un momento dado.
struct DiagnosticInput {
    var memoryPressure = 1          // 1 normal, 2 aviso, 4 crítica
    var swapBytes: UInt64 = 0
    var cpuAverage = 0.0            // 0...100, promedio de las últimas lecturas
    var diskFree: Int64 = 0
    var diskTotal: Int64 = 0
    var thermal = ProcessInfo.ThermalState.nominal
    var lowPowerMode = false
    var batteryPercent: Int?
    var onAC = true
    var charger: ChargerReading?
    var topCPU: ProcessUse?
    var topMemory: ProcessUse?
    var ports: [PortInfo] = []
}

enum Diagnostics {
    static let gb = 1_073_741_824.0

    /// Ordena de lo más grave a lo menos; sin nada que reportar devuelve una lista vacía.
    static func findings(_ i: DiagnosticInput) -> [Finding] {
        var out: [Finding] = []

        let swapGB = Double(i.swapBytes) / gb
        if i.memoryPressure >= 4 || (i.memoryPressure >= 2 && swapGB > 4) {
            out.append(Finding(kind: .memory, severity: .critical, title: tr("Te falta memoria"),
                               detail: memoryDetail(i, swapGB), action: .activityMonitor))
        } else if i.memoryPressure >= 2 || swapGB > 2 {
            out.append(Finding(kind: .memory, severity: .warning, title: tr("La memoria está al límite"),
                               detail: memoryDetail(i, swapGB), action: .activityMonitor))
        }

        if i.cpuAverage >= 75, let top = i.topCPU {
            let severity: Finding.Severity = i.cpuAverage >= 90 ? .critical : .warning
            out.append(Finding(kind: .cpu, severity: severity, title: tr("El procesador está saturado"),
                               detail: String(format: tr("%@ usa %lld%% de un núcleo."), top.name, Int(top.cpu.rounded())), action: .activityMonitor))
        } else if i.cpuAverage >= 75 {
            out.append(Finding(kind: .cpu, severity: .warning, title: tr("El procesador está saturado"),
                               detail: String(format: tr("Lleva %lld%% de uso sostenido."), Int(i.cpuAverage.rounded())), action: .activityMonitor))
        }

        if i.diskTotal > 0 {
            let fraction = Double(i.diskFree) / Double(i.diskTotal)
            let free = Double(i.diskFree) / gb
            if fraction < 0.05 || free < 5 {
                out.append(Finding(kind: .disk, severity: .critical, title: tr("El disco está casi lleno"),
                                   detail: String(format: tr("Quedan %@; con tan poco espacio macOS se vuelve lento."), Format.bytes(i.diskFree)), action: .storage))
            } else if fraction < 0.10 || free < 15 {
                out.append(Finding(kind: .disk, severity: .warning, title: tr("Queda poco espacio en el disco"),
                                   detail: String(format: tr("Quedan %@. Conviene liberar espacio."), Format.bytes(i.diskFree)), action: .storage))
            }
        }

        switch i.thermal {
        case .critical: out.append(Finding(kind: .thermal, severity: .critical, title: tr("El Mac está muy caliente"),
                                           detail: tr("Reduce mucho su velocidad para enfriarse."), action: nil))
        case .serious: out.append(Finding(kind: .thermal, severity: .warning, title: tr("El Mac se está calentando"),
                                          detail: tr("Baja su velocidad para enfriarse. Ventila el equipo y cierra lo pesado."), action: nil))
        case .fair: out.append(Finding(kind: .thermal, severity: .info, title: tr("El Mac está tibio"),
                                       detail: tr("Todavía rinde al máximo, pero si sigue subiendo bajará su velocidad."), action: nil))
        default: break
        }

        if !i.onAC, let percent = i.batteryPercent, percent <= 20 {
            out.append(Finding(kind: .power, severity: percent <= 10 ? .critical : .warning, title: tr("Poca batería"),
                               detail: String(format: tr("Quedan %lld%%. Conecta el cargador."), percent), action: .energy))
        } else if let charger = i.charger, let verdict = ChargerAnalysis.verdict(charger), verdict.severity != .info {
            out.append(Finding(kind: .power, severity: verdict.severity, title: verdict.title, detail: verdict.detail, action: .energy))
        } else if i.lowPowerMode {
            out.append(Finding(kind: .power, severity: .info, title: tr("Modo de bajo consumo activo"),
                               detail: tr("macOS limita el rendimiento para ahorrar batería."), action: .energy))
        }

        if let wet = i.ports.first(where: { $0.liquidDetected }) {
            out.append(Finding(kind: .port, severity: .critical, title: tr("Líquido detectado en un puerto"),
                               detail: String(format: tr("macOS detectó humedad en %@. Desconecta lo que tenga y deja secar."), wet.title), action: nil))
        }
        for port in i.ports {
            if let link = LinkAnalysis.verdict(for: port), link.level == .limited {
                out.append(Finding(kind: .port, severity: .info, title: link.title, detail: link.detail, action: nil))
            }
        }
        return out.sorted { $0.severity > $1.severity }
    }

    private static func memoryDetail(_ i: DiagnosticInput, _ swapGB: Double) -> String {
        var parts: [String] = []
        if let top = i.topMemory { parts.append(String(format: tr("%@ usa %@."), top.name, Format.bytes(Int64(top.memory)))) }
        if swapGB > 0.5 { parts.append(String(format: tr("macOS usa %@ del disco como memoria."), String(format: "%.1f GB", swapGB))) }
        return parts.isEmpty ? tr("macOS está comprimiendo memoria para seguir.") : parts.joined(separator: " ")
    }

    // MARK: Procesos

    /// Agrupa los procesos auxiliares ("Google Chrome Helper (Renderer)") bajo su app.
    static func group(_ rows: [ProcessUse]) -> [ProcessUse] {
        var byName: [String: ProcessUse] = [:]
        for row in rows {
            let name = row.name.components(separatedBy: " Helper").first ?? row.name
            var use = byName[name] ?? ProcessUse(name: name, cpu: 0, memory: 0)
            use.cpu += row.cpu; use.memory += row.memory
            byName[name] = use
        }
        return Array(byName.values)
    }

    /// Lee `ps` (columnas: %cpu, rss en KB y nombre) y devuelve las apps que más consumen.
    static func parse(ps output: String) -> [ProcessUse] {
        var rows: [ProcessUse] = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let cpu = Double(parts[0].replacingOccurrences(of: ",", with: ".")), let rss = UInt64(parts[1]) else { continue }
            rows.append(ProcessUse(name: String(parts[2]), cpu: cpu, memory: rss * 1024))
        }
        return group(rows)
    }

    nonisolated static func readProcesses() -> [ProcessUse] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pcpu=,rss=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return parse(ps: String(decoding: data, as: UTF8.self))
    }

    nonisolated static func memoryPressure() -> Int {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        return Int(level)
    }

    nonisolated static func swapBytes() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }
}

// MARK: - Cargador

/// Lo que el Mac informa de su cargador y del reparto de energía.
struct ChargerReading: Equatable {
    var connected = false
    var charging = false
    var fullyCharged = false
    var percent: Int?
    var adapterWatts: Int?
    var adapterName: String?
    var systemIn: Double?      // W que entran al Mac desde el cargador
    var systemLoad: Double?    // W que gasta el Mac
    var battery: Double?       // W hacia la batería (positivo carga, negativo descarga)
    var slowReason = 0
    var manufacturer: String?
    var options: [PowerOption] = []   // lo que el cargador ofrece
    var selected: Int?                // cuál de las opciones negoció el Mac
}

/// Una potencia que ofrece el cargador (voltaje y corriente máximos).
struct PowerOption: Equatable {
    var volts: Double
    var amps: Double
    var watts: Double { volts * amps }
}

struct ChargerVerdict: Equatable {
    var severity: Finding.Severity
    var title: String
    var detail: String
}

enum ChargerAnalysis {
    /// Explica qué pasa con el cargador en lenguaje llano. `nil` si no hay cargador conectado.
    static func verdict(_ r: ChargerReading) -> ChargerVerdict? {
        guard r.connected else { return nil }
        let watts = r.adapterWatts
        let into = r.systemIn
        func w(_ value: Double) -> String { String(format: "%.0f W", value) }

        if r.fullyCharged || (!r.charging && (r.percent ?? 0) >= 99) {
            let used = r.systemLoad.map { String(format: tr("El Mac toma solo lo que gasta (%@)."), w($0)) } ?? tr("El Mac toma solo lo que gasta.")
            return ChargerVerdict(severity: .info, title: tr("Batería completa"), detail: used)
        }
        // Enchufado pero la batería sigue bajando: el cargador no alcanza para lo que se está haciendo.
        if let battery = r.battery, battery < -3, let load = r.systemLoad {
            let supply = watts.map { String(format: tr("tu cargador es de %lld W"), $0) } ?? tr("el cargador es corto")
            var detail = String(format: tr("El Mac gasta %@ y %@: la diferencia sale de la batería."), w(load), supply)
            if let watts, let into, into >= Double(watts) * 0.9 { detail += " " + String(format: tr("El cargador está al máximo (%@)."), w(into)) }
            return ChargerVerdict(severity: .warning, title: tr("El cargador no alcanza"), detail: detail)
        }
        if r.slowReason != 0 {
            return ChargerVerdict(severity: .info, title: tr("La carga va despacio a propósito"),
                                  detail: tr("macOS la limita para cuidar la batería (temperatura o carga optimizada)."))
        }
        guard let watts, let into else {
            return ChargerVerdict(severity: .info, title: tr("Cargando"), detail: tr("El cargador no informa su potencia."))
        }
        let fraction = into / Double(watts)
        let toBattery = max(r.battery ?? 0, 0)
        if fraction >= 0.9, (r.percent ?? 100) < 80, watts < 60 {
            return ChargerVerdict(severity: .warning, title: tr("El cargador es el límite"),
                                  detail: String(format: tr("Entran %@ de %lld W. Con uno más potente cargaría más rápido."), w(into), watts))
        }
        let split = String(format: tr("%@ a la batería y el resto al sistema."), w(toBattery))
        if fraction < 0.8 {
            return ChargerVerdict(severity: .info, title: tr("Todo normal: el Mac pide menos de lo que da el cargador"),
                                  detail: String(format: tr("Cargador de %lld W, al Mac llegan %@. %@"), watts, w(into), split))
        }
        return ChargerVerdict(severity: .info, title: tr("Cargando bien"),
                              detail: String(format: tr("Cargador de %lld W, al Mac llegan %@. %@"), watts, w(into), split))
    }

    /// Lee la batería inteligente del Mac (`AppleSmartBattery`).
    nonisolated static func read() -> ChargerReading {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return ChargerReading() }
        defer { IOObjectRelease(service) }
        func property(_ key: String) -> Any? { IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() }
        return reading(from: { property($0) })
    }

    /// Separado de la lectura real para poder probarlo con datos de ejemplo.
    nonisolated static func reading(from property: (String) -> Any?) -> ChargerReading {
        var r = ChargerReading()
        r.connected = (property("ExternalConnected") as? Bool) ?? false
        r.charging = (property("IsCharging") as? Bool) ?? false
        r.fullyCharged = (property("FullyCharged") as? Bool) ?? false
        if let current = (property("CurrentCapacity") as? NSNumber)?.intValue { r.percent = current }
        if let details = property("AdapterDetails") as? [String: Any] {
            r.adapterWatts = (details["Watts"] as? NSNumber)?.intValue.nonZero
            r.adapterName = ((details["Name"] as? String) ?? (details["Description"] as? String))?.trimmingCharacters(in: .whitespaces)
            r.manufacturer = details["Manufacturer"] as? String
            if let menu = details["UsbHvcMenu"] as? [[String: Any]] {
                r.options = menu.compactMap { entry in
                    guard let mv = (entry["MaxVoltage"] as? NSNumber)?.doubleValue, let ma = (entry["MaxCurrent"] as? NSNumber)?.doubleValue, mv > 0 else { return nil }
                    return PowerOption(volts: mv / 1000, amps: ma / 1000)
                }
                r.selected = (details["UsbHvcHvcIndex"] as? NSNumber)?.intValue
            }
        }
        if let telemetry = property("PowerTelemetryData") as? [String: Any] {
            func watts(_ key: String) -> Double? { (telemetry[key] as? NSNumber).map { $0.doubleValue / 1000 } }
            r.systemIn = watts("SystemPowerIn")
            r.systemLoad = watts("SystemLoad")
            // BatteryPower ya viene con signo: positivo carga la batería, negativo la descarga.
            r.battery = watts("BatteryPower")
        }
        if let charger = property("ChargerData") as? [String: Any] {
            r.slowReason = (charger["SlowChargingReason"] as? NSNumber)?.intValue ?? 0
        }
        return r
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

// MARK: - Modelo

@MainActor
final class DiagnosticsModel: ObservableObject {
    @Published private(set) var findings: [Finding] = []
    @Published private(set) var charger = ChargerReading()
    @Published private(set) var fans: [Fan] = []
    @Published private(set) var ports: [PortInfo] = []
    @Published private(set) var analyzed: Date?
    @Published private(set) var running = false

    var verdict: ChargerVerdict? { ChargerAnalysis.verdict(charger) }
    /// Lo que más frena ahora, si hay algo que no sea solo informativo.
    var topIssue: Finding? { findings.first { $0.severity >= .warning } }

    /// Datos creíbles para documentación y capturas. Nunca se usa durante el funcionamiento normal.
    func loadDemo() {
        let port1 = PortInfo(number: 1, kind: "USB-C", connected: true,
                             activeTransports: ["CIO", "DisplayPort"],
                             supportedTransports: ["USB2", "USB3", "CIO", "DisplayPort"],
                             plugCount: 18, liquidDetected: false, overcurrentCount: 0,
                             activeCable: true, opticalCable: false)
        let port2 = PortInfo(number: 2, kind: "USB-C", connected: false,
                             activeTransports: [], supportedTransports: ["USB2", "USB3", "CIO", "DisplayPort"],
                             plugCount: 7, liquidDetected: false, overcurrentCount: 0,
                             activeCable: false, opticalCable: false)
        charger = ChargerReading(connected: true, charging: true, percent: 64,
                                 adapterWatts: 96, adapterName: "Adaptador USB-C",
                                 systemIn: 71, systemLoad: 20, battery: 51)
        ports = [port1, port2]
        fans = [Fan(index: 0, rpm: 2140, minimum: 1200, maximum: 6800)]
        findings = [Finding(kind: .cpu, severity: .warning,
                            title: tr("Una app está usando mucho procesador"),
                            detail: String(format: tr("%@ usa %lld%% de un núcleo."), "Chrome", 126),
                            action: .activityMonitor)]
        analyzed = Date().addingTimeInterval(-30)
    }

    /// Mide todo y recalcula. Los procesos se leen fuera del hilo principal.
    func refresh(monitor: SystemMonitor) {
        guard !running else { return }
        running = true
        let recent = monitor.cpuHistory.suffix(5)
        let cpuAverage = recent.isEmpty ? 0 : recent.reduce(0, +) / Double(recent.count) * 100
        var input = DiagnosticInput()
        input.cpuAverage = cpuAverage
        input.diskFree = monitor.diskFree
        input.diskTotal = monitor.diskTotal
        input.batteryPercent = monitor.batteryPercent
        input.onAC = monitor.onAC || !monitor.hasBattery
        input.thermal = ProcessInfo.processInfo.thermalState
        input.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        Task {
            let (processes, pressure, swap, charger, fans, ports) = await Task.detached {
                (Diagnostics.readProcesses(), Diagnostics.memoryPressure(), Diagnostics.swapBytes(), ChargerAnalysis.read(), FanReader.read(), PortInventory.read())
            }.value
            self.fans = fans
            self.ports = ports
            input.memoryPressure = pressure
            input.swapBytes = swap
            input.ports = ports
            input.charger = charger.connected ? charger : nil
            input.topCPU = processes.max { $0.cpu < $1.cpu }
            input.topMemory = processes.max { $0.memory < $1.memory }
            self.charger = charger
            findings = Diagnostics.findings(input)
            analyzed = Date()
            running = false
        }
    }
}
