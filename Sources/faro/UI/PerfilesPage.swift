// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

private struct ProfileTarget: Identifiable { let id: UUID }

struct PerfilesPage: View {
    @EnvironmentObject var engine: WallpaperEngine
    @EnvironmentObject var awake: KeepAwake
    @EnvironmentObject var notch: NotchModel
    @State private var editing: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Perfiles",
                       subtitle: "Un modo guardado: con un clic cambia el fondo, la pantalla despierta y los datos de la barra.")

            VStack(spacing: 12) {
                ForEach(engine.state.profiles) { profile in card(profile) }
                if engine.state.profiles.isEmpty {
                    Text("Todavía no tienes perfiles. Crea uno con lo que tienes configurado ahora.")
                        .foregroundStyle(.secondary)
                }
            }

            Button { newProfile() } label: { Label("Guardar mis ajustes actuales como perfil", systemImage: "plus") }
                .buttonStyle(PillButtonStyle())
        }
        .sheet(item: Binding(get: { editing.map(ProfileTarget.init) }, set: { editing = $0?.id })) { target in
            ProfileSheet(profileID: target.id)
        }
    }

    private func card(_ profile: Profile) -> some View {
        let active = engine.state.activeProfileID == profile.id
        return Card {
            HStack(spacing: 14) {
                Image(systemName: profile.symbol).font(.system(size: 18))
                    .foregroundStyle(active ? Color.white : Theme.accent)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(active ? Theme.accent : Theme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(tr(profile.name)).font(.callout.weight(.semibold))
                        if active { Text("Activo").font(.caption2.weight(.semibold)).foregroundStyle(Theme.accent) }
                        if profile.autoStart { Image(systemName: "clock").font(.caption).foregroundStyle(.secondary) }
                    }
                    Text(summary(of: profile)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Button { AppController.shared.apply(profile) } label: { Text(active ? "Aplicar otra vez" : "Activar") }
                    .buttonStyle(PillButtonStyle(prominent: !active))
                Button { editing = profile.id } label: { Image(systemName: "pencil") }
                    .buttonStyle(IconButtonStyle(size: 34)).instantTip("Editar este perfil", anchor: .topTrailing)
            }
        }
    }

    private func summary(of profile: Profile) -> String {
        var parts: [String] = []
        if let name = engine.state.channels.first(where: { $0.id == profile.channelID })?.name { parts.append(tr(name)) }
        parts.append(Format.interval(profile.intervalMinutes).lowercased())
        if profile.keepAwake { parts.append(tr("despierto")) }
        if profile.eyeBreak { parts.append(tr("descanso visual")) }
        if profile.autoStart { parts.append(scheduleText(profile)) }
        return parts.joined(separator: " · ")
    }

    private func newProfile() {
        let profile = AppController.shared.profileFromCurrentSettings(named: "Perfil \(engine.state.profiles.count + 1)")
        engine.state.profiles.append(profile)
        editing = profile.id
    }
}

func scheduleText(_ p: Profile) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: AppLanguage.activeCode)
    let symbols = calendar.shortWeekdaySymbols
    let order = [2, 3, 4, 5, 6, 7, 1]
    let days = p.days.count == 7 ? tr("todos los días")
        : order.filter { p.days.contains($0) }.map { symbols[$0 - 1] }.joined(separator: " ")
    return String(format: tr("%@ a las %d:%02d"), days, p.hour, p.minute)
}

struct ProfileSheet: View {
    let profileID: UUID
    @EnvironmentObject var engine: WallpaperEngine
    @EnvironmentObject var awake: KeepAwake
    @EnvironmentObject var notch: NotchModel
    @Environment(\.dismiss) private var dismiss

    private let symbols = ["briefcase", "moon.stars", "book", "laptopcomputer", "gamecontroller", "sparkles", "music.note", "cup.and.saucer"]
    private let intervals: [(String, Int)] = [("15 min", 15), ("30 min", 30), ("1 hora", 60), ("2 horas", 120), ("6 horas", 360), ("1 día", 1440), ("A mano", 0)]
    private let dayNames: [(Int, String)] = [(2, "L"), (3, "M"), (4, "X"), (5, "J"), (6, "V"), (7, "S"), (1, "D")]

    private var index: Int? { engine.state.profiles.firstIndex { $0.id == profileID } }

    var body: some View {
        if let index {
            let profile = $engine.state.profiles[index]
            VStack(alignment: .leading, spacing: 22) {
                TextField("Nombre del perfil", text: profile.name).textFieldStyle(.plain).font(.system(size: 22, weight: .semibold))

                HStack(spacing: 8) {
                    ForEach(symbols, id: \.self) { symbol in
                        let on = profile.wrappedValue.symbol == symbol
                        Button { profile.wrappedValue.symbol = symbol } label: {
                            Image(systemName: symbol).font(.system(size: 14)).frame(width: 34, height: 34)
                                .foregroundStyle(on ? Color.white : Color.primary)
                                .background(Circle().fill(on ? Theme.accent : Theme.fill))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 0) {
                    row("Canal de fondos") {
                        Choice(selection: Binding(get: { profile.wrappedValue.channelID ?? engine.state.currentChannelID },
                                                  set: { profile.wrappedValue.channelID = $0 }),
                               options: engine.state.channels.map { ($0.name, $0.id) })
                    }
                    row("Cambiar el fondo") { Choice(selection: profile.intervalMinutes, options: intervals) }
                    row("Mantener despierto") { Toggle("", isOn: profile.keepAwake).labelsHidden() }
                    row("Descanso visual") { Toggle("", isOn: profile.eyeBreak).labelsHidden() }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Datos en la barra de menú").font(.callout)
                        FlowRow(items: MenuBarMetric.allCases) { metric in
                            let on = profile.wrappedValue.menuBarMetrics.contains(metric)
                            Button {
                                if on { profile.wrappedValue.menuBarMetrics.remove(metric) } else { profile.wrappedValue.menuBarMetrics.insert(metric) }
                            } label: {
                                Text(metric.title).font(.caption.weight(.medium))
                                    .foregroundStyle(on ? Color.white : Color.secondary)
                                    .padding(.horizontal, 11).padding(.vertical, 5)
                                    .background(Capsule().fill(on ? Theme.accent : Theme.fill))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)

                    row("Activarse sola a una hora") { Toggle("", isOn: profile.autoStart).labelsHidden() }
                    if profile.wrappedValue.autoStart { schedule(profile) }
                }

                HStack {
                    Button("Usar mis ajustes actuales") { useCurrent(profile) }.buttonStyle(PillButtonStyle())
                    Spacer()
                    Button("Eliminar") { remove() }.buttonStyle(.plain).font(.callout).foregroundStyle(Theme.critical)
                    Button("Listo") { dismiss() }.buttonStyle(PillButtonStyle(prominent: true))
                }
            }
            .padding(28)
            .frame(width: 560)
            .toggleStyle(MiniSwitchStyle())
            .tint(Appearance.shared.accent)
            .onAppear { DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) } }
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func schedule(_ profile: Binding<Profile>) -> some View {
        HStack(spacing: 8) {
            ForEach(dayNames, id: \.0) { day in
                let on = profile.wrappedValue.days.contains(day.0)
                Button {
                    if on { profile.wrappedValue.days.remove(day.0) } else { profile.wrappedValue.days.insert(day.0) }
                } label: {
                    Text(day.1).font(.caption.weight(.semibold)).frame(width: 28, height: 28)
                        .foregroundStyle(on ? Color.white : Color.secondary)
                        .background(Circle().fill(on ? Theme.accent : Theme.fill))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Choice(selection: profile.hour, options: (0..<24).map { (String(format: "%d", $0), $0) })
            Text(":").foregroundStyle(.secondary)
            Choice(selection: profile.minute, options: stride(from: 0, to: 60, by: 5).map { (String(format: "%02d", $0), $0) })
        }
        .padding(.vertical, 8)
    }

    private func useCurrent(_ profile: Binding<Profile>) {
        let current = AppController.shared.profileFromCurrentSettings(named: profile.wrappedValue.name, symbol: profile.wrappedValue.symbol)
        profile.wrappedValue.channelID = current.channelID
        profile.wrappedValue.intervalMinutes = current.intervalMinutes
        profile.wrappedValue.keepAwake = current.keepAwake
        profile.wrappedValue.menuBarMetrics = current.menuBarMetrics
        profile.wrappedValue.eyeBreak = current.eyeBreak
    }

    private func remove() {
        engine.state.profiles.removeAll { $0.id == profileID }
        if engine.state.activeProfileID == profileID { engine.state.activeProfileID = nil }
        dismiss()
    }

    private func row<Control: View>(_ title: LocalizedStringKey, @ViewBuilder control: () -> Control) -> some View {
        HStack { Text(title).font(.callout); Spacer(); control() }.padding(.vertical, 8)
    }
}
