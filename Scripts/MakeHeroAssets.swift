#!/usr/bin/env swift
// Generates README/hero artwork that doesn't require an actual screenshot:
//   screenshots/icon.png    — large rendered app icon
//   screenshots/demo.png    — "before / after" mockup showing the swap concept
//
// Real UI screenshots (menu bar dropdown, Settings window) should be captured
// by hand on a Mac after `Scripts/build.sh` and dropped into screenshots/.

import AppKit
import CoreGraphics
import Foundation

let outDir = "screenshots"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// MARK: - shared helpers

let bgTop = CGColor(red: 0.42, green: 0.45, blue: 0.96, alpha: 1.0)
let bgBot = CGColor(red: 0.20, green: 0.27, blue: 0.85, alpha: 1.0)

func writePNG(_ ctx: CGContext, to path: String) throws {
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

func newContext(width: Int, height: Int) -> CGContext {
    CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

// MARK: - icon.png (1024x1024)

func renderIcon() throws {
    let px = 1024
    let ctx = newContext(width: px, height: px)
    let size = CGFloat(px)
    let cs = CGColorSpaceCreateDeviceRGB()

    let corner = size * 0.2237
    let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                      cornerWidth: corner, cornerHeight: corner, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let bg = CGGradient(colorsSpace: cs, colors: [bgTop, bgBot] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    let arrowWidth = size * 0.62
    let arrowGap = size * 0.13
    let stroke = size * 0.085
    let head = size * 0.13
    let cx = size / 2, cy = size / 2

    ctx.setStrokeColor(gray: 1, alpha: 1)
    ctx.setLineWidth(stroke)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let tR = CGPoint(x: cx + arrowWidth / 2, y: cy + arrowGap)
    ctx.move(to: CGPoint(x: cx - arrowWidth / 2, y: tR.y))
    ctx.addLine(to: tR); ctx.strokePath()
    ctx.move(to: CGPoint(x: tR.x - head, y: tR.y + head))
    ctx.addLine(to: tR)
    ctx.addLine(to: CGPoint(x: tR.x - head, y: tR.y - head))
    ctx.strokePath()

    let bL = CGPoint(x: cx - arrowWidth / 2, y: cy - arrowGap)
    ctx.move(to: CGPoint(x: cx + arrowWidth / 2, y: bL.y))
    ctx.addLine(to: bL); ctx.strokePath()
    ctx.move(to: CGPoint(x: bL.x + head, y: bL.y + head))
    ctx.addLine(to: bL)
    ctx.addLine(to: CGPoint(x: bL.x + head, y: bL.y - head))
    ctx.strokePath()

    try writePNG(ctx, to: "\(outDir)/icon.png")
}

// MARK: - demo.png — before / after card

func renderDemo() throws {
    let W = 1280, H = 540
    let ctx = newContext(width: W, height: H)
    let w = CGFloat(W), h = CGFloat(H)
    let cs = CGColorSpaceCreateDeviceRGB()

    // soft page background
    let pageTop = CGColor(red: 0.95, green: 0.96, blue: 1.0, alpha: 1.0)
    let pageBot = CGColor(red: 0.85, green: 0.88, blue: 0.97, alpha: 1.0)
    let bg = CGGradient(colorsSpace: cs, colors: [pageTop, pageBot] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])

    // Two "cards": typed-wrong on the left, converted on the right
    let cardW: CGFloat = 470
    let cardH: CGFloat = 220
    let gap: CGFloat = 100
    let totalW = cardW * 2 + gap
    let cardY = h / 2 - cardH / 2
    let leftX = (w - totalW) / 2
    let rightX = leftX + cardW + gap

    func drawCard(x: CGFloat, label: String, text: String, accent: CGColor) {
        let r = CGRect(x: x, y: cardY, width: cardW, height: cardH)
        let p = CGPath(roundedRect: r, cornerWidth: 18, cornerHeight: 18, transform: nil)

        // shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -4),
                      blur: 20,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.18))
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.addPath(p); ctx.fillPath()
        ctx.restoreGState()

        // top accent band
        ctx.saveGState()
        ctx.addPath(p); ctx.clip()
        ctx.setFillColor(accent)
        ctx.fill(CGRect(x: x, y: cardY + cardH - 6, width: cardW, height: 6))
        ctx.restoreGState()

        // label
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor(cgColor: accent) ?? .systemBlue
        ]
        let labelLine = CTLineCreateWithAttributedString(
            NSAttributedString(string: label, attributes: labelAttrs) as CFAttributedString
        )
        ctx.textPosition = CGPoint(x: x + 28, y: cardY + cardH - 44)
        CTLineDraw(labelLine, ctx)

        // body text
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 38, weight: .medium),
            .foregroundColor: NSColor(red: 0.18, green: 0.22, blue: 0.30, alpha: 1)
        ]
        let bodyLine = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: bodyAttrs) as CFAttributedString
        )
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let bw = CGFloat(CTLineGetTypographicBounds(bodyLine, &ascent, &descent, &leading))
        ctx.textPosition = CGPoint(x: x + (cardW - bw) / 2, y: cardY + cardH / 2 - 38)
        CTLineDraw(bodyLine, ctx)
    }

    drawCard(
        x: leftX,
        label: "You typed (wrong layout)",
        text: "feliz a;o nuevo",
        accent: CGColor(red: 0.85, green: 0.40, blue: 0.40, alpha: 1)
    )
    drawCard(
        x: rightX,
        label: "Swaype converts",
        text: "feliz año nuevo",
        accent: CGColor(red: 0.30, green: 0.55, blue: 0.40, alpha: 1)
    )

    // Arrow between cards
    let arrowStart = leftX + cardW + 18
    let arrowEnd = rightX - 18
    let arrowY = h / 2
    ctx.setStrokeColor(red: 0.30, green: 0.40, blue: 0.85, alpha: 1)
    ctx.setLineWidth(6)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: arrowStart, y: arrowY))
    ctx.addLine(to: CGPoint(x: arrowEnd, y: arrowY))
    ctx.strokePath()
    ctx.setFillColor(red: 0.30, green: 0.40, blue: 0.85, alpha: 1)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: arrowEnd + 16, y: arrowY))
    ctx.addLine(to: CGPoint(x: arrowEnd - 8, y: arrowY + 14))
    ctx.addLine(to: CGPoint(x: arrowEnd - 8, y: arrowY - 14))
    ctx.closePath()
    ctx.fillPath()

    // Title
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 34, weight: .bold),
        .foregroundColor: NSColor(red: 0.16, green: 0.21, blue: 0.42, alpha: 1)
    ]
    let titleLine = CTLineCreateWithAttributedString(
        NSAttributedString(string: "Press ⌘⌥V — Swaype swaps your layout in place",
                           attributes: titleAttrs) as CFAttributedString
    )
    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
    let tw = CGFloat(CTLineGetTypographicBounds(titleLine, &a, &d, &l))
    ctx.textPosition = CGPoint(x: (w - tw) / 2, y: h - 70)
    CTLineDraw(titleLine, ctx)

    try writePNG(ctx, to: "\(outDir)/demo.png")
}

try renderIcon()
try renderDemo()
