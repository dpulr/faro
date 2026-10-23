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
    var notchSize: CGSize
    var hasHardwareNotch: Bool

    private let spring = Animation.spring(response: 0.4, dampingFraction: 0.82)

    var body: some View {
        ZStack(alignment: .top) {
            if model.expanded {
                expandedBody
                    .frame(width: 470)
                    .background(NotchShape(radius: 32).fill(Color.black))
                    .background(GeometryReader { Color.clear.preference(key: HeightKey.self, value: $0.size.height) })
                    .transition(.opacity)
            } else if model.hasLive {
                wings
                    .frame(width: notchSize.width + 104, height: notchSize.height)
                    .background(NotchShape(radius: 14).fill(Color.black))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(spring, value: model.expanded)
        .animation(spring, value: model.hasLive)
        .onPreferenceChange(HeightKey.self) { if $0 > 0 { model.expandedHeight = $0 } }
        .environment(\.colorScheme, .dark)
    }

    // MARK: Alas (colapsado con algo en vivo)

    private var wings: some View {
        HStack(spacing: 0) {
            Group {
                if model.breakRemaining != nil {
                    Image(systemName: "eye").font(.system(size: 14, weight: .medium))
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
                if let remaining = model.breakRemaining {
                    Text("\(remaining)").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                } else {
                    Image(systemName: "waveform").font(.system(size: 14, weight: .medium))
                        .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                }
            }
            .frame(width: 52)
        }
        .foregroundStyle(.white)
    }

    // MARK: Desplegado

    private var expandedBody: some View {
        VStack(spacing: 14) {
            if model.breakRemaining != nil { breakRow }
            else if model.showMusic { musicRow }
            chips
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
                Text(model.track.map { $0.artist.isEmpty ? $0.source : $0.artist } ?? "Abre Música o Spotify")
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

    private func control(_ symbol: String, size: CGFloat = 32, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size > 36 ? 15 : 12, weight: .semibold))
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(size > 36 ? 0.18 : 0.08)))
        }
        .buttonStyle(.plain)
    }

    private var chips: some View {
        let items = chipItems
        return Group {
            if items.isEmpty {
                Text("Activa módulos en faro → Notch").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
            } else {
                HStack(spacing: 8) { ForEach(items, id: \.id) { chip($0) } }
            }
        }
    }

    private struct Chip { var id: String; var symbol: String; var text: String; var action: (() -> Void)? }

    private var chipItems: [Chip] {
        var out: [Chip] = []
        if model.showWeather, let w = model.weather {
            out.append(Chip(id: "w", symbol: w.symbol, text: "\(w.temperature)° \(w.city)", action: nil))
        }
        if model.showCalendar {
            if let e = model.event {
                out.append(Chip(id: "c", symbol: "calendar", text: eventLabel(e), action: nil))
            } else if !model.calendarDenied {
                out.append(Chip(id: "c", symbol: "calendar", text: "Sin eventos", action: nil))
            }
        }
        if model.eyeBreak, model.breakRemaining == nil, let next = model.nextBreak {
            let minutes = max(Int((next.timeIntervalSinceNow / 60).rounded(.up)), 0)
            out.append(Chip(id: "e", symbol: "eye", text: minutes <= 0 ? "Descanso ya" : "Descanso en \(minutes) min",
                            action: { model.startBreakNow() }))
        }
        return out
    }

    private func eventLabel(_ e: EventInfo) -> String {
        let now = Date()
        if e.allDay { return e.title }
        if e.start <= now { return "Ahora: \(e.title)" }
        let minutes = Int(e.start.timeIntervalSince(now) / 60)
        let when = minutes < 60 ? "en \(max(minutes, 1)) min" : e.start.formatted(date: .omitted, time: .shortened)
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
