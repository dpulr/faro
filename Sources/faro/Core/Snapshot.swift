// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Con `FARO_SNAPSHOT=<carpeta>` dibuja el menú y cada página a PNG y sale. Sirve para revisar el diseño sin abrir la app.
@MainActor
enum Snapshot {
    static func run(_ dir: String) async {
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
                .environmentObject(speed).environmentObject(awake).environmentObject(storage).environmentObject(clipboard).environmentObject(CleaningMode()).environmentObject(NotchModel())
                .environmentObject(Appearance.shared).tint(Appearance.shared.accent))
            let frame = CGRect(origin: .zero, size: size ?? host.fittingSize)
            let window = NSWindow(contentRect: frame, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            host.frame = frame
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }

        render(MenuView(), name: "menu", size: nil)
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
        let notchDemo = NotchModel()
        notchDemo.loadDemo()
        notchDemo.showCalendar = false
        notchDemo.expanded = true
        render(NotchView(model: notchDemo, notchSize: CGSize(width: 220, height: 38), hasHardwareNotch: true)
            .frame(width: 520, height: 230).background(Color(white: 0.78)), name: "notch-expanded", size: CGSize(width: 520, height: 230))
        notchDemo.expanded = false
        render(NotchView(model: notchDemo, notchSize: CGSize(width: 220, height: 38), hasHardwareNotch: true)
            .frame(width: 520, height: 60).background(Color(white: 0.78)), name: "notch-alas", size: CGSize(width: 520, height: 60))
        render(framed(NotchPage()), name: "page-notch", size: nil)
        render(framed(TecladoPage()), name: "page-teclado", size: nil)
        render(CleaningOverlay(mode: CleaningMode()), name: "cleaning-overlay", size: CGSize(width: 900, height: 560))
        render(framed(PortapapelesPage()), name: "page-portapapeles", size: nil)
        render(ClipboardPanelView(store: clipboard, onPaste: { _ in }, onClose: {}), name: "clip-panel", size: nil)
        render(framed(AlmacenamientoPage(expandedInitially: ["derived"])), name: "page-almacenamiento", size: nil)
        exit(0)
    }
}
