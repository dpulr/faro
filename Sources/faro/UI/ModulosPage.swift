// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI
import Darwin

/// Memoria que está usando faro ahora mismo (la misma cifra que muestra el Monitor de Actividad).
enum ProcessMemory {
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }
}

/// Inicio: qué funciones de faro están encendidas. Lo que se apaga aquí se detiene de verdad (sin temporizadores).
struct ModulosPage: View {
    @EnvironmentObject var notch: NotchModel
    @EnvironmentObject var engine: WallpaperEngine
    @EnvironmentObject var clipboard: ClipboardStore
    @EnvironmentObject var extras: NotchExtras

    @State private var memoryMB = ProcessMemory.footprintMB()
    @State private var lightOn = UserDefaults.standard.dictionary(forKey: Self.backupKey) != nil
    private let refresh = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private static let backupKey = "lightModeBackup"
    private static let wallpaperKey = "wallpaperMinutesBeforeOff"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Inicio", subtitle: "Enciende solo lo que uses. Lo que apagas aquí deja de funcionar y no gasta memoria ni batería.")

            lightCard

            Card(padding: 4) {
                VStack(spacing: 0) {
                    row("rectangle.topthird.inset.filled", "Notch", "El panel que cuelga de la parte de arriba de la pantalla.",
                        isOn: notchBinding)
                    divider
                    row("face.smiling", "Mascota", "La lucecita del notch que reacciona a la música y a tus dispositivos.",
                        isOn: Binding(get: { notch.mascot.enabled }, set: { notch.mascot.enabled = $0 }),
                        disabled: !notch.enabled)
                    divider
                    row("photo.on.rectangle", "Cambiar el fondo solo", "Pone una foto nueva en el escritorio cada cierto tiempo.",
                        isOn: wallpaperBinding)
                    divider
                    row("doc.on.clipboard", "Historial del portapapeles", "Guarda lo que copias para que puedas volver a pegarlo.",
                        isOn: Binding(get: { clipboard.active }, set: { clipboard.setActive($0) }))
                    divider
                    row("wifi", "Vigilar el internet", "Avisa si se cae el internet, el Wi‑Fi o la VPN.",
                        isOn: Binding(get: { extras.connection.monitoring }, set: { extras.connection.setMonitoring($0) }))
                    divider
                    row("arrow.down.circle", "Avisar de descargas", "Te dice cuando termina de bajar un archivo.",
                        isOn: Binding(get: { extras.downloads.enabled }, set: { extras.downloads.enabled = $0 }))
                    divider
                    row("camera.viewfinder", "Capturas a la bandeja", "Guarda cada captura de pantalla en la bandeja.",
                        isOn: Binding(get: { extras.screenshots.enabled }, set: { extras.screenshots.enabled = $0 }))
                    divider
                    row("externaldrive", "Avisar de discos y USB", "Te avisa cuando conectas un disco y deja expulsarlo.",
                        isOn: Binding(get: { extras.volumes.enabled }, set: { extras.volumes.enabled = $0 }))
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "memorychip").foregroundStyle(.secondary)
                Text("faro está usando \(Int(memoryMB.rounded())) MB de memoria ahora.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .onReceive(refresh) { _ in memoryMB = ProcessMemory.footprintMB() }
    }

    // MARK: Modo ligero

    private var lightCard: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: lightOn ? "leaf.fill" : "leaf").font(.system(size: 26)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(lightOn ? "Modo ligero activado" : "Modo ligero").font(.headline)
                    Text(lightOn ? "Todo lo opcional está apagado. Solo queda el ícono en la barra de menú."
                                 : "Apaga todo lo opcional con un clic. Solo queda el ícono en la barra de menú.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button(lightOn ? "Volver a como estaba" : "Activar") { lightOn ? restore() : enterLight() }
                    .buttonStyle(PillButtonStyle(prominent: !lightOn))
            }
        }
    }

    private func enterLight() {
        var backup: [String: Int] = [
            "notch": notch.enabled ? 1 : 0, "mascot": notch.mascot.enabled ? 1 : 0,
            "clipboard": clipboard.active ? 1 : 0, "connection": extras.connection.monitoring ? 1 : 0,
            "downloads": extras.downloads.enabled ? 1 : 0, "screenshots": extras.screenshots.enabled ? 1 : 0,
            "usb": extras.volumes.enabled ? 1 : 0, "wallpaper": engine.state.intervalMinutes,
        ]
        if engine.state.intervalMinutes == 0 { backup["wallpaper"] = UserDefaults.standard.integer(forKey: Self.wallpaperKey) }
        UserDefaults.standard.set(backup, forKey: Self.backupKey)
        setNotch(false)
        notch.mascot.enabled = false
        setWallpaper(false)
        clipboard.setActive(false)
        extras.connection.setMonitoring(false)
        extras.downloads.enabled = false
        extras.screenshots.enabled = false
        extras.volumes.enabled = false
        lightOn = true
        memoryMB = ProcessMemory.footprintMB()
    }

    private func restore() {
        let backup = UserDefaults.standard.dictionary(forKey: Self.backupKey) as? [String: Int] ?? [:]
        func on(_ key: String) -> Bool { (backup[key] ?? 1) == 1 }
        setNotch(on("notch"))
        notch.mascot.enabled = on("mascot")
        if let minutes = backup["wallpaper"], minutes > 0 { engine.state.intervalMinutes = minutes }
        clipboard.setActive(on("clipboard"))
        extras.connection.setMonitoring(on("connection"))
        extras.downloads.enabled = on("downloads")
        extras.screenshots.enabled = on("screenshots")
        extras.volumes.enabled = on("usb")
        UserDefaults.standard.removeObject(forKey: Self.backupKey)
        lightOn = false
        memoryMB = ProcessMemory.footprintMB()
    }

    // MARK: Interruptores con efecto real

    private func setNotch(_ on: Bool) {
        notch.enabled = on
        NotchController.shared.apply()
    }

    private var notchBinding: Binding<Bool> {
        Binding(get: { notch.enabled }, set: { setNotch($0) })
    }

    private func setWallpaper(_ on: Bool) {
        if on {
            let saved = UserDefaults.standard.integer(forKey: Self.wallpaperKey)
            engine.state.intervalMinutes = saved > 0 ? saved : 60
        } else {
            if engine.state.intervalMinutes > 0 { UserDefaults.standard.set(engine.state.intervalMinutes, forKey: Self.wallpaperKey) }
            engine.state.intervalMinutes = 0
        }
    }

    private var wallpaperBinding: Binding<Bool> {
        Binding(get: { engine.state.intervalMinutes > 0 }, set: { setWallpaper($0) })
    }

    // MARK: Piezas

    private var divider: some View { Divider().padding(.horizontal, 12) }

    private func row(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey,
                     isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 17)).frame(width: 26).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn).toggleStyle(MiniSwitchStyle()).labelsHidden()
        }
        .padding(12)
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
    }
}
