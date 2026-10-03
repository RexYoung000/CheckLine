import AppKit
import Foundation

// Original CheckLine mark: one budget boundary, one liquid surface.
// Run from the repository root: swift docs/design/explorations/app-icon-study/render.swift
// The source images are opaque squares. The operating system owns the outer mask.

struct Palette {
    let name: String
    let background: [UInt32]
    let card: [UInt32]
    let liquid: [UInt32]
    let edge: UInt32
}

let palettes = [
    Palette(name: "light", background: [0x9380AC, 0x645175], card: [0xFEFCF8, 0xF0E9F5], liquid: [0xC6B5DB, 0x9B83B6], edge: 0xFFFBFF),
    Palette(name: "dark", background: [0x2E263B, 0x17141F], card: [0x645371, 0x4A3D58], liquid: [0xDECEF0, 0xB9A0D2], edge: 0xA58ABB),
    Palette(name: "tinted", background: [0x383838, 0x1C1C1C], card: [0x8E8E8E, 0x696969], liquid: [0xECECEC, 0xC2C2C2], edge: 0xAEAEAE)
]

let baseDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = baseDirectory.appendingPathComponent("Check_Line/Assets.xcassets/AppIcon.appiconset")
let studyDirectory = baseDirectory.appendingPathComponent("docs/design/explorations/app-icon-study")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: studyDirectory, withIntermediateDirectories: true)

func color(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: CGFloat((value >> 16) & 255) / 255,
            green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: alpha)
}

func gradient(_ colors: [UInt32], in path: NSBezierPath, angle: CGFloat = -62) {
    NSGradient(colors: colors.map { color($0) })!.draw(in: path, angle: angle)
}

func liquidPath() -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 164, y: 492))
    path.curve(to: NSPoint(x: 512, y: 492),
               controlPoint1: NSPoint(x: 282, y: 530),
               controlPoint2: NSPoint(x: 392, y: 456))
    path.curve(to: NSPoint(x: 860, y: 502),
               controlPoint1: NSPoint(x: 637, y: 530),
               controlPoint2: NSPoint(x: 746, y: 528))
    path.line(to: NSPoint(x: 860, y: 176))
    path.line(to: NSPoint(x: 164, y: 176))
    path.close()
    return path
}

func drawMark(palette: Palette) {
    let canvas = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024))
    gradient(palette.background, in: canvas)

    // A single large card is legible at home-screen size, without tiny symbols.
    let cardRect = NSRect(x: 176, y: 216, width: 672, height: 592)
    let card = NSBezierPath(roundedRect: cardRect, xRadius: 132, yRadius: 132)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x21172E, alpha: palette.name == "light" ? 0.2 : 0.28)
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 0, height: -20)
    shadow.set()
    color(palette.card[0]).setFill()
    card.fill()
    NSGraphicsContext.restoreGraphicsState()

    gradient(palette.card, in: card, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    card.addClip()
    gradient(palette.liquid, in: liquidPath(), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // This quiet upper rule echoes the budget boundary, not a bank-card number.
    let boundary = NSBezierPath(roundedRect: NSRect(x: 306, y: 659, width: 412, height: 24), xRadius: 12, yRadius: 12)
    color(palette.name == "light" ? 0xB5A5C9 : palette.name == "dark" ? 0xB9A4D1 : 0xCECECE).setFill()
    boundary.fill()

    color(palette.edge, alpha: palette.name == "light" ? 0.72 : 0.36).setStroke()
    card.lineWidth = 6
    card.stroke()
}

func bitmap(width: Int, height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let context = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current!.imageInterpolation = .high
    NSGraphicsContext.current!.shouldAntialias = true
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: context.makeImage()!)
}

var images: [NSImage] = []
for palette in palettes {
    let representation = bitmap(width: 1024, height: 1024) { drawMark(palette: palette) }
    let image = NSImage(size: NSSize(width: 1024, height: 1024))
    image.addRepresentation(representation)
    images.append(image)
    let file = outputDirectory.appendingPathComponent("CheckLine-\(palette.name).png")
    try representation.representation(using: .png, properties: [:])!.write(to: file)
    print(file.path)
}

// Preview uses masks solely to show typical desktop presentation.
let preview = bitmap(width: 1440, height: 920) {
    color(0xF5F4F1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1440, height: 920)).fill()
    let labels = ["浅色", "深色", "系统着色"]
    for (index, image) in images.enumerated() {
        let x = CGFloat(70 + 470 * index)
        let rect = NSRect(x: x, y: 362, width: 360, height: 360)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: 80, yRadius: 80).addClip()
        image.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()

        let titleAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 26, weight: .medium), .foregroundColor: color(0x302A38)]
        (labels[index] as NSString).draw(at: NSPoint(x: x, y: 754), withAttributes: titleAttributes)
        for (offset, size) in [60, 40, 29].enumerated() {
            let iconRect = NSRect(x: x + CGFloat(offset * 116), y: 210, width: CGFloat(size), height: CGFloat(size))
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: iconRect, xRadius: CGFloat(size) * 0.225, yRadius: CGFloat(size) * 0.225).addClip()
            image.draw(in: iconRect)
            NSGraphicsContext.restoreGraphicsState()
            ("\(size) pt" as NSString).draw(at: NSPoint(x: iconRect.minX, y: 167), withAttributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: color(0x645B6D)])
        }
    }
    ("CheckLine · 单卡液面 / App Icon 试用" as NSString).draw(at: NSPoint(x: 70, y: 850), withAttributes: [.font: NSFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: color(0x302A38)])
    ("预览中的外圆角由系统裁切；导出源图均为不透明正方形。" as NSString).draw(at: NSPoint(x: 70, y: 76), withAttributes: [.font: NSFont.systemFont(ofSize: 18), .foregroundColor: color(0x645B6D)])
}
let previewFile = studyDirectory.appendingPathComponent("app-icon-preview.png")
try preview.representation(using: .png, properties: [:])!.write(to: previewFile)
print(previewFile.path)
