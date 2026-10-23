// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `true` cuando salir es una orden explícita (botón de apagar, reinicio, cierre de sesión): no se pregunta.
    static var forceQuit = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        // Al apagar o cerrar sesión no hay que mostrar ningún aviso: bloquearía el apagado.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { _ in AppDelegate.forceQuit = true }
        let env = ProcessInfo.processInfo.environment
        if let dir = env["FARO_SNAPSHOT"] {
            Task { @MainActor in await Snapshot.run(dir) }
            return
        }
        if let out = env["FARO_DEBUG_PERMS"] {
            Task { @MainActor in await AppController.debugPermissions(to: out) }
            return
        }
        let atLogin = launchedAtLogin
        Task { @MainActor in
            AppController.shared.start()
            if let dir = env["FARO_DEBUG_SHOT"] {
                print("ventanas al arrancar: \(NSApp.windows.filter { $0.isVisible }.map(\.title))")
                await AppController.shared.debugCapture(to: dir)
            } else if env["FARO_DEBUG_FEATURES"] != nil {
                await AppController.shared.debugFeatures()
            } else if env["FARO_DEBUG_SOURCES"] != nil {
                await AppController.debugSources()
            } else if env["FARO_DEBUG_QUIT"] != nil {
                AppController.shared.openMain()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                print("antes de ⌘Q: ventana visible=\(AppController.shared.mainWindowVisible)")
                NSApp.terminate(nil)
                try? await Task.sleep(nanoseconds: 800_000_000)
                print("tras ⌘Q (elección=\(env["FARO_QUIT_CHOICE"] ?? "-")): la app sigue viva; ventana visible=\(AppController.shared.mainWindowVisible)")
                exit(0)
            } else if !atLogin {
                AppController.shared.openMain() // abrir faro desde Aplicaciones muestra su ventana
            }
        }
    }

    /// Volver a abrir faro (Launchpad, Finder) enseña la ventana principal.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in AppController.shared.openMain() }
        return true
    }

    /// ⌘Q pregunta antes de cerrar, como un navegador: se puede solo minimizar la vista de escritorio y dejar faro en la barra de menú.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.forceQuit { return .terminateNow }
        let choice = ProcessInfo.processInfo.environment["FARO_QUIT_CHOICE"] ?? askBeforeQuitting()
        switch choice {
        case "quit": return .terminateNow
        case "minimize":
            Task { @MainActor in AppController.shared.closeMainWindow() }
            return .terminateCancel
        default: return .terminateCancel
        }
    }

    private func askBeforeQuitting() -> String {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = tr("¿Seguro que quieres cerrar faro?")
        alert.informativeText = tr("También puedes minimizar solo la vista de escritorio: faro sigue en la barra de menú, con los fondos cambiando y el portapapeles guardando.")
        alert.addButton(withTitle: tr("Minimizar la vista de escritorio"))
        alert.addButton(withTitle: tr("Cerrar faro"))
        alert.addButton(withTitle: tr("Cancelar"))
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: return "minimize"
        case .alertSecondButtonReturn: return "quit"
        default: return "cancel"
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Al iniciar sesión, faro arranca callada en la barra de menú sin abrir ventanas.
    private var launchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
    }

    /// Sin esta barra de menú, ⌘C/⌘V/⌘A no funcionan en los campos de texto de una app sin Dock.
    private func installMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: tr("Ocultar faro"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: tr("Salir de faro"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: tr("Edición"))
        edit.addItem(withTitle: tr("Deshacer"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: tr("Rehacer"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: tr("Cortar"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: tr("Copiar"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: tr("Pegar"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: tr("Seleccionar todo"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: tr("Ventana"))
        window.addItem(withTitle: tr("Cerrar"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: tr("Minimizar"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = window
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }
}
