import AppKit
import Foundation

// Original vector artwork, rendered with AppKit at each icon size. No external assets.
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = output.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let bounds = NSRect(x: 70, y: 70, width: 884, height: 884)
        let shape = NSBezierPath(roundedRect: bounds, xRadius: 206, yRadius: 206)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = 35
        shadow.shadowOffset = NSSize(width: 0, height: -18)
        shadow.set()
        NSColor(calibratedRed: 0.03, green: 0.09, blue: 0.11, alpha: 1).setFill()
        shape.fill()
        NSShadow().set()
        NSGradient(colors: [NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.13, alpha: 1),
                            NSColor(calibratedRed: 0.13, green: 0.29, blue: 0.28, alpha: 1)])!.draw(in: shape, angle: 75)
        NSColor.white.withAlphaComponent(0.18).setStroke()
        shape.lineWidth = 3
        shape.stroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: 203, y: 203, width: 618, height: 618))
        NSColor(calibratedRed: 0.6, green: 1, blue: 0.85, alpha: 0.15).setStroke()
        ring.lineWidth = 3
        ring.stroke()
        let wave = NSBezierPath()
        wave.move(to: NSPoint(x: 270, y: 510))
        wave.curve(to: NSPoint(x: 390, y: 510), controlPoint1: NSPoint(x: 326, y: 510), controlPoint2: NSPoint(x: 338, y: 640))
        wave.curve(to: NSPoint(x: 510, y: 510), controlPoint1: NSPoint(x: 442, y: 380), controlPoint2: NSPoint(x: 454, y: 510))
        wave.curve(to: NSPoint(x: 630, y: 510), controlPoint1: NSPoint(x: 566, y: 510), controlPoint2: NSPoint(x: 578, y: 640))
        wave.curve(to: NSPoint(x: 754, y: 510), controlPoint1: NSPoint(x: 682, y: 380), controlPoint2: NSPoint(x: 698, y: 510))
        wave.lineWidth = 36
        wave.lineCapStyle = .round
        NSColor(calibratedRed: 0.63, green: 0.99, blue: 0.83, alpha: 1).setStroke()
        wave.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let destination = iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try rep.representation(using: .png, properties: [:])!.write(to: destination)
    }
}
let tool = Process()
tool.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
tool.arguments = ["-c", "icns", iconset.path, "-o", output.appendingPathComponent("AppIcon.icns").path]
try tool.run()
tool.waitUntilExit()
guard tool.terminationStatus == 0 else { exit(1) }
try FileManager.default.removeItem(at: iconset)
