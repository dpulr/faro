// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI
import ServiceManagement

struct GeneralPage: View {
    @EnvironmentObject var engine: WallpaperEngine
    @EnvironmentObject var appearance: Appearance
    @EnvironmentObject var updates: UpdateChecker
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let shortcuts: [(String, String)] = [
        ("Siguiente foto", "⌃⌥⌘ →"), ("Foto anterior", "⌃⌥⌘ ←"),
        ("Ocultar esta foto", "⌃⌥⌘ H"), ("Guardar esta foto", "⌃⌥⌘ S"),
        ("Centro de comandos", "⌃⌥⌘ F"),
        ("Historial del portapapeles", "⌃⌥⌘ V"), ("Bandeja de archivos", "⌃⌥⌘ B"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "General", subtitle: "Preferencias de faro.")

            appearanceCard

            Card(padding: 4) {
                VStack(spacing: 0) {
                    setting("Abrir al iniciar sesión", "faro arranca solo con tu Mac.") {
                        Toggle("", isOn: Binding(get: { launchAtLogin }, set: setLaunch))
                            .toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    setting("Idioma", "Cambia al instante; faro se reinicia para aplicarlo.") {
                        MenuChip(text: AppLanguage.current.title) {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                DropdownRow(title: language.title, selected: language == AppLanguage.current) {
                                    guard language != AppLanguage.current else { return }
                                    AppLanguage.apply(language)
                                    AppController.shared.relaunch()
                                }
                            }
                        }
                    }
                    Divider().padding(.horizontal, 12)
                    setting("Un fondo distinto por monitor", "Si tienes varias pantallas, cada una muestra una foto diferente.") {
                        Toggle("", isOn: $engine.state.differentPerScreen).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    setting("Calidad mínima de las fotos", "Descarta imágenes más pequeñas que tu pantalla.") {
                        Segments(selection: $engine.state.minResolution, options: [("Flexible", 0.8), ("Alta", 0.95), ("Exacta", 1.0)])
                    }
                }
            }

            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Espacio usado por faro").font(.callout.weight(.medium))
                        Text("Solo guarda la foto actual de cada monitor. Lo demás se descarga y se borra.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Format.bytes(engine.cacheBytes)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    Button("Vaciar") { engine.clearCache() }.buttonStyle(PillButtonStyle())
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Atajos de teclado").font(.callout.weight(.semibold))
                    ForEach(shortcuts, id: \.0) { s in
                        HStack {
                            Text(s.0)
                            Spacer()
                            Text(s.1).font(.callout.monospaced()).foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.stroke))
                        }
                        .font(.callout)
                    }
                }
            }

            updatesCard

            aboutCard
        }
    }

    /// Aviso legal visible en la app: el AGPL-3.0 lo pide a los programas con interfaz (sección 5d).
    private var aboutCard: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    FaroLogo(style: .color, ring: true).frame(width: 26, height: 26)
                    Text("faro \(version)").font(.callout.weight(.semibold))
                }
                Text("Software libre: puedes usarlo, estudiarlo, modificarlo y compartirlo bajo los términos de la licencia GNU Affero General Public License, versión 3 o posterior. Se ofrece sin ninguna garantía.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("Ver la licencia") { open("https://github.com/dpulr/faro/blob/main/LICENSE") }.buttonStyle(PillButtonStyle())
                    Button("Código fuente") { open("https://github.com/dpulr/faro") }.buttonStyle(PillButtonStyle())
                }
            }
        }
    }

    /// Versión actual, búsqueda manual y aviso automático de versiones nuevas.
    private var updatesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(updateTitle).font(.callout.weight(.medium))
                        Text(updateDetail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if case .available(let release) = updates.state {
                        Button("Descargar") { NSWorkspace.shared.open(release.url) }.buttonStyle(PillButtonStyle())
                    } else {
                        Button(updates.state == .checking ? "Buscando…" : "Buscar ahora") { Task { await updates.check(manual: true) } }
                            .buttonStyle(PillButtonStyle(prominent: false)).disabled(updates.state == .checking)
                    }
                }
                Divider()
                setting("Avisarme de versiones nuevas", "Una consulta al día al sitio de faro; no envía nada tuyo y nunca instala solo.") {
                    Toggle("", isOn: $updates.automatic).toggleStyle(MiniSwitchStyle()).labelsHidden()
                }
            }
        }
    }

    private var updateTitle: String {
        switch updates.state {
        case .available(let release): return String(format: tr("faro %@ está disponible"), release.version)
        case .upToDate: return tr("faro está al día")
        case .failed: return tr("No se pudo buscar")
        default: return String(format: tr("Versión %@"), updates.current)
        }
    }

    private var updateDetail: String {
        switch updates.state {
        case .available(let release): return release.notes.isEmpty ? String(format: tr("Tienes la %@."), updates.current) : release.notes
        case .failed: return tr("Revisa tu conexión e inténtalo de nuevo.")
        case .upToDate: return String(format: tr("Versión %@"), updates.current)
        default:
            guard let last = updates.lastCheck else { return tr("Todavía no se ha buscado.") }
            return String(format: tr("Última búsqueda: %@"), Format.relative(last))
        }
    }

    private func open(_ address: String) {
        if let url = URL(string: address) { NSWorkspace.shared.open(url) }
    }

    private var appearanceCard: some View {
        let accentBinding = Binding<Color>(get: { appearance.accent }, set: { appearance.accentHex = $0.hex })
        let glassBinding = Binding<Color>(get: { appearance.glassTint ?? Theme.accent },
                                          set: { appearance.glassTintHex = $0.hex })
        let windowBinding = Binding<Color>(get: { appearance.windowColor }, set: { appearance.windowColorHex = $0.hex })
        return Card(padding: 4) {
            VStack(spacing: 0) {
                setting("Color de resalte", "Botones, anillos, barras y marcas de selección.") {
                    HStack(spacing: 8) {
                        ForEach(Appearance.presets, id: \.1) { preset in
                            Button { appearance.accentHex = preset.1 } label: {
                                Circle().fill(Color(hex: preset.1) ?? .gray).frame(width: 22, height: 22)
                                    .overlay {
                                        if appearance.accentHex.uppercased() == preset.1 {
                                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain).instantTip(preset.0)
                        }
                        ColorPicker("", selection: accentBinding, supportsOpacity: false).labelsHidden()
                    }
                }
                Divider().padding(.horizontal, 12)
                setting("Color del cristal del menú", "Tiñe el menú de la barra. Sin color, el cristal queda transparente.") {
                    HStack(spacing: 10) {
                        if appearance.glassTint == nil {
                            Text("Sin color").font(.callout).foregroundStyle(.secondary)
                        } else {
                            Button("Quitar") { appearance.glassTintHex = "" }.buttonStyle(PillButtonStyle())
                        }
                        ColorPicker("", selection: glassBinding, supportsOpacity: false).labelsHidden()
                    }
                }
                if appearance.glassTint != nil {
                    Divider().padding(.horizontal, 12)
                    setting("Intensidad del color", "Qué tanto se nota el tinte sobre el cristal.") {
                        Slider(value: $appearance.glassStrength, in: 0.05...0.7).frame(width: 200)
                    }
                }
                Divider().padding(.horizontal, 12)
                setting("Color de fondo de la ventana", "Color fijo de la ventana de faro. Sin elegir, usa el del sistema.") {
                    HStack(spacing: 10) {
                        if appearance.windowColorHex.isEmpty {
                            Text("Del sistema").font(.callout).foregroundStyle(.secondary)
                        } else {
                            Button("Quitar") { appearance.windowColorHex = "" }.buttonStyle(PillButtonStyle())
                        }
                        ColorPicker("", selection: windowBinding, supportsOpacity: false).labelsHidden()
                    }
                }
                Divider().padding(.horizontal, 12)
                setting("Restablecer apariencia", "Vuelve al verde azulado y al cristal sin tinte.") {
                    Button("Restablecer") { appearance.reset() }.buttonStyle(PillButtonStyle())
                }
            }
        }
    }

    private func setting<Control: View>(_ title: LocalizedStringKey, _ detail: LocalizedStringKey,
                                        @ViewBuilder control: () -> Control) -> some View {
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

    private func setLaunch(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
