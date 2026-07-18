#!/usr/bin/env swift
// Generates the DMG installer background: build/dmg_background.png
//
// Usage (run from repo root):
//   swift scripts/gen-dmg-background.swift
//
// Output: build/dmg_background.png — 800×372 px, optimised for the create-dmg
// window size of 800×400 (28 px title bar subtracted so there is no scrollbar).
//
// Re-run whenever the brand colours or copy need updating, then rebuild the DMG.

import Cocoa

let W = 800
let H = 372   // window height 400 − 28 px title bar = no scrollbar

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Cream gradient: #faf7f0 (top) → #ece6d8 (bottom)
let top    = NSColor(calibratedRed: 0xfa/255, green: 0xf7/255, blue: 0xf0/255, alpha: 1)
let bottom = NSColor(calibratedRed: 0xec/255, green: 0xe6/255, blue: 0xd8/255, alpha: 1)
NSGradient(starting: top, ending: bottom)?.draw(
    in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

func drawCentered(_ s: String, yFromTop: CGFloat, font: NSFont, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .kern: -0.2,
    ]
    let sz = s.size(withAttributes: attrs)
    let r = NSRect(
        x: (CGFloat(W) - sz.width) / 2,
        y: CGFloat(H) - yFromTop - sz.height,
        width: sz.width, height: sz.height)
    s.draw(in: r, withAttributes: attrs)
}

// Ink colour #23243a
let ink       = NSColor(calibratedRed: 0x23/255, green: 0x24/255, blue: 0x3a/255, alpha: 1.00)
let secondary = NSColor(calibratedRed: 0x23/255, green: 0x24/255, blue: 0x3a/255, alpha: 0.62)
let arrowCol  = NSColor(calibratedRed: 0x23/255, green: 0x24/255, blue: 0x3a/255, alpha: 0.48)

drawCentered("Install TypeCue",             yFromTop: 40,  font: .systemFont(ofSize: 30, weight: .bold),    color: ink)
drawCentered("Drag TypeCue to Applications", yFromTop: 82,  font: .systemFont(ofSize: 16, weight: .regular), color: secondary)
drawCentered("\u{2192}",                    yFromTop: 162, font: .systemFont(ofSize: 46, weight: .regular), color: arrowCol)

NSGraphicsContext.restoreGraphicsState()

let outURL = URL(fileURLWithPath: "build/dmg_background.png")
try FileManager.default.createDirectory(
    at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let data = rep.representation(using: .png, properties: [:])!
try data.write(to: outURL)
print("wrote \(outURL.path)  (\(W)×\(H) px)")
