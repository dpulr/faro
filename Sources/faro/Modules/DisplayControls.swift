// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import Darwin

/// Brillo de la pantalla integrada y de la retroiluminación del teclado.
/// DisplayServices no tiene un SDK público, así que se carga dinámicamente y Faro sigue funcionando
/// en equipos o versiones de macOS donde el símbolo no esté disponible.
@MainActor
final class DisplayControls: ObservableObject {
    @Published private(set) var screenBrightness = 0.5
    @Published private(set) var keyboardBrightness: Double
    @Published private(set) var canSetScreenBrightness = false

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let framework: UnsafeMutableRawPointer?
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?
    private var timer: Timer?

    init() {
        keyboardBrightness = UserDefaults.standard.object(forKey: "notchKeyboardBrightness") as? Double ?? 0.5
        framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        if let framework {
            getBrightness = dlsym(framework, "DisplayServicesGetBrightness").map { unsafeBitCast($0, to: GetBrightness.self) }
            setBrightness = dlsym(framework, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: SetBrightness.self) }
        } else {
            getBrightness = nil; setBrightness = nil
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = 0.4
    }

    deinit {
        timer?.invalidate()
        if let framework { dlclose(framework) }
    }

    func refresh() {
        guard let getBrightness else { canSetScreenBrightness = false; return }
        var value: Float = 0
        canSetScreenBrightness = getBrightness(CGMainDisplayID(), &value) == 0
        if canSetScreenBrightness { screenBrightness = Double(value) }
    }

    func setScreenBrightness(_ value: Double) {
        let value = min(max(value, 0), 1)
        guard let setBrightness, setBrightness(CGMainDisplayID(), Float(value)) == 0 else { return }
        screenBrightness = value
    }

    func setKeyboardBrightness(_ value: Double) {
        let value = min(max(value, 0), 1)
        let oldStep = Int((keyboardBrightness * 16).rounded())
        let newStep = Int((value * 16).rounded())
        guard oldStep != newStep else { keyboardBrightness = value; return }
        let keyType = newStep > oldStep ? 21 : 22 // NX_KEYTYPE_ILLUMINATION_UP / DOWN
        for _ in 0..<abs(newStep - oldStep) { postSystemKey(keyType) }
        keyboardBrightness = Double(newStep) / 16
        UserDefaults.standard.set(keyboardBrightness, forKey: "notchKeyboardBrightness")
    }

    private func postSystemKey(_ keyType: Int) {
        for state in [0x0A, 0x0B] { // key down, key up
            let event = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0,
                                           windowNumber: 0, context: nil, subtype: 8,
                                           data1: (keyType << 16) | (state << 8), data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
