#!/usr/bin/env swift
// Writes the closed-eye glyph used by packaging/AppIcon.icon as filled outlines.
// Icon Composer's glass renderer mishandles open stroked paths, so strokes are
// expanded and unioned here. Keep the geometry in sync with RestGateIcon.
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("packaging/AppIcon.icon/Assets/closed-eye.svg")

// SVG coordinates on a 1024 canvas, y pointing down.
let lid = CGMutablePath()
lid.move(to: CGPoint(x: 236, y: 408))
lid.addCurve(to: CGPoint(x: 788, y: 408), control1: CGPoint(x: 340, y: 582), control2: CGPoint(x: 684, y: 582))

let lashes = CGMutablePath()
for (start, end) in [
    (CGPoint(x: 512, y: 546), CGPoint(x: 512, y: 644)),
    (CGPoint(x: 386, y: 523), CGPoint(x: 343, y: 611)),
    (CGPoint(x: 638, y: 523), CGPoint(x: 681, y: 611)),
    (CGPoint(x: 291, y: 470), CGPoint(x: 224, y: 535)),
    (CGPoint(x: 733, y: 470), CGPoint(x: 800, y: 535))
] {
    lashes.move(to: start)
    lashes.addLine(to: end)
}

let glyph = lid.copy(strokingWithWidth: 78, lineCap: .round, lineJoin: .round, miterLimit: 10)
    .union(lashes.copy(strokingWithWidth: 54, lineCap: .round, lineJoin: .round, miterLimit: 10))

func format(_ value: CGFloat) -> String {
    String(format: "%.2f", value)
}

var data = ""
glyph.applyWithBlock { element in
    let points = element.pointee.points
    switch element.pointee.type {
    case .moveToPoint:
        data += "M\(format(points[0].x)) \(format(points[0].y))"
    case .addLineToPoint:
        data += "L\(format(points[0].x)) \(format(points[0].y))"
    case .addQuadCurveToPoint:
        data += "Q\(format(points[0].x)) \(format(points[0].y)) \(format(points[1].x)) \(format(points[1].y))"
    case .addCurveToPoint:
        data += "C\(format(points[0].x)) \(format(points[0].y)) \(format(points[1].x)) \(format(points[1].y)) \(format(points[2].x)) \(format(points[2].y))"
    case .closeSubpath:
        data += "Z"
    @unknown default:
        break
    }
}

let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <path fill="#FFFFFF" d="\(data)"/>
</svg>

"""
try svg.write(to: output, atomically: true, encoding: .utf8)
print(output.path)
