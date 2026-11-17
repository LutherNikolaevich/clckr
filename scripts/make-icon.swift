import AppKit

let iconsetSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let cursorOutline: [(x: CGFloat, y: CGFloat)] = [
    (0, 0), (0, -0.34), (0.085, -0.26), (0.15, -0.40),
    (0.21, -0.37), (0.145, -0.235), (0.255, -0.235),
]
let cursorTip = CGPoint(x: 0.40, y: 0.70)
let rippleRadii: [CGFloat] = [0.10, 0.18]

func render(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    let side = CGFloat(pixels)
    context.cgContext.scaleBy(x: side, y: side)

    let body = NSBezierPath(
        roundedRect: NSRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
        xRadius: 0.18, yRadius: 0.18)
    NSGradient(
        starting: NSColor(red: 0.29, green: 0.22, blue: 0.80, alpha: 1),
        ending: NSColor(red: 0.55, green: 0.30, blue: 0.92, alpha: 1)
    )!.draw(in: body, angle: -90)

    context.saveGraphicsState()
    body.addClip()
    for radius in rippleRadii {
        let ring = NSBezierPath(ovalIn: NSRect(
            x: cursorTip.x - radius, y: cursorTip.y - radius,
            width: radius * 2, height: radius * 2))
        ring.lineWidth = 0.022
        NSColor.white.withAlphaComponent(radius == rippleRadii[0] ? 0.55 : 0.28).setStroke()
        ring.stroke()
    }
    context.restoreGraphicsState()

    let cursor = NSBezierPath()
    for (index, point) in cursorOutline.enumerated() {
        let placed = CGPoint(x: cursorTip.x + point.x, y: cursorTip.y + point.y)
        index == 0 ? cursor.move(to: placed) : cursor.line(to: placed)
    }
    cursor.close()
    cursor.lineJoinStyle = .round
    cursor.lineWidth = 0.012
    NSColor.white.setFill()
    cursor.fill()
    NSColor.white.setStroke()
    cursor.stroke()

    NSGraphicsContext.current = nil
    return bitmap.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
let resources = root.appendingPathComponent("Resources")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

for entry in iconsetSizes {
    try render(pixels: entry.pixels).write(to: iconset.appendingPathComponent("\(entry.name).png"))
}

let converter = Process()
converter.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
converter.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try converter.run()
converter.waitUntilExit()
precondition(converter.terminationStatus == 0, "iconutil failed")
try FileManager.default.removeItem(at: iconset)
