import SwiftUI

struct CloudMascotView: View {
    var state: CloudMascotState = .idle
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var player = CloudMascotPlayer()
    @State private var visible = false

    private var running: Bool { visible && scenePhase == .active && !reduceMotion }
    private var now: Double { ProcessInfo.processInfo.systemUptime }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { _ in
            CloudMascotDrawing(frame: player.frame(at: now))
        }
        .accessibilityHidden(true)
        .onAppear {
            visible = true
            player.setReduced(reduceMotion, at: now)
            player.select(state, at: now)
            player.setRunning(running, at: now)
        }
        .onDisappear { visible = false; player.setRunning(false, at: now) }
        .onChange(of: state) { _, value in player.select(value, at: now) }
        .onChange(of: running) { _, value in player.setRunning(value, at: now) }
        .onChange(of: reduceMotion) { _, value in
            player.setReduced(value, at: now)
            player.setRunning(running, at: now)
        }
    }
}

/// The same renderer supplies the static system Tab image and the animated panel.
struct CloudMascotDrawing: View {
    var frame: CloudMascotMotion.Frame
    var compact = false

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 224, size.height / 208) * (compact ? 1.18 : 1)
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: frame.offset.x, y: frame.offset.y)
            let shell = path(frame.outline), bounds = shell.boundingRect
            let start = CGPoint(x: bounds.minX + bounds.width * 0.05, y: bounds.minY)
            let end = CGPoint(x: bounds.minX + bounds.width * 0.68, y: bounds.maxY)
            let shellGradient = Gradient(stops: [
                .init(color: color(0x8976bd), location: 0), .init(color: color(0x4c317b), location: 0.18),
                .init(color: color(0x563496), location: 0.48), .init(color: color(0x7860c9), location: 0.79),
                .init(color: color(0xa698ed), location: 1)
            ])
            context.fill(shell, with: .linearGradient(shellGradient, startPoint: start, endPoint: end))
            context.drawLayer { inside in
                inside.clip(to: shell)
                inside.drawLayer { glow in
                    glow.addFilter(.blur(radius: compact ? 5 : 7))
                    glow.fill(Path(ellipseIn: CGRect(x: -38, y: 33, width: 94, height: 44)), with: .color(color(0xa99dff).opacity(0.76)))
                    for (i, light) in frame.lights.enumerated() {
                        var layer = glow
                        layer.translateBy(x: light.position.x, y: light.position.y)
                        layer.rotate(by: .degrees(light.angle))
                        layer.scaleBy(x: light.sx, y: light.sy)
                        layer.fill(path(light.contour), with: .color(color(i == 0 ? 0xe989bc : 0xffe1ac).opacity(light.opacity)))
                    }
                }
                inside.drawLayer { rim in
                    rim.addFilter(.blur(radius: 2.8))
                    rim.stroke(shell, with: .color(color(0x2c164d).opacity(0.48)), lineWidth: 9)
                    rim.stroke(shell, with: .linearGradient(rimGradient, startPoint: start, endPoint: end), lineWidth: 6)
                }
            }
            context.stroke(shell, with: .linearGradient(rimGradient, startPoint: start, endPoint: end), lineWidth: 0.85)
            for eye in frame.eyes {
                let eyePath = Path(ellipseIn: CGRect(x: eye.center.x - eye.rx, y: eye.center.y - eye.ry, width: eye.rx * 2, height: eye.ry * 2))
                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: 2))
                    glow.fill(eyePath, with: .color(color(0xfff5e9).opacity(0.42)))
                }
                context.fill(eyePath, with: .color(color(0xfffdf4)))
            }
            if frame.badge > 0 {
                var badge = context
                badge.opacity = frame.badge
                badge.fill(Path(ellipseIn: CGRect(x: 54, y: -61, width: 24, height: 24)), with: .color(color(0xf8efdf)))
                badge.fill(Path(ellipseIn: CGRect(x: 58, y: -57, width: 16, height: 16)), with: .color(color(0xa57b43)))
                if frame.error > 0 {
                    badge.opacity *= frame.error
                    var mark = Path(); mark.move(to: CGPoint(x: 66, y: -54)); mark.addLine(to: CGPoint(x: 66, y: -49))
                    badge.stroke(mark, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    badge.fill(Path(ellipseIn: CGRect(x: 64.75, y: -46, width: 2.5, height: 2.5)), with: .color(.white))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var rimGradient: Gradient {
        Gradient(stops: [.init(color: color(0xf3e8ff).opacity(0.95), location: 0), .init(color: color(0xc6b3f9).opacity(0.12), location: 0.29), .init(color: color(0x7561b5).opacity(0.1), location: 0.65), .init(color: color(0xe8ddff).opacity(0.8), location: 1)])
    }
    private func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    private func path(_ points: [CloudMascotMotion.Point]) -> Path {
        var result = Path()
        guard let first = points.first, points.count > 2 else { return result }
        result.move(to: CGPoint(x: first.x, y: first.y))
        for i in points.indices {
            let a = points[(i + points.count - 1) % points.count], b = points[i]
            let c = points[(i + 1) % points.count], d = points[(i + 2) % points.count]
            result.addCurve(to: CGPoint(x: c.x, y: c.y), control1: CGPoint(x: b.x + (c.x - a.x) / 6, y: b.y + (c.y - a.y) / 6), control2: CGPoint(x: c.x - (d.x - b.x) / 6, y: c.y - (d.y - b.y) / 6))
        }
        result.closeSubpath()
        return result
    }
}
