// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import ImageIO
import UniformTypeIdentifiers

enum Imaging {
    /// Reduce la imagen al tamaño de la pantalla y la guarda como JPEG en la caché.
    static func prepare(_ source: URL, maxPixel: Int) throws -> URL {
        guard let src = CGImageSourceCreateWithURL(source as CFURL, nil) else { throw ImagingError.unreadable }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            throw ImagingError.unreadable
        }
        let out = Paths.cache.appendingPathComponent("\(UUID().uuidString).jpg")
        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw ImagingError.unwritable }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ImagingError.unwritable }
        return out
    }

    static func thumbnail(of file: URL, maxPixel: Int = 640) -> NSImage? {
        guard let src = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: .zero)
    }
}

enum ImagingError: LocalizedError {
    case unreadable, unwritable
    var errorDescription: String? {
        switch self {
        case .unreadable: return "No se pudo leer la imagen descargada"
        case .unwritable: return "No se pudo guardar la imagen"
        }
    }
}

extension NSScreen {
    var displayKey: String {
        let n = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return n?.stringValue ?? localizedName
    }

    var maxPixel: Int {
        Int(max(frame.width, frame.height) * backingScaleFactor)
    }
}
