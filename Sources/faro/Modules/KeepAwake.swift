// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation
import IOKit.pwr_mgt

@MainActor
final class KeepAwake: ObservableObject {
    @Published var until: Date?
    @Published var active = false

    private var assertion: IOPMAssertionID = 0
    private var timer: Timer?

    /// `hours == nil` mantiene despierto hasta que se desactive a mano.
    func enable(hours: Double?) {
        disable()
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "faro: mantener despierto" as CFString, &assertion)
        guard result == kIOReturnSuccess else { return }
        active = true
        if let hours {
            until = Date().addingTimeInterval(hours * 3600)
            timer = Timer.scheduledTimer(withTimeInterval: hours * 3600, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.disable() }
            }
        }
    }

    func disable() {
        if active { IOPMAssertionRelease(assertion) }
        assertion = 0
        active = false
        until = nil
        timer?.invalidate()
        timer = nil
    }
}
