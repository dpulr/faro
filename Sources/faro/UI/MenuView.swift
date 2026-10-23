// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Contenido del menú de la barra: foto, controles y un resumen tranquilo del Mac.
struct MenuView: View {
    @EnvironmentObject var engine: WallpaperEngine
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var speed: SpeedTest
    @EnvironmentObject var awake: KeepAwake

    var body: some View {
        VStack(spacing: 14) {
            topBar.zIndex(3)
            nowPlaying
            controls.zIndex(2)
            channelRow
            systemSection
        }
        .padding(14)
        .frame(width: 360)
    }

    // MARK: Barra superior

    private var topBar: some View {
        HStack(spacing: 8) {
            // El logo abre la ventana de escritorio.
            Button { AppController.shared.openMain() } label: {
                HStack(spacing: 8) {
                    FaroLogo(style: .color, ring: false).frame(width: 30, height: 30)
                    Text("faro").font(.system(size: 20, weight: .semibold)).tracking(-0.3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .instantTip("Abrir la ventana de faro", anchor: .bottomLeading)
            Spacer(minLength: 6)
            battery
            Button { AppController.shared.showClipboard() } label: { Image(systemName: "doc.on.clipboard") }
                .buttonStyle(IconButtonStyle(size: 30)).instantTip("Historial del portapapeles (⌃⌥⌘V)", anchor: .bottomTrailing)
            Button { AppController.shared.showShelf() } label: { Image(systemName: "tray.and.arrow.down") }
                .buttonStyle(IconButtonStyle(size: 30)).instantTip("Bandeja de archivos (⌃⌥⌘B)", anchor: .bottomTrailing)
            // Dos acciones discretas, sin botón: expandir a la ventana y salir.
            Button { AppController.shared.openMain() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(QuietIconStyle()).instantTip("Expandir a la ventana", anchor: .bottomTrailing)
            Button { AppController.shared.quit() } label: {
                Image(systemName: "power").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(QuietIconStyle(tint: Theme.critical)).instantTip("Salir de faro", anchor: .bottomTrailing)
        }
        .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 6)
        .glassCapsule()
    }

    /// Batería bien visible: ícono y porcentaje grandes; en rojo si queda poca.
    @ViewBuilder private var battery: some View {
        if let pct = monitor.batteryPercent {
            let low = pct <= 20 && !monitor.batteryCharging
            HStack(spacing: 5) {
                Image(systemName: monitor.batteryCharging ? "battery.100.bolt" : (pct <= 20 ? "battery.25" : (pct <= 60 ? "battery.50" : "battery.75")))
                    .font(.system(size: 17))
                    .foregroundStyle(low ? Theme.critical : (monitor.batteryCharging ? Theme.accent : Color.primary))
                Text("\(pct)%").font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(low ? Theme.critical : Color.primary)
            }
            .padding(.trailing, 4)
            .instantTip(monitor.batteryCharging ? "Cargando" : "Batería", anchor: .bottom)
        }
    }

    // MARK: Foto actual

    /// La foto ocupa la mitad del ancho; al lado van el título y la fuente.
    private var nowPlaying: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 172, height: 108)
                .overlay {
                    if let image = engine.preview {
                        Image(nsImage: image).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Rectangle().fill(Theme.fill)
                            Image(systemName: "photo").font(.title2).foregroundStyle(.secondary)
                        }
                    }
                }
                .overlay { if engine.busy { ProgressView().controlSize(.small) } }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.current?.title ?? "Sin foto todavía").font(.callout.weight(.semibold)).lineLimit(3)
                Text([engine.current?.source.label, engine.current?.author]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .overlay { NoticeBar(text: engine.notice) }
    }

    /// Todos los botones son redondos y sin texto; al pasar el cursor dicen para qué sirven.
    private var controls: some View {
        HStack(spacing: 8) {
            Button { Task { await engine.previous() } } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(IconButtonStyle(size: 38)).instantTip("Volver a la foto anterior", anchor: .topLeading)
                .disabled(engine.busy || engine.state.history.count < 2)
            Button { Task { await engine.next() } } label: {
                if engine.busy { ProgressView().controlSize(.small).tint(.white) } else { Image(systemName: "forward.fill") }
            }
            .buttonStyle(IconButtonStyle(size: 38, prominent: true)).instantTip("Cambiar el fondo ahora")
            .allowsHitTesting(!engine.busy)
            Button { engine.saveCurrent() } label: { Image(systemName: "arrow.down.to.line") }
                .buttonStyle(IconButtonStyle(size: 38)).instantTip("Guardar esta foto en Imágenes")
                .disabled(engine.busy || (engine.current?.url.isFileURL ?? true))
            Button { Task { await engine.hideCurrent() } } label: { Image(systemName: "hand.thumbsdown") }
                .buttonStyle(IconButtonStyle(size: 38)).instantTip("No me gusta: que no vuelva a salir")
                .disabled(engine.busy)
            Spacer(minLength: 0)
            Button { awake.active ? awake.disable() : awake.enable(hours: nil) } label: {
                Image(systemName: awake.active ? "cup.and.saucer.fill" : "cup.and.saucer")
            }
            .buttonStyle(IconButtonStyle(size: 38, prominent: awake.active))
            .instantTip(awake.active ? "Despierto: púlsalo para dejar que el Mac duerma" : "Mantener el Mac despierto")
            Button { AppController.shared.startCleaning() } label: { Image(systemName: "keyboard") }
                .buttonStyle(IconButtonStyle(size: 38)).instantTip("Limpiar teclado: bloquea las teclas", anchor: .topTrailing)
        }
    }

    private var channelRow: some View {
        HStack {
            Menu {
                ForEach(engine.state.channels) { channel in
                    Button(channel.name) { engine.select(channel: channel.id) }
                }
                Divider()
                Button("Editar canales…") { AppController.shared.openMain(.fondos) }
            } label: {
                Label(engine.channel.name, systemImage: engine.channel.isCombo ? "square.stack.3d.up" : "photo.on.rectangle")
                    .font(.callout.weight(.medium))
            }
            .menuStyle(.borderlessButton).fixedSize()
            Spacer()
            profileMenu
        }
        .padding(.horizontal, 4)
    }

    /// Cambiar de perfil: un clic ajusta fondos, pantalla despierta y barra de menú.
    private var profileMenu: some View {
        let active = engine.state.profiles.first { $0.id == engine.state.activeProfileID }
        return Menu {
            ForEach(engine.state.profiles) { profile in
                Button { AppController.shared.apply(profile) } label: { Label(profile.name, systemImage: profile.symbol) }
            }
            Divider()
            Button("Editar perfiles…") { AppController.shared.openMain(.perfiles) }
        } label: {
            Label(active?.name ?? "Perfiles", systemImage: active?.symbol ?? "person.crop.square")
                .font(.callout).foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton).fixedSize()
    }

    // MARK: Sistema

    private var systemSection: some View {
        let health = monitor.health
        return Card(padding: 12, radius: 20) {
            VStack(spacing: 10) {
                if health.level != .ok {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.color(health.level)).frame(width: 7, height: 7)
                        Text(health.title).font(.callout.weight(.semibold))
                        Spacer()
                        Button { AppController.shared.openMain(.almacenamiento) } label: { Image(systemName: "internaldrive") }
                            .buttonStyle(IconButtonStyle(size: 30, prominent: true))
                            .instantTip("Liberar espacio", anchor: .topTrailing)
                    }
                }
                HStack(spacing: 6) {
                    MiniGauge(value: monitor.cpu / 100, tint: Theme.usage(monitor.cpu / 100),
                              title: "Procesador", detail: "\(Int(monitor.cpu.rounded()))%")
                    MiniGauge(value: monitor.memFraction, tint: Theme.usage(monitor.memFraction),
                              title: "Memoria", detail: "\(Int((monitor.memFraction * 100).rounded()))%")
                    MiniGauge(value: monitor.diskUsedFraction, tint: Theme.usage(monitor.diskUsedFraction),
                              title: "Disco libre", detail: Format.bytes(monitor.diskFree).replacingOccurrences(of: ",00", with: ""))
                }
            }
        }
    }
}
