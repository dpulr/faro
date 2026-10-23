// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import AppKit
import SwiftUI

// Genera assets/AppIcon.icns: cuadrado redondeado verde azulado con el faro en trazo blanco.
// Se compila junto con Sources/faro/UI/LighthouseMark.swift (copiando este archivo como main.swift en una carpeta temporal)
// para dibujar exactamente el mismo símbolo.
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let rect = NSRect(x: 100, y: 100, width: size - 200, height: size - 200)
let tile = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor(red: 0.20, green: 0.50, blue: 0.46, alpha: 1), NSColor(red: 0.12, green: 0.30, blue: 0.32, alpha: 1)])!
    .draw(in: tile, angle: -60)

let markHeight: CGFloat = 500
let markRect = CGRect(x: (size - markHeight * 0.95) / 2, y: (size - markHeight) / 2 - 6, width: markHeight * 0.95, height: markHeight)
// El símbolo se define con el origen arriba; el contexto de AppKit lo tiene abajo.
var flip = CGAffineTransform(translationX: 0, y: size).scaledBy(x: 1, y: -1)
let cg = LighthouseMark(lit: true).path(in: CGRect(x: markRect.minX, y: size - markRect.maxY, width: markRect.width, height: markRect.height)).cgPath
if let flipped = cg.copy(using: &flip), let ctx = NSGraphicsContext.current?.cgContext {
    ctx.addPath(flipped)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
}
image.unlockFocus()

let set = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                   ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(set)/icon_\(name).png"))
}
