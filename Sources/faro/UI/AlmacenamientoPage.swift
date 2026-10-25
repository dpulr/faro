// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Charts
import SwiftUI

struct AlmacenamientoPage: View {
    @EnvironmentObject var storage: StorageModel
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var diskAlert: DiskAlert
    @EnvironmentObject var history: DiskHistory

    enum Tab: String, CaseIterable, Identifiable {
        case limpieza = "Limpieza", grandes = "Archivos grandes", carpetas = "Carpetas"
        var id: String { rawValue }
    }

    @State private var tab = Tab.limpieza
    @State private var mode = DeleteMode.trash
    @State private var confirmClean = false
    @State private var pendingFile: CleanItem?
    @State private var confirmSafe = false
    @State private var pendingRecommendation: Recommendation?
    @State private var onlyForgotten = false
    @State private var expanded: Set<String>

    init(expandedInitially: Set<String> = []) {
        _expanded = State(initialValue: expandedInitially)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Almacenamiento",
                       subtitle: "Encuentra qué ocupa espacio y libéralo sin tocar tus documentos.")
            summary
            alertCard
            Segments(selection: $tab, options: Tab.allCases.map { ($0.rawValue, $0) })

            switch tab {
            case .limpieza: cleanup
            case .grandes: large
            case .carpetas: folders
            }
        }
        .task {
            if !storage.didScan { await storage.scan() }
            if !storage.largeScanned { await storage.scanLarge() }   // para detectar lo olvidado
        }
    }

    // MARK: Resumen

    private var summary: some View {
        let tint = Theme.usage(monitor.diskUsedFraction)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Format.bytes(monitor.diskFree)) libres")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("de \(Format.bytes(monitor.diskTotal))").foregroundStyle(.secondary)
                    Spacer()
                    Text(monitor.health.level == .ok ? tr("Espacio saludable") : monitor.health.title)
                        .font(.callout.weight(.medium)).foregroundStyle(tint)
                }
                UsageBar(value: monitor.diskUsedFraction, tint: tint)
                forecastView
            }
        }
    }

    /// Cuánto tardará en llenarse según los últimos días (y la gráfica del espacio usado).
    @ViewBuilder private var forecastView: some View {
        let forecast = history.forecast(free: monitor.diskFree)
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: forecast?.trend == .growing ? "chart.line.uptrend.xyaxis" : "chart.line.flattrend.xyaxis")
                .foregroundStyle(forecast?.trend == .growing && (forecast?.daysLeft ?? 999) <= 30 ? Theme.warning : Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(forecastTitle(forecast)).font(.callout.weight(.medium))
                Text(forecastDetail(forecast)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            if history.samples.count >= 3 {
                Chart(history.samples.suffix(30)) { sample in
                    LineMark(x: .value("Día", sample.day), y: .value("Usado", Double(sample.used) / 1e9)).foregroundStyle(Theme.accent)
                    AreaMark(x: .value("Día", sample.day), y: .value("Usado", Double(sample.used) / 1e9)).foregroundStyle(Theme.accent.opacity(0.15))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis(.hidden).chartYAxis(.hidden)
                .frame(width: 160, height: 44)
            }
        }
        .padding(.top, 4)
    }

    private func forecastTitle(_ forecast: DiskHistory.Forecast?) -> String {
        guard let forecast else { return tr("Todavía no hay suficientes datos para predecir") }
        switch forecast.trend {
        case .growing: return String(format: tr("A este ritmo se llenará en unos %lld días"), forecast.daysLeft ?? 999)
        case .stable: return tr("Tu espacio está estable")
        case .shrinking: return tr("Tu espacio libre está aumentando")
        }
    }

    private func forecastDetail(_ forecast: DiskHistory.Forecast?) -> String {
        guard let forecast else { return tr("faro anota el espacio libre cada día; la predicción aparece en cuanto haya tres días.") }
        let rate = Format.bytes(abs(forecast.bytesPerDay))
        switch forecast.trend {
        case .growing: return String(format: tr("Ocupas unos %@ más cada día (últimos %lld días)."), rate, forecast.sampleDays)
        case .stable: return String(format: tr("Casi no cambia en los últimos %lld días."), forecast.sampleDays)
        case .shrinking: return String(format: tr("Liberas unos %@ al día (últimos %lld días)."), rate, forecast.sampleDays)
        }
    }

    // MARK: Aviso de poco espacio

    private var alertCard: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avisarme cuando quede poco espacio").font(.callout.weight(.medium))
                        Text("Una notificación y una señal en el notch, para no llegar otra vez a quedarte sin disco.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if diskAlert.enabled {
                        Choice(selection: $diskAlert.thresholdGB,
                               options: [5, 10, 20, 50, 100].map { (String(format: tr("Menos de %d GB"), $0), $0) })
                    }
                    Toggle("", isOn: $diskAlert.enabled).toggleStyle(MiniSwitchStyle()).labelsHidden()
                }
                if diskAlert.enabled && diskAlert.notificationsDenied {
                    HStack(spacing: 8) {
                        Text("Las notificaciones de faro están desactivadas en el sistema.").font(.caption).foregroundStyle(Theme.warning)
                        Button("Abrir ajustes") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { NSWorkspace.shared.open(url) }
                        }
                        .buttonStyle(.link).font(.caption)
                    }
                }
            }
        }
        .onAppear { diskAlert.refreshAuthorization() }
    }

    // MARK: Limpieza

    private var cleanup: some View {
        VStack(spacing: 14) {
            assistantCard
            actionBar
            if let message = storage.message { messageCard(message) }
            if storage.scanning {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Analizando tu Mac… puede tardar un par de minutos la primera vez.")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            ForEach(storage.categories) { category in
                if category.scanned && category.total > 0 { categoryCard(category) }
            }
            if let bytes = storage.simulatorBytes, bytes > 0 { simulatorsCard(bytes) }
            HStack {
                Button("Volver a analizar") { Task { await storage.scan() } }
                    .buttonStyle(.link).disabled(storage.scanning)
                Spacer()
                Button("Vaciar la Papelera") { Task { await storage.emptyTrash() } }
                    .buttonStyle(.link).disabled(storage.working)
            }
            .font(.caption)
        }
    }

    // MARK: Asistente

    private var assistantCard: some View {
        let recommendations = Array(storage.recommendations.prefix(5))
        return Card(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles").font(.system(size: 20)).foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44).background(Circle().fill(Theme.accent.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Asistente de almacenamiento").font(.title3.weight(.semibold))
                        Text(assistantSubtitle).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { confirmSafe = true } label: {
                        if storage.working { ProgressView().controlSize(.small) }
                        else { Text(storage.safeBytes > 0 ? "Limpiar lo seguro · \(Format.bytes(storage.safeBytes))" : "Limpiar lo seguro") }
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .disabled(storage.safeBytes == 0 || storage.working || storage.scanning)
                }
                .padding(16)
                if !recommendations.isEmpty {
                    Divider()
                    ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().padding(.leading, 16) }
                        recommendationRow(item)
                    }
                }
            }
        }
        .confirmationDialog("¿Limpiar \(Format.bytes(storage.safeBytes)) de lo seguro?", isPresented: $confirmSafe, titleVisibility: .visible) {
            Button("Mover a la Papelera") { Task { await storage.cleanSafe() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Son cachés, compilaciones y registros que las apps vuelven a crear. Irán a la Papelera; el espacio se recupera cuando la vacíes.")
        }
        .confirmationDialog(pendingRecommendation.map { "¿\($0.title)?" } ?? "", isPresented: Binding(
            get: { pendingRecommendation != nil }, set: { if !$0 { pendingRecommendation = nil } }),
            titleVisibility: .visible, presenting: pendingRecommendation) { item in
            Button(item.action == .emptyTrash ? "Vaciar la Papelera" : item.action == .simulators ? "Quitar no disponibles" : "Mover a la Papelera",
                   role: item.action == .emptyTrash ? .destructive : nil) { perform(item) }
            Button("Cancelar", role: .cancel) {}
        } message: { item in
            Text(item.action == .emptyTrash ? "Se borrará para siempre lo que hay en la Papelera." : "Liberarás unos \(Format.bytes(item.bytes)).")
        }
    }

    private var assistantSubtitle: String {
        if storage.scanning && !storage.didScan { return tr("Analizando tu Mac…") }
        if storage.safeBytes > 0 { return String(format: tr("Puedes liberar %@ sin riesgo."), Format.bytes(storage.safeBytes)) }
        return storage.recommendations.isEmpty ? tr("Todo en orden: no hay nada que valga la pena limpiar.") : tr("No hay nada seguro que limpiar; revisa estas sugerencias.")
    }

    private func recommendationRow(_ item: Recommendation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol).frame(width: 24).foregroundStyle(item.risk == .safe ? Theme.accent : Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.callout.weight(.semibold))
                Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 12)
            riskBadge(item.risk)
            Text(Format.bytes(item.bytes)).font(.callout.weight(.semibold).monospacedDigit()).frame(width: 84, alignment: .trailing)
            Button(actionLabel(item)) { if needsConfirmation(item) { pendingRecommendation = item } else { perform(item) } }
                .buttonStyle(PillButtonStyle(prominent: item.risk == .safe)).disabled(storage.working)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    private func actionLabel(_ item: Recommendation) -> LocalizedStringKey {
        switch item.action {
        case .cleanCategory: return "Limpiar"
        case .emptyTrash: return "Vaciar"
        case .simulators: return "Quitar"
        case .reviewCategory, .reviewForgotten: return "Revisar"
        }
    }

    private func needsConfirmation(_ item: Recommendation) -> Bool {
        switch item.action {
        case .cleanCategory, .emptyTrash, .simulators: return true
        case .reviewCategory, .reviewForgotten: return false
        }
    }

    private func perform(_ item: Recommendation) {
        switch item.action {
        case .cleanCategory(let id): Task { await storage.clean(categoryID: id) }
        case .emptyTrash: Task { await storage.emptyTrash() }
        case .simulators: Task { await storage.removeUnavailableSimulators() }
        case .reviewCategory(let id): expanded.insert(id)
        case .reviewForgotten: onlyForgotten = true; tab = .grandes
        }
    }

    private var actionBar: some View {
        Card {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(storage.selectedBytes == 0 ? "Nada seleccionado"
                         : "Puedes liberar \(Format.bytes(storage.selectedBytes))")
                        .font(.title3.weight(.semibold))
                    Text(mode == .trash
                         ? "\(storage.selectedCount) elementos marcados · irán a la Papelera, donde puedes recuperarlos"
                         : "\(storage.selectedCount) elementos marcados · se borrarán sin pasar por la Papelera")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Segments(selection: $mode, options: [("Papelera", DeleteMode.trash), ("Eliminar ya", DeleteMode.permanent)])
                Button { confirmClean = true } label: {
                    if storage.working { ProgressView().controlSize(.small) } else { Text("Limpiar") }
                }
                .buttonStyle(PillButtonStyle(prominent: true))
                .disabled(storage.selectedBytes == 0 || storage.working)
            }
        }
        .confirmationDialog("¿Limpiar \(Format.bytes(storage.selectedBytes))?",
                            isPresented: $confirmClean, titleVisibility: .visible) {
            Button(mode == .trash ? "Mover a la Papelera" : "Eliminar para siempre",
                   role: mode == .trash ? nil : .destructive) {
                Task { await storage.cleanSelected(mode: mode) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(mode == .trash
                 ? "Los archivos irán a la Papelera. El espacio se recupera cuando la vacíes."
                 : "Los archivos se borrarán de inmediato y no se podrán recuperar.")
        }
    }

    private func messageCard(_ text: String) -> some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                Text(text).font(.callout)
                Spacer()
                if storage.trashedBytes > 0 {
                    Button("Vaciar Papelera") { Task { await storage.emptyTrash() } }
                        .buttonStyle(PillButtonStyle(prominent: true)).disabled(storage.working)
                }
            }
        }
    }

    private func categoryCard(_ category: CleanCategory) -> some View {
        let open = expanded.contains(category.id)
        return Card(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    checkbox(storage.state(of: category)) { storage.toggle(category: category) }
                    Image(systemName: category.spec.symbol).frame(width: 24).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.spec.title).font(.callout.weight(.semibold))
                        Text(category.spec.detail).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    riskBadge(category.spec.risk)
                    Text(Format.bytes(category.total)).font(.callout.weight(.semibold).monospacedDigit())
                    Button {
                        if open { expanded.remove(category.id) } else { expanded.insert(category.id) }
                    } label: {
                        Image(systemName: open ? "chevron.up" : "chevron.down").frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                .padding(14)

                if open {
                    Divider()
                    VStack(spacing: 0) {
                        ForEach(category.items.prefix(25)) { item in
                            HStack(spacing: 12) {
                                checkbox(storage.selected.contains(item.id) ? .all : .none) { storage.toggle(item: item) }
                                Text(item.name).font(.callout).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                if let date = item.modified {
                                    Text(Format.relative(date)).font(.caption).foregroundStyle(.tertiary)
                                }
                                Text(Format.bytes(item.bytes)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 7)
                        }
                        if category.items.count > 25 {
                            Text("y \(category.items.count - 25) elementos más más pequeños")
                                .font(.caption).foregroundStyle(.secondary).padding(10)
                        }
                    }
                }
            }
        }
    }

    private func simulatorsCard(_ bytes: Int64) -> some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "ipad.and.iphone").frame(width: 24).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Simuladores de iOS").font(.callout.weight(.semibold))
                    Text("Ocupan \(Format.bytes(bytes)). Puedo quitar los que ya no funcionan con tu Xcode.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Quitar no disponibles") { Task { await storage.removeUnavailableSimulators() } }
                    .buttonStyle(PillButtonStyle()).disabled(storage.working)
            }
        }
    }

    // MARK: Archivos grandes

    private func idleText(_ days: Int) -> String {
        if days < 30 { return tr("Usado este mes") }
        if days < 365 { return String(format: tr("Sin tocar hace %lld meses"), days / 30) }
        return String(format: tr("Sin tocar hace %lld años"), days / 365)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Archivos de más de 300 MB").font(.callout.weight(.semibold))
                        Text("Busca en tu carpeta personal, sin contar Xcode ni iCloud. Puede tardar unos minutos.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { Task { await storage.scanLarge() } } label: {
                        if storage.scanningLarge {
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Buscando…") }
                        } else {
                            Text(storage.largeScanned ? "Buscar de nuevo" : "Buscar")
                        }
                    }
                    .buttonStyle(PillButtonStyle(prominent: !storage.largeScanned)).disabled(storage.scanningLarge)
                }
            }
            if let message = storage.message, storage.trashedBytes > 0 { messageCard(message) }
            if storage.largeScanned && storage.largeFiles.isEmpty {
                Text("No hay archivos tan grandes en tu carpeta personal.").foregroundStyle(.secondary)
            }
            if !storage.largeFiles.isEmpty {
                HStack(spacing: 12) {
                    Segments(selection: $onlyForgotten, options: [("Todos", false), ("Olvidados", true)])
                    if onlyForgotten {
                        MenuChip(text: String(format: tr("Más de %lld meses"), storage.forgottenDays / 30)) {
                            ForEach([90, 180, 365], id: \.self) { days in
                                DropdownRow(title: String(format: tr("Más de %lld meses"), days / 30), selected: days == storage.forgottenDays) { storage.forgottenDays = days }
                            }
                        }
                    }
                    Spacer()
                    if onlyForgotten {
                        Text(String(format: tr("%lld archivos · %@"), storage.forgotten.count, Format.bytes(storage.forgotten.reduce(0) { $0 + $1.bytes })))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !storage.largeFiles.isEmpty {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array((onlyForgotten ? storage.forgotten : storage.largeFiles).enumerated()), id: \.element.id) { index, file in
                            if index > 0 { Divider() }
                            HStack(spacing: 12) {
                                Image(systemName: "doc").frame(width: 22).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                                    Text(file.url.deletingLastPathComponent().path
                                        .replacingOccurrences(of: DiskTools.home.path, with: "~"))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                                }
                                Spacer()
                                if let days = file.idleDays() {
                                    Text(idleText(days)).font(.caption)
                                        .foregroundStyle(days >= storage.forgottenDays ? Theme.warning : Color.secondary.opacity(0.7))
                                }
                                Text(Format.bytes(file.bytes)).font(.callout.weight(.semibold).monospacedDigit())
                                    .frame(width: 80, alignment: .trailing)
                                Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: {
                                    Image(systemName: "magnifyingglass")
                                }
                                .buttonStyle(IconButtonStyle()).instantTip("Mostrar en Finder", anchor: .topTrailing)
                                Button { pendingFile = file } label: { Image(systemName: "trash") }
                                    .buttonStyle(IconButtonStyle()).instantTip("Mover a la Papelera", anchor: .topTrailing)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                    }
                }
            }
        }
        .confirmationDialog("¿Mover a la Papelera?", isPresented: Binding(
            get: { pendingFile != nil }, set: { if !$0 { pendingFile = nil } }),
            titleVisibility: .visible, presenting: pendingFile) { file in
            Button("Mover \(file.name)") { Task { await storage.trashLarge(file) } }
            Button("Cancelar", role: .cancel) {}
        } message: { file in
            Text("Son \(Format.bytes(file.bytes)). Seguirá en la Papelera hasta que la vacíes.")
        }
    }

    // MARK: Carpetas

    private var folders: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !storage.folderLoaded {
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Explorar tu carpeta personal").font(.callout.weight(.semibold))
                            Text("Mide cada carpeta y te deja entrar en ellas para ver qué pesa más.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Analizar") { Task { await storage.openFolder(DiskTools.home) } }
                            .buttonStyle(PillButtonStyle(prominent: true))
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button { Task { await storage.goUp() } } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(IconButtonStyle()).instantTip("Subir una carpeta", anchor: .topLeading)
                        .disabled(storage.path.path == DiskTools.home.path || storage.browsing)
                    Text(storage.path.path.replacingOccurrences(of: DiskTools.home.path, with: "~"))
                        .font(.callout.weight(.medium)).lineLimit(1).truncationMode(.head)
                    Spacer()
                    if storage.browsing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(Format.bytes(storage.folderTotal)).font(.callout.weight(.semibold).monospacedDigit())
                    }
                    Button { NSWorkspace.shared.activateFileViewerSelecting([storage.path]) } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(IconButtonStyle()).instantTip("Mostrar en Finder", anchor: .topTrailing)
                }
                let top = max(storage.folderEntries.first?.bytes ?? 1, 1)
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(storage.folderEntries.prefix(60).enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Divider() }
                            Button {
                                if entry.isDirectory { Task { await storage.openFolder(entry.url) } }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                                        .frame(width: 22).foregroundStyle(entry.isDirectory ? Theme.accent : .secondary)
                                    Text(entry.url.lastPathComponent).font(.callout).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    UsageBar(value: Double(entry.bytes) / Double(top), tint: Theme.accent)
                                        .frame(width: 150)
                                    Text(Format.bytes(entry.bytes)).font(.callout.monospacedDigit())
                                        .frame(width: 80, alignment: .trailing)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                        .opacity(entry.isDirectory ? 1 : 0)
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 14).padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .opacity(storage.browsing ? 0.5 : 1)
            }
        }
    }

    // MARK: Componentes

    private func checkbox(_ state: CheckState, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: state == .all ? "checkmark.circle.fill" : state == .some ? "minus.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(state == .none ? Color.secondary : Theme.accent)
        }
        .buttonStyle(.plain)
    }

    private func riskBadge(_ risk: Risk) -> some View {
        Text(risk == .safe ? "Seguro" : "Revisa antes")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(risk == .safe ? Theme.accent : Theme.warning)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill((risk == .safe ? Theme.accent : Theme.warning).opacity(0.15)))
    }
}
