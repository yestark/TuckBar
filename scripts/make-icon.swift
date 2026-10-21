// Deterministic, editable AppKit artwork; no external image dependencies.
import AppKit
import Foundation

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/TuckBar.iconset"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func render(size: Int) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(size) / 1024
    context.cgContext.scaleBy(x: scale, y: scale)

    // macOS icon silhouette, generous margins, midnight blue-to-teal.
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
                            xRadius: 190, yRadius: 190)
    let gradient = NSGradient(starting: NSColor(srgbRed: 0.10, green: 0.17, blue: 0.28, alpha: 1),
                              ending: NSColor(srgbRed: 0.06, green: 0.43, blue: 0.49, alpha: 1))!
    gradient.draw(in: tile, angle: 55)

    // Three menu extras tucked into a simple white pocket.
    NSColor.white.withAlphaComponent(0.93).setFill()
    for x in [CGFloat(340), 512, 684] {
        NSBezierPath(ovalIn: NSRect(x: x - 36, y: 600, width: 72, height: 72)).fill()
    }
    let pocket = NSBezierPath()
    pocket.move(to: NSPoint(x: 290, y: 510))
    pocket.line(to: NSPoint(x: 290, y: 375))
    pocket.curve(to: NSPoint(x: 350, y: 315), controlPoint1: NSPoint(x: 290, y: 335), controlPoint2: NSPoint(x: 310, y: 315))
    pocket.line(to: NSPoint(x: 674, y: 315))
    pocket.curve(to: NSPoint(x: 734, y: 375), controlPoint1: NSPoint(x: 714, y: 315), controlPoint2: NSPoint(x: 734, y: 335))
    pocket.line(to: NSPoint(x: 734, y: 510))
    pocket.lineWidth = 48
    pocket.lineCapStyle = .round
    pocket.lineJoinStyle = .round
    NSColor.white.setStroke()
    pocket.stroke()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 512, y: 558))
    arrow.line(to: NSPoint(x: 512, y: 425))
    arrow.move(to: NSPoint(x: 459, y: 475))
    arrow.line(to: NSPoint(x: 512, y: 422))
    arrow.line(to: NSPoint(x: 565, y: 475))
    arrow.lineWidth = 36
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: "\(output)/render-\(size).png"))
}
for size in [16, 32, 64, 128, 256, 512, 1024] { try render(size: size) }
for size in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let suffix = factor == 2 ? "@2x" : ""
        let source = "\(output)/render-\(size * factor).png"
        let target = "\(output)/icon_\(size)x\(size)\(suffix).png"
        if FileManager.default.fileExists(atPath: target) { try FileManager.default.removeItem(atPath: target) }
        try FileManager.default.copyItem(atPath: source, toPath: target)
    }
}
for size in [16, 32, 64, 128, 256, 512, 1024] {
    try FileManager.default.removeItem(atPath: "\(output)/render-\(size).png")
}
