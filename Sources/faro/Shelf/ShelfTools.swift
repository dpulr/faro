// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Herramientas sin conexión para lo que hay en la bandeja: convertir imágenes y comprimir o descomprimir.
/// El resultado queda en una carpeta de trabajo y entra a la bandeja para arrastrarlo adonde haga falta.
enum ShelfTools {
    enum ImageFormat: String, CaseIterable {
        case png, jpeg, heic, tiff

        var type: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .heic: return .heic
            case .tiff: return .tiff
            }
        }

        var label: String {
            switch self {
            case .png: return "PNG"
            case .jpeg: return "JPEG"
            case .heic: return "HEIC"
            case .tiff: return "TIFF"
            }
        }

        var fileExtension: String { self == .jpeg ? "jpg" : rawValue }
    }

    struct ToolError: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    static var outputDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("faro/shelf-out", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func isImage(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .image) ?? false
    }

    static func isArchive(_ url: URL) -> Bool { url.pathExtension.lowercased() == "zip" }

    /// Un nombre que no pisa a otro archivo de la carpeta de trabajo ("foto.png", "foto 2.png"…).
    static func uniqueURL(base: String, ext: String, in dir: URL = outputDirectory) -> URL {
        let manager = FileManager.default
        var url = dir.appendingPathComponent(base).appendingPathExtension(ext)
        var n = 2
        while manager.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return url
    }

    static func convert(_ url: URL, to format: ImageFormat) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw ToolError(message: tr("No se pudo leer la imagen."))
        }
        let out = uniqueURL(base: url.deletingPathExtension().lastPathComponent, ext: format.fileExtension)
        guard let destination = CGImageDestinationCreateWithURL(out as CFURL, format.type.identifier as CFString, 1, nil) else {
            throw ToolError(message: tr("Este formato no está disponible en tu Mac."))
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ToolError(message: tr("No se pudo guardar la imagen.")) }
        return out
    }

    /// Comprime uno o varios archivos o carpetas en un zip que abre Finder (usa `ditto`).
    static func zip(_ urls: [URL]) throws -> URL {
        guard let first = urls.first else { throw ToolError(message: tr("No hay nada que comprimir.")) }
        let manager = FileManager.default
        let staging = manager.temporaryDirectory.appendingPathComponent("faro-zip-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        let name = urls.count == 1 ? first.deletingPathExtension().lastPathComponent : tr("Archivos")
        let folder = staging.appendingPathComponent(name, isDirectory: true)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        for url in urls { // copias por clonación en APFS: no gastan espacio
            try manager.copyItem(at: url, to: uniqueURL(base: url.deletingPathExtension().lastPathComponent,
                                                         ext: url.pathExtension, in: folder))
        }
        let out = uniqueURL(base: name, ext: "zip")
        try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", folder.path, out.path])
        return out
    }

    /// Descomprime un zip en una carpeta de trabajo y devuelve esa carpeta.
    static func unzip(_ url: URL) throws -> URL {
        let out = uniqueURL(base: url.deletingPathExtension().lastPathComponent, ext: "")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", url.path, out.path])
        return out
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ToolError(message: tr("No se pudo completar la operación.")) }
    }
}

extension ShelfStore {
    /// Ejecuta una herramienta fuera del hilo principal y mete el resultado en la bandeja.
    private func runTool(_ work: @escaping @Sendable () throws -> URL) {
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated, operation: work).value
                add([result])
            } catch {
                NSSound.beep()
            }
        }
    }

    func convert(_ item: ShelfItem, to format: ShelfTools.ImageFormat) {
        guard let url = resolve(item) else { return }
        runTool { try ShelfTools.convert(url, to: format) }
    }

    func zip(_ items: [ShelfItem]) {
        let urls = items.compactMap { resolve($0) }
        guard !urls.isEmpty else { return }
        runTool { try ShelfTools.zip(urls) }
    }

    func unzip(_ item: ShelfItem) {
        guard let url = resolve(item) else { return }
        runTool { try ShelfTools.unzip(url) }
    }
}
