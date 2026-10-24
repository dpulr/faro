// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI
import EventKit
import UniformTypeIdentifiers

struct NotchPage: View {
    @EnvironmentObject var notch: NotchModel
    @EnvironmentObject var extras: NotchExtras
    @EnvironmentObject var engine: WallpaperEngine
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var speed: SpeedTest
    @State private var cityDraft = ""
    @State private var draggedWidget: NotchWidgetKind?
    @State private var draggedTool: NotchToolKind?
    @State private var resizingWidget: NotchWidgetKind?
    @State private var resizeStartColumns = 1
    @State private var resizeProposedColumns: Int?
    @State private var hoveredPreviewWidget: NotchWidgetKind?

    private let breakOptions = [20, 30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(title: "Notch",
                       subtitle: "Un panel que cuelga del notch y se despliega desde arriba al centro de la pantalla.")

            Card {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.topthird.inset.filled").font(.system(size: 22)).foregroundStyle(Theme.accent)
                        .frame(width: 48, height: 48).background(Circle().fill(Theme.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Panel del notch").font(.title3.weight(.semibold))
                        Text(NotchController.shared.summary).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { notch.enabled }, set: {
                        notch.enabled = $0
                        NotchController.shared.apply()
                    })).toggleStyle(MiniSwitchStyle()).labelsHidden()
                }
            }

            compactCard
            personalizationCard
            layoutEditorCard

            Card(padding: 4) {
                VStack(spacing: 0) {
                    row("Cómo se abre", "Al pasar el cursor por el notch, o solo cuando le das un clic.") {
                        Segments(selection: $notch.openOnClick, options: [("Al pasar", false), ("Con un clic", true)])
                    }
                    Divider().padding(.horizontal, 12)
                    row("Música", "Lo que suena en Música o Spotify, con controles. macOS te pide permiso la primera vez.") {
                        Toggle("", isOn: $notch.showMusic).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    if notch.showMusic {
                        Divider().padding(.horizontal, 12)
                        row("Letras sincronizadas", "Elige si se ocultan o si muestran una o dos líneas sincronizadas.") {
                            Segments(selection: $notch.lyricsDisplay,
                                     options: NotchLyricsDisplay.allCases.map { ($0.title, $0) })
                        }
                    }
                    Divider().padding(.horizontal, 12)
                    row("Calendario", notch.calendarDenied
                        ? "Sin permiso: actívalo en Ajustes del Sistema → Privacidad y seguridad → Calendarios."
                        : "Tu próximo evento de las siguientes 24 horas.") {
                        Toggle("", isOn: $notch.showCalendar).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    row("Clima", notch.weatherError.map { LocalizedStringKey($0) } ?? "Temperatura y estado del cielo de tu ciudad (Open-Meteo, gratis).") {
                        HStack(spacing: 10) {
                            if notch.showWeather {
                                TextField("Ciudad", text: $cityDraft)
                                    .textFieldStyle(.roundedBorder).frame(width: 150)
                                    .onSubmit { commitCity() }
                                Button("Probar") { commitCity() }.buttonStyle(PillButtonStyle())
                            }
                            Toggle("", isOn: $notch.showWeather).toggleStyle(MiniSwitchStyle()).labelsHidden()
                        }
                    }
                    Divider().padding(.horizontal, 12)
                    row("Volumen", "Un control del volumen de tu Mac dentro del panel.") {
                        Toggle("", isOn: $notch.showVolume).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    row("Bluetooth", "Un aviso en el notch cuando se conectan tus audífonos, teclado o ratón. macOS pide permiso la primera vez.") {
                        Toggle("", isOn: $notch.showBluetooth).toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                    Divider().padding(.horizontal, 12)
                    row("Descanso visual", "Un aviso para mirar a lo lejos 20 segundos (regla 20-20-20) y descansar los ojos.") {
                        HStack(spacing: 10) {
                            if notch.eyeBreak {
                                Choice(selection: $notch.eyeBreakMinutes, options: breakOptions.map { (String(format: tr("Cada %lld min"), $0), $0) })
                            }
                            Toggle("", isOn: $notch.eyeBreak).toggleStyle(MiniSwitchStyle()).labelsHidden()
                        }
                    }
                }
            }

            toolsCard
            alertsCard
            mascotCard

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cómo se usa").font(.callout.weight(.semibold))
                    tip("cursorarrow.motionlines", notch.openOnClick ? "Haz clic en el notch: el panel se despliega y, al alejar el cursor, se recoge." : "Lleva el cursor al notch: el panel se despliega y, al alejarlo, se recoge.")
                    tip("waveform", "Mientras suena música o corre un descanso, aparecen detalles a los lados del notch sin desplegarlo.")
                    tip("tray.and.arrow.down", "Arrastra un archivo hacia el notch y suéltalo en la zona que aparece: se guarda en la bandeja.")
                    tip("eye", "En el panel, el botón «Descanso» empieza la pausa de 20 segundos cuando tú quieras.")
                }
            }
        }
        .onAppear { cityDraft = notch.city }
    }

    private func toggle(_ isOn: Binding<Bool>) -> some View {
        Toggle("", isOn: isOn).toggleStyle(MiniSwitchStyle()).labelsHidden()
    }

    private var personalizationCard: some View {
        let tint = Binding<Color>(get: { Color(hex: notch.panelTintHex) ?? Theme.accent },
                                  set: { notch.panelTintHex = $0.hex })
        return Card(padding: 4) {
            VStack(spacing: 0) {
                personalizationPreview.padding(16)
                Divider().padding(.horizontal, 12)
                row("Ancho del panel", "Más espacio horizontal sin hacerlo más alto.") {
                    Segments(selection: $notch.panelWidth, options: NotchPanelWidth.allCases.map { ($0.title, $0) })
                }
                Divider().padding(.horizontal, 12)
                row("Densidad", "Reduce o amplía el espacio vertical entre widgets.") {
                    Segments(selection: $notch.panelDensity, options: NotchPanelDensity.allCases.map { ($0.title, $0) })
                }
                Divider().padding(.horizontal, 12)
                row("Estilo", "Negro, teñido, cristal translúcido o liquid crystal.") {
                    MenuChip(text: notch.panelStyle.title) {
                        ForEach(NotchPanelStyle.allCases) { style in
                            DropdownRow(title: style.title, selected: style == notch.panelStyle) { notch.panelStyle = style }
                        }
                    }
                }
                if notch.panelStyle != .black {
                    Divider().padding(.horizontal, 12)
                    row("Color y transparencia", "Personaliza el tono y cuánto deja ver el fondo.") {
                        HStack(spacing: 12) {
                            ColorPicker("", selection: tint, supportsOpacity: false).labelsHidden()
                            Slider(value: $notch.panelOpacity, in: 0.15...1).frame(width: 150)
                            Text("\(Int((notch.panelOpacity * 100).rounded()))%")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 34)
                        }
                    }
                }
                Divider().padding(.horizontal, 12)
                row("Dock de herramientas", "Déjalo en su pestaña o visible al pie de cualquier sección.") {
                    Segments(selection: $notch.dockPlacement,
                             options: NotchDockPlacement.allCases.map { ($0.title, $0) })
                }
                Divider().padding(.horizontal, 12)
                row("Tamaño del dock", "Cambia la altura de los accesos sin afectar los widgets.") {
                    Segments(selection: $notch.dockScale, options: NotchDockScale.allCases.map { ($0.title, $0) })
                }
                Divider().padding(.horizontal, 12)
                row("Indicadores al expandir", "Muestra arriba los mismos iconos y métricas de las alas del notch cerrado.") {
                    toggle($notch.showExpandedStatus)
                }
                Divider().padding(.horizontal, 12)
                row("Iconos en las pestañas", "Muestra u oculta el símbolo que acompaña a Inicio, Sistema y Herramientas.") {
                    toggle($notch.showTabIcons)
                }
                Divider().padding(.horizontal, 12)
                row("Fondo de Estado del Mac", "Usa tarjetas sutiles o deja cada métrica integrada con el fondo del notch.") {
                    toggle($notch.showSystemItemBackgrounds)
                }
                Divider().padding(.horizontal, 12)
                row("Tamaño de Estado del Mac", "Reduce iconos, valores, separaciones y altura de cada métrica.") {
                    Segments(selection: $notch.systemMetricScale,
                             options: NotchSystemMetricScale.allCases.map { ($0.title, $0) })
                }
                Divider().padding(.horizontal, 12)
                row("Descripciones del sistema", "Muestra u oculta la explicación debajo del valor de cada métrica.") {
                    toggle($notch.showSystemDescriptions)
                }
                Divider().padding(.horizontal, 12)
                row("Título Estado del Mac", "Permite omitir el encabezado para ahorrar todavía más altura.") {
                    toggle($notch.showSystemTitle)
                }
                Divider().padding(.horizontal, 12)
                row("Título de herramientas", "Muestra u oculta el encabezado del dock de herramientas.") {
                    toggle($notch.showToolsTitle)
                }
                Divider().padding(.horizontal, 12)
                row("Ancho del notch cerrado", "Automático usa solo el espacio que necesitan los iconos; Amplio conserva alas largas.") {
                    Segments(selection: $notch.collapsedWidthMode,
                             options: NotchCollapsedWidthMode.allCases.map { ($0.title, $0) })
                }
                Divider().padding(.horizontal, 12)
                row("Forma de las herramientas", "Elige botones rectangulares, circulares o completamente transparentes.") {
                    Segments(selection: $notch.toolButtonStyle,
                             options: NotchToolButtonStyle.allCases.map { ($0.title, $0) })
                }
            }
        }
    }

    private var personalizationPreview: some View {
        let baseWidth: CGFloat = switch notch.panelWidth { case .compact: 360; case .balanced: 440; case .wide: 560 }
        let height: CGFloat = switch notch.panelDensity { case .tight: 105; case .balanced: 128; case .roomy: 150 }
        return VStack(spacing: 8) {
            Text("Vista previa").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            VStack(spacing: 7) {
                HStack {
                    Label("Inicio", systemImage: "sparkles").font(.system(size: 9, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 9))
                }
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.09)).frame(maxWidth: .infinity)
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)).frame(width: baseWidth * 0.3)
                }
            }
            .foregroundStyle(.white.opacity(0.8)).padding(12)
            .frame(width: baseWidth, height: height)
            .background(previewFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12)))
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: notch.panelWidth)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: notch.panelDensity)
        }
        .frame(maxWidth: .infinity)
    }

    private var previewFill: AnyShapeStyle {
        let tint = Color(hex: notch.panelTintHex) ?? Theme.accent
        switch notch.panelStyle {
        case .black: return AnyShapeStyle(Color.black)
        case .tinted: return AnyShapeStyle(LinearGradient(colors: [tint.opacity(notch.panelOpacity), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .glass: return AnyShapeStyle(.ultraThinMaterial)
        case .liquid: return AnyShapeStyle(LinearGradient(colors: [tint.opacity(notch.panelOpacity), Color(red: 0.08, green: 0.12, blue: 0.16), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var layoutEditorCard: some View {
        Card(padding: 4) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Organizar el notch").font(.title3.weight(.semibold))
                    Text("Arrastra los widgets para ordenarlos. Usa la manija del borde derecho para darles 1/3, 2/3 o todo el ancho.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.top, 12)

                layoutLivePreview

                HStack {
                    Text("WIDGETS · ARRASTRA PARA ORDENAR")
                        .font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
                    Spacer()
                    Text("El ancho cambia al soltar")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)

                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(Array(editorWidgetRows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(row) { config in
                                widgetEditorTile(config)
                                    .gridCellColumns(config.size.columns)
                            }
                            if row.reduce(0, { $0 + $1.size.columns }) < 3 {
                                Color.clear.frame(height: 1)
                                    .gridCellColumns(3 - row.reduce(0, { $0 + $1.size.columns }))
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)

                widgetDetailsEditor

                Divider().padding(.horizontal, 12)
                VStack(alignment: .leading, spacing: 8) {
                    Text("DOCK · ARRASTRA PARA ORDENAR")
                        .font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
                    HStack(spacing: 7) {
                        ForEach(notch.toolLayout) { config in toolEditorTile(config) }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
    }

    private var widgetDetailsEditor: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 12)
            row("Saludo personalizado", "Escribe un mensaje, añade un emoji y decide si también aparece junto a las pestañas.") {
                HStack(spacing: 8) {
                    TextField("👋", text: $notch.greetingEmoji).frame(width: 42)
                    TextField("Hola Daniel", text: $notch.greetingText).frame(width: 170)
                    Toggle("En encabezado", isOn: $notch.showGreetingInHeader).toggleStyle(.checkbox)
                }
            }
            Divider().padding(.horizontal, 12)
            row("Controles visibles", "Elige cuáles aparecen dentro del widget de controles del sistema.") {
                HStack(spacing: 12) {
                    Toggle("Volumen", isOn: $notch.showVolumeControl).toggleStyle(.checkbox)
                    Toggle("Pantalla", isOn: $notch.showDisplayControl).toggleStyle(.checkbox)
                    Toggle("Teclado", isOn: $notch.showKeyboardControl).toggleStyle(.checkbox)
                }
            }
            Divider().padding(.horizontal, 12)
            row("Contenido del calendario", "Muestra el próximo evento o una vista del mes que abre Calendario al seleccionarla.") {
                Segments(selection: Binding(get: { notch.calendarStyle }, set: { style in
                    notch.calendarStyle = style
                    if style == .month, let index = notch.widgetLayout.firstIndex(where: { $0.kind == .calendar }) {
                        notch.widgetLayout[index].height = .double
                    }
                }), options: NotchCalendarStyle.allCases.map { ($0.title, $0) })
            }
        }
    }

    private var layoutLivePreview: some View {
        let width: CGFloat = switch notch.panelWidth { case .compact: 440; case .balanced: 520; case .wide: 620 }
        return VStack(spacing: 7) {
            if notch.showExpandedStatus {
                HStack(spacing: 7) {
                    Image(systemName: "doc.on.clipboard")
                    Image(systemName: "cpu")
                    Text("18%").monospacedDigit()
                    Spacer()
                    Image(systemName: "battery.75percent")
                    Text("74%").monospacedDigit()
                    Image(systemName: "tray.and.arrow.down")
                }
                .font(.system(size: 8, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 9).frame(height: 24)
                .background(Capsule().fill(Color.white.opacity(0.055)))
            }
            HStack(spacing: 5) {
                previewTab("Inicio", "sparkles", selected: true)
                previewTab("Sistema", "gauge.with.dots.needle.50percent", selected: false)
                previewTab("Herramientas", "square.grid.2x2", selected: false)
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 8, weight: .semibold)).frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            NotchMatrixLayout(rowHeight: 44, spacing: 6) {
                ForEach(previewVisibleConfigs) { config in
                    previewWidget(config)
                        .overlay(alignment: .bottomTrailing) {
                            if hoveredPreviewWidget == config.kind || resizingWidget == config.kind {
                                previewResizeHandle(config)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if (config.kind == .music || config.kind == .calendar), hoveredPreviewWidget == config.kind {
                                Button {
                                    if let index = notch.widgetLayout.firstIndex(where: { $0.kind == config.kind }) {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                            notch.widgetLayout[index].height = config.height == .single ? .double : .single
                                        }
                                    }
                                } label: {
                                    Image(systemName: "arrow.up.and.down")
                                        .font(.system(size: 7, weight: .bold)).frame(width: 18, height: 18)
                                        .background(Circle().fill(Color.white.opacity(0.14)))
                                }
                                .buttonStyle(.plain).padding(4).help(tr("Cambiar entre una y dos filas"))
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(draggedWidget == config.kind ? Theme.accent : .clear, lineWidth: 1.5))
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onHover { inside in hoveredPreviewWidget = inside ? config.kind : nil }
                        .onDrag {
                            draggedWidget = config.kind
                            return NSItemProvider(object: config.kind.rawValue as NSString)
                        }
                        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
                            moveDraggedWidget(before: config.kind); return true
                        }
                        .notchMatrixSpan(columns: config.size.columns, rows: config.height == .double ? 2 : 1)
                }
            }
            previewTools
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(width: width)
        .background(previewFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12)))
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: notch.widgetLayout)
    }

    private func previewTab(_ title: String, _ symbol: String, selected: Bool) -> some View {
        HStack(spacing: 4) {
            if notch.showTabIcons { Image(systemName: symbol) }
            Text(LocalizedStringKey(title))
        }
        .font(.system(size: 8, weight: .medium))
        .foregroundStyle(.white.opacity(selected ? 1 : 0.48))
        .padding(.horizontal, 8).frame(height: 24)
        .background(Capsule().fill(Color.white.opacity(selected ? 0.11 : 0)))
    }

    private var previewVisibleConfigs: [NotchWidgetConfig] {
        notch.widgetLayout.filter { config in
            guard config.enabled else { return false }
            if config.kind == .volume { return notch.showVolumeControl || notch.showDisplayControl || notch.showKeyboardControl }
            if config.kind == .greeting {
                return !notch.greetingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !notch.greetingEmoji.isEmpty
            }
            return true
        }
    }

    @ViewBuilder private func previewWidget(_ config: NotchWidgetConfig) -> some View {
        Group {
            switch config.kind {
            case .greeting:
                HStack(spacing: 6) {
                    Text(notch.greetingEmoji).font(.system(size: 14))
                    Text(notch.greetingText).font(.system(size: 10, weight: .semibold)).lineLimit(2)
                    Spacer(minLength: 0)
                }
            case .volume:
                HStack(spacing: 5) {
                    ForEach(previewControlSymbols, id: \.self) { symbol in
                        VStack(spacing: 4) {
                            Image(systemName: symbol).font(.system(size: 8))
                            Capsule().fill(Color.white.opacity(0.2)).frame(height: 3)
                        }.frame(maxWidth: .infinity)
                    }
                }.frame(height: 38)
            case .music:
                previewMusic
            case .weather:
                previewInfo(symbol: "cloud.fill", title: "19°", detail: tr("Nublado"), background: false)
            case .calendar:
                previewInfo(symbol: "calendar", title: notch.calendarStyle == .month ? tr("Mes completo") : tr("Sin eventos"),
                            detail: notch.calendarStyle == .month ? Date().formatted(.dateTime.month(.wide)) : tr("En las próximas 24 horas"), background: false)
            case .timer:
                previewInfo(symbol: "timer", title: "25:00", detail: tr("Enfoque"), background: false)
            case .devices:
                previewInfo(symbol: "airpods", title: "AirPods", detail: "82%", background: false)
            case .eyeBreak:
                previewInfo(symbol: "eye", title: tr("Próxima pausa"), detail: tr("En 12 min"), background: false)
            case .storage:
                previewInfo(symbol: "internaldrive", title: "128 GB", detail: tr("Espacio libre"), background: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(config.showsBackground ? 0.055 : 0)))
    }

    private var previewControlSymbols: [String] {
        var symbols: [String] = []
        if notch.showVolumeControl { symbols.append("speaker.wave.2.fill") }
        if notch.showDisplayControl { symbols.append("sun.max.fill") }
        if notch.showKeyboardControl { symbols.append("light.beacon.max.fill") }
        return symbols
    }

    private var previewMusic: some View {
        HStack(spacing: 7) {
            Image(systemName: "music.note").font(.system(size: 13)).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("Nada sonando").font(.system(size: 10, weight: .semibold)).lineLimit(1)
                if notch.lyricsDisplay == .hidden {
                    Text("Abre Música o Spotify").font(.system(size: 7)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                } else {
                    Text("Una letra sincronizada…").font(.system(size: 6.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68)).lineLimit(1)
                    if notch.lyricsDisplay == .twoLines {
                        Text("La siguiente línea…").font(.system(size: 6)).foregroundStyle(.white.opacity(0.35)).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }

    private func previewResizeHandle(_ config: NotchWidgetConfig) -> some View {
        HStack(spacing: 3) {
            Text("\(resizingWidget == config.kind ? (resizeProposedColumns ?? config.size.columns) : config.size.columns)/3")
                .font(.system(size: 7, weight: .bold, design: .rounded)).monospacedDigit()
            Image(systemName: "arrow.left.and.right").font(.system(size: 7, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6).frame(height: 18)
        .background(Capsule().fill(Theme.accent.opacity(0.9)))
        .contentShape(Capsule())
        .padding(4)
        .gesture(resizeGesture(for: config.kind, threshold: 45))
        .help(tr("Arrastra para cambiar el ancho"))
    }

    private func previewInfo(symbol: String, title: String, detail: String, background: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 13)).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                Text(detail).font(.system(size: 7)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).frame(height: 42)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(background ? 0.055 : 0)))
    }

    private var previewTools: some View {
        VStack(alignment: .leading, spacing: notch.showToolsTitle ? 4 : 0) {
            if notch.showToolsTitle {
                Text("Herramientas")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            HStack(spacing: 4) {
                ForEach(notch.toolLayout.filter(\.enabled)) { config in
                    VStack(spacing: 3) {
                        Image(systemName: toolSymbol(config.kind)).font(.system(size: 9, weight: .medium))
                        Text(config.kind.title).font(.system(size: 6)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity).frame(height: 32)
                    .background { previewToolBackground }
                    .contentShape(Rectangle())
                    .onDrag {
                        draggedTool = config.kind
                        return NSItemProvider(object: config.kind.rawValue as NSString)
                    }
                    .onDrop(of: [UTType.text], isTargeted: nil) { _ in
                        moveDraggedTool(before: config.kind); return true
                    }
                }
            }
        }
    }

    @ViewBuilder private var previewToolBackground: some View {
        switch notch.toolButtonStyle {
        case .rounded: RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.055))
        case .circle: Circle().fill(Color.white.opacity(0.055)).frame(width: 32, height: 32)
        case .plain: Color.clear
        }
    }

    private var editorWidgetRows: [[NotchWidgetConfig]] {
        var rows: [[NotchWidgetConfig]] = [], row: [NotchWidgetConfig] = []
        var used = 0
        for config in notch.widgetLayout {
            if used + config.size.columns > 3, !row.isEmpty { rows.append(row); row = []; used = 0 }
            row.append(config); used += config.size.columns
            if used == 3 { rows.append(row); row = []; used = 0 }
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    private func widgetEditorTile(_ config: NotchWidgetConfig) -> some View {
        let index = notch.widgetLayout.firstIndex(where: { $0.kind == config.kind }) ?? 0
        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").font(.caption).foregroundStyle(.secondary)
            Image(systemName: config.kind.symbol).frame(width: 20).foregroundStyle(config.enabled ? Theme.accent : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(config.kind.title).font(.callout.weight(.medium)).lineLimit(1)
                Text(config.size.title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button { notch.widgetLayout[index].enabled.toggle() } label: {
                Image(systemName: config.enabled ? "eye.fill" : "eye.slash")
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain).help(config.enabled ? tr("Ocultar widget") : tr("Mostrar widget"))
            Button { notch.widgetLayout[index].showsBackground.toggle() } label: {
                Image(systemName: config.showsBackground ? "rectangle.fill" : "rectangle")
                    .frame(width: 22, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(config.showsBackground ? Theme.accent : .secondary)
            .help(config.showsBackground ? tr("Usar fondo transparente") : tr("Mostrar fondo del widget"))
            if config.kind == .music || config.kind == .calendar {
                Menu {
                    ForEach(NotchWidgetHeight.allCases) { height in
                        Button(height.title) { notch.widgetLayout[index].height = height }
                    }
                } label: {
                    Image(systemName: config.height == .double ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                        .frame(width: 22, height: 24)
                }
                .menuStyle(.borderlessButton).fixedSize()
                .help(tr("Altura del widget"))
            }
            VStack(spacing: 2) {
                Text("\(resizingWidget == config.kind ? (resizeProposedColumns ?? config.size.columns) : config.size.columns)/3")
                    .font(.system(size: 8, weight: .semibold, design: .rounded)).monospacedDigit()
                Image(systemName: "arrow.left.and.right").font(.system(size: 9, weight: .semibold))
            }
                .foregroundStyle(Theme.accent)
                .frame(width: 26, height: 42)
                .contentShape(Rectangle())
                .gesture(resizeGesture(for: config.kind))
                .help(tr("Arrastra para cambiar el ancho"))
        }
        .padding(.leading, 12).padding(.trailing, 5).frame(height: 58)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(config.enabled ? Theme.card : Theme.card.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(draggedWidget == config.kind ? Theme.accent : Color.primary.opacity(0.08), lineWidth: 1))
        .opacity(config.enabled ? 1 : 0.55)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDrag {
            draggedWidget = config.kind
            return NSItemProvider(object: config.kind.rawValue as NSString)
        }
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
            moveDraggedWidget(before: config.kind); return true
        }
    }

    private func toolEditorTile(_ config: NotchToolConfig) -> some View {
        let index = notch.toolLayout.firstIndex(where: { $0.kind == config.kind }) ?? 0
        return VStack(spacing: 5) {
            Image(systemName: toolSymbol(config.kind)).font(.system(size: 14, weight: .medium))
            Text(config.kind.title).font(.system(size: 9, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(config.enabled ? Color.primary : Color.secondary)
        .frame(maxWidth: .infinity).frame(height: 52)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card.opacity(config.enabled ? 1 : 0.35)))
        .overlay(alignment: .topTrailing) {
            Button { notch.toolLayout[index].enabled.toggle() } label: {
                Image(systemName: config.enabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10)).frame(width: 20, height: 20)
            }.buttonStyle(.plain).offset(x: 3, y: -3)
        }
        .onDrag {
            draggedTool = config.kind
            return NSItemProvider(object: config.kind.rawValue as NSString)
        }
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
            moveDraggedTool(before: config.kind); return true
        }
    }

    private func resizeGesture(for kind: NotchWidgetKind, threshold: CGFloat = 80) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard let index = notch.widgetLayout.firstIndex(where: { $0.kind == kind }) else { return }
                if resizingWidget != kind {
                    resizingWidget = kind
                    resizeStartColumns = notch.widgetLayout[index].size.columns
                    resizeProposedColumns = resizeStartColumns
                }
                let delta = Int((value.translation.width / threshold).rounded())
                resizeProposedColumns = min(max(resizeStartColumns + delta, 1), 3)
            }
            .onEnded { _ in
                guard let index = notch.widgetLayout.firstIndex(where: { $0.kind == kind }) else {
                    resizingWidget = nil; resizeProposedColumns = nil; return
                }
                let columns = resizeProposedColumns ?? resizeStartColumns
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    notch.widgetLayout[index].size = .columns(columns)
                }
                resizingWidget = nil
                resizeProposedColumns = nil
            }
    }

    private func moveDraggedWidget(before destination: NotchWidgetKind) {
        guard let source = draggedWidget,
              let from = notch.widgetLayout.firstIndex(where: { $0.kind == source }),
              let to = notch.widgetLayout.firstIndex(where: { $0.kind == destination }), from != to else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            let item = notch.widgetLayout.remove(at: from)
            notch.widgetLayout.insert(item, at: from < to ? to - 1 : to)
        }
        draggedWidget = nil
    }

    private func moveDraggedTool(before destination: NotchToolKind) {
        guard let source = draggedTool,
              let from = notch.toolLayout.firstIndex(where: { $0.kind == source }),
              let to = notch.toolLayout.firstIndex(where: { $0.kind == destination }), from != to else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            let item = notch.toolLayout.remove(at: from)
            notch.toolLayout.insert(item, at: from < to ? to - 1 : to)
        }
        draggedTool = nil
    }

    private func toolSymbol(_ kind: NotchToolKind) -> String {
        switch kind {
        case .clipboard: "doc.on.clipboard"; case .shelf: "tray.and.arrow.down"; case .timer: "timer"
        case .microphone: "mic"; case .eyedropper: "eyedropper"; case .emoji: "face.smiling"; case .awake: "cup.and.saucer"
        case .keyboard: "keyboard"; case .settings: "slider.horizontal.3"
        }
    }

    /// Vista previa y selección de lo que permanece visible alrededor del notch.
    private var compactCard: some View {
        Card(padding: 4) {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Vista compacta").font(.callout.weight(.semibold))
                    HStack(spacing: 5) {
                        ForEach(MenuBarMetric.allCases.filter { engine.state.notchMetrics.contains($0) }) { metric in
                            HStack(spacing: 4) {
                                Image(systemName: metric.symbol).font(.system(size: 10, weight: .medium))
                                Text(MetricValue.text(metric, monitor: monitor, speed: speed))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded)).monospacedDigit()
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8).frame(height: 24)
                            .background(Capsule().fill(Color.white.opacity(0.09)))
                        }
                        if engine.state.notchMetrics.isEmpty {
                            Text("Sin datos fijos").font(.caption).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Capsule().fill(Color.black))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)

                Divider().padding(.horizontal, 12)
                row("Botones en las orillas", "Portapapeles y bandeja quedan a un clic cuando no hay una actividad prioritaria.") {
                    toggle($notch.showCompactControls)
                }
                ForEach(MenuBarMetric.allCases) { metric in
                    Divider().padding(.horizontal, 12)
                    row(LocalizedStringKey(metric.title), LocalizedStringKey(metric.detail)) {
                        Toggle("", isOn: Binding(
                            get: { engine.state.notchMetrics.contains(metric) },
                            set: { on in
                                if on { engine.state.notchMetrics.insert(metric) }
                                else { engine.state.notchMetrics.remove(metric) }
                            }))
                            .toggleStyle(MiniSwitchStyle()).labelsHidden()
                    }
                }
            }
        }
    }

    private func minutesChip(_ value: Binding<Int>, _ options: [Int]) -> some View {
        MenuChip(text: String(format: tr("%lld min"), value.wrappedValue)) {
            ForEach(options, id: \.self) { m in
                DropdownRow(title: String(format: tr("%lld min"), m), selected: m == value.wrappedValue) { value.wrappedValue = m }
            }
        }
    }

    /// Botones y módulos que se usan a mano desde el panel desplegado.
    private var toolsCard: some View {
        Card(padding: 4) {
            VStack(spacing: 0) {
                row("Temporizador", "Un Pomodoro (enfoque y descanso) o un temporizador simple. La cuenta se ve con el notch recogido.") {
                    HStack(spacing: 10) {
                        if extras.timer.enabled {
                            Segments(selection: $extras.timer.pomodoro, options: [("Pomodoro", true), ("Simple", false)])
                        }
                        toggle($extras.timer.enabled)
                    }
                }
                if extras.timer.enabled {
                    Divider().padding(.horizontal, 12)
                    row("Duración", extras.timer.pomodoro ? "Cuánto dura el enfoque y cuánto el descanso." : "Cuánto dura el temporizador.") {
                        HStack(spacing: 8) {
                            if extras.timer.pomodoro {
                                minutesChip($extras.timer.focusMinutes, [15, 20, 25, 30, 45, 50, 60])
                                minutesChip($extras.timer.restMinutes, [3, 5, 10, 15])
                            } else {
                                minutesChip($extras.timer.simpleMinutes, [5, 10, 15, 30, 45, 60, 90])
                            }
                        }
                    }
                }
                Divider().padding(.horizontal, 12)
                row("Silenciar el micrófono", extras.mic.available
                    ? "Un botón en el panel (y ⌃⌥⌘M) silencia el micrófono para todas las apps de videollamada."
                    : "El micrófono actual no deja controlar su volumen desde el Mac.") {
                    toggle($extras.mic.enabled)
                }
                Divider().padding(.horizontal, 12)
                row("Gotero de color", "Toma el color de cualquier punto de la pantalla y copia su código.") {
                    toggle($extras.eyedropperEnabled)
                }
                Divider().padding(.horizontal, 12)
                row("Batería de dispositivos", "La carga de tus AirPods (con el estuche), teclado, ratón y trackpad Bluetooth, junto al clima.") {
                    toggle($extras.devices.enabled)
                }
            }
        }
    }

    /// Avisos que salen solos del notch.
    private var alertsCard: some View {
        Card(padding: 4) {
            VStack(spacing: 0) {
                row("Batería llena", "Un aviso cuando la carga llega al nivel que elijas, para desenchufar.") {
                    HStack(spacing: 10) {
                        if extras.battery.fullEnabled {
                            MenuChip(text: "\(extras.battery.fullLevel)%") {
                                ForEach([80, 85, 90, 95, 100], id: \.self) { level in
                                    DropdownRow(title: "\(level)%", selected: level == extras.battery.fullLevel) { extras.battery.fullLevel = level }
                                }
                            }
                        }
                        toggle($extras.battery.fullEnabled)
                    }
                }
                Divider().padding(.horizontal, 12)
                row("Batería baja", "Un aviso cuando queda poca carga (20 y 10 por ciento) y no estás cargando.") { toggle($extras.battery.lowEnabled) }
                Divider().padding(.horizontal, 12)
                row("Descargas terminadas", "Un aviso con botón para mostrar el archivo cuando termina una descarga. macOS pide permiso para ver la carpeta Descargas.") {
                    toggle($extras.downloads.enabled)
                }
                Divider().padding(.horizontal, 12)
                row("Capturas a la bandeja", "Cada captura de pantalla nueva entra sola a la bandeja de archivos. macOS pide permiso para ver la carpeta donde se guardan.") {
                    toggle($extras.screenshots.enabled)
                }
                Divider().padding(.horizontal, 12)
                row("Discos USB", "Un aviso con botón para expulsar al conectar una memoria o un disco.") { toggle($extras.volumes.enabled) }
                Divider().padding(.horizontal, 12)
                row("Cámara y micrófono en uso", "Un punto verde o naranja junto al notch cuando una app los usa.") { toggle($extras.privacyEnabled) }
                Divider().padding(.horizontal, 12)
                row("Bloq Mayús", "Un aviso breve cada vez que lo activas o desactivas.") { toggle($extras.capsEnabled) }
            }
        }
    }

    // MARK: Mascota

    @State private var previewMood: MascotMood = .idle

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

    private func commitCity() {
        notch.city = cityDraft.trimmingCharacters(in: .whitespaces)
        Task { await notch.refreshWeather() }
    }

    private func tip(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 20).foregroundStyle(.secondary)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
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
}
