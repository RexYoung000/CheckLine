import SwiftUI
#if DEBUG
import os
#if canImport(UIKit)
import UIKit
#endif

/// Local Instruments/XCTest evidence only; no ledger fields enter a signpost.
nonisolated private enum LiquidFrameTrace {
    static let signposter = OSSignposter(subsystem: "Rex.CheckLine", category: "Liquid")
}

/// Explicit local UI-test probe. Plain locked storage never invalidates SwiftUI.
/// No counter, timer, or accessibility probe exists in Release.
nonisolated private final class LiquidFrameMetrics: @unchecked Sendable {
    static let enabled = ProcessInfo.processInfo.arguments.contains("-design-preview")
        && ProcessInfo.processInfo.arguments.contains("-design-liquid-metrics")
    static let shared = LiquidFrameMetrics()
    private let lock = NSLock()
    private var frames: UInt64 = 0
    private var runningSurfaces: Set<UUID> = []

    func didDraw() {
        guard Self.enabled else { return }
        lock.lock(); defer { lock.unlock() }
        frames &+= 1
    }
    func setRunning(_ running: Bool, id: UUID) {
        guard Self.enabled else { return }
        lock.lock(); defer { lock.unlock() }
        if running { runningSurfaces.insert(id) } else { runningSurfaces.remove(id) }
    }
    func snapshot() -> String {
        lock.lock(); defer { lock.unlock() }
        return "frames=\(frames);running=\(runningSurfaces.count)"
    }
}

#if canImport(UIKit)
/// UIKit asks for this value on demand. Updating the draw count does not publish
/// state, update a label, or schedule another Canvas frame.
private struct LiquidMetricsProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> LiquidMetricsProbeView { LiquidMetricsProbeView() }
    func updateUIView(_ uiView: LiquidMetricsProbeView, context: Context) {}
}

private final class LiquidMetricsProbeView: UIView {
    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityIdentifier = "debug.liquid.metrics"
        accessibilityLabel = "Local liquid rendering probe"
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var accessibilityValue: String? {
        get { LiquidFrameMetrics.shared.snapshot() }
        set { /* Always expose a live read of the plain counter. */ }
    }
}
#endif
#endif

extension View {
    @ViewBuilder func liquidMetricsProbe() -> some View {
        #if DEBUG && canImport(UIKit)
        if LiquidFrameMetrics.enabled {
            overlay(alignment: .topLeading) {
                LiquidMetricsProbe().frame(width: 1, height: 1).padding(32).allowsHitTesting(false)
            }
        } else { self }
        #else
        self
        #endif
    }
}

/// Physical budget colors are independent from the neutral interface accent.
/// A dark selected control must never turn the water gray.
enum BudgetGlassPalette {
    static let tint = Color.paper(light: 0x37B9E8, dark: 0x8FD8F2)
    static let ink = Color.paper(light: 0x12384B, dark: 0x12384B)
    static let metadata = Color.paper(light: 0x27526A, dark: 0x204B62)
    static let solid = Color.paper(light: 0xC5EAF7, dark: 0x8FD8F2)
    static func amount(level: CGFloat) -> Color {
        Color.paper(light: 0x103D52, dark: level > 0.2 ? 0xFFFFFF : 0x12384B)
    }

    static func water(dark: Bool, fullness: Double, opaque: Bool) -> [Color] {
        if !dark {
            return [0.16, 0.22, 0.28].map { tint.opacity(opaque ? $0 + 0.12 : $0) }
        }
        // Full water transmits more of the bright shell rather than stacking black.
        let source: [(Double, Double, Double, Double)] = [(134,226,255,0.20),(11,76,116,0.64),(16,62,88,0.75)]
        let full: [(Double, Double, Double, Double)] = [(166,232,255,0.09),(23,109,147,0.30),(9,59,81,0.56)]
        return zip(source, full).map { a, b in
            let f = min(1, max(0, fullness))
            return Color(red: (a.0 + (b.0-a.0)*f)/255, green: (a.1 + (b.1-a.1)*f)/255,
                         blue: (a.2 + (b.2-a.2)*f)/255, opacity: a.3 + (b.3-a.3)*f)
        }
    }
}

/// Geometry only: never reads a ledger or changes the balance ratio.
nonisolated struct LiquidSurfaceGeometry {
    let front: [CGPoint]
    let rear: [CGPoint]
    let volume: Path
    let surface: Path
    let frontLine: Path
    let rearLine: Path

    static func fullness(_ level: CGFloat) -> CGFloat {
        let x = min(1, max(0, (level - 0.88) / 0.12))
        return x*x*(3-2*x)
    }

    static func make(size: CGSize, level rawLevel: CGFloat, morph rawMorph: CGFloat = 0,
                     time: Double = 0, tilt: Double = 0, impact: Double = 0) -> Self {
        let level = min(1, max(0, rawLevel)), morph = min(1, max(0, rawMorph))
        guard level > 0, size.width > 0, size.height > 0 else {
            return Self(front: [], rear: [], volume: Path(), surface: Path(), frontLine: Path(), rearLine: Path())
        }
        let full = fullness(level)
        let edge = max(full*0.48, min(1, level/0.12, (1-level)/0.12))
        let scale = min(size.width/400, size.height/258)
        let amplitude = 5.8*Double(edge)*Double(scale)*(0.92+0.08*sin(time*0.37))
        let motionScale = 4/hypot(4, abs(tilt)+abs(impact))
        let headspace = 20*full*scale
        let vertical = size.height*(1-level)+headspace
        let horizontal = size.width*level-headspace
        var front: [CGPoint] = [], rear: [CGPoint] = []
        for index in 0...40 {
            let u = Double(index)/40, tau = Double.pi*2
            let ripple = amplitude*(0.78*sin(tau*u-time*0.86)+0.22*sin(tau*2*u+time*0.51+0.8))
            let sway = Double(edge)*Double(scale)*motionScale*(tilt*cos(.pi*u)+impact*cos(tau*u))
            let wave = CGFloat(ripple+sway)
            let depth = edge*scale*CGFloat(3.2+0.65*sin(tau*u+time*0.31))
            let x = CGFloat(u)*size.width, y = CGFloat(u)*size.height
            front.append(CGPoint(x: x+(horizontal+wave-x)*morph, y: vertical+wave+(y-vertical-wave)*morph))
            rear.append(CGPoint(x: x+(horizontal+wave+depth-x)*morph, y: vertical+wave-depth+(y-vertical-wave+depth)*morph))
        }
        let line = smooth(front), back = smooth(rear)
        var volume = line
        volume.addLine(to: CGPoint(x: size.width*(1-morph), y: size.height))
        volume.addLine(to: CGPoint(x: 0, y: size.height*(1-morph)))
        volume.closeSubpath()
        var surface = back
        for point in front.reversed() { surface.addLine(to: point) }
        surface.closeSubpath()
        return Self(front: front, rear: rear, volume: volume, surface: surface, frontLine: line, rearLine: back)
    }

    private static func smooth(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for i in 1..<points.count {
            let a = points[i-1], b = points[i]
            let before = points[max(0, i-2)], after = points[min(points.count-1, i+1)]
            path.addCurve(to: b,
                          control1: CGPoint(x: a.x+(b.x-before.x)/6, y: a.y+(b.y-before.y)/6),
                          control2: CGPoint(x: b.x-(after.x-a.x)/6, y: b.y-(after.y-a.y)/6))
        }
        return path
    }
}

/// One event identity belongs to the existing cartridge state machine.
nonisolated struct LiquidSurfaceImpulse: Equatable {
    let id = UUID()
    var direction: Double
}

/// Display-only liquid. The clock counts visible time and never seeks on resume.
struct NativeLiquidSurface: View {
    var progress: CGFloat
    var horizontal = false
    var burstAt: Date? = nil
    var active = true
    var horizontalAmount: CGFloat? = nil
    var dragOffset: CGFloat = 0
    var impulse: LiquidSurfaceImpulse? = nil
    var staticPreview = false
    @State private var visible = false
    @State private var motionClock = LiquidMotionClock()
    @State private var contactTime: TimeInterval?
    @State private var impulseTime: TimeInterval?
    @State private var impulseDirection = 0.0
    @State private var releasedTilt = 0.0
    @State private var releaseTime: TimeInterval?
    #if DEBUG
    @State private var metricsSurfaceID = UUID()
    #endif
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    private var running: Bool { active && visible && !staticPreview && !reduceMotion && scenePhase == .active && progress > 0 }
    private var now: TimeInterval { Date().timeIntervalSinceReferenceDate }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30, paused: !running)) { tick in
            let time = reduceMotion || staticPreview ? 0 : motionClock.elapsedTime(at: tick.date.timeIntervalSinceReferenceDate)
            let morph = min(1, max(0, horizontalAmount ?? (horizontal ? 1 : 0)))
            Canvas { context, size in
                #if DEBUG
                let frameInterval = LiquidFrameTrace.signposter.beginInterval("LiquidFrame", id: LiquidFrameTrace.signposter.makeSignpostID())
                defer {
                    LiquidFrameMetrics.shared.didDraw()
                    LiquidFrameTrace.signposter.endInterval("LiquidFrame", frameInterval)
                }
                #endif
                let level = min(1, max(0, progress))
                guard level > 0 else { return }
                let drag = running ? Double(min(5.8, max(-5.8, -dragOffset/22))) : 0
                let afterDrag = decaying(releasedTilt, since: releaseTime, at: time, damping: 3.9, frequency: 4.78, startsAtRest: false)
                let switched = decaying(-impulseDirection*6.2, since: impulseTime, at: time, damping: 3.9, frequency: 4.78)
                let contact = decaying(8.5, since: contactTime, at: time, damping: 2.8, frequency: 6.34)
                let shape = LiquidSurfaceGeometry.make(size: size, level: level, morph: morph, time: time,
                                                       tilt: drag+afterDrag+switched, impact: contact)
                var waterContext = context
                waterContext.fill(shape.volume, with: .linearGradient(Gradient(colors: BudgetGlassPalette.water(dark: scheme == .dark, fullness: Double(LiquidSurfaceGeometry.fullness(level)), opaque: reduceTransparency)), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                waterContext.clip(to: shape.volume)
                let glow = Path(ellipseIn: CGRect(x: -size.width*0.23, y: size.height*0.20, width: size.width*1.18, height: size.height*0.65))
                waterContext.fill(glow, with: .radialGradient(Gradient(colors: [.white.opacity(scheme == .dark ? 0.12 : 0.16), .clear]), center: CGPoint(x: size.width*0.3, y: size.height*0.62), startRadius: 0, endRadius: size.width*0.65))
                for pose in LiquidBubbleField.ambient(size: size, level: level, morph: morph, time: time, seed: 41, count: staticPreview ? 10 : 28) {
                    bubble(&waterContext, pose: pose)
                }
                if running, let contactTime {
                    let age = time-contactTime
                    burst(&waterContext, size: size, level: level, morph: morph, age: age)
                }
                context.fill(shape.surface, with: .color(.white.opacity(contrast == .increased ? 0.20 : 0.085)))
                context.stroke(shape.rearLine, with: .color(Color(red: 0.88, green: 0.98, blue: 1).opacity(0.30)), lineWidth: 0.85)
                context.stroke(shape.frontLine, with: .color(.white.opacity(contrast == .increased ? 0.98 : 0.68)), lineWidth: contrast == .increased ? 1.7 : 1.2)
                context.stroke(shape.frontLine, with: .linearGradient(Gradient(stops: [.init(color: .clear, location: 0.3), .init(color: .white.opacity(0.7), location: 0.5), .init(color: .clear, location: 0.7)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), lineWidth: 1.55)
                if running, morph < 0.05, let contactTime {
                    splash(&context, shape: shape, age: time-contactTime, size: size)
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .onAppear { visible = true }
        .onDisappear { visible = false; pause() }
        .onChange(of: running, initial: true) { _, value in
            motionClock.setRunning(value, at: now)
            if !value { clearImpulses() }
            #if DEBUG
            LiquidFrameMetrics.shared.setRunning(value, id: metricsSurfaceID)
            if !staticPreview {
                if value { LiquidFrameTrace.signposter.emitEvent("LiquidResumed") }
                else { LiquidFrameTrace.signposter.emitEvent("LiquidPaused") }
            }
            #endif
        }
        .onChange(of: burstAt) { _, value in
            guard running, let value, abs(Date().timeIntervalSince(value)) < 0.25 else { contactTime = nil; return }
            contactTime = motionClock.elapsedTime(at: now)
        }
        .onChange(of: impulse) { _, value in
            guard running, let value else { impulseTime = nil; return }
            impulseTime = motionClock.elapsedTime(at: now); impulseDirection = value.direction
        }
        .onChange(of: dragOffset) { old, value in
            if running, value == 0, old != 0 {
                releasedTilt = Double(min(5.8, max(-5.8, -old/22)))
                releaseTime = motionClock.elapsedTime(at: now)
            }
        }
    }

    private func clearImpulses() { contactTime = nil; impulseTime = nil; releaseTime = nil; releasedTilt = 0 }
    private func pause() {
        motionClock.setRunning(false, at: now); clearImpulses()
        #if DEBUG
        LiquidFrameMetrics.shared.setRunning(false, id: metricsSurfaceID)
        #endif
    }
    private func decaying(_ value: Double, since start: TimeInterval?, at time: TimeInterval, damping: Double, frequency: Double, startsAtRest: Bool = true) -> Double {
        guard !reduceMotion, let start else { return 0 }
        let age = max(0, time-start)
        return value*exp(-damping*age)*(startsAtRest ? sin(frequency*age) : cos(frequency*age))
    }
    private func bubble(_ context: inout GraphicsContext, pose: LiquidBubblePose) {
        let r = pose.radius, center = pose.center, opacity = pose.opacity
        let rect = CGRect(x: center.x-r, y: center.y-r, width: r*2, height: r*2)
        let ring = Path(ellipseIn: rect)
        context.fill(ring, with: .radialGradient(Gradient(stops: [.init(color: .clear, location: 0), .init(color: .white.opacity(opacity*0.01), location: 0.64), .init(color: .white.opacity(opacity*0.11), location: 0.82), .init(color: .white.opacity(opacity*0.23), location: 0.94), .init(color: .clear, location: 1)]), center: center, startRadius: 0, endRadius: r))
        var glint = Path(); glint.addArc(center: center, radius: r*0.91, startAngle: .degrees(205), endAngle: .degrees(278), clockwise: false)
        context.stroke(glint, with: .color(.white.opacity(opacity*0.96)), style: StrokeStyle(lineWidth: max(0.55, r*0.14), lineCap: .round))
        var counter = Path(); counter.addArc(center: center, radius: r*0.91, startAngle: .degrees(18), endAngle: .degrees(91), clockwise: false)
        context.stroke(counter, with: .color(.white.opacity(opacity*0.46)), style: StrokeStyle(lineWidth: max(0.35, r*0.08), lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: center.x-r*0.52, y: center.y-r*0.56, width: r*0.40, height: r*0.18)), with: .color(.white.opacity(opacity*0.88)))
    }
    private func burst(_ context: inout GraphicsContext, size: CGSize, level: CGFloat, morph: CGFloat, age: Double) {
        guard age >= 0, age < 4.2 else { return }
        var random = VisualRandom(state: burstAt?.timeIntervalSinceReferenceDate.bitPattern ?? 41)
        for index in 0..<36 {
            let x = random.next(), delay = random.next()*0.52, life = 2.1+random.next()*1.5
            let drift = (random.next()-0.5)*size.width*0.14
            let r = index < 24 ? 1.2+random.next() : 2.75+random.next()*1.5
            let t = (age-delay)/life
            guard t > 0, t < 1 else { continue }
            let center = CGPoint(x: size.width*(0.09+x*0.82)+drift*t, y: size.height-t*size.height*level)
            bubble(&context, pose: LiquidBubblePose(center: center, radius: r, opacity: min(1, t*8, (1-t)*5)*0.85))
        }
    }
    private func splash(_ context: inout GraphicsContext, shape: LiquidSurfaceGeometry, age: Double, size: CGSize) {
        guard age >= 0, age < 0.82, !shape.front.isEmpty else { return }
        var random = VisualRandom(state: 85)
        for _ in 0..<12 {
            let index = min(40, max(0, Int((0.06+random.next()*0.88)*40)))
            let delay = random.next()*0.1, duration = 0.48+random.next()*0.24
            let drift = (random.next()-0.5)*19, lift = 4+random.next()*8
            let t = (age-delay)/duration
            guard t > 0, t < 1 else { continue }
            let origin = shape.front[index]
            let p = CGPoint(x: origin.x+drift*t, y: origin.y-4*lift*t*(1-t))
            context.fill(Path(ellipseIn: CGRect(x: p.x-1, y: p.y-1.9, width: 2, height: 3.8)), with: .color(.white.opacity(sin(t*Double.pi)*0.74)))
        }
    }
}

nonisolated struct LiquidBubblePose {
    var center: CGPoint
    var radius: Double
    var opacity: Double
}

/// Three loose streams of fine bubbles with a few clear, larger near spheres.
nonisolated enum LiquidBubbleField {
    static func ambient(size: CGSize, level rawLevel: CGFloat, morph: CGFloat, time: Double, seed: UInt64, count: Int = 28) -> [LiquidBubblePose] {
        guard rawLevel > 0, size.width > 0, size.height > 0 else { return [] }
        let level = min(1, rawLevel), morph = min(1, max(0, morph))
        let headspace = 20*LiquidSurfaceGeometry.fullness(level)*min(size.width/400, size.height/258)
        let waterHeight = max(0, size.height*level-headspace), waterWidth = max(0, size.width*level-headspace)
        var random = VisualRandom(state: seed)
        return (0..<count).map { index in
            let fine = index < Int(Double(count)*0.65)
            let x = fine ? [0.16, 0.47, 0.79][index%3]+(random.next()-0.5)*0.14 : 0.08+random.next()*0.84
            let phase = random.next(), pace = 3.9+Double(waterHeight)*0.008+random.next()*1.9
            let radius = fine ? 1.3+random.next()*0.85 : 2.8+random.next()*1.8
            let cycle = time/pace+phase, t = cycle-floor(cycle)
            let drift = sin(t*6+phase*12)*(2+random.next()*4)
            let vx = min(size.width, max(0, x*size.width+drift))
            let hx = min(waterWidth, max(0, x*waterWidth+drift))
            let vy = size.height-max(0, waterHeight-radius)*t
            let hy = size.height-max(0, size.height-radius)*t
            return LiquidBubblePose(center: CGPoint(x: vx+(hx-vx)*morph, y: vy+(hy-vy)*morph),
                                    radius: radius, opacity: min(1, t*9, (1-t)*8)*(fine ? 0.90 : 0.82))
        }
    }
}

struct NativeGlassCard: ViewModifier {
    var radius: CGFloat = 28
    var level: CGFloat = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.background {
            ZStack {
                shape.fill(reduceTransparency ? BudgetGlassPalette.solid : BudgetGlassPalette.tint.opacity(scheme == .dark ? 0.92-0.10*Double(LiquidSurfaceGeometry.fullness(level)) : 0.28))
                shape.fill(RadialGradient(stops: [.init(color: .white.opacity(scheme == .dark ? 0.76 : 0.78), location: 0), .init(color: .white.opacity(0.20), location: 0.46), .init(color: .clear, location: 0.76)], center: UnitPoint(x: 0.135, y: 0.12), startRadius: 0, endRadius: 320))
            }
        }
        .clipShape(shape)
        .overlay {
            ZStack {
                shape.strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.96), location: 0), .init(color: .white.opacity(0.66), location: 0.28), .init(color: BudgetGlassPalette.ink.opacity(0.18), location: 0.65), .init(color: .white.opacity(0.78), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: contrast == .increased ? 1.8 : 1)
                shape.inset(by: 2.2).strokeBorder(BudgetGlassPalette.ink.opacity(contrast == .increased ? 0.32 : 0.12), lineWidth: 0.8).offset(x: 0.8, y: 1.2).clipShape(shape)
                shape.inset(by: 1.5).trim(from: 0.48, to: 0.88).stroke(.white.opacity(0.80), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
        .shadow(color: (scheme == .dark ? Color.black : BudgetGlassPalette.ink).opacity(scheme == .dark ? 0.28 : 0.10), radius: 10, y: 5)
    }
}

struct NativeDrawerStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    func body(content: Content) -> some View {
        content.presentationDetents(typeSize.isAccessibilitySize || sizeClass == .regular ? [.large] : [.fraction(0.76), .large])
            .presentationDragIndicator(.visible).presentationCornerRadius(32)
            .presentationBackground(PaperTheme.canvas)
    }
}

/// Exact formatted digits roll in their own font metrics; no floating-point money conversion.
struct ContactOdometerText: View {
    let text: String
    let contact: Date?
    @State private var running = false
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30,paused: !running || reduceMotion || voiceOver || scenePhase != .active)) { clock in
            let elapsed=contact.map { max(0,clock.date.timeIntervalSince($0)) } ?? 1
            let p = !running || reduceMotion || voiceOver || scenePhase != .active ? 1 : min(1,elapsed/0.85)
            let eased=1-pow(1-p,3)
            HStack(alignment: .firstTextBaseline,spacing: 0) {
                ForEach(Array(text.enumerated()),id: \.offset) { _,character in
                    if let digit=character.wholeNumberValue, running && !reduceMotion && !voiceOver {
                        Text("0").hidden().overlay {
                            GeometryReader { proxy in
                                VStack(spacing: 0) {
                                    ForEach(0...9,id: \.self) { n in Text(String(n)).frame(width: proxy.size.width,height: proxy.size.height) }
                                }.offset(y: -CGFloat(digit)*proxy.size.height*eased)
                            }.clipped()
                        }
                    } else { Text(String(character)) }
                }
            }.monospacedDigit().accessibilityElement(children: .ignore).accessibilityLabel(text)
        }.task(id: contact) {
            let remaining=contact.map { max(0,0.85-Date().timeIntervalSince($0)) } ?? 0
            running=remaining>0 && !reduceMotion && !voiceOver
            do { try await Task.sleep(for: .seconds(remaining));try Task.checkCancellation();running=false } catch { running=false }
        }
    }
}

struct ContactAmountText: View {
    let value: Decimal
    let currency: String
    let contact: Date?
    var body: some View { ContactOdometerText(text: MoneyFormat.string(value,currencyCode: currency),contact: contact) }
}
struct ContactNumberText: View {
    let value: Int
    let contact: Date?
    var body: some View { ContactOdometerText(text: value.formatted(),contact: contact) }
}
