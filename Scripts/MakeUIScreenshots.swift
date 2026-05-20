#!/usr/bin/env swift
// Renders mockup PNGs for the README that we can't easily capture as real
// screenshots from a CI machine:
//
//   screenshots/menubar.png   — slice of the macOS menu bar with our icon
//   screenshots/menu.png      — the dropdown menu opened from the menu bar
//   screenshots/settings.png  — the Settings window with both pickers filled
//
// These are high-quality mockups, not pixel-perfect screenshots. Replace them
// with real captures once you've installed the app on a Mac.

import AppKit
import CoreGraphics
import CoreText
import Foundation

let outDir = "screenshots"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// MARK: - Drawing helpers

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

func writePNG(_ ctx: CGContext, to path: String) throws {
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

@discardableResult
func drawText(_ text: String, in ctx: CGContext, x: CGFloat, topY: CGFloat, font: NSFont, color: NSColor) -> CGSize {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let attr = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attr as CFAttributedString)
    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let w = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
    ctx.textPosition = CGPoint(x: x, y: topY - ascent)
    CTLineDraw(line, ctx)
    return CGSize(width: w, height: ascent + descent)
}

func textSize(_ text: String, font: NSFont) -> CGSize {
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    return NSAttributedString(string: text, attributes: attrs).size()
}

func roundedRect(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat, fill: CGColor) {
    let p = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.setFillColor(fill)
    ctx.addPath(p)
    ctx.fillPath()
}

func roundedRectStroke(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat, stroke: CGColor, width: CGFloat) {
    let p = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(width)
    ctx.addPath(p)
    ctx.strokePath()
}

func tintedSymbol(_ name: String, size: NSSize, color: NSColor, weight: NSFont.Weight = .regular) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: size.height * 0.78, weight: weight)
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return nil }

    let result = NSImage(size: size)
    result.lockFocus()
    let imgSize = symbol.size
    let dr = NSRect(
        x: (size.width - imgSize.width) / 2,
        y: (size.height - imgSize.height) / 2,
        width: imgSize.width,
        height: imgSize.height
    )
    symbol.draw(in: dr)
    color.set()
    NSRect(origin: .zero, size: size).fill(using: .sourceIn)
    result.unlockFocus()
    return result
}

func drawSymbol(_ name: String, in ctx: CGContext, rect: CGRect, color: NSColor, weight: NSFont.Weight = .regular) {
    guard let img = tintedSymbol(name, size: rect.size, color: color, weight: weight),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    ctx.draw(cg, in: rect)
}

/// Renders the Swaype brand mark — same design as the app icon (blue gradient
/// rounded square + white swap arrows). Used wherever a Swaype icon appears
/// inside a mockup.
func drawSwaypeIcon(in ctx: CGContext, rect: CGRect) {
    let s = min(rect.width, rect.height)
    let r = CGRect(x: rect.midX - s/2, y: rect.midY - s/2, width: s, height: s)

    let cs = CGColorSpaceCreateDeviceRGB()
    let corner = s * 0.2237
    let path = CGPath(roundedRect: r, cornerWidth: corner, cornerHeight: corner, transform: nil)

    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let g = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.42, green: 0.45, blue: 0.96, alpha: 1.0),
            CGColor(red: 0.20, green: 0.27, blue: 0.85, alpha: 1.0)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(g,
                           start: CGPoint(x: r.minX, y: r.maxY),
                           end: CGPoint(x: r.minX, y: r.minY),
                           options: [])
    ctx.restoreGState()

    let cx = r.midX, cy = r.midY
    let aw = s * 0.58
    let ag = s * 0.16
    let stroke = max(s * 0.12, 1.5)
    let head = s * 0.16

    ctx.setStrokeColor(gray: 1, alpha: 1)
    ctx.setLineWidth(stroke)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let tR = CGPoint(x: cx + aw/2, y: cy + ag)
    ctx.move(to: CGPoint(x: cx - aw/2, y: tR.y))
    ctx.addLine(to: tR); ctx.strokePath()
    ctx.move(to: CGPoint(x: tR.x - head, y: tR.y + head))
    ctx.addLine(to: tR)
    ctx.addLine(to: CGPoint(x: tR.x - head, y: tR.y - head))
    ctx.strokePath()

    let bL = CGPoint(x: cx - aw/2, y: cy - ag)
    ctx.move(to: CGPoint(x: cx + aw/2, y: bL.y))
    ctx.addLine(to: bL); ctx.strokePath()
    ctx.move(to: CGPoint(x: bL.x + head, y: bL.y + head))
    ctx.addLine(to: bL)
    ctx.addLine(to: CGPoint(x: bL.x + head, y: bL.y - head))
    ctx.strokePath()
}

// MARK: - menubar.png

func renderMenubar() throws {
    let scale = 2
    let W = 1400 * scale, H = 64 * scale
    let ctx = newContext(width: W, height: H)
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let w: CGFloat = 1400, h: CGFloat = 64

    // Wallpaper-ish background to give the menu bar context.
    let cs = CGColorSpaceCreateDeviceRGB()
    let bg = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.82, green: 0.89, blue: 1.00, alpha: 1),
            CGColor(red: 0.55, green: 0.70, blue: 0.92, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(bg,
                           start: CGPoint(x: 0, y: 0),
                           end: CGPoint(x: w, y: h),
                           options: [])

    // Menu bar strip (translucent white).
    let barH: CGFloat = 28
    let barY = h - barH
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.82)
    ctx.fill(CGRect(x: 0, y: barY, width: w, height: barH))
    // hairline at the bottom of the bar
    ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 0.08)
    ctx.fill(CGRect(x: 0, y: barY, width: w, height: 0.5))

    let textColor = NSColor(red: 0.13, green: 0.16, blue: 0.22, alpha: 1)
    let labelFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    let appNameFont = NSFont.systemFont(ofSize: 13, weight: .semibold)

    // Left side: Apple logo + active app + menus.
    let appleSize: CGFloat = 16
    drawSymbol("apple.logo",
               in: ctx,
               rect: CGRect(x: 18, y: barY + (barH - appleSize)/2, width: appleSize, height: appleSize),
               color: textColor)

    var x: CGFloat = 18 + appleSize + 14
    let labelTop = barY + (barH + labelFont.capHeight) / 2 + 2  // crude vertical center

    let appName = "TextEdit"
    let appSize = textSize(appName, font: appNameFont)
    drawText(appName, in: ctx, x: x, topY: labelTop, font: appNameFont, color: textColor)
    x += appSize.width + 22

    for label in ["File", "Edit", "Format", "View", "Window", "Help"] {
        let s = textSize(label, font: labelFont)
        drawText(label, in: ctx, x: x, topY: labelTop, font: labelFont, color: textColor)
        x += s.width + 18
    }

    // Right side: status icons (right-to-left).
    var rx: CGFloat = w - 18
    let iconSize: CGFloat = 18
    let iconY = barY + (barH - iconSize) / 2

    // Time
    let timeFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    let timeText = "Wed 10:24"
    let timeSize = textSize(timeText, font: timeFont)
    rx -= timeSize.width
    drawText(timeText, in: ctx, x: rx, topY: labelTop, font: timeFont, color: textColor)
    rx -= 14

    func placeIcon(_ name: String, w iw: CGFloat = 18, weight: NSFont.Weight = .regular) {
        rx -= iw
        drawSymbol(name, in: ctx,
                   rect: CGRect(x: rx, y: iconY, width: iw, height: iconSize),
                   color: textColor, weight: weight)
        rx -= 10
    }

    placeIcon("switch.2")                       // control center
    placeIcon("battery.75percent", w: 30)        // battery
    placeIcon("speaker.wave.2.fill")             // volume
    placeIcon("wifi", weight: .medium)           // wifi

    // Our Swaype icon — slightly larger to draw the eye.
    let swaypeSize: CGFloat = 22
    rx -= swaypeSize
    let swaypeRect = CGRect(x: rx, y: barY + (barH - swaypeSize) / 2,
                            width: swaypeSize, height: swaypeSize)
    drawSwaypeIcon(in: ctx, rect: swaypeRect)
    rx -= 10

    placeIcon("magnifyingglass", weight: .medium)
    placeIcon("character.bubble")                // input source

    try writePNG(ctx, to: "\(outDir)/menubar.png")
}

// MARK: - menu.png

func renderMenu() throws {
    let scale = 2
    let W = 520 * scale, H = 420 * scale
    let ctx = newContext(width: W, height: H)
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let w: CGFloat = 520, h: CGFloat = 420

    // Desktop-ish background so the menu pops.
    let cs = CGColorSpaceCreateDeviceRGB()
    let bg = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.86, green: 0.91, blue: 1.0, alpha: 1),
            CGColor(red: 0.62, green: 0.74, blue: 0.94, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(bg,
                           start: CGPoint(x: 0, y: h),
                           end: CGPoint(x: w, y: 0),
                           options: [])

    // Tiny menu bar slice at top with the Swaype icon highlighted.
    let barH: CGFloat = 28
    let barY = h - barH
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.85)
    ctx.fill(CGRect(x: 0, y: barY, width: w, height: barH))
    let swaypeIconSize: CGFloat = 18
    let menuAnchor = CGRect(
        x: w - 30 - swaypeIconSize,
        y: barY + (barH - swaypeIconSize) / 2,
        width: swaypeIconSize,
        height: swaypeIconSize
    )
    drawSwaypeIcon(in: ctx, rect: menuAnchor)
    // highlight the icon to suggest "menu opened from here"
    ctx.setFillColor(red: 0.30, green: 0.40, blue: 0.85, alpha: 0.18)
    let highlight = menuAnchor.insetBy(dx: -3, dy: -3)
    ctx.addPath(CGPath(roundedRect: highlight, cornerWidth: 4, cornerHeight: 4, transform: nil))
    ctx.fillPath()

    // Dropdown menu, anchored so its right edge sits roughly below the icon
    // (matching macOS menu behaviour: menus open down-and-to-the-left).
    let menuW: CGFloat = 280
    let menuH: CGFloat = 300
    let menuX = max(20, menuAnchor.maxX - menuW + 14)
    let menuY = barY - menuH - 4

    // shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6),
                  blur: 26,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
    roundedRect(ctx,
                CGRect(x: menuX, y: menuY, width: menuW, height: menuH),
                radius: 10,
                fill: CGColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 0.98))
    ctx.restoreGState()

    // subtle border
    roundedRectStroke(ctx,
                      CGRect(x: menuX, y: menuY, width: menuW, height: menuH),
                      radius: 10,
                      stroke: CGColor(red: 0, green: 0, blue: 0, alpha: 0.08),
                      width: 1)

    // Menu items, top-to-bottom.
    let itemFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    let disabledColor = NSColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1)
    let activeColor = NSColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1)
    let shortcutColor = NSColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 1)

    enum Row {
        case item(String, shortcut: String? = nil, checked: Bool = false)
        case separator
        case disabled(String)
    }

    let rows: [Row] = [
        .item("Swap Selection"),
        .item("Convert Clipboard"),
        .separator,
        .disabled("Pair: U.S. ↔ Hebrew"),
        .separator,
        .item("Launch at Login", checked: true),
        .item("Check for Updates…"),
        .item("Settings…", shortcut: "⌘,"),
        .separator,
        .item("Quit Swaype", shortcut: "⌘Q")
    ]

    let rowH: CGFloat = 24
    let sepH: CGFloat = 9
    let padX: CGFloat = 18
    let padY: CGFloat = 8
    var rowTop = menuY + menuH - padY

    for row in rows {
        switch row {
        case .item(let title, let shortcut, let checked):
            if checked {
                // checkmark
                let cm = NSFont.systemFont(ofSize: 11, weight: .bold)
                drawText("✓", in: ctx, x: menuX + 6, topY: rowTop - 2, font: cm, color: activeColor)
            }
            drawText(title, in: ctx, x: menuX + padX, topY: rowTop - 3, font: itemFont, color: activeColor)
            if let shortcut = shortcut {
                let s = textSize(shortcut, font: itemFont)
                drawText(shortcut, in: ctx,
                         x: menuX + menuW - padX - s.width,
                         topY: rowTop - 3, font: itemFont, color: shortcutColor)
            }
            rowTop -= rowH

        case .separator:
            let y = rowTop - sepH / 2
            ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 0.08)
            ctx.fill(CGRect(x: menuX + 10, y: y, width: menuW - 20, height: 1))
            rowTop -= sepH

        case .disabled(let title):
            drawText(title, in: ctx, x: menuX + padX, topY: rowTop - 3,
                     font: itemFont, color: disabledColor)
            rowTop -= rowH
        }
    }

    try writePNG(ctx, to: "\(outDir)/menu.png")
}

// MARK: - settings.png

func renderSettings() throws {
    let scale = 2
    let W = 720 * scale, H = 560 * scale
    let ctx = newContext(width: W, height: H)
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let w: CGFloat = 720, h: CGFloat = 560

    // Desktop background
    let cs = CGColorSpaceCreateDeviceRGB()
    let bg = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.86, green: 0.91, blue: 1.0, alpha: 1),
            CGColor(red: 0.62, green: 0.74, blue: 0.94, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(bg,
                           start: CGPoint(x: 0, y: h),
                           end: CGPoint(x: w, y: 0),
                           options: [])

    // Window
    let winInset: CGFloat = 30
    let win = CGRect(x: winInset, y: winInset + 10, width: w - winInset * 2, height: h - winInset * 2 - 10)

    // Window shadow + body
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8),
                  blur: 30,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.25))
    roundedRect(ctx, win, radius: 10,
                fill: CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1))
    ctx.restoreGState()

    // Title bar
    let tbH: CGFloat = 38
    let tbRect = CGRect(x: win.minX, y: win.maxY - tbH, width: win.width, height: tbH)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: win, cornerWidth: 10, cornerHeight: 10, transform: nil))
    ctx.clip()
    let tbGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1),
            CGColor(red: 0.88, green: 0.88, blue: 0.91, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(tbGrad,
                           start: CGPoint(x: tbRect.minX, y: tbRect.maxY),
                           end: CGPoint(x: tbRect.minX, y: tbRect.minY),
                           options: [])
    // separator under title bar
    ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 0.1)
    ctx.fill(CGRect(x: tbRect.minX, y: tbRect.minY, width: tbRect.width, height: 0.5))
    ctx.restoreGState()

    // Traffic lights
    let dotR: CGFloat = 6
    let dotY = tbRect.midY
    let dotColors: [CGColor] = [
        CGColor(red: 0.99, green: 0.36, blue: 0.31, alpha: 1),
        CGColor(red: 0.99, green: 0.74, blue: 0.16, alpha: 1),
        CGColor(red: 0.16, green: 0.79, blue: 0.27, alpha: 1)
    ]
    for (i, color) in dotColors.enumerated() {
        let cx = tbRect.minX + 14 + CGFloat(i) * 18
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: cx - dotR, y: dotY - dotR,
                                   width: dotR * 2, height: dotR * 2))
    }

    // Title text
    let titleFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    let titleColor = NSColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1)
    let titleText = "Swaype Settings"
    let ts = textSize(titleText, font: titleFont)
    drawText(titleText, in: ctx,
             x: tbRect.midX - ts.width / 2,
             topY: tbRect.midY + ts.height / 2 - 1,
             font: titleFont, color: titleColor)

    // Form content area
    let content = CGRect(x: win.minX, y: win.minY,
                        width: win.width, height: win.maxY - tbH - win.minY)

    let sectionFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    let sectionColor = NSColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 1)
    let labelFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    let valueFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    let captionFont = NSFont.systemFont(ofSize: 11, weight: .regular)
    let captionColor = NSColor(red: 0.40, green: 0.40, blue: 0.46, alpha: 1)
    let bodyColor = NSColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1)

    let sectionMarginX: CGFloat = 24
    let cardR: CGFloat = 8
    let cardX = content.minX + sectionMarginX
    let cardW = content.width - sectionMarginX * 2

    var top = content.maxY - 18

    // Section: SHORTCUT
    drawText("SHORTCUT", in: ctx,
             x: cardX + 4, topY: top,
             font: sectionFont, color: sectionColor)
    top -= 22

    let shortcutH: CGFloat = 78
    let shortcutCard = CGRect(x: cardX, y: top - shortcutH, width: cardW, height: shortcutH)
    roundedRect(ctx, shortcutCard, radius: cardR,
                fill: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    roundedRectStroke(ctx, shortcutCard, radius: cardR,
                      stroke: CGColor(red: 0, green: 0, blue: 0, alpha: 0.08),
                      width: 0.5)

    drawText("Swap layout:", in: ctx,
             x: shortcutCard.minX + 18,
             topY: shortcutCard.maxY - 14,
             font: labelFont, color: bodyColor)

    // Shortcut "pill"
    let pillText = "⌘⌥V"
    let pillSize = textSize(pillText, font: valueFont)
    let pillW = pillSize.width + 22
    let pillH: CGFloat = 22
    let pillRect = CGRect(
        x: shortcutCard.maxX - 18 - pillW,
        y: shortcutCard.maxY - 14 - pillH + 3,
        width: pillW, height: pillH
    )
    roundedRect(ctx, pillRect, radius: 5,
                fill: CGColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1))
    roundedRectStroke(ctx, pillRect, radius: 5,
                      stroke: CGColor(red: 0, green: 0, blue: 0, alpha: 0.12),
                      width: 0.5)
    drawText(pillText, in: ctx,
             x: pillRect.midX - pillSize.width / 2,
             topY: pillRect.midY + pillSize.height / 2 - 1,
             font: valueFont, color: bodyColor)

    drawText("Press the shortcut while text is selected — Swaype copies, converts,",
             in: ctx,
             x: shortcutCard.minX + 18,
             topY: shortcutCard.maxY - 44,
             font: captionFont, color: captionColor)
    drawText("and pastes the result back in place.",
             in: ctx,
             x: shortcutCard.minX + 18,
             topY: shortcutCard.maxY - 60,
             font: captionFont, color: captionColor)

    top = shortcutCard.minY - 22

    // Section: LAYOUTS
    drawText("LAYOUTS", in: ctx,
             x: cardX + 4, topY: top,
             font: sectionFont, color: sectionColor)
    top -= 22

    let layoutsH: CGFloat = 130
    let layoutsCard = CGRect(x: cardX, y: top - layoutsH, width: cardW, height: layoutsH)
    roundedRect(ctx, layoutsCard, radius: cardR,
                fill: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    roundedRectStroke(ctx, layoutsCard, radius: cardR,
                      stroke: CGColor(red: 0, green: 0, blue: 0, alpha: 0.08),
                      width: 0.5)

    func drawPicker(label: String, value: String, rowTop ry: CGFloat) {
        drawText(label, in: ctx,
                 x: layoutsCard.minX + 18, topY: ry,
                 font: labelFont, color: bodyColor)

        let pickerW: CGFloat = 220
        let pickerH: CGFloat = 22
        let pickerRect = CGRect(
            x: layoutsCard.maxX - 18 - pickerW,
            y: ry - pickerH + 4,
            width: pickerW, height: pickerH
        )
        roundedRect(ctx, pickerRect, radius: 5,
                    fill: CGColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1))
        roundedRectStroke(ctx, pickerRect, radius: 5,
                          stroke: CGColor(red: 0, green: 0, blue: 0, alpha: 0.18),
                          width: 0.5)
        drawText(value, in: ctx,
                 x: pickerRect.minX + 10,
                 topY: pickerRect.midY + 6,
                 font: valueFont, color: bodyColor)
        // chevron
        drawSymbol("chevron.up.chevron.down", in: ctx,
                   rect: CGRect(x: pickerRect.maxX - 18,
                                y: pickerRect.midY - 7,
                                width: 14, height: 14),
                   color: NSColor(red: 0.35, green: 0.35, blue: 0.40, alpha: 1))
    }

    drawPicker(label: "Primary:", value: "U.S.",
               rowTop: layoutsCard.maxY - 18)
    drawPicker(label: "Secondary:", value: "Hebrew",
               rowTop: layoutsCard.maxY - 50)

    drawText("Active pair: U.S. ↔ Hebrew", in: ctx,
             x: layoutsCard.minX + 18,
             topY: layoutsCard.maxY - 82,
             font: captionFont, color: captionColor)
    drawText("Detected from System Settings → Keyboard → Input Sources.",
             in: ctx,
             x: layoutsCard.minX + 18,
             topY: layoutsCard.maxY - 102,
             font: captionFont, color: captionColor)

    top = layoutsCard.minY - 22

    // Section: BEHAVIOR
    drawText("BEHAVIOR", in: ctx,
             x: cardX + 4, topY: top,
             font: sectionFont, color: sectionColor)
    top -= 22

    let behaviorH: CGFloat = 50
    let behaviorCard = CGRect(x: cardX, y: top - behaviorH, width: cardW, height: behaviorH)
    roundedRect(ctx, behaviorCard, radius: cardR,
                fill: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    roundedRectStroke(ctx, behaviorCard, radius: cardR,
                      stroke: CGColor(red: 0, green: 0, blue: 0, alpha: 0.08),
                      width: 0.5)

    drawText("Launch at login", in: ctx,
             x: behaviorCard.minX + 18,
             topY: behaviorCard.midY + 6,
             font: labelFont, color: bodyColor)

    // Toggle switch (off-state, blue when on; show as ON)
    let toggleW: CGFloat = 38
    let toggleH: CGFloat = 22
    let toggleRect = CGRect(
        x: behaviorCard.maxX - 18 - toggleW,
        y: behaviorCard.midY - toggleH / 2,
        width: toggleW, height: toggleH
    )
    roundedRect(ctx, toggleRect, radius: toggleH / 2,
                fill: CGColor(red: 0.30, green: 0.50, blue: 0.95, alpha: 1))
    let knob = CGRect(x: toggleRect.maxX - toggleH + 2,
                      y: toggleRect.minY + 2,
                      width: toggleH - 4, height: toggleH - 4)
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fillEllipse(in: knob)

    try writePNG(ctx, to: "\(outDir)/settings.png")
}

try renderMenubar()
try renderMenu()
try renderSettings()
