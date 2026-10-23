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
                        Text("macOS no permite cambiar el volumen de otras apps; Música y Spotify sí tienen el suyo.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    appRow("Música", "music.note", value: mixer.musicVolume) { mixer.setAppVolume("Music", $0) }
                    appRow("Spotify", "music.quarternote.3", value: mixer.spotifyVolume) { mixer.setAppVolume("Spotify", $0) }
                    if mixer.musicVolume == nil && mixer.spotifyVolume == nil {
                        Text("Abre Música o Spotify para ver su volumen aquí.").font(.caption).foregroundStyle(.tertiary)
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
}
