// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Con `FARO_SNAPSHOT=<carpeta>` dibuja el menú y cada página a PNG y sale. Sirve para revisar el diseño sin abrir la app.
@MainActor
enum Snapshot {
    static func run(_ dir: String) async {
        NSApp.appearance = NSAppearance(named: .darkAqua) // los textos "primarios" se dibujan claros
        let engine = WallpaperEngine(), monitor = SystemMonitor(), speed = SpeedTest(), awake = KeepAwake()
        let storage = StorageModel()
        let clipboard = ClipboardStore(persistent: false)
        clipboard.addDemo(text: "https://example.com/articulo-interesante", app: "Safari", pinned: true, ago: 86_400)
        clipboard.addDemo(text: "func nextWallpaper() async {\n    guard !busy else { return }\n}", app: "Xcode", ago: 120)
        clipboard.addDemo(text: "Reunión de equipo el jueves a las 3 pm", app: "Notas", ago: 3_600)
        clipboard.addDemo(text: "Código de confirmación: 482 915", app: "Mail", ago: 14_000)
        if ProcessInfo.processInfo.environment["FARO_SNAPSHOT_SCAN"] != nil { await storage.scan() }
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        func render<V: View>(_ view: V, name: String, size: CGSize?) {
            let host = NSHostingView(rootView: view
                .environmentObject(engine).environmentObject(monitor)
                .environmentObject(speed).environmentObject(awake).environmentObject(storage).environmentObject(clipboard).environmentObject(CleaningMode()).environmentObject(NotchModel()).environmentObject(DiskAlert()).environmentObject(UpdateChecker()).environmentObject(NotchExtras()).environmentObject(AudioMixer())
                .environmentObject(Appearance.shared).tint(Appearance.shared.accent))
            let frame = CGRect(origin: .zero, size: size ?? host.fittingSize)
            let window = NSWindow(contentRect: frame, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            host.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            host.frame = frame
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }

        render(MenuView(), name: "menu", size: nil)
        render(MenuView().environment(\.colorScheme, .dark).background(Color(red: 0.07, green: 0.086, blue: 0.105)), name: "site-menu", size: nil)
        UserDefaults.standard.set("sistema", forKey: "page")
        render(MainWindow(), name: "window", size: CGSize(width: 1020, height: 720))
        func framed<V: View>(_ v: V) -> some View {
            v.padding(32).frame(width: 860, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        render(framed(FondosPage()), name: "page-fondos", size: nil)
        render(framed(SistemaPage()), name: "page-sistema", size: nil)
        render(framed(InternetPage()), name: "page-internet", size: nil)
        render(framed(EnergiaPage()), name: "page-energia", size: nil)
        render(framed(BarraPage()), name: "page-barra", size: nil)
        render(framed(GeneralPage()), name: "page-general", size: nil)
        func sheet<V: View>(_ v: V) -> some View { v.background(Color(nsColor: .windowBackgroundColor)) }
        render(sheet(ChannelSheet(channelID: engine.state.channels.first { $0.isCombo }!.id)), name: "sheet-mezcla", size: nil)
        render(sheet(ChannelSheet(channelID: engine.state.channels[0].id)), name: "sheet-canal", size: nil)
        render(sheet(ProfileSheet(profileID: engine.state.profiles[0].id)), name: "sheet-perfil", size: nil)
        render(framed(PerfilesPage()), name: "page-perfiles", size: nil)
        let demoExtras = NotchExtras()
        let demoMixer = AudioMixer()
        func demoNotch(_ model: NotchModel, _ extras: NotchExtras = demoExtras) -> some View {
            NotchView(model: model, mixer: demoMixer, extras: extras, engine: engine, monitor: monitor,
                      speed: speed, awake: awake, notchSize: CGSize(width: 220, height: 38), hasHardwareNotch: true)
        }
        let notchDemo = NotchModel()
        notchDemo.loadDemo()
        notchDemo.showMusic = true
        notchDemo.lyrics.loadDemo()
        notchDemo.showCalendar = false
        notchDemo.expanded = true
        render(demoNotch(notchDemo)
            .frame(width: 620, height: 560).background(Color(white: 0.78)), name: "notch-expanded", size: CGSize(width: 620, height: 560))
        // Para el sitio web: mismos paneles pero sobre fondo transparente (se recortan después).
        render(demoNotch(notchDemo).frame(width: 760, height: 600).background(Color.clear), name: "site-notch", size: CGSize(width: 760, height: 600))
        notchDemo.expanded = false
        // Música en pausa (antes la carátula se amontonaba junto a los botones) y la isla flotante sin datos en un Mac sin notch.
        let paused = NotchModel(); paused.loadDemo(); paused.showMusic = true
        paused.track = Track(title: "Cavalcade", artist: "Black Midi", source: "Music", playing: false, artworkURL: nil)
        render(demoNotch(paused).frame(width: 620, height: 90).background(Color(white: 0.78)), name: "notch-pausa", size: CGSize(width: 620, height: 90))
        let savedMetrics = engine.state.notchMetrics
        engine.state.notchMetrics = []
        let idle = NotchModel(); idle.showCompactControls = false
        render(NotchView(model: idle, mixer: demoMixer, extras: demoExtras, engine: engine, monitor: monitor, speed: speed, awake: awake,
                         notchSize: CGSize(width: 112, height: 30), hasHardwareNotch: false)
            .frame(width: 520, height: 70).background(Color(white: 0.78)), name: "notch-sin-notch", size: CGSize(width: 520, height: 70))
        render(NotchView(model: idle, mixer: demoMixer, extras: demoExtras, engine: engine, monitor: monitor, speed: speed, awake: awake,
                         notchSize: CGSize(width: 112, height: 30), hasHardwareNotch: false)
            .frame(width: 520, height: 70).background(Color.clear), name: "site-isla", size: CGSize(width: 520, height: 70))
        engine.state.notchMetrics = savedMetrics
        render(demoNotch(notchDemo)
            .frame(width: 520, height: 90).background(Color(white: 0.78)), name: "notch-alas", size: CGSize(width: 520, height: 90))
        render(demoNotch(notchDemo).frame(width: 760, height: 110).background(Color.clear), name: "site-alas", size: CGSize(width: 760, height: 110))
        let siteToast = NotchModel(); siteToast.showToast(symbol: "arrow.down.circle.fill", text: "Descarga lista: faro-1.7.dmg", seconds: 600, actionLabel: "Mostrar") {}
        render(demoNotch(siteToast).frame(width: 520, height: 110).background(Color.clear), name: "site-aviso", size: CGSize(width: 520, height: 110))
        let lowDisk = NotchModel(); lowDisk.loadDemo(); lowDisk.lowDiskGB = 7
        render(demoNotch(lowDisk)
            .frame(width: 520, height: 70).background(Color(white: 0.78)), name: "notch-poco-espacio", size: CGSize(width: 520, height: 70))
        let drop = NotchModel(); drop.loadDemo(); drop.dropActive = true
        render(demoNotch(drop)
            .frame(width: 520, height: 150).background(Color(white: 0.78)), name: "notch-soltar", size: CGSize(width: 520, height: 150))
        let toast = NotchModel(); toast.loadDemo(); toast.showToast(symbol: "airpods", text: "AirPods Pro conectado", seconds: 60)
        render(demoNotch(toast)
            .frame(width: 520, height: 110).background(Color(white: 0.78)), name: "notch-bluetooth", size: CGSize(width: 520, height: 110))
        // Temporizador en marcha, aviso con botón y gotero.
        let busy = NotchExtras(); busy.timer.begin(.focus, minutes: 25)
        let busyModel = NotchModel(); busyModel.loadDemo(); busyModel.expanded = true
        render(demoNotch(busyModel, busy)
            .frame(width: 620, height: 620).background(Color(white: 0.78)), name: "notch-temporizador", size: CGSize(width: 620, height: 620))
        let calm = NotchModel(); calm.showMusic = false
        render(demoNotch(calm, busy)
            .frame(width: 520, height: 76).background(Color(white: 0.78)), name: "notch-alas-temporizador", size: CGSize(width: 520, height: 76))
        let usb = NotchModel(); usb.showToast(symbol: "externaldrive.fill", text: "SANDISK conectado", seconds: 60, actionLabel: "Expulsar") {}
        render(demoNotch(usb)
            .frame(width: 520, height: 110).background(Color(white: 0.78)), name: "notch-usb", size: CGSize(width: 520, height: 110))
        // Mascota: todos los ánimos, formas y ojos.
        let mm = MascotModel()
        mm.react(.hearts, seconds: 120)
        try? await Task.sleep(nanoseconds: 900_000_000)
        let moods: [MascotMood] = [.sleeping, .idle, .dancing, .hearts, .bluetooth, .celebrate, .sad]
        render(VStack(spacing: 18) {
            HStack(spacing: 20) { ForEach(0..<moods.count, id: \.self) { MascotView(model: mm, size: 96, forcedMood: moods[$0]) } }
            HStack(spacing: 20) { ForEach(MascotShape.allCases) { MascotView(model: mm, size: 96, forcedMood: .idle, shape: $0) } }
            HStack(spacing: 20) { ForEach(MascotEyes.allCases) { MascotView(model: mm, size: 96, forcedMood: .idle, eyes: $0) } }
        }.padding(24).background(Color(red: 0.04, green: 0.05, blue: 0.06)), name: "mascota-estados", size: CGSize(width: 880, height: 400))
        let savedLook = (mm.shape, mm.accessory, mm.colorHex)
        mm.shape = .cloud; mm.accessory = .headphones; mm.colorHex = "#6BA5CE"
        render(HStack(spacing: 20) { ForEach([MascotMood.idle, .dancing, .sleeping], id: \.self.hashValue) { MascotView(model: mm, size: 96, forcedMood: $0) } }
            .padding(24).background(Color.black), name: "mascota-personalizada", size: CGSize(width: 420, height: 150))
        (mm.shape, mm.accessory, mm.colorHex) = savedLook // las capturas no tocan tus ajustes
        render(framed(NotchPage()), name: "page-notch", size: nil)
        render(framed(AudioPage()), name: "page-audio", size: nil)
        render(framed(TecladoPage()), name: "page-teclado", size: nil)
        render(CleaningOverlay(mode: CleaningMode()), name: "cleaning-overlay", size: CGSize(width: 900, height: 560))
        render(framed(PortapapelesPage()), name: "page-portapapeles", size: nil)
        render(ClipboardPanelView(store: clipboard, onPaste: { _ in }, onClose: {}), name: "clip-panel", size: nil)
        render(framed(AlmacenamientoPage(expandedInitially: ["derived"])), name: "page-almacenamiento", size: nil)
        exit(0)
    }
}
