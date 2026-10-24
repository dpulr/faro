// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit

/// Temporizador del notch: un Pomodoro (enfoque y descanso) o un temporizador simple.
/// Sigue contando aunque el panel esté recogido: la cuenta se ve en la pastilla.
@MainActor
final class FocusTimer: ObservableObject {
    enum Phase: Equatable { case idle, focus, rest, timer }

    @Published var enabled: Bool { didSet { save("timerEnabled", enabled); if !enabled { reset() } } }
    @Published var pomodoro: Bool { didSet { save("timerPomodoro", pomodoro) } }
    @Published var focusMinutes: Int { didSet { save("timerFocus", focusMinutes) } }
    @Published var restMinutes: Int { didSet { save("timerRest", restMinutes) } }
    @Published var simpleMinutes: Int { didSet { save("timerSimple", simpleMinutes) } }
    @Published private(set) var phase: Phase = .idle
    /// Segundos que faltan.
    @Published private(set) var remaining = 0
    @Published private(set) var running = false
    /// Enfoques completados desde que se abrió faro.
    @Published private(set) var completed = 0

    /// Lo llama al terminar una fase: (símbolo SF, texto).
    var onEvent: ((String, String) -> Void)?

    private var endDate: Date?
    private var total = 0
    private var timer: Timer?

    /// Sigue visible en la pastilla mientras haya una cuenta en marcha o en pausa.
    var active: Bool { phase != .idle }

    var progress: Double { total > 0 ? 1 - Double(remaining) / Double(total) : 0 }

    var title: String {
        switch phase {
        case .focus: return tr("Enfoque")
        case .rest: return tr("Descanso")
        case .timer: return tr("Temporizador")
        case .idle: return tr("Temporizador")
        }
    }

    var clock: String { String(format: "%d:%02d", remaining / 60, remaining % 60) }

    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }

    init() {
        let d = UserDefaults.standard
        func number(_ key: String, _ fallback: Int) -> Int { d.integer(forKey: key) == 0 ? fallback : d.integer(forKey: key) }
        enabled = d.object(forKey: "timerEnabled") as? Bool ?? true
        pomodoro = d.object(forKey: "timerPomodoro") as? Bool ?? true
        focusMinutes = number("timerFocus", 25)
        restMinutes = number("timerRest", 5)
        simpleMinutes = number("timerSimple", 15)
    }

    // MARK: Control

    /// Un toque: empieza si está parado, pausa o reanuda si ya hay una cuenta.
    func tap() {
        switch phase {
        case .idle: pomodoro ? begin(.focus, minutes: focusMinutes) : begin(.timer, minutes: simpleMinutes)
        default: running ? pause() : resume()
        }
    }

    func begin(_ phase: Phase, minutes: Int, now: Date = Date()) {
        self.phase = phase
        total = max(minutes, 1) * 60
        remaining = total
        endDate = now.addingTimeInterval(Double(total))
        running = true
        schedule()
    }

    func pause(now: Date = Date()) {
        guard running, let endDate else { return }
        remaining = max(Int(endDate.timeIntervalSince(now).rounded(.up)), 0)
        running = false
        timer?.invalidate()
    }

    func resume(now: Date = Date()) {
        guard !running, phase != .idle else { return }
        endDate = now.addingTimeInterval(Double(remaining))
        running = true
        schedule()
    }

    func reset() {
        timer?.invalidate()
        phase = .idle
        running = false
        remaining = 0
        total = 0
        endDate = nil
    }

    /// Salta a la siguiente fase del Pomodoro (o termina el temporizador simple).
    func skip(now: Date = Date()) {
        guard phase != .idle else { return }
        finishPhase(playSound: false, now: now)
    }

    // MARK: Cuenta

    private func schedule() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// `now` se puede adelantar en las pruebas.
    func tick(now: Date = Date()) {
        guard running, let endDate else { return }
        remaining = max(Int(endDate.timeIntervalSince(now).rounded(.up)), 0)
        if remaining == 0 { finishPhase(playSound: true, now: now) }
    }

    private func finishPhase(playSound: Bool, now: Date) {
        if playSound { NSSound(named: "Glass")?.play() }
        switch phase {
        case .focus:
            completed += 1
            onEvent?("cup.and.saucer.fill", String(format: tr("Enfoque terminado: descansa %lld min"), restMinutes))
            begin(.rest, minutes: restMinutes, now: now)
        case .rest:
            onEvent?("brain.head.profile", tr("Descanso terminado: a enfocarse"))
            reset()
        case .timer:
            onEvent?("timer", tr("Tiempo terminado"))
            reset()
        case .idle:
            break
        }
    }
}
