// Draws the app icon, a prompt chevron and a block cursor on a dark tile, into an
// .iconset folder that `iconutil` turns into AppIcon.icns.
//
// Usage: swift Scripts/make-icon.swift <output.iconset>

import AppKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.iconset>\n".utf8))
    exit(64)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// Renders the icon at `pixels` square. All geometry is laid out on a 1024-point canvas.
func render(pixels: Int) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: space, components: [red, green, blue, alpha])!
    }

    // The tile follows the macOS icon grid: 824 points square, centred, with soft corners.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0, 0, 0, 0.45))
    context.addPath(tilePath)
    context.setFillColor(color(0.039, 0.043, 0.047))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [color(0.098, 0.106, 0.114), color(0.031, 0.035, 0.039)] as CFArray,
        locations: [0, 1])!
    context.drawLinearGradient(
        gradient, start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: tile.minY), options: [])
    context.restoreGState()

    context.addPath(CGPath(
        roundedRect: tile.insetBy(dx: 3, dy: 3), cornerWidth: 183, cornerHeight: 183, transform: nil))
    context.setStrokeColor(color(1, 1, 1, 0.09))
    context.setLineWidth(6)
    context.strokePath()

    let green = color(0.45, 0.90, 0.62)

    // Prompt chevron.
    context.move(to: CGPoint(x: 322, y: 666))
    context.addLine(to: CGPoint(x: 476, y: 512))
    context.addLine(to: CGPoint(x: 322, y: 358))
    context.setStrokeColor(green)
    context.setLineWidth(68)
    context.setLineCap(.butt)
    context.setLineJoin(.miter)
    context.strokePath()

    // Block cursor.
    context.setFillColor(green)
    context.fill(CGRect(x: 556, y: 358, width: 160, height: 308))

    let image = context.makeImage()!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 1 ? "" : "@2x"
        let file = output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try render(pixels: points * scale).write(to: file)
    }
}
