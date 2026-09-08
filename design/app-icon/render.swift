#!/usr/bin/swift
//
// UniEnter app icon renderer.
//
// Draws a flat macOS-style rounded-square tile with the same return-arrow
// "↵" glyph geometry used in site/public/favicon.svg (M45 21 V35 H19 +
// arrowhead M27 27 19 35 27 43, in a 64x64 box, stroke 6, round caps/joins),
// scaled up onto the standard macOS icon grid (tile ~= 824/1024 of the
// canvas, corner radius ~= 185/1024, centered).
//
// Usage:
//   swift render.swift <canvasSize> <tileHex> <glyphHex> <outPath> [gradient]
//
//   canvasSize  Int, pixel size of the (square) output image, e.g. 1024
//   tileHex     "#RRGGBB" fill color of the rounded-square tile
//   glyphHex    "#RRGGBB" color of the return-arrow glyph
//   outPath     output PNG path
//   gradient    optional: "1" to add a very subtle top-to-bottom lightening
//               (<=6% mix toward white at the top) inside the tile. Default 0.
//
// No external dependencies -- pure CoreGraphics/ImageIO, exact pixel control.

import CoreGraphics
import Foundation
import ImageIO
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 5 else {
    fail("usage: swift render.swift <canvasSize> <tileHex> <glyphHex> <outPath> [gradient]")
}

guard let canvasSize = Double(args[1]) else { fail("bad canvasSize: \(args[1])") }
let tileHex = args[2]
let glyphHex = args[3]
let outPath = args[4]
let useGradient = args.count >= 6 && (args[5] == "1" || args[5].lowercased() == "true")

func parseHex(_ hex: String) -> (r: Double, g: Double, b: Double) {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { fail("bad hex color: \(hex)") }
    let r = Double((v >> 16) & 0xFF) / 255.0
    let g = Double((v >> 8) & 0xFF) / 255.0
    let b = Double(v & 0xFF) / 255.0
    return (r, g, b)
}

func lighten(_ c: (r: Double, g: Double, b: Double), by fraction: Double) -> (r: Double, g: Double, b: Double) {
    // Mix `fraction` of the way toward white -- a subtle, flat-looking lightening.
    (
        r: c.r + (1.0 - c.r) * fraction,
        g: c.g + (1.0 - c.g) * fraction,
        b: c.b + (1.0 - c.b) * fraction
    )
}

let tileColor = parseHex(tileHex)
let glyphColor = parseHex(glyphHex)

// --- macOS icon grid geometry (fractions of the full canvas) ---
let tileFrac: Double = 824.0 / 1024.0
let radiusFrac: Double = 185.0 / 1024.0

let tileSize = canvasSize * tileFrac
let cornerRadius = canvasSize * radiusFrac
let margin = (canvasSize - tileSize) / 2.0

// --- glyph geometry, reused from favicon.svg's 64x64 box, scaled onto the tile ---
// favicon: rect 0,0,64,64 rx14; glyph stroke-width 6, round caps/joins:
//   path 1: M45 21 V35 H19
//   path 2 (arrowhead): M27 27 19 35 27 43
let glyphBoxSize = 64.0
var glyphScale = tileSize / glyphBoxSize
var strokeWidth = 6.0 * glyphScale

// Small-size legibility boost: thicken the stroke and enlarge the glyph
// slightly relative to the tile at the sizes where menu-bar-scale detail
// would otherwise vanish.
if canvasSize <= 16.0 {
    glyphScale *= 1.25
    strokeWidth = 6.0 * (tileSize / glyphBoxSize) * 1.45
} else if canvasSize <= 32.0 {
    glyphScale *= 1.15
    strokeWidth = 6.0 * (tileSize / glyphBoxSize) * 1.30
}

// Recenter the (possibly boosted) glyph within the tile. The favicon glyph's
// own bounding box within its 64x64 box (including stroke half-width) is
// roughly x:[16,48] y:[18,46] -- centered close to (32,32). We map glyph
// space (0...64) to canvas space using glyphScale, anchored so the glyph's
// geometric center (32,32 in glyph space) lands on the tile's center.
let tileCenterX = margin + tileSize / 2.0
let tileCenterY = margin + tileSize / 2.0
func mapGlyphPoint(_ gx: Double, _ gy: Double) -> (x: Double, y: Double) {
    let x = tileCenterX + (gx - 32.0) * glyphScale
    let y = tileCenterY + (gy - 32.0) * glyphScale
    return (x, y)
}

// --- build the bitmap context (RGBA, premultiplied, transparent background) ---
let width = Int(canvasSize.rounded())
let height = Int(canvasSize.rounded())
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fail("could not create CGContext") }

// Flip to a top-left, y-down coordinate system matching the geometry above (SVG-like).
ctx.translateBy(x: 0, y: canvasSize)
ctx.scaleBy(x: 1, y: -1)

// --- rounded-square tile ---
let tileRect = CGRect(x: margin, y: margin, width: tileSize, height: tileSize)
let tilePath = CGPath(roundedRect: tileRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()

if useGradient {
    let top = lighten(tileColor, by: 0.06)
    let bottom = tileColor
    let colors = [
        CGColor(red: top.r, green: top.g, blue: top.b, alpha: 1.0),
        CGColor(red: bottom.r, green: bottom.g, blue: bottom.b, alpha: 1.0)
    ] as CFArray
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else {
        fail("could not create gradient")
    }
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: canvasSize / 2, y: margin),
        end: CGPoint(x: canvasSize / 2, y: margin + tileSize),
        options: []
    )
} else {
    ctx.setFillColor(CGColor(red: tileColor.r, green: tileColor.g, blue: tileColor.b, alpha: 1.0))
    ctx.fill(tileRect)
}
ctx.restoreGState()

// --- glyph: return arrow "↵" ---
let p1 = mapGlyphPoint(45, 21)
let p2 = mapGlyphPoint(45, 35)
let p3 = mapGlyphPoint(19, 35)

let a1 = mapGlyphPoint(27, 27)
let a2 = mapGlyphPoint(19, 35)
let a3 = mapGlyphPoint(27, 43)

let glyphPath = CGMutablePath()
glyphPath.move(to: CGPoint(x: p1.x, y: p1.y))
glyphPath.addLine(to: CGPoint(x: p2.x, y: p2.y))
glyphPath.addLine(to: CGPoint(x: p3.x, y: p3.y))

glyphPath.move(to: CGPoint(x: a1.x, y: a1.y))
glyphPath.addLine(to: CGPoint(x: a2.x, y: a2.y))
glyphPath.addLine(to: CGPoint(x: a3.x, y: a3.y))

ctx.setStrokeColor(CGColor(red: glyphColor.r, green: glyphColor.g, blue: glyphColor.b, alpha: 1.0))
ctx.setLineWidth(strokeWidth)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addPath(glyphPath)
ctx.strokePath()

// --- write PNG ---
guard let image = ctx.makeImage() else { fail("could not render image") }

let outURL = URL(fileURLWithPath: outPath)
let utType: CFString
if #available(macOS 11.0, *) {
    utType = UTType.png.identifier as CFString
} else {
    utType = "public.png" as CFString
}
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, utType, 1, nil) else {
    fail("could not create image destination at \(outPath)")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fail("could not finalize PNG at \(outPath)") }

print("wrote \(outPath) (\(width)x\(height))")
