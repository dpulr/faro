// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

struct AudioPage: View {
    @EnvironmentObject var mixer: AudioMixer

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Audio", subtitle: "El volumen y la salida de tu Mac, a mano.")

            Card {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Salida").font(.callout.weight(.semibold))
                        Spacer()
                        Choice(selection: Binding(get: { mixer.defaultOutput }, set: { mixer.selectOutput($0) }),
                               options: mixer.outputs.map { ($0.name, $0.id) })
                    }
                    HStack(spacing: 14) {
                        Button { mixer.setMuted(!mixer.muted) } label: {
                            Image(systemName: mixer.muted || mixer.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        }
                        .buttonStyle(IconButtonStyle(size: 36, prominent: mixer.muted))
                        .instantTip(mixer.muted ? "Quitar el silencio" : "Silenciar")
                        FaroSlider(value: Binding(get: { mixer.volume }, set: { mixer.setVolume($0) }))
                            .disabled(!mixer.canSetVolume).opacity(mixer.canSetVolume ? 1 : 0.4)
                        Text("\(Int((mixer.volume * 100).rounded()))%").font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    }
                    if !mixer.canSetVolume {
                        Text("Esta salida no deja cambiar el volumen desde el Mac; se controla en el propio dispositivo.")
                            .font(.caption).foregroundStyle(Theme.warning)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Volumen por app").font(.callout.weight(.semibold))
                        Text("Faro detecta las apps que están sonando. Música y Spotify ofrecen volumen propio; las demás siguen el volumen general de macOS.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    appRow("Música", "music.note", value: mixer.musicVolume) { mixer.setAppVolume("Music", $0) }
                    appRow("Spotify", "music.quarternote.3", value: mixer.spotifyVolume) { mixer.setAppVolume("Spotify", $0) }
                    ForEach(inheritedApps) { app in inheritedAppRow(app) }
                    if mixer.musicVolume == nil && mixer.spotifyVolume == nil && inheritedApps.isEmpty {
                        Text("Reproduce audio en una aplicación para verla aquí.").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .onAppear { mixer.refresh(); mixer.refreshApps() }
    }

    @ViewBuilder
    private func appRow(_ name: String, _ symbol: String, value: Double?, set: @escaping (Double) -> Void) -> some View {
        if let value {
            HStack(spacing: 14) {
                Image(systemName: symbol).frame(width: 24).foregroundStyle(.secondary)
                Text(LocalizedStringKey(name)).font(.callout).frame(width: 70, alignment: .leading)
                FaroSlider(value: Binding(get: { value }, set: set))
                Text("\(Int((value * 100).rounded()))%").font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            }
        }
    }

    private var inheritedApps: [AudioProcessApp] {
        mixer.activeOutputApps.filter { app in
            if app.bundleID == "com.apple.Music" { return mixer.musicVolume == nil }
            if app.bundleID == "com.spotify.client" { return mixer.spotifyVolume == nil }
            return true
        }
    }

    private func inheritedAppRow(_ app: AudioProcessApp) -> some View {
        HStack(spacing: 14) {
            Group {
                if let icon = app.icon { Image(nsImage: icon).resizable().scaledToFit() }
                else { Image(systemName: "speaker.wave.2") }
            }
            .frame(width: 24, height: 24)
            Text(app.name).font(.callout).lineLimit(1).frame(width: 130, alignment: .leading)
            Spacer()
            Label("Volumen general", systemImage: "link")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Color.primary.opacity(0.055)))
        }
        .instantTip("macOS no ofrece un control de volumen independiente para esta aplicación.")
    }
}
