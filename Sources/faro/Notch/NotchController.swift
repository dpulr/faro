// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Coloca el panel sobre el notch y lo despliega cuando el cursor llega arriba al centro de la pantalla.
@MainActor
final class NotchController {
    static let shared = NotchController()

    private(set) var notchSize = CGSize(width: 200, height: 32)
    private(set) var hasHardwareNotch = false
    private var panel: NotchPanel?
    private var model: NotchModel?
    private var timer: Timer?
    private var screen: NSScreen?
    private var hoverTicks = 0
    private var leaveTicks = 0
    private var observer: NSObjectProtocol?

    var window: NSWindow? { panel }

    var summary: String {
        hasHardwareNotch ? "Notch detectado (\(Int(notchSize.width))×\(Int(notchSize.height)) puntos)"
                         : "Tu pantalla no tiene notch: el panel aparece como una cápsula arriba al centro"
    }

    func start(model: NotchModel) {
        self.model = model
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
        guard let model else { return }
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
        panel?.contentView = NSHostingView(rootView: NotchView(model: model, notchSize: notchSize,
                                                              hasHardwareNotch: hasHardwareNotch))
        panel?.orderFrontRegardless()
    }

    // MARK: Cursor

    private func pollMouse() {
        guard let model, model.enabled, let screen else { return }
        let p = NSEvent.mouseLocation
        let top = screen.frame.maxY
        if !model.expanded {
            let hot = CGRect(x: screen.frame.midX - notchSize.width / 2 - 24, y: top - notchSize.height - 2,
                             width: notchSize.width + 48, height: notchSize.height + 2)
            if hot.contains(p) { hoverTicks += 1; if hoverTicks >= 2 { setExpanded(true) } } else { hoverTicks = 0 }
        } else {
            let height = model.expandedHeight + 14
            let zone = CGRect(x: screen.frame.midX - 245, y: top - height, width: 490, height: height)
            if zone.contains(p) { leaveTicks = 0 } else { leaveTicks += 1; if leaveTicks >= 4 { setExpanded(false) } }
        }
    }

    private func setExpanded(_ on: Bool) {
        guard let model, model.expanded != on else { return }
        hoverTicks = 0
        leaveTicks = 0
        model.expanded = on
        panel?.ignoresMouseEvents = !on
        if on { model.pollMusic() }
    }
}
