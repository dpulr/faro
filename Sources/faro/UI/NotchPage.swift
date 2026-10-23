// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI
import EventKit

struct NotchPage: View {
    @EnvironmentObject var notch: NotchModel
    @State private var cityDraft = ""

    private let breakOptions = [20, 30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Notch",
                       subtitle: "Un panel que cuelga del notch y se despliega desde arriba al centro de la pantalla.")

            Card {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.topthird.inset.filled").font(.system(size: 22)).foregroundStyle(Theme.accent)
                        .frame(width: 48, height: 48).background(Circle().fill(Theme.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Panel del notch").font(.title3.weight(.semibold))
                        Text(NotchController.shared.summary).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { notch.enabled }, set: {
                        notch.enabled = $0
                        NotchController.shared.apply()
                    })).toggleStyle(MiniSwitchStyle()).labelsHidden()
                }
            }

            Card(padding: 4) {
                VStack(spacing: 0) {
                    row("Cómo se abre", "Al pasar el cursor por el notch, o solo cuando le das un clic.") {
                        Segments(selection: $notch.openOnClick, options: [("Al pasar", false), ("Con un clic", true)])
                    }
                    Divider().padding(.horizontal, 12)
                    row("Música", "Lo que suena en Música o Spotify, con controles. macOS te pide permiso la primera vez.") {
                        Toggle("", isOn: $notch.showMusic).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    row("Calendario", notch.calendarDenied
                        ? "Sin permiso: actívalo en Ajustes del Sistema → Privacidad y seguridad → Calendarios."
                        : "Tu próximo evento de las siguientes 24 horas.") {
                        Toggle("", isOn: $notch.showCalendar).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    row("Clima", notch.weatherError.map { LocalizedStringKey($0) } ?? "Temperatura y estado del cielo de tu ciudad (Open-Meteo, gratis).") {
                        HStack(spacing: 10) {
                            if notch.showWeather {
                                TextField("Ciudad", text: $cityDraft)
                                    .textFieldStyle(.roundedBorder).frame(width: 150)
                                    .onSubmit { commitCity() }
                                Button("Probar") { commitCity() }.buttonStyle(PillButtonStyle())
                            }
                            Toggle("", isOn: $notch.showWeather).toggleStyle(MiniSwitchStyle()).labelsHidden()
                        }
                    }
                    Divider().padding(.horizontal, 12)
                    row("Volumen", "Un control del volumen de tu Mac dentro del panel.") {
                        Toggle("", isOn: $notch.showVolume).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    row("Bluetooth", "Un aviso en el notch cuando se conectan tus audífonos, teclado o ratón. macOS pide permiso la primera vez.") {
                        Toggle("", isOn: $notch.showBluetooth).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    row("Descanso visual", "Un aviso para mirar a lo lejos 20 segundos (regla 20-20-20) y descansar los ojos.") {
                        HStack(spacing: 10) {
                            if notch.eyeBreak {
                                Choice(selection: $notch.eyeBreakMinutes, options: breakOptions.map { (String(format: tr("Cada %lld min"), $0), $0) })
                            }
                            Toggle("", isOn: $notch.eyeBreak).toggleStyle(MiniSwitchStyle()).labelsHidden()
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cómo se usa").font(.callout.weight(.semibold))
                    tip("cursorarrow.motionlines", notch.openOnClick ? "Haz clic en el notch: el panel se despliega y, al alejar el cursor, se recoge." : "Lleva el cursor al notch: el panel se despliega y, al alejarlo, se recoge.")
                    tip("waveform", "Mientras suena música o corre un descanso, aparecen detalles a los lados del notch sin desplegarlo.")
                    tip("tray.and.arrow.down", "Arrastra un archivo hacia el notch y suéltalo en la zona que aparece: se guarda en la bandeja.")
                    tip("eye", "En el panel, el botón «Descanso» empieza la pausa de 20 segundos cuando tú quieras.")
                }
            }
        }
        .onAppear { cityDraft = notch.city }
    }

    private func commitCity() {
        notch.city = cityDraft.trimmingCharacters(in: .whitespaces)
        Task { await notch.refreshWeather() }
    }

    private func tip(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 20).foregroundStyle(.secondary)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func row<Control: View>(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(12)
    }
}
