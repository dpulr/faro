// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct FaroCommand: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var symbol: String
    var category: String
    var keywords: [String] = []
    var action: () -> Void

    var searchableText: String { ([title, subtitle, category] + keywords).joined(separator: " ").folded }
}

@MainActor
final class CommandCenterStore: ObservableObject {
    @Published var favorites: [String] { didSet { defaults.set(favorites, forKey: "commandFavorites") } }
    @Published var recent: [String] { didSet { defaults.set(recent, forKey: "commandRecent") } }
    private let defaults = UserDefaults.standard

    init() {
        favorites = defaults.stringArray(forKey: "commandFavorites") ?? []
        recent = defaults.stringArray(forKey: "commandRecent") ?? []
    }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.removeAll { $0 == id } } else { favorites.append(id) }
    }

    func record(_ id: String) {
        recent.removeAll { $0 == id }; recent.insert(id, at: 0)
        recent = Array(recent.prefix(10))
    }
}

@MainActor
final class CommandCenterController {
    static let shared = CommandCenterController()
    let store = CommandCenterStore()
    private var panel: FloatingPanel?
    private var observer: NSObjectProtocol?
    private var installed = false

    func install() {
        guard !installed else { return }
        installed = true
        Hotkeys.shared.register(keyCode: kVK_ANSI_F, modifiers: cmdKey | optionKey | controlKey) { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
    }

    func toggle() { panel?.isVisible == true ? close() : show() }

    func show() {
        close()
        let size = CGSize(width: 580, height: 520)
        let window = FloatingPanel(contentRect: CGRect(origin: .zero, size: size),
                                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                                   backing: .buffered, defer: false)
        window.isFloatingPanel = true; window.level = .floating; window.hasShadow = true
        window.isOpaque = false; window.backgroundColor = .clear; window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: CommandCenterView(store: store,
            onRun: { [weak self] command in self?.run(command) }, onClose: { [weak self] in self?.close() }))
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        window.setFrameOrigin(CGPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2))
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                                           object: window, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
        panel = window
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil; panel?.orderOut(nil); panel = nil
    }

    private func run(_ command: FaroCommand) {
        store.record(command.id); close()
        DispatchQueue.main.async { command.action() }
    }
}

struct CommandCenterView: View {
    @ObservedObject var store: CommandCenterStore
    var onRun: (FaroCommand) -> Void
    var onClose: () -> Void
    @State private var query = ""
    @State private var selection: String?
    @FocusState private var searching: Bool

    private var commands: [FaroCommand] { AppController.shared.commandItems() }
    private var results: [FaroCommand] {
        let needle = query.folded.trimmingCharacters(in: .whitespaces)
        if needle.isEmpty {
            let rank: (FaroCommand) -> Int = { command in
                if let i = store.favorites.firstIndex(of: command.id) { return i }
                if let i = store.recent.firstIndex(of: command.id) { return 100 + i }
                return 1_000
            }
            return commands.sorted { rank($0) == rank($1) ? $0.title < $1.title : rank($0) < rank($1) }
        }
        return commands.filter { command in needle.split(separator: " ").allSatisfy { command.searchableText.contains($0) } }
            .sorted { left, right in
                let lp = left.title.folded.hasPrefix(needle), rp = right.title.folded.hasPrefix(needle)
                return lp == rp ? left.title < right.title : lp
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                FaroLogo(style: .color, ring: false).frame(width: 28, height: 28)
                TextField("¿Qué quieres hacer?", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 19, weight: .medium)).focused($searching)
                    .onSubmit { runSelected() }
                Text("⌃⌥⌘F").font(.caption.monospaced()).foregroundStyle(.tertiary)
            }.padding(.horizontal, 18).padding(.vertical, 16)
            Divider()
            if results.isEmpty {
                ContentUnavailableView("Sin resultados", systemImage: "magnifyingglass",
                                       description: Text("Prueba con escena, volumen, teclado o ajustes."))
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(results.prefix(40)) { command in row(command).id(command.id) }
                        }.padding(9)
                    }.onChange(of: selection) { if let selection { proxy.scrollTo(selection) } }
                }
            }
            Divider()
            HStack(spacing: 14) {
                hint("↑↓", "elegir"); hint("↵", "ejecutar"); hint("esc", "cerrar")
                Spacer(); Text("Todo ocurre en tu Mac").font(.caption2).foregroundStyle(.tertiary)
            }.padding(.horizontal, 16).padding(.vertical, 9)
        }
        .frame(width: 580, height: 520)
        .background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
        .onAppear { searching = true; selection = results.first?.id }
        .onChange(of: query) { selection = results.first?.id }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onExitCommand { onClose() }
    }

    private func row(_ command: FaroCommand) -> some View {
        HStack(spacing: 12) {
            Image(systemName: command.symbol).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38).background(Circle().fill(Theme.accent.opacity(0.11)))
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title).font(.callout.weight(.semibold))
                Text(command.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(command.category).font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
            Button { store.toggleFavorite(command.id) } label: {
                Image(systemName: store.favorites.contains(command.id) ? "star.fill" : "star")
                    .foregroundStyle(store.favorites.contains(command.id) ? Theme.warning : Color.secondary)
                    .frame(width: 28, height: 28)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(selection == command.id ? Theme.accent.opacity(0.16) : Color.clear))
        .contentShape(Rectangle()).onTapGesture { onRun(command) }.onHover { if $0 { selection = command.id } }
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selection } ?? (delta > 0 ? -1 : results.count)
        selection = results[min(max(current + delta, 0), results.count - 1)].id
    }

    private func runSelected() {
        if let command = results.first(where: { $0.id == selection }) ?? results.first { onRun(command) }
    }

    private func hint(_ key: String, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text(key).font(.caption2.weight(.semibold).monospaced()).padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.fill))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private extension String {
    var folded: String { folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased() }
}

extension AppController {
    func showCommands() { closePopover(); CommandCenterController.shared.show() }

    func commandItems() -> [FaroCommand] {
        var commands = engine.state.profiles.map { profile in
            FaroCommand(id: "scene:\(profile.id)", title: tr(profile.name),
                        subtitle: tr("Aplicar todos sus ajustes y acciones"), symbol: profile.symbol,
                        category: tr("Escena"), keywords: ["perfil", "modo", "scene"]) { [weak self] in self?.apply(profile) }
        }
        commands += Page.allCases.map { page in
            FaroCommand(id: "page:\(page.rawValue)", title: page.title,
                        subtitle: String(format: tr("Abrir %@ en Faro"), page.title), symbol: page.symbol,
                        category: tr("Sección"), keywords: ["configurar", "ajustes"]) { [weak self] in self?.openMain(page) }
        }
        func add(_ id: String, _ title: String, _ subtitle: String, _ symbol: String,
                 _ category: String = tr("Acción"), keywords: [String] = [], action: @escaping () -> Void) {
            commands.append(FaroCommand(id: id, title: title, subtitle: subtitle, symbol: symbol,
                                        category: category, keywords: keywords, action: action))
        }
        add("tool:clipboard", tr("Abrir historial del portapapeles"), tr("Busca y pega algo que copiaste"), "doc.on.clipboard") { [weak self] in self?.showClipboard() }
        add("tool:shelf", tr("Abrir bandeja de archivos"), tr("Archivos guardados temporalmente"), "tray.and.arrow.down") { [weak self] in self?.showShelf() }
        add("tool:timer", extras.timer.active ? tr("Pausar o reanudar temporizador") : tr("Iniciar temporizador"),
            tr("Controla el enfoque desde el notch"), "timer") { [weak self] in
                guard let self else { return }; self.extras.timer.enabled = true; self.extras.timer.tap()
            }
        add("tool:mic", extras.mic.muted ? tr("Activar micrófono") : tr("Silenciar micrófono"),
            tr("Cambia el micrófono predeterminado"), extras.mic.muted ? "mic.fill" : "mic.slash") { [weak self] in
                guard let self else { return }
                if self.extras.mic.enabled, self.extras.mic.available { self.extras.toggleMic() } else { self.openMain(.audio) }
            }
        add("tool:audio", mixer.muted ? tr("Activar sonido") : tr("Silenciar sonido"),
            tr("Cambia el audio general del Mac"), mixer.muted ? "speaker.wave.2" : "speaker.slash") { [weak self] in self?.mixer.setMuted(!(self?.mixer.muted ?? false)) }
        add("tool:awake", awake.active ? tr("Dejar de mantener despierto") : tr("Mantener el Mac despierto"),
            tr("Evita que la pantalla entre en reposo"), awake.active ? "cup.and.saucer.fill" : "cup.and.saucer") { [weak self] in
                guard let self else { return }; self.awake.active ? self.awake.disable() : self.awake.enable(hours: nil)
            }
        add("tool:wallpaper", tr("Cambiar fondo ahora"), tr("Busca la siguiente imagen del canal activo"), "photo.on.rectangle") { [weak self] in
            guard let self else { return }; Task { await self.engine.next() }
        }
        add("tool:emoji", tr("Abrir emojis"), tr("Muestra el visor de caracteres de macOS"), "face.smiling") { [weak self] in self?.showEmojiPicker() }
        add("tool:color", tr("Tomar un color"), tr("Copia el color de cualquier punto de la pantalla"), "eyedropper") { [weak self] in
            guard let self else { return }
            self.extras.eyedropperEnabled ? self.extras.pickColor() : self.openMain(.notch)
        }
        add("tool:keyboard", tr("Limpiar el teclado"), tr("Bloquea las teclas temporalmente"), "keyboard") { [weak self] in self?.startCleaning() }
        add("automation:pause", sceneAutomationPaused ? tr("Reanudar automatizaciones") : tr("Pausar automatizaciones una hora"),
            tr("Controla los cambios automáticos de escenas"), sceneAutomationPaused ? "play.fill" : "pause.fill",
            tr("Automatización")) { [weak self] in
                guard let self else { return }
                self.sceneAutomationPaused ? self.resumeSceneAutomation() : self.pauseSceneAutomation(until: Date().addingTimeInterval(3600))
            }
        return commands
    }
}
