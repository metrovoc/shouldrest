#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("packaging/AppIcon.iconset")
let output = root.appendingPathComponent("packaging/AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer {
    try? FileManager.default.removeItem(at: iconset)
}

struct IconVariant {
    let fileName: String
    let pixels: Int
}

let variants = [
    IconVariant(fileName: "icon_16x16.png", pixels: 16),
    IconVariant(fileName: "icon_16x16@2x.png", pixels: 32),
    IconVariant(fileName: "icon_32x32.png", pixels: 32),
    IconVariant(fileName: "icon_32x32@2x.png", pixels: 64),
    IconVariant(fileName: "icon_128x128.png", pixels: 128),
    IconVariant(fileName: "icon_128x128@2x.png", pixels: 256),
    IconVariant(fileName: "icon_256x256.png", pixels: 256),
    IconVariant(fileName: "icon_256x256@2x.png", pixels: 512),
    IconVariant(fileName: "icon_512x512.png", pixels: 512),
    IconVariant(fileName: "icon_512x512@2x.png", pixels: 1024)
]

func drawIcon(pixels: Int) throws -> Data {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "ShouldRestIcon", code: 1)
    }

    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let corner = size * 0.21
    let background = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: corner, yRadius: corner)
    NSColor(red: 0.05, green: 0.09, blue: 0.11, alpha: 1).setFill()
    background.fill()

    let inset = size * 0.12
    let inner = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2), xRadius: corner * 0.72, yRadius: corner * 0.72)
    NSColor(red: 0.03, green: 0.19, blue: 0.20, alpha: 1).setFill()
    inner.fill()

    let ringRect = NSRect(x: size * 0.22, y: size * 0.24, width: size * 0.56, height: size * 0.56)
    let ring = NSBezierPath(ovalIn: ringRect)
    NSColor(red: 0.70, green: 0.96, blue: 0.92, alpha: 1).setFill()
    ring.fill()

    let centerRect = ringRect.insetBy(dx: size * 0.075, dy: size * 0.075)
    let center = NSBezierPath(ovalIn: centerRect)
    NSColor(red: 0.03, green: 0.19, blue: 0.20, alpha: 1).setFill()
    center.fill()

    let leftBar = NSBezierPath(
        roundedRect: NSRect(x: size * 0.405, y: size * 0.37, width: size * 0.07, height: size * 0.28),
        xRadius: size * 0.032,
        yRadius: size * 0.032
    )
    let rightBar = NSBezierPath(
        roundedRect: NSRect(x: size * 0.525, y: size * 0.37, width: size * 0.07, height: size * 0.28),
        xRadius: size * 0.032,
        yRadius: size * 0.032
    )
    NSColor(red: 0.70, green: 0.96, blue: 0.92, alpha: 1).setFill()
    leftBar.fill()
    rightBar.fill()

    let cadenceDot = NSBezierPath(ovalIn: NSRect(x: size * 0.65, y: size * 0.64, width: size * 0.12, height: size * 0.12))
    NSColor(red: 0.44, green: 0.88, blue: 0.72, alpha: 1).setFill()
    cadenceDot.fill()

    let restBar = NSBezierPath(roundedRect: NSRect(x: size * 0.30, y: size * 0.20, width: size * 0.40, height: size * 0.065), xRadius: size * 0.032, yRadius: size * 0.032)
    NSColor(red: 0.44, green: 0.88, blue: 0.72, alpha: 1).setFill()
    restBar.fill()

    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ShouldRestIcon", code: 2)
    }
    return data
}

for variant in variants {
    let data = try drawIcon(pixels: variant.pixels)
    try data.write(to: iconset.appendingPathComponent(variant.fileName))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw NSError(domain: "ShouldRestIcon", code: Int(process.terminationStatus))
}
