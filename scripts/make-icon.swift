// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI

// Genera assets/AppIcon.icns: el logo de faro (con su círculo) sobre un cuadrado redondeado claro.
// Se compila junto con Sources/faro/UI/FaroLogo.swift, FaroLogoData.swift y Core/Appearance.swift,
// copiando este archivo como main.swift en una carpeta temporal:
//   swiftc main.swift FaroLogo.swift FaroLogoData.swift Appearance.swift -o make-icon && ./make-icon faro.iconset
//   iconutil -c icns faro.iconset -o assets/AppIcon.icns

MainActor.assumeIsolated {
    let tile = ZStack {
        RoundedRectangle(cornerRadius: 190, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: "FFFFFF")!, Color(hex: "DCE9F3")!], startPoint: .top, endPoint: .bottom))
            .frame(width: 824, height: 824)
            .shadow(color: .black.opacity(0.22), radius: 16, y: 10)
        FaroLogo(style: .color, ring: true).frame(width: 600, height: 600)
    }
    .frame(width: 1024, height: 1024)

    let renderer = ImageRenderer(content: tile)
    renderer.scale = 1
    guard let master = renderer.cgImage else { fatalError("no se pudo dibujar el ícono") }

    let set = CommandLine.arguments[1]
    try? FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
    for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                       ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: master, size: NSSize(width: 1024, height: 1024)).draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.restoreGraphicsState()
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(set)/icon_\(name).png"))
    }
}
