// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

struct CleanItem: Identifiable, Hashable {
    var url: URL
    var bytes: Int64
    var modified: Date?
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

enum Risk { case safe, review }

struct CategorySpec: Identifiable, Sendable {
    var id: String
    var title: String
    var detail: String
    var symbol: String
    var relativeRoot: String
    var risk: Risk
    var preselect: Bool
    var excludePrefix: String?
    var onlySuffix: String?
    /// Cuántos elementos recientes quedan sin marcar (los más nuevos suelen estar en uso).
    var keepNewest = 0

    init(id: String, title: String, detail: String, symbol: String, relativeRoot: String,
         risk: Risk, preselect: Bool, excludePrefix: String? = nil, onlySuffix: String? = nil, keepNewest: Int = 0) {
        self.id = id; self.title = title; self.detail = detail; self.symbol = symbol
        self.relativeRoot = relativeRoot; self.risk = risk; self.preselect = preselect
        self.excludePrefix = excludePrefix; self.onlySuffix = onlySuffix; self.keepNewest = keepNewest
    }

    var root: URL { DiskTools.home.appendingPathComponent(relativeRoot) }
}

struct CleanCategory: Identifiable {
    var spec: CategorySpec
    var items: [CleanItem] = []
    var scanned = false
    var id: String { spec.id }
    var total: Int64 { items.reduce(0) { $0 + $1.bytes } }
}

enum CleanupCatalog {
    static let specs: [CategorySpec] = [
        CategorySpec(id: "derived", title: tr("Compilaciones de Xcode"),
                     detail: tr("Archivos temporales de tus proyectos. Xcode los vuelve a crear al compilar."),
                     symbol: "hammer", relativeRoot: "Library/Developer/Xcode/DerivedData", risk: .safe, preselect: true),
        CategorySpec(id: "devsupport", title: tr("Símbolos de dispositivos iOS"),
                     detail: tr("Se descargan otra vez al conectar un iPhone o iPad. Los 2 más recientes quedan sin marcar."),
                     symbol: "iphone", relativeRoot: "Library/Developer/Xcode/iOS DeviceSupport",
                     risk: .safe, preselect: true, keepNewest: 2),
        CategorySpec(id: "appcaches", title: tr("Cachés de aplicaciones"),
                     detail: tr("Datos temporales que las apps vuelven a crear solas."),
                     symbol: "square.stack.3d.down.right", relativeRoot: "Library/Caches",
                     risk: .safe, preselect: true, excludePrefix: "com.apple."),
        CategorySpec(id: "logs", title: tr("Registros"),
                     detail: tr("Historial técnico de las apps; no lo necesitas."),
                     symbol: "doc.text", relativeRoot: "Library/Logs", risk: .safe, preselect: true),
        CategorySpec(id: "gradle", title: tr("Dependencias de Gradle"),
                     detail: tr("Se descargan de nuevo al compilar un proyecto Android; la primera vez tardará más."),
                     symbol: "shippingbox", relativeRoot: ".gradle/caches", risk: .safe, preselect: false),
        CategorySpec(id: "npm", title: tr("Caché de npm"),
                     detail: tr("Paquetes descargados; npm los baja otra vez si hacen falta."),
                     symbol: "shippingbox", relativeRoot: ".npm/_cacache", risk: .safe, preselect: false),
        CategorySpec(id: "dotcache", title: tr("Caché de herramientas"),
                     detail: tr("Descargas temporales de herramientas de desarrollo (carpeta .cache)."),
                     symbol: "terminal", relativeRoot: ".cache", risk: .safe, preselect: false),
        CategorySpec(id: "archives", title: tr("Archivos de Xcode"),
                     detail: tr("Versiones empaquetadas de tus apps. Bórralas solo si ya las publicaste."),
                     symbol: "archivebox", relativeRoot: "Library/Developer/Xcode/Archives", risk: .review, preselect: false),
        CategorySpec(id: "avd", title: tr("Emuladores de Android"),
                     detail: tr("Cada uno es un teléfono virtual con sus datos; si lo borras tendrás que crearlo de nuevo."),
                     symbol: "iphone.gen3", relativeRoot: ".android/avd", risk: .review, preselect: false, onlySuffix: ".avd"),
    ]

    static func discover(_ spec: CategorySpec) -> [CleanItem] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        return DiskTools.childSizes(of: spec.root).children.compactMap { child in
            let name = child.url.lastPathComponent
            if name == ".DS_Store" || child.bytes < 100_000 { return nil }
            if let p = spec.excludePrefix, name.hasPrefix(p) { return nil }
            if name == "faro" || name == "co.soyholistico.faro" { return nil } // la caché de esta misma app
            if let s = spec.onlySuffix, !name.hasSuffix(s) { return nil }
            let date = try? child.url.resourceValues(forKeys: keys).contentModificationDate
            return CleanItem(url: child.url, bytes: child.bytes, modified: date)
        }
    }
}

enum DeleteMode: String { case trash, permanent }

/// Solo se puede borrar lo que está dentro de las carpetas del catálogo, o un archivo suelto que el usuario eligió.
enum Safety {
    enum Kind { case catalogItem, userFile }

    private static let protectedTop: Set<String> = [
        "Documents", "Desktop", "Downloads", "Pictures", "Movies", "Music", "Library", "Applications", "Public",
    ]

    static func allows(_ url: URL, kind: Kind) -> Bool {
        let path = url.standardizedFileURL.path
        let home = DiskTools.home.path
        switch kind {
        case .catalogItem:
            return CleanupCatalog.specs.contains { path.hasPrefix($0.root.standardizedFileURL.path + "/") }
        case .userFile:
            guard path.hasPrefix(home + "/") else { return false }
            let first = path.dropFirst(home.count + 1).split(separator: "/").first.map(String.init) ?? ""
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? true
            return !isDir && !(path.dropFirst(home.count + 1).split(separator: "/").count == 1 && protectedTop.contains(first))
        }
    }
}

enum Cleaner {
    /// Devuelve los elementos que sí se pudieron quitar.
    static func remove(_ urls: [URL], mode: DeleteMode, kind: Safety.Kind) -> [URL] {
        let fm = FileManager.default
        var done: [URL] = []
        for url in urls where Safety.allows(url, kind: kind) {
            var targets = [url]
            if url.pathExtension == "avd" { targets.append(url.deletingPathExtension().appendingPathExtension("ini")) }
            var ok = true
            for target in targets where fm.fileExists(atPath: target.path) {
                do {
                    if mode == .trash { try fm.trashItem(at: target, resultingItemURL: nil) }
                    else { try fm.removeItem(at: target) }
                } catch { ok = false }
            }
            if ok { done.append(url) }
        }
        return done
    }
}
