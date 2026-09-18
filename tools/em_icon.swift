#!/usr/bin/env swift
// em_icon.swift — renders the iPhoneEM app icon and packs an .icns
// Apple-style macOS icon: dark squircle tile, a meticulously rendered device,
// layered highlights (no flat shapes, no gradient soup).
import AppKit
import Foundation

let outputDirectory = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1]) : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)


/// Apple-style continuous corner (squircle) path.
func squircle(_ rect: NSRect, _ radius: CGFloat, k: CGFloat = 0.52) -> NSBezierPath {
    let r = min(radius, min(rect.width, rect.height) / 2)
    let x0 = rect.minX, x1 = rect.maxX, y0 = rect.minY, y1 = rect.maxY
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x0 + r, y: y0))
    path.line(to: NSPoint(x: x1 - r, y: y0))
    path.curve(to: NSPoint(x: x1, y: y0 + r),
               controlPoint1: NSPoint(x: x1 - r + r * k, y: y0),
               controlPoint2: NSPoint(x: x1, y: y0 + r - r * k))
    path.line(to: NSPoint(x: x1, y: y1 - r))
    path.curve(to: NSPoint(x: x1 - r, y: y1),
               controlPoint1: NSPoint(x: x1, y: y1 - r + r * k),
               controlPoint2: NSPoint(x: x1 - r + r * k, y: y1))
    path.line(to: NSPoint(x: x0 + r, y: y1))
    path.curve(to: NSPoint(x: x0, y: y1 - r),
               controlPoint1: NSPoint(x: x0 + r - r * k, y: y1),
               controlPoint2: NSPoint(x: x0, y: y1 - r + r * k))
    path.line(to: NSPoint(x: x0, y: y0 + r))
    path.curve(to: NSPoint(x: x0 + r, y: y0),
               controlPoint1: NSPoint(x: x0, y: y0 + r - r * k),
               controlPoint2: NSPoint(x: x0 + r - r * k, y: y0))
    path.close()
    return path
}

func drawIcon(size S: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: S, height: S))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // ── tile (Apple squircle proportions) ───────────────────────────────
    let inset = S * 0.055
    let tile = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
    let tileRadius = tile.width * 0.2237
    let tilePath = squircle(tile, tileRadius)

    ctx.saveGState()
    tilePath.addClip()

    // quiet two-step background
    if let bg = NSGradient(colorsAndLocations:
        (NSColor(srgbRed: 0.133, green: 0.141, blue: 0.165, alpha: 1), 0.0),
        (NSColor(srgbRed: 0.098, green: 0.105, blue: 0.125, alpha: 1), 0.55),
        (NSColor(srgbRed: 0.071, green: 0.075, blue: 0.090, alpha: 1), 1.0)) {
        bg.draw(in: tile, angle: -90)
    }

    // ── device ──────────────────────────────────────────────────────────
    let w = tile.width * 0.420
    let h = tile.height * 0.682
    let device = NSRect(x: tile.midX - w / 2, y: tile.midY - h / 2 + tile.height * 0.008, width: w, height: h)
    let deviceRadius = w * 0.243
    let devicePath = squircle(device, deviceRadius)

    // ambient glow: radial, so it dies out before it can touch the tile edge
    if let glow = NSGradient(colorsAndLocations:
        (NSColor(srgbRed: 0.38, green: 0.57, blue: 1.0, alpha: 0.16), 0.00),
        (NSColor(srgbRed: 0.38, green: 0.57, blue: 1.0, alpha: 0.10), 0.32),
        (NSColor(srgbRed: 0.38, green: 0.57, blue: 1.0, alpha: 0.035), 0.60),
        (NSColor(srgbRed: 0.38, green: 0.57, blue: 1.0, alpha: 0.0), 0.92)) {
        let radius = tile.width * 0.80
        let circle = NSBezierPath(ovalIn: NSRect(x: device.midX - radius, y: device.midY - radius,
                                                 width: radius * 2, height: radius * 2))
        glow.draw(in: circle, relativeCenterPosition: .zero)
    }

    // contact shadow under the device
    ctx.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.65)
    shadow.shadowBlurRadius = S * 0.05
    shadow.shadowOffset = NSSize(width: 0, height: -S * 0.016)
    shadow.set()
    NSColor(srgbRed: 0.09, green: 0.09, blue: 0.11, alpha: 1).setFill()
    devicePath.fill()
    ctx.restoreGState()

    // metallic frame
    ctx.saveGState()
    devicePath.addClip()
    if let frame = NSGradient(colorsAndLocations:
        (NSColor(srgbRed: 0.949, green: 0.957, blue: 0.973, alpha: 1), 0.00),
        (NSColor(srgbRed: 0.784, green: 0.804, blue: 0.839, alpha: 1), 0.14),
        (NSColor(srgbRed: 0.588, green: 0.608, blue: 0.643, alpha: 1), 0.34),
        (NSColor(srgbRed: 0.400, green: 0.416, blue: 0.447, alpha: 1), 0.56),
        (NSColor(srgbRed: 0.267, green: 0.278, blue: 0.302, alpha: 1), 0.78),
        (NSColor(srgbRed: 0.216, green: 0.224, blue: 0.243, alpha: 1), 1.00)) {
        frame.draw(in: device, angle: 42)
    }
    ctx.restoreGState()

    // rim: bright where the light hits, faint elsewhere
    ctx.saveGState()
    devicePath.addClip()
    if let rim = NSGradient(colorsAndLocations:
        (NSColor(white: 1, alpha: 0.75), 0.0),
        (NSColor(white: 1, alpha: 0.22), 0.28),
        (NSColor(white: 1, alpha: 0.06), 0.58),
        (NSColor(white: 1, alpha: 0.24), 1.0)) {
        let stroke = squircle(device.insetBy(dx: S * 0.0016, dy: S * 0.0016), deviceRadius)
        stroke.lineWidth = S * 0.0032
        stroke.setClip()
        rim.draw(in: device, angle: 42)
    }
    ctx.restoreGState()

    // side buttons
    func nub(_ x: CGFloat, _ y: CGFloat, _ height: CGFloat, _ bright: Bool) {
        let bw = max(1.2, S * 0.006)
        let bar = NSRect(x: x, y: y, width: bw, height: height)
        if let gradient = NSGradient(colorsAndLocations:
            (NSColor(white: bright ? 0.80 : 0.52, alpha: 1), 0.0),
            (NSColor(white: bright ? 0.46 : 0.28, alpha: 1), 1.0)) {
            gradient.draw(in: NSBezierPath(roundedRect: bar, xRadius: bw / 2, yRadius: bw / 2), angle: -90)
        }
    }
    nub(device.minX - S * 0.0038, device.minY + h * 0.578, h * 0.070, false)
    nub(device.minX - S * 0.0038, device.minY + h * 0.462, h * 0.090, false)
    nub(device.minX - S * 0.0038, device.minY + h * 0.346, h * 0.090, false)
    nub(device.maxX - S * 0.0022, device.minY + h * 0.508, h * 0.120, true)

    // ── screen ──────────────────────────────────────────────────────────
    let bezel = w * 0.038
    let screen = device.insetBy(dx: bezel, dy: bezel)
    let screenRadius = deviceRadius - bezel * 0.70
    let screenPath = squircle(screen, screenRadius)

    ctx.saveGState()
    screenPath.addClip()
    // wallpaper
    if let wallpaper = NSGradient(colorsAndLocations:
        (NSColor(srgbRed: 0.145, green: 0.243, blue: 0.639, alpha: 1), 0.00),
        (NSColor(srgbRed: 0.180, green: 0.396, blue: 0.965, alpha: 1), 0.34),
        (NSColor(srgbRed: 0.404, green: 0.353, blue: 0.980, alpha: 1), 0.70),
        (NSColor(srgbRed: 0.635, green: 0.376, blue: 0.945, alpha: 1), 1.00)) {
        wallpaper.draw(in: screen, angle: -74)
    }
    // light falling from the top, fading over the first third
    if let light = NSGradient(colorsAndLocations:
        (NSColor(white: 1, alpha: 0.22), 0.0),
        (NSColor(white: 1, alpha: 0.06), 0.55),
        (NSColor(white: 1, alpha: 0.0), 1.0)) {
        light.draw(in: NSRect(x: screen.minX, y: screen.midY, width: screen.width, height: screen.height / 2),
                   angle: -90)
    }
    // glass sweep
    if let sweep = NSGradient(colorsAndLocations:
        (NSColor(white: 1, alpha: 0.13), 0.0),
        (NSColor(white: 1, alpha: 0.0), 1.0)) {
        sweep.draw(in: NSRect(x: screen.minX, y: screen.maxY - screen.height * 0.38,
                              width: screen.width, height: screen.height * 0.38), angle: -80)
    }
    // grounded base: a hint of shadow at the bottom of the display
    if let base = NSGradient(colorsAndLocations:
        (NSColor(white: 0, alpha: 0.0), 0.0),
        (NSColor(white: 0, alpha: 0.16), 1.0)) {
        base.draw(in: NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height * 0.16),
                  angle: -90)
    }
    ctx.restoreGState()

    // island
    let islandWidth = w * 0.295
    let islandHeight = islandWidth * 0.275
    let island = NSRect(x: device.midX - islandWidth / 2,
                        y: screen.maxY - islandHeight - h * 0.021,
                        width: islandWidth, height: islandHeight)
    NSColor(white: 0.02, alpha: 1).setFill()
    NSBezierPath(roundedRect: island, xRadius: islandHeight / 2, yRadius: islandHeight / 2).fill()

    // black bezel ring: the display sits inside the frame
    ctx.saveGState()
    NSColor(srgbRed: 0.071, green: 0.075, blue: 0.086, alpha: 1).setStroke()
    let bezelRing = squircle(screen.insetBy(dx: -bezel * 0.26, dy: -bezel * 0.26), screenRadius + bezel * 0.18)
    bezelRing.lineWidth = bezel * 0.52
    bezelRing.stroke()
    ctx.restoreGState()

    // screen sits inside the bezel: a soft inner shadow sells the recess
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: S * 0.018, color: NSColor(white: 0, alpha: 0.5).cgColor)
    NSColor(white: 0, alpha: 0.001).setStroke()
    let ring = squircle(screen.insetBy(dx: -0.5, dy: -0.5), screenRadius)
    ring.lineWidth = 2.5
    ring.stroke()
    ctx.restoreGState()

    // ── tile edges ──────────────────────────────────────────────────────
    ctx.restoreGState()
    ctx.saveGState()
    tilePath.addClip()
    NSColor(white: 1, alpha: 0.075).setFill()
    NSRect(x: tile.minX, y: tile.maxY - S * 0.0035, width: tile.width, height: S * 0.0035).fill()
    NSColor(white: 1, alpha: 0.09).setStroke()
    tilePath.lineWidth = max(0.8, S * 0.002)
    tilePath.stroke()
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixelSize: Int) {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return }
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
}

let iconset = outputDirectory.appendingPathComponent("EMAppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, pixel) in variants {
    writePNG(drawIcon(size: CGFloat(pixel)), to: iconset.appendingPathComponent("\(name).png"), pixelSize: pixel)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", outputDirectory.appendingPathComponent("EMAppIcon.icns").path]
try? process.run()
process.waitUntilExit()
print("icon written to \(outputDirectory.appendingPathComponent("EMAppIcon.icns").path)")
