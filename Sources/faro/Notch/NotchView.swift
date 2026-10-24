// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

struct NotchShape: Shape {
    var radius: CGFloat
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: radius, bottomTrailing: radius, topTrailing: 0),
                               style: .continuous).path(in: rect)
    }
}

/// Usa el recorte superior del Mac cuando existe y una cápsula completamente flotante en monitores normales.
private struct NotchSurfaceShape: Shape {
    var radius: CGFloat
    var attachedToTop: Bool

    func path(in rect: CGRect) -> Path {
        if attachedToTop {
            return NotchShape(radius: radius).path(in: rect)
        }
        return RoundedRectangle(cornerRadius: min(radius, rect.height / 2), style: .continuous).path(in: rect)
    }
}

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Panel negro que cuelga del notch: pequeño con "alas" cuando algo está en vivo y desplegado al acercar el cursor.
struct NotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var mixer: AudioMixer
    @ObservedObject var extras: NotchExtras
    @ObservedObject var engine: WallpaperEngine
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var speed: SpeedTest
    @ObservedObject var awake: KeepAwake
    @StateObject private var displayControls = DisplayControls()
    var notchSize: CGSize
    var hasHardwareNotch: Bool

    @State private var dropTargeted = false
    @State private var expandedSection: ExpandedSection = .home
    private let spring = Animation.spring(response: 0.4, dampingFraction: 0.82)

    private enum ExpandedSection { case home, system, tools }

    var body: some View {
        ZStack(alignment: .top) {
            if model.expanded {
                expandedBody
                    .frame(width: model.panelWidth.points)
                    .background { expandedBackground }
                    .background(GeometryReader { Color.clear.preference(key: HeightKey.self, value: $0.size.height) })
                    .transition(.opacity)
            } else if model.dropActive {
                dropZone
                    .transition(.opacity)
            } else if model.toast != nil {
                toastBody
                    .transition(.opacity)
            } else if model.hasLive || extras.hasLive || hasCompactContent || !hasHardwareNotch {
                collapsedBody
                    .frame(width: collapsedPanelWidth)
                    .background(NotchSurfaceShape(radius: hasHardwareNotch ? 14 : 18,
                                                  attachedToTop: hasHardwareNotch).fill(Color.black))
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(spring, value: model.expanded)
        .animation(spring, value: model.hasLive || extras.hasLive)
        .animation(spring, value: model.dropActive)
        .animation(spring, value: model.toast)
        .onPreferenceChange(HeightKey.self) { if $0 > 0 { model.expandedHeight = $0 } }
        .environment(\.colorScheme, .dark)
    }

    private var compactMetrics: [MenuBarMetric] {
        MenuBarMetric.allCases.filter { engine.state.notchMetrics.contains($0) }
    }

    private var hasCompactContent: Bool {
        model.showCompactControls || !compactMetrics.isEmpty || model.mascot.enabled
    }

    private var compactPanelWidth: CGFloat {
        let width = model.compactPanelWidth(notchWidth: notchSize.width, metricCount: compactMetrics.count,
                                            hasActivity: model.hasLive || extras.hasLive)
        return hasHardwareNotch ? width : min(width, 360)
    }

    private var collapsedPanelWidth: CGFloat {
        guard collapsedLyric != nil else { return compactPanelWidth }
        let lyricWidth: CGFloat = hasHardwareNotch ? 620 : 440
        return max(compactPanelWidth, min(model.panelWidth.points, lyricWidth))
    }

    private var collapsedLyric: String? {
        guard model.showMusic, model.track?.playing == true, model.lyricsDisplay != .hidden else { return nil }
        return model.lyrics.line
    }

    private var collapsedBody: some View {
        VStack(spacing: 0) {
            wings.frame(height: notchSize.height)
            if let line = collapsedLyric {
                VStack(spacing: 1) {
                    Text(line)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                    if model.lyricsDisplay == .twoLines, let next = model.lyrics.next {
                        Text(next)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .id(line)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: collapsedLyric)
    }

    // MARK: Alas (colapsado con algo en vivo)

    private var wings: some View {
        let middle = Int(ceil(Double(compactMetrics.count) / 2))
        let leftMetrics = Array(compactMetrics.prefix(middle))
        let rightMetrics = Array(compactMetrics.dropFirst(middle))
        return HStack(spacing: 0) {
            HStack(spacing: 2) {
                if model.mascot.enabled {
                    Button { model.mascot.pet() } label: {
                        MascotView(model: model.mascot, size: 24).frame(width: 28, height: 28).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(tr("Acariciar a la mascota"))
                }
                if model.showCompactControls {
                    compactAction("doc.on.clipboard", help: tr("Portapapeles")) { AppController.shared.showClipboard() }
                }
                ForEach(leftMetrics) { compactMetric($0) }
                leftActivity
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            Color.clear.frame(width: notchSize.width)
            HStack(spacing: 2) {
                rightActivity
                ForEach(rightMetrics) { compactMetric($0) }
                if model.showCompactControls {
                    compactAction("tray.and.arrow.down", help: tr("Bandeja")) { AppController.shared.showShelf() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var leftActivity: some View {
        if extras.cameraOn {
            Image(systemName: "video.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(.green).help(tr("Cámara en uso"))
        } else if extras.micOn {
            Image(systemName: "mic.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(.orange).help(tr("Micrófono en uso"))
        } else if model.breakRemaining != nil {
            Image(systemName: "eye").font(.system(size: 14, weight: .medium)).help(tr("Descanso visual"))
        } else if extras.timer.active, !(model.showMusic && model.track?.playing == true) {
            Image(systemName: extras.timer.phase == .rest ? "cup.and.saucer.fill" : "timer")
                .font(.system(size: 14, weight: .medium)).help(extras.timer.title)
        } else if model.lowDiskGB != nil {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange).help(tr("Poco espacio en disco"))
        } else if model.showMusic, model.track?.playing == true, let art = model.artwork {
            Image(nsImage: art).resizable().scaledToFill().frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)).help(tr("Música"))
        }
    }

    @ViewBuilder private var rightActivity: some View {
        if extras.timer.active {
            Text(extras.timer.clock).font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(extras.timer.running ? Color.white : Color.white.opacity(0.5)).help(extras.timer.title)
        } else if let remaining = model.breakRemaining {
            Text("\(remaining)").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                .help(tr("Segundos de descanso restantes"))
        } else if let gb = model.lowDiskGB {
            Text("\(gb) GB").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(.orange).help(tr("Espacio libre"))
        } else if model.showMusic, model.track?.playing == true {
            Image(systemName: "waveform").font(.system(size: 14, weight: .medium))
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating).help(tr("Reproduciendo"))
        }
    }

    private func compactMetric(_ metric: MenuBarMetric) -> some View {
        Button { open(metric) } label: {
            VStack(spacing: 0) {
                Image(systemName: metric.symbol).font(.system(size: 8, weight: .medium))
                Text(compactValue(metric)).font(.system(size: 8, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            }
            .foregroundStyle(metricTint(metric))
            .frame(width: 34, height: max(notchSize.height - 2, 24))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(metric.title) · \(MetricValue.text(metric, monitor: monitor, speed: speed))")
    }

    private func compactValue(_ metric: MenuBarMetric) -> String {
        switch metric {
        case .cpu: return "\(Int(monitor.cpu.rounded()))"
        case .gpu: return monitor.gpu.map { "\(Int($0.rounded()))" } ?? "—"
        case .memory: return "\(Int((monitor.memFraction * 100).rounded()))"
        case .disk: return "\(Int((Double(monitor.diskFree) / 1_000_000_000).rounded()))G"
        case .network: return "↓\(Format.compactRate(monitor.netDown))"
        case .battery: return monitor.batteryPercent.map(String.init) ?? "—"
        case .speed: return speed.last.map { "\(Int($0.downMbps.rounded()))M" } ?? "—"
        }
    }

    private func compactAction(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 28).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func metricTint(_ metric: MenuBarMetric) -> Color {
        if metric == .battery, let percent = monitor.batteryPercent, percent <= 20, !monitor.batteryCharging { return .red }
        if metric == .disk, monitor.diskFree < 10_000_000_000 { return .orange }
        return .white.opacity(0.88)
    }

    private func open(_ metric: MenuBarMetric) {
        model.collapse?()
        switch metric {
        case .cpu, .gpu, .memory: AppController.shared.openMain(.sistema)
        case .disk: AppController.shared.openMain(.almacenamiento)
        case .network, .speed: AppController.shared.openMain(.internet)
        case .battery: AppController.shared.openMain(.energia)
        }
    }

    // MARK: Aviso y zona para soltar

    private var toastBody: some View {
        HStack(spacing: 10) {
            if let hex = model.toast?.swatch, let color = Color(hex: hex) {
                Circle().fill(color).frame(width: 18, height: 18).overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
            } else {
                Image(systemName: model.toast?.symbol ?? "bell").font(.system(size: 16, weight: .medium))
            }
            Text(model.toast?.text ?? "").font(.system(size: 13, weight: .medium)).lineLimit(1)
            if let label = model.toast?.actionLabel {
                Button {
                    let action = model.toastAction
                    model.toast = nil
                    action?()
                } label: {
                    Text(label).font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.top, hasHardwareNotch ? notchSize.height + 4 : 12)
        .padding(.bottom, 14)
        .frame(minWidth: 280)
        .background(NotchSurfaceShape(radius: 26, attachedToTop: hasHardwareNotch).fill(Color.black))
    }

    private var dropZone: some View {
        VStack(spacing: 6) {
            Image(systemName: dropTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                .font(.system(size: 24, weight: .light))
            Text("Suelta aquí para guardar en la bandeja").font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(dropTargeted ? Color.white : Color.white.opacity(0.75))
        .padding(.horizontal, 30)
        .padding(.top, hasHardwareNotch ? notchSize.height + 6 : 12)
        .padding(.bottom, 18)
        .frame(width: 380)
        .background(NotchSurfaceShape(radius: 30, attachedToTop: hasHardwareNotch).fill(Color.black))
        .overlay(NotchSurfaceShape(radius: 30, attachedToTop: hasHardwareNotch)
            .stroke(Theme.accent.opacity(dropTargeted ? 1 : 0.35), lineWidth: 2))
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            ShelfDrop.load(providers) { urls in model.onFilesDropped?(urls) }
            return !providers.isEmpty
        }
    }

    // MARK: Desplegado

    private var expandedBody: some View {
        VStack(spacing: model.panelDensity.spacing) {
            if model.showExpandedStatus { expandedCompactBar }
            expandedNavigation
            switch expandedSection {
            case .home: homeSection
            case .system: systemSection
            case .tools: toolsDock
            }
            if model.dockPlacement == .bottom, expandedSection != .tools { toolsDock }
        }
        .padding(.horizontal, 18)
        .padding(.top, hasHardwareNotch ? notchSize.height + 10 : 10)
        .padding(.bottom, model.panelDensity.verticalPadding)
        .foregroundStyle(.white)
    }

    /// Conserva en el panel abierto los mismos controles, actividad y métricas de las alas compactas.
    private var expandedCompactBar: some View {
        HStack(spacing: 4) {
            if model.showCompactControls {
                compactAction("doc.on.clipboard", help: tr("Portapapeles")) { AppController.shared.showClipboard() }
            }
            leftActivity
            ForEach(compactMetrics) { compactMetric($0) }
            Spacer(minLength: 6)
            rightActivity
            if model.showCompactControls {
                compactAction("tray.and.arrow.down", help: tr("Bandeja")) { AppController.shared.showShelf() }
            }
        }
        .frame(height: 32)
        .padding(.horizontal, 5)
        .background(Capsule().fill(Color.white.opacity(0.055)))
    }

    @ViewBuilder private var expandedBackground: some View {
        let shape = NotchSurfaceShape(radius: 34, attachedToTop: hasHardwareNotch)
        switch model.panelStyle {
        case .black:
            shape.fill(Color.black)
        case .tinted:
            ZStack {
                shape.fill(Color.black.opacity(0.92))
                shape.fill((Color(hex: model.panelTintHex) ?? Theme.accent).opacity(model.panelOpacity * 0.55))
            }
        case .glass:
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill((Color(hex: model.panelTintHex) ?? Color.white).opacity(model.panelOpacity * 0.18)))
                .overlay(shape.stroke(Color.white.opacity(0.13), lineWidth: 0.7))
        case .liquid:
            shape.fill(LinearGradient(
                colors: [(Color(hex: model.panelTintHex) ?? Theme.accent).opacity(model.panelOpacity * 0.62),
                         Color.black.opacity(0.88), Color(red: 0.08, green: 0.12, blue: 0.16).opacity(0.94)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(shape.stroke(LinearGradient(colors: [Color.white.opacity(0.28), Theme.accent.opacity(0.22), .clear],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
        }
    }

    private var expandedNavigation: some View {
        HStack(spacing: 4) {
            if model.mascot.enabled {
                Button { model.mascot.pet() } label: {
                    MascotView(model: model.mascot, size: 32).frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tr("Acariciar a la mascota"))
            }
            if model.showGreetingInHeader, !model.greetingEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(model.greetingEmoji).font(.system(size: 13)).padding(.horizontal, 3)
            }
            sectionButton(.home, "Inicio", "sparkles")
            sectionButton(.system, "Sistema", "gauge.with.dots.needle.50percent")
            sectionButton(.tools, "Herramientas", "square.grid.2x2")
            Spacer(minLength: 8)
            Button {
                model.collapse?()
                AppController.shared.openMain()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.09)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(tr("Abrir la aplicación de escritorio"))
        }
    }

    private func sectionButton(_ section: ExpandedSection, _ title: LocalizedStringKey, _ symbol: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { expandedSection = section } } label: {
            HStack(spacing: 6) {
                if model.showTabIcons { Image(systemName: symbol) }
                Text(title)
            }
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 9).frame(height: 30)
                .foregroundStyle(expandedSection == section ? Color.white : Color.white.opacity(0.48))
                .background(Capsule().fill(Color.white.opacity(expandedSection == section ? 0.12 : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var homeSection: some View {
        NotchMatrixLayout(rowHeight: 74, spacing: model.panelDensity.spacing) {
            ForEach(visibleWidgetConfigs) { config in
                widget(config)
                    .notchMatrixSpan(columns: config.size.columns, rows: config.height == .double ? 2 : 1)
            }
        }
    }

    private var visibleWidgetConfigs: [NotchWidgetConfig] {
        model.widgetLayout.filter { $0.enabled && isWidgetVisible($0.kind) }
    }

    @ViewBuilder private func widget(_ config: NotchWidgetConfig) -> some View {
        Group {
            switch config.kind {
            case .greeting:
                HStack(spacing: 9) {
                    if !model.greetingEmoji.isEmpty { Text(model.greetingEmoji).font(.system(size: 22)) }
                    Text(model.greetingText).font(.system(size: 17, weight: .semibold)).lineLimit(2)
                    Spacer(minLength: 0)
                }.padding(12)
            case .timer:
                if extras.timer.enabled, extras.timer.active { timerRow.padding(12) }
            case .music:
                if model.breakRemaining != nil { breakRow }
                else if model.showMusic {
                    VStack(spacing: 2) {
                        musicRow
                        if model.lyricsDisplay != .hidden, let line = model.lyrics.line {
                            lyricsRow(line)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 4)
                        }
                    }
                }
            case .volume:
                if model.showVolume { volumeRow }
            case .weather:
                if model.showWeather, let weather = model.weather {
                    infoCard(InfoItem(id: "w", symbol: weather.symbol, eyebrow: weather.city,
                                      value: "\(weather.temperature)°", detail: weather.summary, action: nil), showsBackground: false)
                }
            case .calendar:
                if model.showCalendar {
                    if model.calendarStyle == .month {
                        monthCalendar
                    } else if let event = model.event {
                        infoCard(InfoItem(id: "c", symbol: "calendar", eyebrow: tr("Próximo evento"), value: event.title,
                                          detail: eventTiming(event), action: nil), showsBackground: false)
                    } else if !model.calendarDenied {
                        infoCard(InfoItem(id: "c", symbol: "calendar", eyebrow: tr("Calendario"), value: tr("Sin eventos"),
                                          detail: tr("En las próximas 24 horas"), action: nil), showsBackground: false)
                    }
                }
            case .devices:
                if extras.devices.enabled, let device = extras.devices.devices.first {
                    infoCard(InfoItem(id: "b-\(device.id)", symbol: device.symbol, eyebrow: tr("Dispositivo"),
                                      value: device.name.components(separatedBy: " de ").first ?? device.name,
                                      detail: "\(device.percent)%", action: nil), showsBackground: false)
                }
            case .eyeBreak:
                if model.eyeBreak, model.breakRemaining == nil, let next = model.nextBreak {
                    let minutes = max(Int((next.timeIntervalSinceNow / 60).rounded(.up)), 0)
                    infoCard(InfoItem(id: "e", symbol: "eye", eyebrow: tr("Descanso visual"), value: tr("Próxima pausa"),
                                      detail: minutes <= 0 ? tr("Ahora") : String(format: tr("En %lld min"), minutes),
                                      action: { model.startBreakNow() }), showsBackground: false)
                }
            case .storage:
                if let gb = model.lowDiskGB {
                    infoCard(InfoItem(id: "d", symbol: "internaldrive", eyebrow: tr("Almacenamiento"),
                                      value: String(format: tr("Quedan %d GB"), gb), detail: tr("Conviene liberar espacio"),
                                      action: { AppController.shared.openMain(.almacenamiento) }), showsBackground: false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(config.showsBackground ? 0.055 : 0)))
    }

    private func isWidgetVisible(_ kind: NotchWidgetKind) -> Bool {
        switch kind {
        case .greeting:
            return !model.greetingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.greetingEmoji.isEmpty
        case .timer: return extras.timer.enabled && extras.timer.active
        case .music: return model.showMusic
        case .volume: return model.showVolume && (model.showVolumeControl || model.showDisplayControl || model.showKeyboardControl)
        case .weather: return model.showWeather && model.weather != nil
        case .calendar: return model.showCalendar && !model.calendarDenied
        case .devices: return extras.devices.enabled && !extras.devices.devices.isEmpty
        case .eyeBreak: return model.eyeBreak && model.breakRemaining == nil && model.nextBreak != nil
        case .storage: return model.lowDiskGB != nil
        }
    }

    private var monthCalendar: some View {
        let calendar = Calendar.current
        let now = Date()
        let interval = calendar.dateInterval(of: .month, for: now)
        let first = interval?.start ?? now
        let days = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        return Button { openCalendar() } label: {
            VStack(spacing: 6) {
                HStack {
                    Text(now.formatted(.dateTime.month(.wide).year())).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.forward.app").font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                }
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                        Text(symbol).font(.system(size: 7, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                    }
                    ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 15) }
                    ForEach(1...days, id: \.self) { day in
                        Text("\(day)").font(.system(size: 8, weight: day == calendar.component(.day, from: now) ? .bold : .regular))
                            .frame(maxWidth: .infinity).frame(height: 15)
                            .background(Circle().fill(day == calendar.component(.day, from: now) ? Theme.accent.opacity(0.8) : .clear))
                    }
                }
            }
            .padding(12).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func openCalendar() {
        if let url = URL(string: "ical://") { NSWorkspace.shared.open(url) }
    }

    private var systemSection: some View {
        let compact = model.systemMetricScale == .compact
        return VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            if model.showSystemTitle {
                Text("Estado del Mac").font(.system(size: compact ? 9 : 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: compact ? 4 : 8), GridItem(.flexible())],
                      spacing: compact ? 4 : 8) {
                ForEach(MenuBarMetric.allCases) { metric in
                    systemMetricCard(metric, compact: compact)
                }
            }
        }
    }

    private func systemMetricCard(_ metric: MenuBarMetric, compact: Bool) -> some View {
        let item = systemInfo(metric)
        let content = HStack(spacing: compact ? 7 : 11) {
            Image(systemName: item.symbol)
                .font(.system(size: compact ? 13 : 18, weight: .medium))
                .symbolRenderingMode(.hierarchical).frame(width: compact ? 20 : 26)
                .foregroundStyle(.white.opacity(0.78))
            VStack(alignment: .leading, spacing: compact ? 0 : 1) {
                Text(item.eyebrow).font(.system(size: compact ? 8 : 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                Text(item.value).font(.system(size: compact ? 13 : 16, weight: .semibold)).lineLimit(1)
                if model.showSystemDescriptions {
                    Text(item.detail).font(.system(size: compact ? 8 : 10))
                        .foregroundStyle(.white.opacity(0.48)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 9 : 12)
        .frame(height: compact ? (model.showSystemDescriptions ? 50 : 40) : (model.showSystemDescriptions ? 70 : 54))
        .background(RoundedRectangle(cornerRadius: compact ? 12 : 18, style: .continuous)
            .fill(Color.white.opacity(model.showSystemItemBackgrounds ? 0.055 : 0)))
        .contentShape(Rectangle())
        return Button { open(metric) } label: { content }.buttonStyle(.plain)
    }

    private var musicRow: some View {
        let hasLyrics = model.lyricsDisplay != .hidden && model.lyrics.line != nil
        let hasTwoLyrics = hasLyrics && model.lyricsDisplay == .twoLines
        let artworkSize: CGFloat = hasTwoLyrics ? 36 : (hasLyrics ? 42 : 52)
        return HStack(spacing: 14) {
            Group {
                if let art = model.artwork {
                    Image(nsImage: art).resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.white.opacity(0.1)
                        Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .frame(width: artworkSize, height: artworkSize)
            .clipShape(RoundedRectangle(cornerRadius: hasLyrics ? 11 : 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.track?.title ?? "Nada sonando").font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(model.track.map { $0.artist.isEmpty ? $0.source : $0.artist } ?? tr("Abre Música o Spotify"))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            Spacer(minLength: 8)
            if model.track != nil {
                HStack(spacing: 6) {
                    control("backward.fill") { model.musicCommand("previous track") }
                    control(model.track?.playing == true ? "pause.fill" : "play.fill", size: hasTwoLyrics ? 32 : (hasLyrics ? 34 : 40)) { model.musicCommand("playpause") }
                    control("forward.fill") { model.musicCommand("next track") }
                }
            }
        }
        .padding(hasTwoLyrics ? 3 : (hasLyrics ? 5 : 10))
        // Un toque en la carátula o en el título abre la app desde la que suena (los botones siguen siendo botones).
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: artworkSize + 14 + 170, height: artworkSize)
                .padding(.leading, hasTwoLyrics ? 3 : (hasLyrics ? 5 : 10))
                .contentShape(Rectangle())
                .onTapGesture { model.openPlayer() }
                .help(model.track.map { String(format: tr("Abrir %@"), $0.source) } ?? "")
        }
    }

    /// La línea actual se integra discretamente bajo la canción sin aumentar la tarjeta.
    private func lyricsRow(_ line: String) -> some View {
        VStack(spacing: 1) {
            Text(line)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
            if model.lyricsDisplay == .twoLines, let next = model.lyrics.next {
                Text(next)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
        .id(line)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: line)
    }

    private var volumeRow: some View {
        HStack(spacing: 0) {
            if model.showVolumeControl {
                systemSlider(title: tr("Volumen"),
                             symbol: mixer.muted || mixer.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                             value: Binding(get: { mixer.volume }, set: { mixer.setVolume($0) }),
                             enabled: mixer.canSetVolume) { mixer.setMuted(!mixer.muted) }
            }
            if model.showDisplayControl {
                if model.showVolumeControl { systemControlDivider }
                systemSlider(title: tr("Pantalla"), symbol: "sun.max.fill",
                             value: Binding(get: { displayControls.screenBrightness }, set: { displayControls.setScreenBrightness($0) }),
                             enabled: displayControls.canSetScreenBrightness)
            }
            if model.showKeyboardControl {
                if model.showVolumeControl || model.showDisplayControl { systemControlDivider }
                systemSlider(title: tr("Teclado"), symbol: "light.beacon.max.fill",
                             value: Binding(get: { displayControls.keyboardBrightness }, set: { displayControls.setKeyboardBrightness($0) }))
            }
        }
        .frame(height: 46)
    }

    private var systemControlDivider: some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 30).padding(.horizontal, 10)
    }

    private func systemSlider(title: String, symbol: String, value: Binding<Double>, enabled: Bool = true,
                              action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Button { action?() } label: {
                    Image(systemName: symbol).font(.system(size: 10, weight: .medium)).frame(width: 14, height: 14)
                }
                .buttonStyle(.plain).disabled(action == nil)
                Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                Spacer(minLength: 2)
                Text("\(Int((value.wrappedValue * 100).rounded()))")
                    .font(.system(size: 8, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.38))
            }
            FaroSlider(value: value, tint: .white, track: Color.white.opacity(0.16))
        }
        .frame(maxWidth: .infinity)
        .opacity(enabled ? 1 : 0.32)
        .disabled(!enabled)
    }

    private var breakRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "eye").font(.system(size: 22, weight: .light))
                .frame(width: 56, height: 56).background(Circle().fill(Color.white.opacity(0.1)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Descansa la vista").font(.system(size: 14, weight: .semibold))
                Text("Mira algo lejano, a unos 6 metros").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Text("\(model.breakRemaining ?? 0)").font(.system(size: 28, weight: .light, design: .rounded)).monospacedDigit()
        }
    }

    private func control(_ symbol: String, size: CGFloat = 32, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size > 36 ? 15 : 12, weight: .semibold))
                .foregroundStyle(tint ?? .white)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(size > 36 ? 0.18 : 0.08)))
        }
        .buttonStyle(.plain)
    }

    private var toolsDock: some View {
        VStack(alignment: .leading, spacing: model.showToolsTitle ? 8 : 0) {
            if model.showToolsTitle {
                Text("Herramientas")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            HStack(spacing: 4) {
                ForEach(model.toolLayout.filter(\.enabled)) { toolConfig($0.kind) }
            }
        }
    }

    @ViewBuilder private func toolConfig(_ kind: NotchToolKind) -> some View {
        switch kind {
        case .clipboard:
            tool("doc.on.clipboard", kind.title) { model.collapse?(); AppController.shared.showClipboard() }
        case .shelf:
            tool("tray.and.arrow.down", kind.title) { model.collapse?(); AppController.shared.showShelf() }
        case .timer:
            tool(extras.timer.active ? (extras.timer.running ? "pause.fill" : "play.fill") : "timer", kind.title,
                 active: extras.timer.active) {
                if extras.timer.enabled { extras.timer.tap() } else { model.collapse?(); AppController.shared.openMain(.notch) }
            }
        case .microphone:
            tool(extras.mic.muted ? "mic.slash.fill" : "mic.fill", kind.title,
                 tint: extras.mic.muted ? .red : nil, active: extras.mic.enabled) {
                if extras.mic.enabled, extras.mic.available { extras.toggleMic() }
                else { model.collapse?(); AppController.shared.openMain(.audio) }
            }
        case .eyedropper:
            tool("eyedropper", kind.title, active: extras.eyedropperPicking) {
                if extras.eyedropperEnabled { extras.pickColor() }
                else { model.collapse?(); AppController.shared.openMain(.notch) }
            }
        case .emoji:
            tool("face.smiling", kind.title) { AppController.shared.showEmojiPicker() }
        case .awake:
            tool(awake.active ? "cup.and.saucer.fill" : "cup.and.saucer", kind.title, active: awake.active) {
                awake.active ? awake.disable() : awake.enable(hours: nil)
            }
        case .keyboard:
            tool("keyboard", kind.title) { model.collapse?(); AppController.shared.startCleaning() }
        case .settings:
            tool("slider.horizontal.3", kind.title) { model.collapse?(); AppController.shared.openMain(.notch) }
        }
    }

    private func tool(_ symbol: String, _ label: String, tint: Color? = nil, active: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: model.dockScale.iconSize, weight: .medium)).foregroundStyle(tint ?? .white)
                Text(LocalizedStringKey(label)).font(.system(size: 8, weight: .medium)).lineLimit(1)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity).frame(height: model.dockScale.height)
            .background { toolBackground(active: active) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tr(label))
    }

    @ViewBuilder private func toolBackground(active: Bool) -> some View {
        let fill = Color.white.opacity(active ? 0.13 : 0.055)
        switch model.toolButtonStyle {
        case .rounded:
            RoundedRectangle(cornerRadius: 13, style: .continuous).fill(fill)
        case .circle:
            Circle().fill(fill).frame(width: model.dockScale.height, height: model.dockScale.height)
        case .plain:
            Color.clear
        }
    }

    private var timerRow: some View {
        let timer = extras.timer
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 4)
                Circle().trim(from: 0, to: timer.progress).stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: timer.phase == .rest ? "cup.and.saucer.fill" : "timer").font(.system(size: 14))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(timer.clock).font(.system(size: 24, weight: .light, design: .rounded)).monospacedDigit()
                Text(timer.title).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 6) {
                control(timer.running ? "pause.fill" : "play.fill") { timer.tap() }
                if timer.pomodoro { control("forward.end.fill") { timer.skip() } }
                control("xmark") { timer.reset() }
            }
        }
    }

    private struct InfoItem {
        var id: String
        var symbol: String
        var eyebrow: String
        var value: String
        var detail: String
        var action: (() -> Void)?
    }

    private func systemInfo(_ metric: MenuBarMetric) -> InfoItem {
        InfoItem(id: "metric-\(metric.rawValue)", symbol: metric.symbol, eyebrow: metric.title,
                 value: MetricValue.text(metric, monitor: monitor, speed: speed), detail: metric.detail,
                 action: { open(metric) })
    }

    private var infoGrid: some View {
        let items = infoItems
        return Group {
            if items.count == 1, let item = items.first {
                infoCard(item)
            } else if !items.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                    ForEach(items, id: \.id) { infoCard($0) }
                }
            }
        }
    }

    private var infoItems: [InfoItem] {
        var out: [InfoItem] = []
        if let gb = model.lowDiskGB {
            out.append(InfoItem(id: "d", symbol: "internaldrive", eyebrow: tr("Almacenamiento"),
                                value: String(format: tr("Quedan %d GB"), gb), detail: tr("Conviene liberar espacio"),
                                action: { AppController.shared.openMain(.almacenamiento) }))
        }
        if model.showWeather, let w = model.weather {
            out.append(InfoItem(id: "w", symbol: w.symbol, eyebrow: w.city, value: "\(w.temperature)°", detail: w.summary, action: nil))
        }
        if model.showCalendar {
            if let e = model.event {
                out.append(InfoItem(id: "c", symbol: "calendar", eyebrow: tr("Próximo evento"), value: e.title,
                                    detail: eventTiming(e), action: nil))
            } else if !model.calendarDenied {
                out.append(InfoItem(id: "c", symbol: "calendar", eyebrow: tr("Calendario"), value: tr("Sin eventos"),
                                    detail: tr("En las próximas 24 horas"), action: nil))
            }
        }
        if extras.devices.enabled {
            for device in extras.devices.devices.prefix(2) {
                let short = device.name.components(separatedBy: " de ").first ?? device.name
                out.append(InfoItem(id: "b-\(device.id)", symbol: device.symbol, eyebrow: tr("Dispositivo"), value: short,
                                    detail: "\(device.percent)%", action: nil))
            }
        }
        if model.eyeBreak, model.breakRemaining == nil, let next = model.nextBreak {
            let minutes = max(Int((next.timeIntervalSinceNow / 60).rounded(.up)), 0)
            out.append(InfoItem(id: "e", symbol: "eye", eyebrow: tr("Descanso visual"), value: tr("Próxima pausa"),
                                detail: minutes <= 0 ? tr("Ahora") : String(format: tr("En %lld min"), minutes),
                                action: { model.startBreakNow() }))
        }
        return out
    }

    private func eventTiming(_ e: EventInfo) -> String {
        let now = Date()
        if e.allDay { return tr("Todo el día") }
        if e.start <= now { return tr("Ahora") }
        let minutes = Int(e.start.timeIntervalSince(now) / 60)
        return minutes < 60 ? String(format: tr("En %lld min"), max(minutes, 1))
                            : e.start.formatted(date: .omitted, time: .shortened)
    }

    private func eventLabel(_ e: EventInfo) -> String {
        let now = Date()
        if e.allDay { return e.title }
        if e.start <= now { return String(format: tr("Ahora: %@"), e.title) }
        let minutes = Int(e.start.timeIntervalSince(now) / 60)
        let when = minutes < 60 ? String(format: tr("en %lld min"), max(minutes, 1)) : e.start.formatted(date: .omitted, time: .shortened)
        return "\(e.title) · \(when)"
    }

    private func infoCard(_ item: InfoItem, showsBackground: Bool = true) -> some View {
        let content = HStack(spacing: 11) {
            Image(systemName: item.symbol).font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical).frame(width: 26).foregroundStyle(.white.opacity(0.82))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.eyebrow).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.42))
                    .textCase(.uppercase).lineLimit(1)
                Text(item.value).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(item.detail).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).frame(height: 70)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(showsBackground ? 0.055 : 0)))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        return Group {
            if let action = item.action { Button(action: action) { content }.buttonStyle(.plain) } else { content }
        }
    }
}

private extension View {
    func surface() -> some View {
        padding(12).background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.065)))
    }
}
