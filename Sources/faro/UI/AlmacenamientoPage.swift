// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

struct AlmacenamientoPage: View {
    @EnvironmentObject var storage: StorageModel
    @EnvironmentObject var monitor: SystemMonitor

    enum Tab: String, CaseIterable, Identifiable {
        case limpieza = "Limpieza", grandes = "Archivos grandes", carpetas = "Carpetas"
        var id: String { rawValue }
    }

    @State private var tab = Tab.limpieza
    @State private var mode = DeleteMode.trash
    @State private var confirmClean = false
    @State private var pendingFile: CleanItem?
    @State private var expanded: Set<String>

    init(expandedInitially: Set<String> = []) {
        _expanded = State(initialValue: expandedInitially)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "Almacenamiento",
                       subtitle: "Encuentra qué ocupa espacio y libéralo sin tocar tus documentos.")
            summary
            Segments(selection: $tab, options: Tab.allCases.map { ($0.rawValue, $0) })

            switch tab {
            case .limpieza: cleanup
            case .grandes: large
            case .carpetas: folders
            }
        }
        .task { if !storage.didScan { await storage.scan() } }
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
                    Text(monitor.health.level == .ok ? "Espacio saludable" : monitor.health.title)
                        .font(.callout.weight(.medium)).foregroundStyle(tint)
                }
                UsageBar(value: monitor.diskUsedFraction, tint: tint)
            }
        }
    }

    // MARK: Limpieza

    private var cleanup: some View {
        VStack(spacing: 14) {
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
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(storage.largeFiles.enumerated()), id: \.element.id) { index, file in
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
                                if let date = file.modified {
                                    Text(Format.relative(date)).font(.caption).foregroundStyle(.tertiary)
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
