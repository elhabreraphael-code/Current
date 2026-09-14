import AppKit
let directory = CommandLine.arguments[1]
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let tile = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 200, yRadius: 200)
        NSGradient(starting: NSColor(red: 0.88, green: 0.96, blue: 0.91, alpha: 1),
                   ending: NSColor(red: 0.61, green: 0.81, blue: 0.70, alpha: 1))!.draw(in: tile, angle: -70)
        NSColor.white.withAlphaComponent(0.5).setStroke()
        tile.lineWidth = 3
        tile.stroke()
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: 555, y: 809))
        bolt.line(to: NSPoint(x: 323, y: 481))
        bolt.curve(to: NSPoint(x: 339, y: 450), controlPoint1: NSPoint(x: 310, y: 463), controlPoint2: NSPoint(x: 321, y: 450))
        bolt.line(to: NSPoint(x: 483, y: 450))
        bolt.line(to: NSPoint(x: 451, y: 218))
        bolt.line(to: NSPoint(x: 705, y: 553))
        bolt.curve(to: NSPoint(x: 688, y: 584), controlPoint1: NSPoint(x: 718, y: 571), controlPoint2: NSPoint(x: 706, y: 584))
        bolt.line(to: NSPoint(x: 540, y: 584))
        bolt.close()
        NSColor(red: 0.16, green: 0.40, blue: 0.29, alpha: 1).setFill()
        bolt.fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to:
            URL(fileURLWithPath: directory).appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
