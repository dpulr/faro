// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import IOKit
import IOKit.ps

@MainActor
final class SystemMonitor: ObservableObject {
    @Published var cpu = 0.0
    @Published var memUsed: UInt64 = 0
    @Published var memTotal = ProcessInfo.processInfo.physicalMemory
    @Published var diskFree: Int64 = 0
    @Published var diskTotal: Int64 = 0
    @Published var netDown = 0.0
    @Published var netUp = 0.0
    @Published var batteryPercent: Int?
    @Published var batteryCharging = false
    @Published var batteryCycles: Int?
    @Published var batteryHealth: Int?
    @Published var hasBattery = false
    @Published var cpuHistory: [Double] = []
    @Published var memHistory: [Double] = []
    @Published var netDownHistory: [Double] = []

    enum Level { case ok, warning, critical }

    struct Health {
        var title: String
        var detail: String
        var level: Level
    }

    var memFraction: Double { Double(memUsed) / Double(max(memTotal, 1)) }
    var diskUsedFraction: Double { diskTotal > 0 ? Double(diskTotal - diskFree) / Double(diskTotal) : 0 }

    /// Resumen en lenguaje llano de cómo está el Mac.
    var health: Health {
        let freeFraction = diskTotal > 0 ? Double(diskFree) / Double(diskTotal) : 1
        let free = ByteCountFormatter.string(fromByteCount: diskFree, countStyle: .file)
        if diskFree < 10_000_000_000 || freeFraction < 0.05 {
            return Health(title: tr("Casi sin espacio en disco"), detail: String(format: tr("Solo quedan %@. Conviene liberar espacio."), free), level: .critical)
        }
        if memFraction > 0.92 {
            return Health(title: tr("Memoria casi llena"), detail: tr("Cerrar apps que no uses ayudaría."), level: .warning)
        }
        if cpu > 85 {
            return Health(title: tr("El procesador está muy ocupado"), detail: tr("Alguna app está trabajando duro."), level: .warning)
        }
        if freeFraction < 0.1 {
            return Health(title: tr("Poco espacio en disco"), detail: String(format: tr("Te quedan %@."), free), level: .warning)
        }
        return Health(title: tr("Tu Mac va tranquilo"), detail: tr("Todo está en orden."), level: .ok)
    }

    private var timer: Timer?
    private var prevTicks: (UInt32, UInt32, UInt32, UInt32)?
    private var prevNet: [String: (UInt32, UInt32)] = [:]
    private let interval = 3.0

    init() {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        timer?.tolerance = 1
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
        sampleDisk()
        sampleNetwork()
        sampleBattery()
        record(&cpuHistory, cpu / 100)
        record(&memHistory, memFraction)
        record(&netDownHistory, netDown)
    }

    private func record(_ series: inout [Double], _ value: Double) {
        series.append(value)
        if series.count > 60 { series.removeFirst(series.count - 60) }
    }

    private func sampleCPU() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let t = info.cpu_ticks // user, system, idle, nice
        let now = (t.0, t.1, t.2, t.3)
        if let p = prevTicks {
            let user = Double(now.0 &- p.0), sys = Double(now.1 &- p.1)
            let idle = Double(now.2 &- p.2), nice = Double(now.3 &- p.3)
            let total = user + sys + idle + nice
            if total > 0 { cpu = (user + sys + nice) / total * 100 }
        }
        prevTicks = now
    }

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let page = UInt64(sysconf(_SC_PAGESIZE))
        // Misma cuenta que "Memoria usada" en el Monitor de Actividad.
        let pages = UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count)
            + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        memUsed = pages * page
    }

    private func sampleDisk() {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) else { return }
        diskFree = v.volumeAvailableCapacityForImportantUsage ?? 0
        diskTotal = Int64(v.volumeTotalCapacity ?? 0)
    }

    private func sampleNetwork() {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return }
        defer { freeifaddrs(head) }
        var down = 0.0, up = 0.0
        var seen: [String: (UInt32, UInt32)] = [:]
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
                  let data = ifa.ifa_data else { continue }
            let name = String(cString: ifa.ifa_name)
            guard name.hasPrefix("en") else { continue }
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            seen[name] = (d.ifi_ibytes, d.ifi_obytes)
            if let p = prevNet[name] {
                down += Double(d.ifi_ibytes &- p.0)
                up += Double(d.ifi_obytes &- p.1)
            }
        }
        if !prevNet.isEmpty { netDown = down / interval; netUp = up / interval }
        prevNet = seen
    }

    private func sampleBattery() {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef],
              let source = list.first,
              let desc = IOPSGetPowerSourceDescription(snap, source)?.takeUnretainedValue() as? [String: Any]
        else { batteryPercent = nil; hasBattery = false; return }
        hasBattery = true
        batteryPercent = desc[kIOPSCurrentCapacityKey] as? Int
        batteryCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            batteryCycles = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
            func number(_ key: String) -> Double? {
                (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? NSNumber)?.doubleValue
            }
            if let raw = number("AppleRawMaxCapacity"), let design = number("DesignCapacity"), design > 0 {
                batteryHealth = Int((raw / design * 100).rounded())
            }
            IOObjectRelease(service)
        }
    }
}
