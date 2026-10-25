// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let size = NSSize(width: 1280, height: 640)
let image = NSImage(size: size)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func rounded(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

func text(_ value: String, rect: NSRect, size: CGFloat, weight: NSFont.Weight, color ink: NSColor, spacing: CGFloat = 0) {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: ink,
        .kern: spacing,
        .paragraphStyle: style
    ]
    value.draw(in: rect, withAttributes: attrs)
}

image.lockFocus()

NSGradient(colors: [color(0x071018), color(0x102B3D), color(0x071018)])!.draw(in: NSRect(origin: .zero, size: size), angle: 0)

let amberGlow = NSGradient(colors: [color(0xF4B34F, 0.42), color(0xF4B34F, 0)])!
amberGlow.draw(in: NSBezierPath(ovalIn: NSRect(x: -180, y: 240, width: 780, height: 620)), relativeCenterPosition: .zero)
let aquaGlow = NSGradient(colors: [color(0x4ED7C8, 0.22), color(0x4ED7C8, 0)])!
aquaGlow.draw(in: NSBezierPath(ovalIn: NSRect(x: 760, y: -260, width: 760, height: 680)), relativeCenterPosition: .zero)

for x in stride(from: CGFloat(0), through: size.width, by: 48) {
    color(0xFFFFFF, 0.025).setStroke()
    let line = NSBezierPath()
    line.move(to: NSPoint(x: x, y: 0))
    line.line(to: NSPoint(x: x + 300, y: size.height))
    line.lineWidth = 1
    line.stroke()
}

if let icon = NSImage(contentsOf: root.appendingPathComponent("site/public/img/icon.png")) {
    rounded(NSRect(x: 70, y: 488, width: 84, height: 84), radius: 24, fill: color(0xFFFFFF, 0.07), stroke: color(0xFFFFFF, 0.14))
    icon.draw(in: NSRect(x: 80, y: 498, width: 64, height: 64), from: .zero, operation: .sourceOver, fraction: 1)
}
text("faro", rect: NSRect(x: 174, y: 505, width: 240, height: 60), size: 38, weight: .bold, color: .white, spacing: -1)
text("OPEN SOURCE · NATIVE FOR macOS", rect: NSRect(x: 72, y: 450, width: 470, height: 28), size: 14, weight: .bold, color: color(0xF6C56F), spacing: 1.4)
text("Your Mac, explained.\nAnd under control.", rect: NSRect(x: 68, y: 235, width: 520, height: 196), size: 56, weight: .bold, color: .white, spacing: -1.8)
text("Diagnostics, automation, storage, audio and everyday tools — from the menu bar and notch.", rect: NSRect(x: 72, y: 126, width: 500, height: 86), size: 20, weight: .medium, color: color(0xC7D5DE), spacing: -0.2)

let chips = ["LOCAL-FIRST", "NO TELEMETRY", "SWIFT"]
var chipX: CGFloat = 72
for chip in chips {
    let width = CGFloat(chip.count * 9 + 34)
    rounded(NSRect(x: chipX, y: 62, width: width, height: 38), radius: 19, fill: color(0xFFFFFF, 0.075), stroke: color(0xFFFFFF, 0.14))
    text(chip, rect: NSRect(x: chipX + 17, y: 72, width: width - 30, height: 18), size: 11, weight: .bold, color: color(0xE9F1F5), spacing: 0.9)
    chipX += width + 10
}

rounded(NSRect(x: 586, y: 244, width: 646, height: 275), radius: 38, fill: color(0x020405, 0.95), stroke: color(0xFFFFFF, 0.16))
if let notch = NSImage(contentsOf: root.appendingPathComponent("site/public/img/hero-notch.png")) {
    notch.draw(in: NSRect(x: 602, y: 263, width: 614, height: 226), from: NSRect(origin: .zero, size: notch.size), operation: .sourceOver, fraction: 1)
}

rounded(NSRect(x: 772, y: 72, width: 432, height: 158), radius: 28, fill: color(0x020405, 0.96), stroke: color(0xFFFFFF, 0.16))
if let mascot = NSImage(contentsOf: root.appendingPathComponent("site/public/img/mascota-personalizada.png")) {
    mascot.draw(in: NSRect(x: 786, y: 83, width: 404, height: 144), from: NSRect(origin: .zero, size: mascot.size), operation: .sourceOver, fraction: 1)
}

text("A CONECTA LAB PRODUCT", rect: NSRect(x: 1020, y: 28, width: 210, height: 22), size: 10, weight: .bold, color: color(0x9FB2BD), spacing: 1.1)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render social preview")
}

for path in ["site/public/img/social-preview.png", "docs/images/social-preview.png"] {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: url, options: .atomic)
    let resize = Process()
    resize.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    resize.arguments = ["-z", "640", "1280", url.path]
    resize.standardOutput = FileHandle.nullDevice
    resize.standardError = FileHandle.nullDevice
    try resize.run()
    resize.waitUntilExit()
    guard resize.terminationStatus == 0 else {
        fatalError("Could not resize \(path)")
    }
    print("Generated \(path)")
}
