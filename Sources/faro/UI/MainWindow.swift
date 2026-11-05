// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case modulos, fondos, perfiles, sistema, diagnostico, almacenamiento, internet, portapapeles, energia, audio, teclado, notch, mascota, barra, general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modulos: return tr("Inicio")
        case .fondos: return tr("Fondos")
        case .perfiles: return tr("Escenas")
        case .sistema: return tr("Sistema")
        case .diagnostico: return tr("Diagnóstico")
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
        case .modulos: return "house"
        case .fondos: return "photo.on.rectangle"
        case .perfiles: return "rectangle.3.group"
        case .sistema: return "cpu"
        case .diagnostico: return "stethoscope"
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

/// La barra lateral muestra pocos grupos; dentro de cada uno las páginas van en pestañas.
enum PageGroup: String, CaseIterable, Identifiable {
    case inicio, mac, personalizar, herramientas, ajustes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inicio: return tr("Inicio")
        case .mac: return tr("Mi Mac")
        case .personalizar: return tr("Personalizar")
        case .herramientas: return tr("Herramientas")
        case .ajustes: return tr("Ajustes")
        }
    }

    var symbol: String {
        switch self {
        case .inicio: return "house"
        case .mac: return "stethoscope"
        case .personalizar: return "paintbrush"
        case .herramientas: return "wrench.and.screwdriver"
        case .ajustes: return "gearshape"
        }
    }

    var pages: [Page] {
        switch self {
        case .inicio: return [.modulos]
        case .mac: return [.diagnostico, .sistema, .almacenamiento, .energia, .internet]
        case .personalizar: return [.fondos, .notch, .mascota, .perfiles, .barra]
        case .herramientas: return [.portapapeles, .audio, .teclado]
        case .ajustes: return [.general]
        }
    }

    static func of(_ page: Page) -> PageGroup { allCases.first { $0.pages.contains(page) } ?? .inicio }
}

struct MainWindow: View {
    @AppStorage("page") private var pageRaw = Page.modulos.rawValue

    private var current: Page { Page(rawValue: pageRaw) ?? .modulos }
    private var group: PageGroup { PageGroup.of(current) }

    /// Al pulsar un grupo se vuelve a la última pestaña que se vio en él.
    private func open(_ group: PageGroup) {
        let saved = UserDefaults.standard.string(forKey: "page.\(group.rawValue)").flatMap(Page.init(rawValue:))
        select(saved.flatMap { group.pages.contains($0) ? $0 : nil } ?? group.pages[0])
    }

    private func select(_ page: Page) {
        pageRaw = page.rawValue
        UserDefaults.standard.set(page.rawValue, forKey: "page.\(PageGroup.of(page).rawValue)")
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                if group.pages.count > 1 { tabs }
                Group {
                    switch current {
                    case .modulos: ModulosPage()
                    case .fondos: FondosPage()
                    case .perfiles: PerfilesPage()
                    case .sistema: SistemaPage()
                    case .diagnostico: DiagnosticoPage()
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
            ForEach(PageGroup.allCases) { item in
                Button { open(item) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.symbol).frame(width: 20)
                        Text(item.title)
                        Spacer()
                    }
                    .font(.callout.weight(item == group ? .semibold : .regular))
                    .foregroundStyle(item == group ? Theme.accent : Color.primary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(item == group ? Theme.accent.opacity(0.14) : Color.clear))
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

    /// Pestañas de las páginas del grupo actual.
    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(group.pages) { page in
                    Button { select(page) } label: {
                        Text(page.title)
                            .font(.callout.weight(page == current ? .semibold : .regular))
                            .foregroundStyle(page == current ? Color.white : Color.primary)
                            .padding(.horizontal, 14).frame(height: 32)
                            .background(Capsule().fill(page == current ? Theme.accent : Theme.fill))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
