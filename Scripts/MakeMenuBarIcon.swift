#!/usr/bin/env swift
// Generates the colourful menu bar icon — same design language as the app
// icon (blue rounded square + white swap arrows) but with thicker strokes so
// it reads cleanly at 22 pt. Produces @1x / @2x / @3x for crisp rendering on
// any Mac display.

import AppKit
import CoreGraphics
import Foundation

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/menubar"

let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(size px: Int) -> Data {
    let size = CGFloat(px)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: px,
        height: px,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.2237
    let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let top = CGColor(red: 0.42, green: 0.45, blue: 0.96, alpha: 1.0)
    let bot = CGColor(red: 0.20, green: 0.27, blue: 0.85, alpha: 1.0)
    let gradient = CGGradient(
        colorsSpace: cs,
        colors: [top, bot] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    ctx.restoreGState()

    // Arrows — proportionally thicker than the app icon so the symbol is
    // legible at small menu bar sizes.
    let arrowWidth = size * 0.58
    let arrowGap = size * 0.16
    let stroke = max(size * 0.12, 1.5)
    let head = size * 0.16
    let cx = size / 2
    let cy = size / 2

    ctx.setStrokeColor(gray: 1, alpha: 1)
    ctx.setLineWidth(stroke)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let topY = cy + arrowGap
    let topLeft = CGPoint(x: cx - arrowWidth / 2, y: topY)
    let topRight = CGPoint(x: cx + arrowWidth / 2, y: topY)
    ctx.move(to: topLeft)
    ctx.addLine(to: topRight)
    ctx.strokePath()
    ctx.move(to: CGPoint(x: topRight.x - head, y: topRight.y + head))
    ctx.addLine(to: topRight)
    ctx.addLine(to: CGPoint(x: topRight.x - head, y: topRight.y - head))
    ctx.strokePath()

    let botY = cy - arrowGap
    let botLeft = CGPoint(x: cx - arrowWidth / 2, y: botY)
    let botRight = CGPoint(x: cx + arrowWidth / 2, y: botY)
    ctx.move(to: botRight)
    ctx.addLine(to: botLeft)
    ctx.strokePath()
    ctx.move(to: CGPoint(x: botLeft.x + head, y: botLeft.y + head))
    ctx.addLine(to: botLeft)
    ctx.addLine(to: CGPoint(x: botLeft.x + head, y: botLeft.y - head))
    ctx.strokePath()

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

let entries: [(name: String, size: Int)] = [
    ("MenuBarIcon.png", 22),
    ("MenuBarIcon@2x.png", 44),
    ("MenuBarIcon@3x.png", 66)
]

for entry in entries {
    let data = render(size: entry.size)
    let url = URL(fileURLWithPath: "\(outDir)/\(entry.name)")
    try data.write(to: url)
    print("wrote \(entry.name)")
}
