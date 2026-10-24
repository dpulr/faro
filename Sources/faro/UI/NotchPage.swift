// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI
import EventKit

struct NotchPage: View {
    @EnvironmentObject var notch: NotchModel
    @EnvironmentObject var extras: NotchExtras
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
                    if notch.showMusic {
                        Divider().padding(.horizontal, 12)
                        row("Letras sincronizadas", "La letra de lo que suena, bajo la pastilla y en el panel. Consulta lrclib.net con el título y el artista de la canción.") {
                            toggle($notch.lyrics.enabled)
                        }
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

            toolsCard
            alertsCard

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

    private func toggle(_ isOn: Binding<Bool>) -> some View {
        Toggle("", isOn: isOn).toggleStyle(MiniSwitchStyle()).labelsHidden()
    }

    private func minutesChip(_ value: Binding<Int>, _ options: [Int]) -> some View {
        MenuChip(text: String(format: tr("%lld min"), value.wrappedValue)) {
            ForEach(options, id: \.self) { m in
                DropdownRow(title: String(format: tr("%lld min"), m), selected: m == value.wrappedValue) { value.wrappedValue = m }
            }
        }
    }

    /// Botones y módulos que se usan a mano desde el panel desplegado.
    private var toolsCard: some View {
        Card(padding: 4) {
            VStack(spacing: 0) {
                row("Temporizador", "Un Pomodoro (enfoque y descanso) o un temporizador simple. La cuenta se ve con el notch recogido.") {
                    HStack(spacing: 10) {
                        if extras.timer.enabled {
                            Segments(selection: $extras.timer.pomodoro, options: [("Pomodoro", true), ("Simple", false)])
                        }
                        toggle($extras.timer.enabled)
                    }
                }
                if extras.timer.enabled {
                    Divider().padding(.horizontal, 12)
                    row("Duración", extras.timer.pomodoro ? "Cuánto dura el enfoque y cuánto el descanso." : "Cuánto dura el temporizador.") {
                        HStack(spacing: 8) {
                            if extras.timer.pomodoro {
                                minutesChip($extras.timer.focusMinutes, [15, 20, 25, 30, 45, 50, 60])
                                minutesChip($extras.timer.restMinutes, [3, 5, 10, 15])
                            } else {
                                minutesChip($extras.timer.simpleMinutes, [5, 10, 15, 30, 45, 60, 90])
                            }
                        }
                    }
                }
                Divider().padding(.horizontal, 12)
                row("Silenciar el micrófono", extras.mic.available
                    ? "Un botón en el panel (y ⌃⌥⌘M) silencia el micrófono para todas las apps de videollamada."
                    : "El micrófono actual no deja controlar su volumen desde el Mac.") {
                    toggle($extras.mic.enabled)
                }
                Divider().padding(.horizontal, 12)
                row("Gotero de color", "Toma el color de cualquier punto de la pantalla y copia su código.") {
                    toggle($extras.eyedropperEnabled)
                }
                Divider().padding(.horizontal, 12)
                row("Batería de dispositivos", "La carga de tus AirPods (con el estuche), teclado, ratón y trackpad Bluetooth, junto al clima.") {
                    toggle($extras.devices.enabled)
                }
            }
        }
    }

    /// Avisos que salen solos del notch.
    private var alertsCard: some View {
        Card(padding: 4) {
            VStack(spacing: 0) {
                row("Batería llena", "Un aviso cuando la carga llega al nivel que elijas, para desenchufar.") {
                    HStack(spacing: 10) {
                        if extras.battery.fullEnabled {
                            MenuChip(text: "\(extras.battery.fullLevel)%") {
                                ForEach([80, 85, 90, 95, 100], id: \.self) { level in
                                    DropdownRow(title: "\(level)%", selected: level == extras.battery.fullLevel) { extras.battery.fullLevel = level }
                                }
                            }
                        }
                        toggle($extras.battery.fullEnabled)
                    }
                }
                Divider().padding(.horizontal, 12)
                row("Batería baja", "Un aviso cuando queda poca carga (20 y 10 por ciento) y no estás cargando.") { toggle($extras.battery.lowEnabled) }
                Divider().padding(.horizontal, 12)
                row("Descargas terminadas", "Un aviso con botón para mostrar el archivo cuando termina una descarga. macOS pide permiso para ver la carpeta Descargas.") {
                    toggle($extras.downloads.enabled)
                }
                Divider().padding(.horizontal, 12)
                row("Capturas a la bandeja", "Cada captura de pantalla nueva entra sola a la bandeja de archivos. macOS pide permiso para ver la carpeta donde se guardan.") {
                    toggle($extras.screenshots.enabled)
                }
                Divider().padding(.horizontal, 12)
                row("Discos USB", "Un aviso con botón para expulsar al conectar una memoria o un disco.") { toggle($extras.volumes.enabled) }
                Divider().padding(.horizontal, 12)
                row("Cámara y micrófono en uso", "Un punto verde o naranja junto al notch cuando una app los usa.") { toggle($extras.privacyEnabled) }
                Divider().padding(.horizontal, 12)
                row("Bloq Mayús", "Un aviso breve cada vez que lo activas o desactivas.") { toggle($extras.capsEnabled) }
            }
        }
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
