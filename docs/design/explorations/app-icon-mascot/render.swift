import AppKit
import SwiftUI
import Foundation

// Design discussion only. This renderer never writes the AppIcon asset catalog.
// Compile with the existing CloudMascotMotion and CloudMascotDrawing (see README).
// The mascot itself is rendered by the same Canvas used by the native App.

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

private func fillGradient(_ colors: [UInt32], path: NSBezierPath, angle: CGFloat = -75) {
    NSGradient(colors: colors.map { color($0) })!.draw(in: path, angle: angle)
}

private func bitmap(width: Int, height: Int, draw: () -> Void) -> NSBitmapImageRep {
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

private func rounded(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

private func shadowed(_ path: NSBezierPath, fill: UInt32, blur: CGFloat = 28, offset: CGFloat = -14) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x30203F, alpha: 0.18)
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: offset)
    shadow.set()
    color(fill).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
}

private func wave(left: CGFloat, right: CGFloat, level: CGFloat, floor: CGFloat, amplitude: CGFloat) -> NSBezierPath {
    let middle = (left + right) / 2, width = right - left
    let path = NSBezierPath()
    path.move(to: NSPoint(x: left, y: level))
    path.curve(to: NSPoint(x: middle, y: level),
        controlPoint1: NSPoint(x: left + width * 0.18, y: level + amplitude),
        controlPoint2: NSPoint(x: middle - width * 0.18, y: level - amplitude))
    path.curve(to: NSPoint(x: right, y: level + amplitude * 0.13),
        controlPoint1: NSPoint(x: middle + width * 0.18, y: level + amplitude),
        controlPoint2: NSPoint(x: right - width * 0.18, y: level + amplitude))
    path.line(to: NSPoint(x: right, y: floor))
    path.line(to: NSPoint(x: left, y: floor))
    path.close()
    return path
}

private func mascot(_ image: NSImage, in rect: NSRect, shadow: Bool = true) {
    NSGraphicsContext.saveGraphicsState()
    if shadow {
        let effect = NSShadow()
        effect.shadowColor = color(0x3A254A, alpha: 0.22)
        effect.shadowBlurRadius = rect.width * 0.038
        effect.shadowOffset = NSSize(width: 0, height: -rect.width * 0.024)
        effect.set()
    }
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

private func drawA(mascot cloud: NSImage) {
    fillGradient([0xFBF8F5, 0xECE5F5], path: NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)))
    // An uncluttered face is the primary mark; the shallow liquid tray is secondary.
    let tray = rounded(NSRect(x: 183, y: 147, width: 658, height: 157), radius: 77)
    shadowed(tray, fill: 0xDDD0EA, blur: 25, offset: -12)
    fillGradient([0xE4D8F0, 0xBEA8D5], path: tray)
    NSGraphicsContext.saveGraphicsState()
    tray.addClip()
    fillGradient([0xCEB9E2, 0xAF91CC], path: wave(left: 175, right: 850, level: 247, floor: 130, amplitude: 19))
    NSGraphicsContext.restoreGraphicsState()
    mascot(cloud, in: NSRect(x: 65, y: 195, width: 894, height: 830))
}

private func drawB(mascot cloud: NSImage) {
    fillGradient([0xF5F0F8, 0xE9E0F0], path: NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)))
    let back = rounded(NSRect(x: 235, y: 333, width: 554, height: 375), radius: 93)
    shadowed(back, fill: 0xFDF9FD, blur: 26, offset: -15)
    fillGradient([0xFFFBFF, 0xDBCEE8], path: back)
    mascot(cloud, in: NSRect(x: 154, y: 352, width: 716, height: 664))

    // The dipped opening hides only the lower body; both eyes stay fully visible.
    let pocket = NSBezierPath()
    pocket.move(to: NSPoint(x: 151, y: 526))
    pocket.curve(to: NSPoint(x: 512, y: 449), controlPoint1: NSPoint(x: 306, y: 534), controlPoint2: NSPoint(x: 309, y: 449))
    pocket.curve(to: NSPoint(x: 873, y: 526), controlPoint1: NSPoint(x: 715, y: 449), controlPoint2: NSPoint(x: 718, y: 534))
    pocket.line(to: NSPoint(x: 873, y: 281))
    pocket.curve(to: NSPoint(x: 759, y: 166), controlPoint1: NSPoint(x: 873, y: 205), controlPoint2: NSPoint(x: 836, y: 166))
    pocket.line(to: NSPoint(x: 265, y: 166))
    pocket.curve(to: NSPoint(x: 151, y: 281), controlPoint1: NSPoint(x: 188, y: 166), controlPoint2: NSPoint(x: 151, y: 205))
    pocket.close()
    shadowed(pocket, fill: 0x80619B, blur: 34, offset: -18)
    fillGradient([0x9B80B9, 0x6B4B89], path: pocket, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    pocket.addClip()
    fillGradient([0xBDA4D4, 0x8C6BA8], path: wave(left: 145, right: 880, level: 336, floor: 140, amplitude: 28))
    NSGraphicsContext.restoreGraphicsState()
    let lip = NSBezierPath()
    lip.move(to: NSPoint(x: 159, y: 524))
    lip.curve(to: NSPoint(x: 512, y: 449), controlPoint1: NSPoint(x: 306, y: 534), controlPoint2: NSPoint(x: 309, y: 449))
    lip.curve(to: NSPoint(x: 865, y: 524), controlPoint1: NSPoint(x: 715, y: 449), controlPoint2: NSPoint(x: 718, y: 534))
    color(0xF8EFFD, alpha: 0.62).setStroke()
    lip.lineWidth = 5
    lip.stroke()
}

private func drawC(mascot cloud: NSImage) {
    fillGradient([0x8F79A8, 0x5E4973], path: NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)))
    let card = rounded(NSRect(x: 148, y: 183, width: 728, height: 623), radius: 132)
    shadowed(card, fill: 0xFAF5FE, blur: 35, offset: -17)
    fillGradient([0xFFFCFA, 0xEDE5F4], path: card, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    card.addClip()
    fillGradient([0xCEBAE0, 0xAA8CC5], path: wave(left: 140, right: 884, level: 469, floor: 160, amplitude: 31), angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    color(0xB9A6CD).setFill()
    rounded(NSRect(x: 280, y: 655, width: 253, height: 24), radius: 12).fill()
    mascot(cloud, in: NSRect(x: 545, y: 601, width: 450, height: 417))
}

private func text(_ value: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight = .regular, ink: UInt32 = 0x302A38) {
    (value as NSString).draw(at: point, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color(ink)])
}

private func drawMasked(_ image: NSImage, in rect: NSRect) {
    NSGraphicsContext.saveGraphicsState()
    rounded(rect, radius: rect.width * 0.225).addClip()
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

@main
struct MascotIconStudy {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("docs/design/explorations/app-icon-mascot")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let renderer = ImageRenderer(content: CloudMascotDrawing(frame: CloudMascotMotion.sample(.idle, elapsed: 0, reduced: true)).frame(width: 1024, height: 951))
        renderer.scale = 1
        guard let cg = renderer.cgImage else { fatalError("Native Xiaoduo renderer returned no image") }
        let cloud = NSImage(cgImage: cg, size: NSSize(width: 1024, height: 951))
        let draws: [(String, (NSImage) -> Void)] = [("a-mascot", drawA), ("b-pocket", drawB), ("c-card", drawC)]
        var images: [NSImage] = []
        for (name, draw) in draws {
            let rep = bitmap(width: 1024, height: 1024) { draw(cloud) }
            let image = NSImage(size: NSSize(width: 1024, height: 1024))
            image.addRepresentation(rep)
            images.append(image)
            try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name).png"))
        }
        let board = bitmap(width: 1560, height: 1120) {
            color(0xF5F4F1).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1560, height: 1120)).fill()
            text("CheckLine · 小朵 App Icon 构图探索", at: NSPoint(x: 72, y: 1025), size: 34, weight: .semibold)
            text("候选未接受 · 复用原生小朵，未替换 App 图标", at: NSPoint(x: 72, y: 980), size: 21, ink: 0x645B6D)
            let titles = ["A  小朵为主", "B  从卡夹探出", "C  预算卡＋小朵"]
            let notes = ["角色辨识优先，液面作为辅助", "预算卡夹与角色结合", "预算主体，角色作角标"]
            for (index, image) in images.enumerated() {
                let x = CGFloat(72 + index * 500)
                text(titles[index], at: NSPoint(x: x, y: 897), size: 27, weight: .semibold)
                drawMasked(image, in: NSRect(x: x, y: 470, width: 416, height: 416))
                text(notes[index], at: NSPoint(x: x, y: 420), size: 21, ink: 0x645B6D)
                // Native-size thumbnails on both light and dark desktop surfaces.
                for (row, background) in [UInt32(0xEBE7F0), UInt32(0x25202E)].enumerated() {
                    let y = CGFloat(252 - row * 113)
                    color(background).setFill()
                    rounded(NSRect(x: x, y: y, width: 416, height: 95), radius: 23).fill()
                    drawMasked(image, in: NSRect(x: x + 24, y: y + 17, width: 60, height: 60))
                    drawMasked(image, in: NSRect(x: x + 198, y: y + 31, width: 32, height: 32))
                    text("60 px", at: NSPoint(x: x + 98, y: y + 36), size: 18, ink: row == 0 ? 0x645B6D : 0xC1B5CF)
                    text("32 px", at: NSPoint(x: x + 244, y: y + 36), size: 18, ink: row == 0 ? 0x645B6D : 0xC1B5CF)
                }
            }
            text("先选「小朵与预算」的主次；深色、系统着色与最终精修随后验证。", at: NSPoint(x: 72, y: 66), size: 21, ink: 0x645B6D)
        }
        let boardFile = output.appendingPathComponent("mascot-icon-comparison.png")
        try board.representation(using: .png, properties: [:])!.write(to: boardFile)
        print(boardFile.path)
    }
}
