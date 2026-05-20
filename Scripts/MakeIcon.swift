#!/usr/bin/env swift
// Generates an AppIcon.iconset directory with PNGs at every size macOS expects,
// then iconutil (invoked by build.sh) packs it into AppIcon.icns.
//
// Design: rounded-square with a vertical blue gradient, two stacked horizontal
// arrows (top pointing right, bottom pointing left) — a script-agnostic
// "swap" symbol that doesn't favor any particular language pair.

import AppKit
import CoreGraphics
import Foundation

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/AppIcon.iconset"

let fm = FileManager.default
try? fm.removeItem(atPath: outDir)
try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

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

    // Rounded-square clip (macOS uses ~22.37% corner radius).
    let corner = size * 0.2237
    let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // Vertical gradient: indigo top → deep blue bottom.
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

    // Subtle top highlight band — gives the icon a bit of depth.
    let highlight = CGColor(red: 1, green: 1, blue: 1, alpha: 0.18)
    let clear = CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
    let hl = CGGradient(
        colorsSpace: cs,
        colors: [highlight, clear] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        hl,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: size * 0.55),
        options: []
    )

    ctx.restoreGState()

    // Two horizontal arrows: top points right, bottom points left.
    // Sized to read clearly even at 16×16.
    let arrowWidth = size * 0.62
    let arrowGap = size * 0.13       // distance from center to each arrow
    let stroke = max(size * 0.085, 2)
    let head = size * 0.13
    let cx = size / 2
    let cy = size / 2

    ctx.setStrokeColor(gray: 1, alpha: 1)
    ctx.setLineWidth(stroke)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Top arrow (→), drawn slightly above center.
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

    // Bottom arrow (←), drawn slightly below center.
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

    // PNG out.
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

let entries: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for entry in entries {
    let data = render(size: entry.size)
    let url = URL(fileURLWithPath: "\(outDir)/\(entry.name)")
    try data.write(to: url)
    print("wrote \(entry.name)")
}
