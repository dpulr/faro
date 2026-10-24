// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case fondos, perfiles, sistema, almacenamiento, internet, portapapeles, energia, audio, teclado, notch, mascota, barra, general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fondos: return tr("Fondos")
        case .perfiles: return tr("Perfiles")
        case .sistema: return tr("Sistema")
        case .almacenamiento: return tr("Almacenamiento")
        case .internet: return tr("Internet")
        case .portapapeles: return tr("Portapapeles")
        case .energia: return tr("Energía")
        case .audio: return tr("Audio")
        case .teclado: return tr("Limpiar teclado")
        case .notch: return tr("Notch")
        case .mascota: return tr("Mascota")
        case .barra: return tr("Barra de menú")
        case .general: return tr("General")
        }
    }

    var symbol: String {
        switch self {
        case .fondos: return "photo.on.rectangle"
        case .perfiles: return "person.crop.square"
        case .sistema: return "cpu"
        case .almacenamiento: return "internaldrive"
        case .internet: return "wifi"
        case .portapapeles: return "doc.on.clipboard"
        case .energia: return "cup.and.saucer"
        case .audio: return "speaker.wave.2"
        case .teclado: return "keyboard"
        case .notch: return "rectangle.topthird.inset.filled"
        case .mascota: return "face.smiling"
        case .barra: return "menubar.rectangle"
        case .general: return "gearshape"
        }
    }
}

struct MainWindow: View {
    @AppStorage("page") private var pageRaw = Page.fondos.rawValue

    private var current: Page { Page(rawValue: pageRaw) ?? .fondos }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                Group {
                    switch current {
                    case .fondos: FondosPage()
                    case .perfiles: PerfilesPage()
                    case .sistema: SistemaPage()
                    case .almacenamiento: AlmacenamientoPage()
                    case .internet: InternetPage()
                    case .portapapeles: PortapapelesPage()
                    case .energia: EnergiaPage()
                    case .audio: AudioPage()
                    case .teclado: TecladoPage()
                    case .notch: NotchPage()
                    case .mascota: MascotaPage()
                    case .barra: BarraPage()
                    case .general: GeneralPage()
                    }
                }
                .padding(32)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            wordmark
            ForEach(Page.allCases) { page in
                Button { pageRaw = page.rawValue } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page.symbol).frame(width: 20)
                        Text(page.title)
                        Spacer()
                    }
                    .font(.callout.weight(page == current ? .semibold : .regular))
                    .foregroundStyle(page == current ? Theme.accent : Color.primary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(page == current ? Theme.accent.opacity(0.14) : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(Theme.fillFaint)
    }

    private var wordmark: some View {
        HStack(spacing: 10) {
            FaroLogo(style: .color, ring: false).frame(width: 40, height: 40)
            Text("faro").font(.system(size: 28, weight: .semibold)).tracking(-0.5)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 46)
        .padding(.bottom, 16)
    }
}
