// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case fondos, perfiles, sistema, almacenamiento, internet, portapapeles, energia, teclado, notch, barra, general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fondos: return "Fondos"
        case .perfiles: return "Perfiles"
        case .sistema: return "Sistema"
        case .almacenamiento: return "Almacenamiento"
        case .internet: return "Internet"
        case .portapapeles: return "Portapapeles"
        case .energia: return "Energía"
        case .teclado: return "Limpiar teclado"
        case .notch: return "Notch"
        case .barra: return "Barra de menú"
        case .general: return "General"
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
        case .teclado: return "keyboard"
        case .notch: return "rectangle.topthird.inset.filled"
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
                    case .teclado: TecladoPage()
                    case .notch: NotchPage()
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
