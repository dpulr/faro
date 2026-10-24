// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

struct NotchShape: Shape {
    var radius: CGFloat
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: radius, bottomTrailing: radius, topTrailing: 0),
                               style: .continuous).path(in: rect)
    }
}

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Panel negro que cuelga del notch: pequeño con "alas" cuando algo está en vivo y desplegado al acercar el cursor.
struct NotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var mixer: AudioMixer
    @ObservedObject var extras: NotchExtras
    var notchSize: CGSize
    var hasHardwareNotch: Bool

    @State private var dropTargeted = false
    private let spring = Animation.spring(response: 0.4, dampingFraction: 0.82)

    var body: some View {
        ZStack(alignment: .top) {
            if model.expanded {
                expandedBody
                    .frame(width: 470)
                    .background(NotchShape(radius: 32).fill(Color.black))
                    .background(GeometryReader { Color.clear.preference(key: HeightKey.self, value: $0.size.height) })
                    .transition(.opacity)
            } else if model.dropActive {
                dropZone
                    .transition(.opacity)
            } else if model.toast != nil {
                toastBody
                    .transition(.opacity)
            } else if model.hasLive || extras.hasLive {
                VStack(spacing: 0) {
                    wings.frame(width: notchSize.width + 104, height: notchSize.height)
                    if let lyric = collapsedLyric {
                        Text(lyric).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: notchSize.width + 150).padding(.horizontal, 10)
                            .padding(.top, 2).padding(.bottom, 9)
                            .id(lyric)
                            .transition(.opacity)
                    }
                }
                .background(NotchShape(radius: collapsedLyric == nil ? 14 : 20).fill(Color.black))
                .animation(.easeInOut(duration: 0.25), value: collapsedLyric)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(spring, value: model.expanded)
        .animation(spring, value: model.hasLive || extras.hasLive)
        .animation(spring, value: model.dropActive)
        .animation(spring, value: model.toast)
        .onPreferenceChange(HeightKey.self) { if $0 > 0 { model.expandedHeight = $0 } }
        .environment(\.colorScheme, .dark)
    }

    /// Línea de la letra que cuelga bajo la pastilla mientras suena una canción con letra.
    private var collapsedLyric: String? {
        guard model.showMusic, model.track?.playing == true, model.lyrics.enabled else { return nil }
        return model.lyrics.line
    }

    // MARK: Alas (colapsado con algo en vivo)

    private var wings: some View {
        HStack(spacing: 0) {
            Group {
                if extras.cameraOn {
                    Image(systemName: "video.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(.green)
                } else if extras.micOn {
                    Image(systemName: "mic.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(.orange)
                } else if model.breakRemaining != nil {
                    Image(systemName: "eye").font(.system(size: 14, weight: .medium))
                } else if extras.timer.active, !(model.showMusic && model.track?.playing == true) {
                    Image(systemName: extras.timer.phase == .rest ? "cup.and.saucer.fill" : "timer").font(.system(size: 14, weight: .medium))
                } else if model.lowDiskGB != nil {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(.orange)
                } else if let art = model.artwork {
                    Image(nsImage: art).resizable().scaledToFill().frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: "music.note").font(.system(size: 14, weight: .medium))
                }
            }
            .frame(width: 52)
            Spacer(minLength: 0)
            Group {
                if extras.timer.active {
                    Text(extras.timer.clock).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(extras.timer.running ? Color.white : Color.white.opacity(0.5))
                } else if let remaining = model.breakRemaining {
                    Text("\(remaining)").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                } else if let gb = model.lowDiskGB {
                    Text("\(gb) GB").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.orange)
                } else {
                    Image(systemName: "waveform").font(.system(size: 14, weight: .medium))
                        .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                }
            }
            .frame(width: 52)
        }
        .foregroundStyle(.white)
    }

    // MARK: Aviso y zona para soltar

    private var toastBody: some View {
        HStack(spacing: 10) {
            if let hex = model.toast?.swatch, let color = Color(hex: hex) {
                Circle().fill(color).frame(width: 18, height: 18).overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
            } else {
                Image(systemName: model.toast?.symbol ?? "bell").font(.system(size: 16, weight: .medium))
            }
            Text(model.toast?.text ?? "").font(.system(size: 13, weight: .medium)).lineLimit(1)
            if let label = model.toast?.actionLabel {
                Button {
                    let action = model.toastAction
                    model.toast = nil
                    action?()
                } label: {
                    Text(label).font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.top, notchSize.height + 4)
        .padding(.bottom, 14)
        .frame(minWidth: 280)
        .background(NotchShape(radius: 26).fill(Color.black))
    }

    private var dropZone: some View {
        VStack(spacing: 6) {
            Image(systemName: dropTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                .font(.system(size: 24, weight: .light))
            Text("Suelta aquí para guardar en la bandeja").font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(dropTargeted ? Color.white : Color.white.opacity(0.75))
        .padding(.horizontal, 30)
        .padding(.top, notchSize.height + 6)
        .padding(.bottom, 18)
        .frame(width: 380)
        .background(NotchShape(radius: 30).fill(Color.black))
        .overlay(NotchShape(radius: 30).stroke(Theme.accent.opacity(dropTargeted ? 1 : 0.35), lineWidth: 2))
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            ShelfDrop.load(providers) { urls in model.onFilesDropped?(urls) }
            return !providers.isEmpty
        }
    }

    // MARK: Desplegado

    private var expandedBody: some View {
        VStack(spacing: 14) {
            if extras.timer.enabled, extras.timer.active { timerRow }
            if model.breakRemaining != nil { breakRow }
            else if model.showMusic { musicRow }
            if model.showMusic, model.lyrics.enabled, let line = model.lyrics.line { lyricsRow(line) }
            if model.showVolume { volumeRow }
            chips
            actionsRow
        }
        .padding(.horizontal, 22)
        .padding(.top, notchSize.height + 4)
        .padding(.bottom, 20)
        .foregroundStyle(.white)
    }

    private var musicRow: some View {
        HStack(spacing: 14) {
            Group {
                if let art = model.artwork {
                    Image(nsImage: art).resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.white.opacity(0.1)
                        Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.track?.title ?? "Nada sonando").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(model.track.map { $0.artist.isEmpty ? $0.source : $0.artist } ?? tr("Abre Música o Spotify"))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            Spacer(minLength: 8)
            if model.track != nil {
                HStack(spacing: 6) {
                    control("backward.fill") { model.musicCommand("previous track") }
                    control(model.track?.playing == true ? "pause.fill" : "play.fill", size: 40) { model.musicCommand("playpause") }
                    control("forward.fill") { model.musicCommand("next track") }
                }
            }
        }
    }

    /// La línea que suena y la siguiente, en pequeño.
    private func lyricsRow(_ line: String) -> some View {
        VStack(spacing: 3) {
            Text(line).font(.system(size: 15, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
            if let next = model.lyrics.next {
                Text(next).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .id(line)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: line)
    }

    private var volumeRow: some View {
        HStack(spacing: 12) {
            Button { mixer.setMuted(!mixer.muted) } label: {
                Image(systemName: mixer.muted || mixer.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13)).frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            FaroSlider(value: Binding(get: { mixer.volume }, set: { mixer.setVolume($0) }),
                       tint: .white, track: Color.white.opacity(0.18))
            Text("\(Int((mixer.volume * 100).rounded()))").font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55)).frame(width: 26, alignment: .trailing)
        }
        .opacity(mixer.canSetVolume ? 1 : 0.4)
    }

    private var breakRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "eye").font(.system(size: 22, weight: .light))
                .frame(width: 56, height: 56).background(Circle().fill(Color.white.opacity(0.1)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Descansa la vista").font(.system(size: 14, weight: .semibold))
                Text("Mira algo lejano, a unos 6 metros").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Text("\(model.breakRemaining ?? 0)").font(.system(size: 28, weight: .light, design: .rounded)).monospacedDigit()
        }
    }

    private func control(_ symbol: String, size: CGFloat = 32, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size > 36 ? 15 : 12, weight: .semibold))
                .foregroundStyle(tint ?? .white)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(size > 36 ? 0.18 : 0.08)))
        }
        .buttonStyle(.plain)
    }

    /// Datos en una línea: clima, evento, descanso, baterías de dispositivos.
    private var chips: some View {
        let items = chipItems
        return Group {
            if !items.isEmpty { HStack(spacing: 8) { ForEach(items, id: \.id) { chip($0) } } }
        }
    }

    /// Botones redondos de acceso rápido.
    private var actionsRow: some View {
        HStack(spacing: 10) {
            control("doc.on.clipboard", size: 34) { model.collapse?(); AppController.shared.showClipboard() }
                .help(tr("Portapapeles"))
            control("tray.and.arrow.down", size: 34) { model.collapse?(); AppController.shared.showShelf() }
                .help(tr("Bandeja"))
            if extras.timer.enabled, !extras.timer.active {
                control(extras.timer.active ? (extras.timer.running ? "pause.fill" : "play.fill") : "timer", size: 34) { extras.timer.tap() }
                    .help(extras.timer.pomodoro ? tr("Pomodoro") : tr("Temporizador"))
            }
            if extras.mic.enabled, extras.mic.available {
                control(extras.mic.muted ? "mic.slash.fill" : "mic.fill", size: 34, tint: extras.mic.muted ? .red : nil) { extras.toggleMic() }
                    .help(extras.mic.muted ? tr("Activar el micrófono") : tr("Silenciar el micrófono"))
            }
            if extras.eyedropperEnabled {
                control("eyedropper", size: 34) { extras.pickColor() }
                    .help(tr("Gotero de color"))
            }
        }
    }

    private var timerRow: some View {
        let timer = extras.timer
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 4)
                Circle().trim(from: 0, to: timer.progress).stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: timer.phase == .rest ? "cup.and.saucer.fill" : "timer").font(.system(size: 14))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(timer.clock).font(.system(size: 24, weight: .light, design: .rounded)).monospacedDigit()
                Text(timer.title).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 6) {
                control(timer.running ? "pause.fill" : "play.fill") { timer.tap() }
                if timer.pomodoro { control("forward.end.fill") { timer.skip() } }
                control("xmark") { timer.reset() }
            }
        }
    }

    private struct Chip { var id: String; var symbol: String; var text: String; var action: (() -> Void)? }

    private var chipItems: [Chip] {
        var out: [Chip] = []
        if let gb = model.lowDiskGB {
            out.append(Chip(id: "d", symbol: "internaldrive", text: String(format: tr("Quedan %d GB"), gb),
                            action: { AppController.shared.openMain(.almacenamiento) }))
        }
        if model.showWeather, let w = model.weather {
            out.append(Chip(id: "w", symbol: w.symbol, text: "\(w.temperature)° \(w.city)", action: nil))
        }
        if model.showCalendar {
            if let e = model.event {
                out.append(Chip(id: "c", symbol: "calendar", text: eventLabel(e), action: nil))
            } else if !model.calendarDenied {
                out.append(Chip(id: "c", symbol: "calendar", text: tr("Sin eventos"), action: nil))
            }
        }
        if extras.devices.enabled {
            for device in extras.devices.devices.prefix(2) {
                let short = device.name.components(separatedBy: " de ").first ?? device.name
                out.append(Chip(id: "b-\(device.id)", symbol: device.symbol, text: "\(short) \(device.percent)%", action: nil))
            }
        }
        if model.eyeBreak, model.breakRemaining == nil, let next = model.nextBreak {
            let minutes = max(Int((next.timeIntervalSinceNow / 60).rounded(.up)), 0)
            out.append(Chip(id: "e", symbol: "eye", text: minutes <= 0 ? tr("ya") : String(format: tr("%lld min"), minutes),
                            action: { model.startBreakNow() }))
        }
        return out
    }

    private func eventLabel(_ e: EventInfo) -> String {
        let now = Date()
        if e.allDay { return e.title }
        if e.start <= now { return String(format: tr("Ahora: %@"), e.title) }
        let minutes = Int(e.start.timeIntervalSince(now) / 60)
        let when = minutes < 60 ? String(format: tr("en %lld min"), max(minutes, 1)) : e.start.formatted(date: .omitted, time: .shortened)
        return "\(e.title) · \(when)"
    }

    private func chip(_ c: Chip) -> some View {
        let content = HStack(spacing: 6) {
            Image(systemName: c.symbol).font(.system(size: 12))
            Text(c.text).font(.system(size: 12, weight: .medium)).lineLimit(1)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.1)))
        return Group {
            if let action = c.action { Button(action: action) { content }.buttonStyle(.plain) } else { content }
        }
    }
}
