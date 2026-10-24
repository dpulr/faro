// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

/// Página propia de la mascota: apariencia, pruebas de reacciones y cuándo se duerme.
struct MascotaPage: View {
    @EnvironmentObject var notch: NotchModel
    @State private var previewMood: MascotMood = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Mascota", subtitle: "Un personaje que vive en el notch y reacciona a lo que pasa.")
            mascotCard
        }
    }

    private func toggle(_ isOn: Binding<Bool>) -> some View {
        Toggle("", isOn: isOn).toggleStyle(MiniSwitchStyle()).labelsHidden()
    }

    private func row<Control: View>(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(12)
    }

    private var mascotCard: some View {
        let mascot = notch.mascot
        let moods: [(MascotMood, String)] = [(.sleeping, tr("Dormida")), (.idle, tr("Tranquila")), (.dancing, tr("Baila")), (.hearts, tr("Caricia")),
                                             (.bluetooth, tr("Bluetooth")), (.celebrate, tr("Fiesta")), (.sad, tr("Triste"))]
        let swatches = ["#F2B24F", "#6BA5CE", "#4ED7C8", "#FF7A8A", "#9B8CFF", "#7EE08A", "#F5F0E6", "#3A3F4A"]
        return Card(padding: 4) {
            VStack(spacing: 0) {
                row("Mascota", "Un personaje que vive en el notch, te sigue con la mirada y reacciona a lo que pasa. Solo está despierta cuando usas el notch.") {
                    toggle($notch.mascot.enabled)
                }
                if mascot.enabled {
                    Divider().padding(.horizontal, 12)
                    HStack(spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black)
                            MascotView(model: mascot, size: 96, forcedMood: previewMood)
                        }
                        .frame(width: 130, height: 130)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Probar reacciones").font(.callout.weight(.medium))
                            Text("Toca un ánimo para verlo aquí y en la mascota real de tu notch.").font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], alignment: .leading, spacing: 6) {
                                ForEach(moods, id: \.1) { mood, label in
                                    Button { previewMood = mood; notch.mascot.demo(mood) } label: {
                                        Text(label).font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 5)
                                            .background(Capsule().fill(previewMood == mood ? Theme.accent.opacity(0.3) : Theme.fill))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    Divider().padding(.horizontal, 12)
                    row("Personaje", "Elige su forma.") {
                        HStack(spacing: 8) {
                            ForEach(MascotShape.allCases) { shape in
                                Button { notch.mascot.shape = shape } label: {
                                    MascotView(model: mascot, size: 38, forcedMood: .idle, shape: shape)
                                        .padding(5).background(RoundedRectangle(cornerRadius: 12).fill(mascot.shape == shape ? Theme.accent.opacity(0.28) : Theme.fill))
                                }.buttonStyle(.plain).instantTip(shape.title)
                            }
                        }
                    }
                    Divider().padding(.horizontal, 12)
                    row("Color", "El color principal del cuerpo.") {
                        HStack(spacing: 7) {
                            ForEach(swatches, id: \.self) { hex in
                                Button { notch.mascot.colorHex = hex } label: {
                                    Circle().fill(Color(hex: hex) ?? .gray).frame(width: 22, height: 22)
                                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: mascot.colorHex.uppercased() == hex ? 2 : 0))
                                }.buttonStyle(.plain)
                            }
                            ColorPicker("", selection: Binding(get: { Color(hex: mascot.colorHex) ?? Theme.accent }, set: { notch.mascot.colorHex = $0.hex }),
                                        supportsOpacity: false).labelsHidden()
                        }
                    }
                    Divider().padding(.horizontal, 12)
                    row("Ojos", "El estilo de sus ojos.") {
                        HStack(spacing: 8) {
                            ForEach(MascotEyes.allCases) { eyes in
                                Button { notch.mascot.eyes = eyes } label: {
                                    MascotView(model: mascot, size: 38, forcedMood: .idle, eyes: eyes)
                                        .padding(5).background(RoundedRectangle(cornerRadius: 12).fill(mascot.eyes == eyes ? Theme.accent.opacity(0.28) : Theme.fill))
                                }.buttonStyle(.plain).instantTip(eyes.title)
                            }
                        }
                    }
                    Divider().padding(.horizontal, 12)
                    row("Accesorio", "Algo para llevar puesto.") {
                        Segments(selection: $notch.mascot.accessory, options: MascotAccessory.allCases.map { ($0.title, $0) })
                    }
                    Divider().padding(.horizontal, 12)
                    row("Cachetes", "Dos mejillas sonrosadas.") { toggle($notch.mascot.blush) }
                    Divider().padding(.horizontal, 12)
                    row("Se duerme tras", "Sin usar el notch, la mascota se duerme y deja de animarse.") {
                        HStack(spacing: 10) {
                            MenuChip(text: String(format: tr("%lld s"), mascot.sleepAfter)) {
                                ForEach([15, 30, 60, 120], id: \.self) { seconds in
                                    DropdownRow(title: String(format: tr("%lld s"), seconds), selected: seconds == mascot.sleepAfter) { notch.mascot.sleepAfter = seconds }
                                }
                            }
                            Button("Restablecer") { notch.mascot.resetAppearance() }.buttonStyle(PillButtonStyle(prominent: false))
                        }
                    }
                }
            }
        }
    }
}
