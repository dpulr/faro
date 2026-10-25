// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct ProfileTarget: Identifiable { let id: UUID }

struct PerfilesPage: View {
    @EnvironmentObject var engine: WallpaperEngine
    @EnvironmentObject var awake: KeepAwake
    @EnvironmentObject var notch: NotchModel
    @EnvironmentObject var monitor: SystemMonitor
    @State private var editing: UUID?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Escenas Faro",
                       subtitle: "El notch se adapta a lo que haces sin obligarte a configurar cada detalle una y otra vez.")

            if !engine.state.sceneOnboardingCompleted { onboardingCard }
            automationCard

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Mis escenas").font(.title3.weight(.semibold))
                    Text("\(engine.state.profiles.count)").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    Spacer()
                    Button { let count = AppController.shared.importScenes(); message = count > 0 ? "Se importaron \(count) escenas" : nil } label: {
                        Label("Importar", systemImage: "square.and.arrow.down")
                    }.buttonStyle(PillButtonStyle())
                    Button { newProfile() } label: { Label("Nueva escena", systemImage: "plus") }
                        .buttonStyle(PillButtonStyle(prominent: true))
                }
                ForEach(engine.state.profiles) { profile in card(profile) }
                if engine.state.profiles.isEmpty {
                    Card { Text("Crea una escena con tu configuración actual o deja que Faro prepare las recomendadas.")
                            .foregroundStyle(.secondary) }
                }
            }

            if !engine.state.sceneHistory.isEmpty { historyCard }
            if let message { Text(message).font(.caption).foregroundStyle(Theme.accent) }
        }
        .sheet(item: Binding(get: { editing.map(ProfileTarget.init) }, set: { editing = $0?.id })) { target in
            ProfileSheet(profileID: target.id)
        }
    }

    private var onboardingCard: some View {
        Card {
            HStack(spacing: 16) {
                Image(systemName: "sparkles.rectangle.stack").font(.system(size: 24)).foregroundStyle(Theme.accent)
                    .frame(width: 52, height: 52).background(Circle().fill(Theme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configura Faro en un minuto").font(.title3.weight(.semibold))
                    Text(recommendationText).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Ahora no") { AppController.shared.skipSceneOnboarding() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Button("Preparar mis escenas") { AppController.shared.installRecommendedScenes() }
                    .buttonStyle(PillButtonStyle(prominent: true))
            }
        }
    }

    private var recommendationText: String {
        var facts: [String] = []
        if AppController.shared.hasExternalDisplay { facts.append(tr("un monitor externo")) }
        if monitor.hasBattery { facts.append(monitor.onAC ? tr("tu Mac conectado") : tr("tu Mac usando batería")) }
        if let app = AppController.shared.currentApplication?.name { facts.append(String(format: tr("%@ al frente"), app)) }
        let found = facts.isEmpty ? tr("tu configuración actual") : facts.joined(separator: ", ")
        return String(format: tr("Detecté %@. Crearé Trabajo, Reunión, Multimedia, Escritorio y Minimal; luego puedes ajustar cualquier detalle."), found)
    }

    private var automationCard: some View {
        Card(padding: 4) {
            VStack(spacing: 4) {
                HStack(spacing: 14) {
                    Image(systemName: engine.state.sceneAutomationEnabled && !AppController.shared.sceneAutomationPaused ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 18)).foregroundStyle(Theme.accent).frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.accent.opacity(0.11)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cambio automático").font(.callout.weight(.semibold))
                        Text(contextText).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if engine.state.sceneAutomationEnabled { automationPauseControl }
                    Toggle("", isOn: $engine.state.sceneAutomationEnabled).toggleStyle(MiniSwitchStyle()).labelsHidden()
                        .onChange(of: engine.state.sceneAutomationEnabled) { _, on in
                            AppController.shared.sceneAutomationSettingChanged(on)
                        }
                }
                if let activation = engine.state.lastSceneActivation {
                    Divider().opacity(0.45)
                    HStack(spacing: 9) {
                        Image(systemName: activation.automatic ? "bolt.badge.clock" : "hand.tap")
                            .foregroundStyle(Theme.accent)
                        Text("\(tr(activation.profileName)): \(activation.reason)").font(.caption).lineLimit(2)
                        Spacer()
                        Text(activation.date.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                    }.padding(.horizontal, 12).padding(.vertical, 8)
                }
            }.padding(8)
        }
    }

    @ViewBuilder private var automationPauseControl: some View {
        if AppController.shared.sceneAutomationPaused {
            Button("Reanudar") { AppController.shared.resumeSceneAutomation() }.buttonStyle(PillButtonStyle())
        } else {
            Menu {
                Button("1 hora") { AppController.shared.pauseSceneAutomation(until: Date().addingTimeInterval(3600)) }
                Button("Hasta mañana") {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
                    AppController.shared.pauseSceneAutomation(until: tomorrow)
                }
            } label: { Label("Pausar", systemImage: "pause.fill") }.buttonStyle(PillButtonStyle())
        }
    }

    private var contextText: String {
        if let until = engine.state.sceneAutomationPauseUntil, until > Date() {
            return String(format: tr("En pausa hasta %@"), until.formatted(date: .omitted, time: .shortened))
        }
        let app = AppController.shared.currentApplication?.name ?? tr("ninguna app")
        let screen = AppController.shared.hasExternalDisplay ? tr("monitor externo") : tr("pantalla del Mac")
        let power = monitor.hasBattery ? (monitor.onAC ? tr("con corriente") : tr("con batería")) : tr("Mac de escritorio")
        return "\(app) · \(screen) · \(power)"
    }

    private func card(_ profile: Profile) -> some View {
        let active = engine.state.activeProfileID == profile.id
        return Card {
            HStack(spacing: 14) {
                Image(systemName: profile.symbol).font(.system(size: 18))
                    .foregroundStyle(active ? Color.white : Theme.accent).frame(width: 46, height: 46)
                    .background(Circle().fill(active ? Theme.accent : Theme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text(tr(profile.name)).font(.callout.weight(.semibold))
                        if active { badge("Activa", color: Theme.accent) }
                        if profile.hasContextTrigger || profile.autoStart { badge("Automática", color: .secondary) }
                    }
                    Text(summary(of: profile)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 12)
                if let settings = profile.notch { scenePreview(settings) }
                Button { AppController.shared.apply(profile) } label: { Text(active ? "Reaplicar" : "Activar") }
                    .buttonStyle(PillButtonStyle(prominent: !active))
                Menu {
                    Button("Editar", systemImage: "pencil") { editing = profile.id }
                    Button("Duplicar", systemImage: "plus.square.on.square") { AppController.shared.duplicate(profile) }
                    Button("Exportar…", systemImage: "square.and.arrow.up") {
                        message = AppController.shared.exportScene(profile) ? tr("Escena exportada") : nil
                    }
                    Button("Copiar enlace para Atajos", systemImage: "command") {
                        AppController.shared.copySceneShortcut(profile)
                    }
                    Divider()
                    Button("Eliminar", systemImage: "trash", role: .destructive) { remove(profile) }
                } label: { Image(systemName: "ellipsis") }
                    .buttonStyle(IconButtonStyle(size: 34)).instantTip("Más opciones", anchor: .topTrailing)
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3).background(Capsule().fill(color.opacity(0.12)))
    }

    /// Miniatura del notch: un panel negro con los widgets activos, del color de cada tipo, que siempre cabe en su caja.
    private func scenePreview(_ settings: NotchSceneSettings) -> some View {
        let widgets = settings.widgetLayout.filter(\.enabled)
        let rows = max(1, NotchMatrixLayout.rowCount(spans: widgets.map { ($0.size.columns, $0.height == .double ? 2 : 1) }))
        let box = CGSize(width: 132, height: 54)
        let inset: CGFloat = 6, gap: CGFloat = 2
        let rowHeight = max(3, (box.height - inset * 2 - gap * CGFloat(rows - 1)) / CGFloat(rows))
        return NotchMatrixLayout(rowHeight: rowHeight, spacing: gap) {
            ForEach(widgets) { item in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Self.tint(for: item.kind).opacity(item.showsBackground ? 0.85 : 0.45))
                    .notchMatrixSpan(columns: item.size.columns, rows: item.height == .double ? 2 : 1)
            }
        }
        .padding(inset)
        .frame(width: box.width, height: box.height, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .help(widgets.map { $0.kind.title }.joined(separator: " · "))
    }

    private static func tint(for kind: NotchWidgetKind) -> Color {
        switch kind {
        case .music: return Color(red: 0.96, green: 0.70, blue: 0.31)
        case .timer: return Color(red: 0.31, green: 0.84, blue: 0.78)
        case .weather: return Color(red: 0.47, green: 0.74, blue: 0.91)
        case .calendar: return Color(red: 0.98, green: 0.45, blue: 0.5)
        case .volume: return Color(red: 0.85, green: 0.88, blue: 0.92)
        case .devices: return Color(red: 0.49, green: 0.88, blue: 0.54)
        case .eyeBreak: return Color(red: 0.61, green: 0.55, blue: 1.0)
        case .storage: return Color(red: 1.0, green: 0.6, blue: 0.25)
        case .connection: return Color(red: 0.36, green: 0.62, blue: 1.0)
        case .greeting: return Color(red: 0.7, green: 0.72, blue: 0.76)
        }
    }

    private func summary(of profile: Profile) -> String {
        var parts: [String] = []
        if !profile.applications.isEmpty { parts.append(profile.applications.map(\.name).joined(separator: ", ")) }
        if profile.externalDisplay { parts.append(tr("al conectar un monitor")) }
        if profile.powerTrigger != .any { parts.append(profile.powerTrigger.title.lowercased()) }
        if profile.meetingTrigger { parts.append(tr("al comenzar una reunión")) }
        if profile.fullScreenTrigger { parts.append(tr("en pantalla completa")) }
        if !profile.bluetoothDevices.isEmpty { parts.append(profile.bluetoothDevices.joined(separator: ", ")) }
        if let level = profile.batteryBelow { parts.append(String(format: tr("batería bajo %lld%%"), level)) }
        if profile.autoStart { parts.append(scheduleText(profile)) }
        if parts.isEmpty { parts.append(tr("Activación manual")) }
        if !profile.actions.isEmpty { parts.append(tr("con acciones")) }
        parts.append(profile.notch == nil ? tr("perfil compatible") : tr("notch completo"))
        return parts.joined(separator: " · ")
    }

    private var historyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Historial").font(.title3.weight(.semibold)); Spacer()
                    Button("Vaciar") { engine.state.sceneHistory = [] }.buttonStyle(.plain).foregroundStyle(.secondary) }
                Text("Restaura cómo estaba Faro antes de aplicar una escena.").font(.caption).foregroundStyle(.secondary)
                ForEach(engine.state.sceneHistory.prefix(5)) { entry in
                    HStack {
                        Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading) {
                            Text(entry.snapshot.name).font(.callout.weight(.medium))
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Restaurar") { AppController.shared.restore(entry) }.buttonStyle(PillButtonStyle())
                    }
                }
            }
        }
    }

    private func newProfile() {
        let profile = AppController.shared.profileFromCurrentSettings(named: "Escena \(engine.state.profiles.count + 1)")
        engine.state.profiles.append(profile); editing = profile.id
    }

    private func remove(_ profile: Profile) {
        engine.state.profiles.removeAll { $0.id == profile.id }
        if engine.state.activeProfileID == profile.id { engine.state.activeProfileID = nil }
    }
}

func scheduleText(_ p: Profile) -> String {
    var calendar = Calendar(identifier: .gregorian); calendar.locale = Locale(identifier: AppLanguage.activeCode)
    let symbols = calendar.shortWeekdaySymbols, order = [2, 3, 4, 5, 6, 7, 1]
    let days = p.days.count == 7 ? tr("todos los días")
        : order.filter { p.days.contains($0) }.map { symbols[$0 - 1] }.joined(separator: " ")
    return String(format: tr("%@ a las %d:%02d"), days, p.hour, p.minute)
}

struct ProfileSheet: View {
    let profileID: UUID
    @EnvironmentObject var engine: WallpaperEngine
    @EnvironmentObject var notch: NotchModel
    @EnvironmentObject var extras: NotchExtras
    @Environment(\.dismiss) private var dismiss

    private let symbols = ["briefcase", "video", "moon.stars", "book", "display.2", "gamecontroller", "sparkles", "music.note", "cup.and.saucer"]
    private let intervals: [(String, Int)] = [("15 min", 15), ("30 min", 30), ("1 hora", 60), ("2 horas", 120), ("6 horas", 360), ("1 día", 1440), ("A mano", 0)]
    private let dayNames: [(Int, String)] = [(2, "L"), (3, "M"), (4, "X"), (5, "J"), (6, "V"), (7, "S"), (1, "D")]
    private var index: Int? { engine.state.profiles.firstIndex { $0.id == profileID } }

    var body: some View {
        if let index {
            let profile = $engine.state.profiles[index]
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        TextField("Nombre de la escena", text: profile.name).textFieldStyle(.plain).font(.system(size: 22, weight: .semibold))
                        Text("Prioridad \(profile.wrappedValue.priority)").font(.caption).foregroundStyle(.secondary)
                        Stepper("", value: profile.priority, in: 1...100, step: 5).labelsHidden()
                    }
                    HStack(spacing: 8) {
                        ForEach(symbols, id: \.self) { symbol in
                            let on = profile.wrappedValue.symbol == symbol
                            Button { profile.wrappedValue.symbol = symbol } label: {
                                Image(systemName: symbol).font(.system(size: 14)).frame(width: 34, height: 34)
                                    .foregroundStyle(on ? Color.white : Color.primary).background(Circle().fill(on ? Theme.accent : Theme.fill))
                            }.buttonStyle(.plain)
                        }
                    }

                    section("Qué cambia", "La escena guarda el notch completo además de estos ajustes.") {
                        row("Canal de fondos") { Choice(selection: Binding(get: { profile.wrappedValue.channelID ?? engine.state.currentChannelID },
                            set: { profile.wrappedValue.channelID = $0 }), options: engine.state.channels.map { ($0.name, $0.id) }) }
                        row("Cambiar el fondo") { Choice(selection: profile.intervalMinutes, options: intervals) }
                        row("Mantener despierto") { Toggle("", isOn: profile.keepAwake).labelsHidden() }
                        row("Descanso visual") { Toggle("", isOn: profile.eyeBreak).labelsHidden() }
                        Button { useCurrent(profile) } label: { Label("Actualizar con mis ajustes actuales", systemImage: "camera.metering.center.weighted") }
                            .buttonStyle(PillButtonStyle()).padding(.vertical, 9)
                    }

                    section("Cuándo se activa", "Si coinciden varias escenas, Faro elige la más específica y luego la de mayor prioridad.") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text("Aplicaciones").font(.callout); Spacer()
                                Button("La app al frente") { addCurrentApp(profile) }.buttonStyle(PillButtonStyle())
                                    .disabled(AppController.shared.currentApplication == nil)
                                Button("Elegir…") { chooseApps(profile) }.buttonStyle(PillButtonStyle())
                            }
                            FlowRow(items: profile.wrappedValue.applications) { app in
                                Button { profile.wrappedValue.applications.removeAll { $0.id == app.id } } label: {
                                    Label(app.name, systemImage: "xmark").font(.caption).padding(.horizontal, 9).padding(.vertical, 5)
                                        .background(Capsule().fill(Theme.fill))
                                }.buttonStyle(.plain)
                            }
                        }.padding(.vertical, 8)
                        row("Al conectar un monitor") { Toggle("", isOn: profile.externalDisplay).labelsHidden() }
                        row("Energía") { Segments(selection: profile.powerTrigger, options: ScenePowerTrigger.allCases.map { ($0.title, $0) }) }
                        row("Al comenzar una reunión") { Toggle("", isOn: profile.meetingTrigger).labelsHidden() }
                        row("Al usar pantalla completa") { Toggle("", isOn: profile.fullScreenTrigger).labelsHidden() }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("Dispositivo Bluetooth").font(.callout); Spacer()
                                Button("Actualizar") { extras.devices.refresh(force: true) }.buttonStyle(.plain).foregroundStyle(Theme.accent) }
                            if extras.devices.devices.isEmpty {
                                Text("Conecta el dispositivo para poder elegirlo.").font(.caption).foregroundStyle(.secondary)
                            } else {
                                FlowRow(items: extras.devices.devices) { device in
                                    let on = profile.wrappedValue.bluetoothDevices.contains(device.name)
                                    Button {
                                        if on { profile.wrappedValue.bluetoothDevices.removeAll { $0 == device.name } }
                                        else { profile.wrappedValue.bluetoothDevices.append(device.name) }
                                    } label: {
                                        Label(device.name, systemImage: device.symbol).font(.caption.weight(.medium))
                                            .foregroundStyle(on ? Color.white : Color.secondary)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(Capsule().fill(on ? Theme.accent : Theme.fill))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }.padding(.vertical, 9)
                        row("Batería baja") {
                            HStack(spacing: 8) {
                                if profile.wrappedValue.batteryBelow != nil {
                                    Choice(selection: Binding(get: { profile.wrappedValue.batteryBelow ?? 20 },
                                                              set: { profile.wrappedValue.batteryBelow = $0 }),
                                           options: [10, 20, 30, 40, 50].map { ("\($0)%", $0) })
                                }
                                Toggle("", isOn: Binding(get: { profile.wrappedValue.batteryBelow != nil },
                                                          set: { profile.wrappedValue.batteryBelow = $0 ? 20 : nil })).labelsHidden()
                            }
                        }
                        row("A una hora") { Toggle("", isOn: profile.autoStart).labelsHidden() }
                        if profile.wrappedValue.autoStart { schedule(profile) }
                    }

                    section("Acciones al entrar", "Solo se ejecutan al activar la escena. Al terminar una activación automática, Faro restaura los controles anteriores.") {
                        actionSlider("Volumen", symbol: "speaker.wave.2", value: profile.actions.volume, fallback: 45)
                        actionSlider("Brillo de pantalla", symbol: "sun.max", value: profile.actions.screenBrightness, fallback: 70)
                        actionSlider("Brillo del teclado", symbol: "light.max", value: profile.actions.keyboardBrightness, fallback: 50)
                        row("Micrófono") {
                            Segments(selection: profile.actions.microphone,
                                     options: SceneMicrophoneAction.allCases.map { ($0.title, $0) })
                        }
                        row("Iniciar enfoque") {
                            Choice(selection: profile.actions.focusMinutes,
                                   options: [(tr("No"), nil), ("15 min", 15), ("25 min", 25), ("45 min", 45), ("60 min", 60)] as [(String, Int?)])
                        }
                        VStack(alignment: .leading, spacing: 9) {
                            HStack { Text("Abrir aplicaciones").font(.callout); Spacer()
                                Button("Elegir…") { chooseActionApps(profile.actions.launchApplications) }.buttonStyle(PillButtonStyle()) }
                            FlowRow(items: profile.wrappedValue.actions.launchApplications) { app in
                                Button { profile.wrappedValue.actions.launchApplications.removeAll { $0.id == app.id } } label: {
                                    Label(app.name, systemImage: "xmark").font(.caption).padding(.horizontal, 9).padding(.vertical, 5)
                                        .background(Capsule().fill(Theme.fill))
                                }.buttonStyle(.plain)
                            }
                        }.padding(.vertical, 8)
                        row("Abrir enlace") {
                            TextField("https://…", text: profile.actions.openURL).textFieldStyle(.roundedBorder).frame(width: 250)
                        }
                    }

                    section("Barra de menú", "Elige los datos que acompañan esta escena.") {
                        FlowRow(items: MenuBarMetric.allCases) { metric in
                            let on = profile.wrappedValue.menuBarMetrics.contains(metric)
                            Button {
                                if on { profile.wrappedValue.menuBarMetrics.remove(metric) } else { profile.wrappedValue.menuBarMetrics.insert(metric) }
                            } label: {
                                Text(metric.title).font(.caption.weight(.medium)).foregroundStyle(on ? Color.white : Color.secondary)
                                    .padding(.horizontal, 11).padding(.vertical, 5).background(Capsule().fill(on ? Theme.accent : Theme.fill))
                            }.buttonStyle(.plain)
                        }.padding(.vertical, 9)
                    }

                    HStack { Spacer(); Button("Listo") { dismiss() }.buttonStyle(PillButtonStyle(prominent: true)) }
                }.padding(28)
            }
            .frame(width: 650, height: 680).toggleStyle(MiniSwitchStyle()).tint(Appearance.shared.accent)
            .onAppear { DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) } }
        } else { Color.clear.onAppear { dismiss() } }
    }

    private func section<Content: View>(_ title: String, _ detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.weight(.semibold)); Text(detail).font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 0) { content() }.padding(.horizontal, 12).background(RoundedRectangle(cornerRadius: 14).fill(Theme.fillFaint))
        }
    }

    private func addCurrentApp(_ profile: Binding<Profile>) {
        guard let app = AppController.shared.currentApplication,
              !profile.wrappedValue.applications.contains(where: { $0.id == app.id }) else { return }
        profile.wrappedValue.applications.append(app)
    }

    private func chooseApps(_ profile: Binding<Profile>) {
        pickApplications(into: profile.applications, title: tr("Elegir aplicaciones"))
    }

    private func chooseActionApps(_ applications: Binding<[SceneApplication]>) {
        pickApplications(into: applications, title: tr("Aplicaciones que abrirá la escena"))
    }

    private func pickApplications(into applications: Binding<[SceneApplication]>, title: String) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = tr("Agregar")
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url)?.bundleIdentifier,
                  !applications.wrappedValue.contains(where: { $0.bundleIdentifier == bundle }) else { continue }
            applications.wrappedValue.append(.init(bundleIdentifier: bundle,
                                                    name: url.deletingPathExtension().lastPathComponent))
        }
    }

    private func actionSlider(_ title: String, symbol: String, value: Binding<Int?>, fallback: Int) -> some View {
        let enabled = Binding(get: { value.wrappedValue != nil }, set: { value.wrappedValue = $0 ? fallback : nil })
        let number = Binding(get: { Double(value.wrappedValue ?? fallback) },
                             set: { value.wrappedValue = Int($0.rounded()) })
        return HStack(spacing: 10) {
            Label(title, systemImage: symbol).font(.callout).frame(width: 150, alignment: .leading)
            if enabled.wrappedValue {
                Slider(value: number, in: 0...100).frame(maxWidth: 220)
                Text("\(value.wrappedValue ?? fallback)%").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 38)
            }
            Spacer()
            Toggle("", isOn: enabled).labelsHidden()
        }.padding(.vertical, 9)
    }

    private func useCurrent(_ profile: Binding<Profile>) {
        let current = AppController.shared.profileFromCurrentSettings(named: profile.wrappedValue.name, symbol: profile.wrappedValue.symbol)
        profile.wrappedValue.channelID = current.channelID; profile.wrappedValue.intervalMinutes = current.intervalMinutes
        profile.wrappedValue.keepAwake = current.keepAwake; profile.wrappedValue.menuBarMetrics = current.menuBarMetrics
        profile.wrappedValue.menuBarShowIcon = current.menuBarShowIcon; profile.wrappedValue.eyeBreak = current.eyeBreak
        profile.wrappedValue.notch = current.notch
    }

    private func schedule(_ profile: Binding<Profile>) -> some View {
        HStack(spacing: 8) {
            ForEach(dayNames, id: \.0) { day in
                let on = profile.wrappedValue.days.contains(day.0)
                Button {
                    if on { profile.wrappedValue.days.remove(day.0) } else { profile.wrappedValue.days.insert(day.0) }
                } label: { Text(day.1).font(.caption.weight(.semibold)).frame(width: 28, height: 28)
                        .foregroundStyle(on ? Color.white : Color.secondary).background(Circle().fill(on ? Theme.accent : Theme.fill)) }
                    .buttonStyle(.plain)
            }
            Spacer()
            Choice(selection: profile.hour, options: (0..<24).map { (String(format: "%d", $0), $0) })
            Text(":").foregroundStyle(.secondary)
            Choice(selection: profile.minute, options: stride(from: 0, to: 60, by: 5).map { (String(format: "%02d", $0), $0) })
        }.padding(.vertical, 8)
    }

    private func row<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack { Text(title).font(.callout); Spacer(); control() }.padding(.vertical, 9)
    }
}
