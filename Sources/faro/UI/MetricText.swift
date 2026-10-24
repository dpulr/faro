// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Valor corto de cada métrica, usado en la barra de menú y en su vista previa.
@MainActor
enum MetricValue {
    static func text(_ metric: MenuBarMetric, monitor: SystemMonitor, speed: SpeedTest) -> String {
        switch metric {
        case .cpu: return "\(Int(monitor.cpu.rounded()))%"
        case .gpu: return monitor.gpu.map { "\(Int($0.rounded()))%" } ?? "—"
        case .memory: return "\(Int((monitor.memFraction * 100).rounded()))%"
        case .disk: return "\(Int((Double(monitor.diskFree) / 1_000_000_000).rounded())) GB"
        case .network: return "↓\(Format.compactRate(monitor.netDown)) ↑\(Format.compactRate(monitor.netUp))"
        case .battery: return monitor.batteryPercent.map { "\($0)%" } ?? "—"
        case .speed: return speed.last.map { "\(Int($0.downMbps.rounded())) Mb/s" } ?? "—"
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var engine: WallpaperEngine
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var speed: SpeedTest
    @ObservedObject var awake: KeepAwake

    private var metrics: [MenuBarMetric] {
        MenuBarMetric.allCases.filter { engine.state.menuBarMetrics.contains($0) }
    }

    var body: some View {
        HStack(spacing: 8) {
            if engine.state.menuBarShowIcon || metrics.isEmpty {
                FaroLogo(style: .template, ring: true, lit: awake.active).frame(width: 18, height: 18)
            }
            ForEach(metrics) { metric in
                HStack(spacing: 3) {
                    Image(systemName: metric.symbol).imageScale(.small)
                    Text(MetricValue.text(metric, monitor: monitor, speed: speed)).monospacedDigit()
                }
            }
        }
    }
}
