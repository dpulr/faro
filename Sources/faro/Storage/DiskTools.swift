// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import Foundation

enum DiskTools {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    /// Ejecuta una herramienta del sistema y devuelve su salida estándar (los errores se descartan).
    static func run(_ path: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    /// Tamaño en disco de cada hijo directo (carpetas con `du`, archivos sueltos leídos aparte) y el total.
    static func childSizes(of url: URL) -> (children: [(url: URL, bytes: Int64)], total: Int64) {
        var kids: [(URL, Int64)] = []
        var total: Int64 = 0
        var folders: Set<String> = []
        for line in run("/usr/bin/du", ["-k", "-d", "1", url.path]).split(separator: "\n") {
            guard let tab = line.firstIndex(of: "\t"), let kb = Int64(line[..<tab]) else { continue }
            let path = String(line[line.index(after: tab)...])
            if path == url.path { total = kb * 1024 } else { kids.append((URL(fileURLWithPath: path), kb * 1024)); folders.insert(path) }
        }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .totalFileAllocatedSizeKey]
        let entries = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys))) ?? []
        for file in entries where !folders.contains(file.path) {
            guard let v = try? file.resourceValues(forKeys: keys), v.isDirectory != true else { continue }
            kids.append((file, Int64(v.totalFileAllocatedSize ?? 0)))
        }
        return (kids.sorted { $0.1 > $1.1 }, total)
    }

    static func size(of url: URL) -> Int64 {
        let text = run("/usr/bin/du", ["-s", "-k", url.path])
        return (Int64(text.split(separator: "\t").first ?? "") ?? 0) * 1024
    }

    /// Archivos de más de `minMB` en la carpeta personal, sin Xcode, la Papelera ni iCloud.
    static func largeFiles(minMB: Int) -> [CleanItem] {
        let skip = ["Library/Developer", ".Trash", "Library/Mobile Documents", "Library/CloudStorage"]
            .map { home.appendingPathComponent($0).path + "/*" }
        var args = [home.path, "-xdev", "("]
        for (i, pattern) in skip.enumerated() {
            if i > 0 { args.append("-o") }
            args += ["-path", pattern]
        }
        args += [")", "-prune", "-o", "-type", "f", "-size", "+\(minMB)M", "-print"]
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .contentModificationDateKey]
        return run("/usr/bin/find", args).split(separator: "\n").compactMap { line in
            let url = URL(fileURLWithPath: String(line))
            guard let v = try? url.resourceValues(forKeys: keys),
                  let bytes = v.totalFileAllocatedSize else { return nil }
            return CleanItem(url: url, bytes: Int64(bytes), modified: v.contentModificationDate)
        }
        .sorted { $0.bytes > $1.bytes }
        .prefix(80).map { $0 }
    }
}
