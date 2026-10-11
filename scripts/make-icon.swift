import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
func render(size: Int, name: String) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "HoverCapture.Icon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let base = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 194, yRadius: 194)
    NSGradient(starting: NSColor(calibratedRed: 0.05, green: 0.25, blue: 0.33, alpha: 1),
        ending: NSColor(calibratedRed: 0.03, green: 0.58, blue: 0.61, alpha: 1))?.draw(in: base, angle: 50)
    NSColor.white.setStroke()
    let corners = NSBezierPath()
    corners.lineWidth = 38
    corners.lineCapStyle = .round
    corners.lineJoinStyle = .round
    for (x, y, dx, dy) in [(260.0, 764.0, 135.0, -135.0), (764, 764, -135, -135),
        (260, 260, 135, 135), (764, 260, -135, 135)] {
        corners.move(to: NSPoint(x: x + dx, y: y))
        corners.line(to: NSPoint(x: x, y: y))
        corners.line(to: NSPoint(x: x, y: y + dy))
    }
    corners.stroke()
    let pointer = NSBezierPath()
    pointer.move(to: NSPoint(x: 427, y: 669))
    pointer.line(to: NSPoint(x: 427, y: 361))
    pointer.line(to: NSPoint(x: 507, y: 430))
    pointer.line(to: NSPoint(x: 568, y: 312))
    pointer.line(to: NSPoint(x: 627, y: 343))
    pointer.line(to: NSPoint(x: 565, y: 461))
    pointer.line(to: NSPoint(x: 671, y: 482))
    pointer.close()
    NSColor.white.setFill()
    pointer.fill()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "HoverCapture.Icon", code: 2)
    }
    try png.write(to: destination.appendingPathComponent(name))
}
for size in [16, 32, 128, 256, 512] {
    try render(size: size, name: "icon_\(size)x\(size).png")
    try render(size: size * 2, name: "icon_\(size)x\(size)@2x.png")
}

// ICNS supports PNG payloads directly; writing the container avoids requiring
// an Xcode asset catalog or the icon conversion service at build time.
func bigEndian(_ number: UInt32) -> Data {
    var value = number.bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var elements = Data()
for (type, filename) in [
    ("ic07", "icon_128x128.png"), ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"), ("ic10", "icon_512x512@2x.png"),
    ("ic11", "icon_16x16@2x.png"), ("ic12", "icon_32x32@2x.png"),
    ("ic13", "icon_128x128@2x.png"), ("ic14", "icon_256x256@2x.png")
] {
    let png = try Data(contentsOf: destination.appendingPathComponent(filename))
    elements.append(Data(type.utf8))
    elements.append(bigEndian(UInt32(png.count + 8)))
    elements.append(png)
}
var icon = Data("icns".utf8)
icon.append(bigEndian(UInt32(elements.count + 8)))
icon.append(elements)
try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
