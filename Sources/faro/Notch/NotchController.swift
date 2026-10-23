// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Ventana casi invisible sobre el notch que recibe los archivos arrastrados: aunque el panel ignore el ratón,
/// esta ventana (solo activa mientras dura un arrastre) avisa de que hay un archivo cerca.
final class DropTriggerView: NSView {
    var onEnter: (() -> Void)?
    var onDrop: (([URL]) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.02).cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onEnter?()
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                         options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        onDrop?(urls)
        return !urls.isEmpty
    }
}

/// Coloca el panel sobre el notch y lo despliega cuando el cursor llega arriba al centro de la pantalla.
@MainActor
final class NotchController {
    static let shared = NotchController()

    private(set) var notchSize = CGSize(width: 200, height: 32)
    private(set) var hasHardwareNotch = false
    private var panel: NotchPanel?
    private var trigger: NotchPanel?
    private var model: NotchModel?
    private var mixer: AudioMixer?
    private var dragBaseline = NSPasteboard(name: .drag).changeCount
    private var dropHideTicks = 0
    private var prevButton = false
    private var timer: Timer?
    private var screen: NSScreen?
    private var hoverTicks = 0
    private var leaveTicks = 0
    private var observer: NSObjectProtocol?

    var window: NSWindow? { panel }

    var summary: String {
        hasHardwareNotch ? String(format: tr("Notch detectado (%lld×%lld puntos)"), Int(notchSize.width), Int(notchSize.height))
                         : tr("Tu pantalla no tiene notch: el panel aparece como una cápsula arriba al centro")
    }

    func start(model: NotchModel, mixer: AudioMixer) {
        self.model = model
        self.mixer = mixer
        model.collapse = { [weak self] in self?.setExpanded(false) }
        model.start()
        apply()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.apply() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollMouse() }
        }
    }

    /// Crea o quita el panel según el ajuste y lo ubica en la pantalla con notch (o la principal).
    func apply() {
        guard let model, let mixer else { return }
        guard model.enabled else { panel?.orderOut(nil); panel = nil; return }
        let target = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        screen = target
        hasHardwareNotch = target.safeAreaInsets.top > 0
        if hasHardwareNotch {
            let left = target.auxiliaryTopLeftArea?.width ?? 0, right = target.auxiliaryTopRightArea?.width ?? 0
            notchSize = CGSize(width: target.frame.width - left - right, height: target.safeAreaInsets.top)
        } else {
            notchSize = CGSize(width: 160, height: NSStatusBar.system.thickness)
        }
        let size = CGSize(width: 520, height: 300)
        let origin = CGPoint(x: target.frame.midX - size.width / 2, y: target.frame.maxY - size.height)
        if panel == nil {
            let p = NotchPanel(contentRect: CGRect(origin: origin, size: size),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.hidesOnDeactivate = false
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            panel = p
        }
        panel?.setFrame(CGRect(origin: origin, size: size), display: true)
        panel?.contentView = NSHostingView(rootView: NotchView(model: model, mixer: mixer, notchSize: notchSize,
                                                              hasHardwareNotch: hasHardwareNotch))
        panel?.orderFrontRegardless()
        installTrigger(on: target)
    }

    private func installTrigger(on target: NSScreen) {
        let size = CGSize(width: notchSize.width + 48, height: notchSize.height + 2)
        let frame = CGRect(x: target.frame.midX - size.width / 2, y: target.frame.maxY - size.height,
                           width: size.width, height: size.height)
        if trigger == nil {
            let t = NotchPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            t.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
            t.isOpaque = false
            t.backgroundColor = .clear
            t.hasShadow = false
            t.ignoresMouseEvents = true
            t.hidesOnDeactivate = false
            t.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            let view = DropTriggerView(frame: CGRect(origin: .zero, size: size))
            view.onEnter = { [weak self] in self?.showDropZone() }
            view.onDrop = { [weak self] urls in self?.model?.onFilesDropped?(urls); self?.hideDropZone() }
            t.contentView = view
            trigger = t
        }
        trigger?.setFrame(frame, display: true)
        trigger?.orderFrontRegardless()
    }

    private func showDropZone() {
        guard let model else { return }
        dropHideTicks = 0
        if !model.dropActive { model.dropActive = true }
        updateMouseTransparency()
    }

    private func hideDropZone() {
        model?.dropActive = false
        dropHideTicks = 0
        updateMouseTransparency()
    }

    // MARK: Cursor

    private func pollMouse() {
        guard let model, model.enabled, let screen else { return }
        let p = NSEvent.mouseLocation
        let top = screen.frame.maxY
        let buttonDown = NSEvent.pressedMouseButtons & 1 != 0

        // ¿Hay un archivo arrastrándose? El portapapeles de arrastre cambia al empezar un arrastre nuevo.
        let dragBoard = NSPasteboard(name: .drag)
        if !buttonDown { dragBaseline = dragBoard.changeCount }
        let dragging = buttonDown && dragBoard.changeCount != dragBaseline
        // La ventana disparadora solo atiende al ratón mientras hay un arrastre, para no tapar la barra de menú.
        // No se depende del portapapeles de arrastre (el Dock y otras apps no siempre lo cambian): con el botón
        // pulsado cerca del notch la ventana ya escucha, y solo los archivos la activan.
        let wantTrigger = (buttonDown && p.y > top - 160) || model.dropActive
        if trigger?.ignoresMouseEvents == wantTrigger { trigger?.ignoresMouseEvents = !wantTrigger }
        let dropZone = CGRect(x: screen.frame.midX - 230, y: top - 140, width: 460, height: 140)
        if buttonDown && dropZone.contains(p) && model.dropActive { dropHideTicks = 0; return }
        if model.dropActive {
            // Se espera un poco tras soltar para no ocultar la zona antes de recibir el archivo.
            dropHideTicks += 1
            if dropHideTicks >= 6 { hideDropZone() }
            return
        }

        if !model.expanded {
            let justPressed = buttonDown && !prevButton
            prevButton = buttonDown
            if !model.openOnClick { guard !buttonDown else { hoverTicks = 0; return } }
            let hot = CGRect(x: screen.frame.midX - notchSize.width / 2 - 24, y: top - notchSize.height - 2,
                             width: notchSize.width + 48, height: notchSize.height + 2)
            if model.openOnClick {
                if justPressed && hot.contains(p) { setExpanded(true) }
            } else if hot.contains(p) { hoverTicks += 1; if hoverTicks >= 2 { setExpanded(true) } } else { hoverTicks = 0 }
        } else {
            let height = model.expandedHeight + 14
            let zone = CGRect(x: screen.frame.midX - 245, y: top - height, width: 490, height: height)
            if zone.contains(p) { leaveTicks = 0 } else { leaveTicks += 1; if leaveTicks >= 4 { setExpanded(false) } }
        }
    }

    /// El panel solo recibe el ratón cuando está desplegado o mostrando la zona de soltar.
    private func updateMouseTransparency() {
        guard let model else { return }
        panel?.ignoresMouseEvents = !(model.expanded || model.dropActive)
    }

    private func setExpanded(_ on: Bool) {
        guard let model, model.expanded != on else { return }
        hoverTicks = 0
        leaveTicks = 0
        model.expanded = on
        updateMouseTransparency()
        if on { model.pollMusic() }
    }
}
