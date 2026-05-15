import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let outputs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

var pngFiles: [String: Data] = [:]
for output in outputs {
    let data = drawIcon(size: Int(output.1))
    let url = iconset.appendingPathComponent(output.0)
    try data.write(to: url)
    pngFiles[output.0] = data
}

try drawIconTIFF(size: 1024).write(to: resources.appendingPathComponent("AppIcon.tiff"))
try makeICNS(from: pngFiles).write(to: resources.appendingPathComponent("AppIcon.icns"))

func drawIcon(size: Int) -> Data {
    let rep = drawIconRep(size: size)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    return data
}

func drawIconTIFF(size: Int) -> Data {
    drawIconRep(size: size).tiffRepresentation ?? Data()
}

func drawIconRep(size: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap context")
    }

    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let canvasSize = CGFloat(size)
    let scale = canvasSize / 1024.0
    let bounds = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
    NSColor.clear.setFill()
    bounds.fill()

    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }

    let appRect = rect(68, 68, 888, 888)
    let corner = 196 * scale
    let appPath = NSBezierPath(roundedRect: appRect, xRadius: corner, yRadius: corner)

    NSGraphicsContext.saveGraphicsState()
    NSShadow().apply(color: NSColor.black.withAlphaComponent(0.28), blur: 40 * scale, y: -18 * scale)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.19, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.28, blue: 0.31, alpha: 1)
    ])
    gradient?.draw(in: appPath, angle: 45)
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.16).setStroke()
    appPath.lineWidth = 10 * scale
    appPath.stroke()

    let folder = NSBezierPath()
    folder.move(to: NSPoint(x: 232 * scale, y: 326 * scale))
    folder.line(to: NSPoint(x: 232 * scale, y: 654 * scale))
    folder.curve(to: NSPoint(x: 286 * scale, y: 708 * scale), controlPoint1: NSPoint(x: 232 * scale, y: 686 * scale), controlPoint2: NSPoint(x: 254 * scale, y: 708 * scale))
    folder.line(to: NSPoint(x: 424 * scale, y: 708 * scale))
    folder.curve(to: NSPoint(x: 482 * scale, y: 666 * scale), controlPoint1: NSPoint(x: 456 * scale, y: 708 * scale), controlPoint2: NSPoint(x: 462 * scale, y: 666 * scale))
    folder.line(to: NSPoint(x: 738 * scale, y: 666 * scale))
    folder.curve(to: NSPoint(x: 792 * scale, y: 612 * scale), controlPoint1: NSPoint(x: 770 * scale, y: 666 * scale), controlPoint2: NSPoint(x: 792 * scale, y: 644 * scale))
    folder.line(to: NSPoint(x: 792 * scale, y: 326 * scale))
    folder.curve(to: NSPoint(x: 738 * scale, y: 272 * scale), controlPoint1: NSPoint(x: 792 * scale, y: 294 * scale), controlPoint2: NSPoint(x: 770 * scale, y: 272 * scale))
    folder.line(to: NSPoint(x: 286 * scale, y: 272 * scale))
    folder.curve(to: NSPoint(x: 232 * scale, y: 326 * scale), controlPoint1: NSPoint(x: 254 * scale, y: 272 * scale), controlPoint2: NSPoint(x: 232 * scale, y: 294 * scale))
    folder.close()

    NSGraphicsContext.saveGraphicsState()
    NSShadow().apply(color: NSColor.black.withAlphaComponent(0.30), blur: 22 * scale, y: -8 * scale)
    NSColor(calibratedRed: 0.80, green: 0.94, blue: 0.95, alpha: 1).setFill()
    folder.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedRed: 0.51, green: 0.80, blue: 0.82, alpha: 1).setStroke()
    folder.lineWidth = 8 * scale
    folder.stroke()

    let document = NSBezierPath(roundedRect: rect(356, 356, 312, 352), xRadius: 34 * scale, yRadius: 34 * scale)
    NSGraphicsContext.saveGraphicsState()
    NSShadow().apply(color: NSColor.black.withAlphaComponent(0.18), blur: 16 * scale, y: -6 * scale)
    NSColor.white.setFill()
    document.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.26, alpha: 0.22).setStroke()
    document.lineWidth = 6 * scale
    document.stroke()

    let hashAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 190 * scale, weight: .heavy),
        .foregroundColor: NSColor(calibratedRed: 0.05, green: 0.28, blue: 0.31, alpha: 1)
    ]
    let hash = NSString(string: "#")
    let hashSize = hash.size(withAttributes: hashAttributes)
    hash.draw(
        at: NSPoint(x: (512 * scale) - hashSize.width / 2, y: (532 * scale) - hashSize.height / 2),
        withAttributes: hashAttributes
    )

    let markAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 78 * scale, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.05, green: 0.28, blue: 0.31, alpha: 0.85)
    ]
    let mark = NSString(string: "MD")
    let markSize = mark.size(withAttributes: markAttributes)
    mark.draw(
        at: NSPoint(x: (512 * scale) - markSize.width / 2, y: 380 * scale),
        withAttributes: markAttributes
    )

    NSGraphicsContext.restoreGraphicsState()

    return rep
}

private extension NSShadow {
    func apply(color: NSColor, blur: CGFloat, y: CGFloat) {
        shadowColor = color
        shadowBlurRadius = blur
        shadowOffset = NSSize(width: 0, height: y)
        set()
    }
}

func makeICNS(from files: [String: Data]) -> Data {
    let chunks: [(String, String)] = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic14", "icon_256x256@2x.png")
    ]

    var body = Data()
    for chunk in chunks {
        guard let png = files[chunk.1] else { continue }
        body.append(chunk.0.data(using: .ascii)!)
        body.appendUInt32BE(UInt32(png.count + 8))
        body.append(png)
    }

    var data = Data()
    data.append("icns".data(using: .ascii)!)
    data.appendUInt32BE(UInt32(body.count + 8))
    data.append(body)
    return data
}

private extension Data {
    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }
}
