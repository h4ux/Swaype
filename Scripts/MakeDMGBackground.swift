#!/usr/bin/env swift
// Renders the DMG installer background: 600x400 PNG with a soft gradient,
// the Swaype title, and an arrow pointing from where the .app will sit to
// where the user drags it (the Applications symlink).

import AppKit
import CoreGraphics
import Foundation

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/dmg-background.png"

func render(width: Int, height: Int) -> Data {
    let w = CGFloat(width)
    let h = CGFloat(height)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Soft vertical gradient background — light gray top → near-white bottom.
    let top = CGColor(red: 0.96, green: 0.97, blue: 1.00, alpha: 1.0)
    let bot = CGColor(red: 0.86, green: 0.89, blue: 0.97, alpha: 1.0)
    let bg = CGGradient(
        colorsSpace: cs,
        colors: [top, bot] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        bg,
        start: CGPoint(x: 0, y: h),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // Title.
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .bold),
        .foregroundColor: NSColor(red: 0.16, green: 0.21, blue: 0.42, alpha: 1.0)
    ]
    let title = NSAttributedString(string: "Install Swaype", attributes: titleAttrs)
    let tLine = CTLineCreateWithAttributedString(title as CFAttributedString)
    var tAsc: CGFloat = 0
    var tDes: CGFloat = 0
    var tLead: CGFloat = 0
    let tWidth = CGFloat(CTLineGetTypographicBounds(tLine, &tAsc, &tDes, &tLead))
    ctx.textPosition = CGPoint(x: (w - tWidth) / 2, y: h - 56)
    CTLineDraw(tLine, ctx)

    // Subtitle.
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor(red: 0.30, green: 0.34, blue: 0.50, alpha: 1.0)
    ]
    let sub = NSAttributedString(
        string: "Drag Swaype into the Applications folder",
        attributes: subAttrs
    )
    let sLine = CTLineCreateWithAttributedString(sub as CFAttributedString)
    var sAsc: CGFloat = 0
    var sDes: CGFloat = 0
    var sLead: CGFloat = 0
    let sWidth = CGFloat(CTLineGetTypographicBounds(sLine, &sAsc, &sDes, &sLead))
    ctx.textPosition = CGPoint(x: (w - sWidth) / 2, y: h - 90)
    CTLineDraw(sLine, ctx)

    // Arrow from app icon position (≈ x:175,y:185) to Applications (≈ x:425,y:185).
    // We draw at center vertical of the icons.
    let arrowY: CGFloat = h - 230  // matches icon center row in the DMG window
    let startX: CGFloat = 230
    let endX: CGFloat = 370

    ctx.setStrokeColor(red: 0.30, green: 0.40, blue: 0.85, alpha: 0.9)
    ctx.setLineWidth(4)
    ctx.setLineCap(.round)

    ctx.move(to: CGPoint(x: startX, y: arrowY))
    ctx.addLine(to: CGPoint(x: endX, y: arrowY))
    ctx.strokePath()

    // Arrowhead.
    ctx.setFillColor(red: 0.30, green: 0.40, blue: 0.85, alpha: 0.95)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: endX + 14, y: arrowY))
    ctx.addLine(to: CGPoint(x: endX - 6, y: arrowY + 12))
    ctx.addLine(to: CGPoint(x: endX - 6, y: arrowY - 12))
    ctx.closePath()
    ctx.fillPath()

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

// 600x400 base; we also write @2x for retina displays.
let dirURL = URL(fileURLWithPath: outPath).deletingLastPathComponent()
try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

let base = render(width: 600, height: 400)
try base.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")

let twoX = (outPath as NSString).deletingPathExtension + "@2x.png"
let big = render(width: 1200, height: 800)
try big.write(to: URL(fileURLWithPath: twoX))
print("wrote \(twoX)")
