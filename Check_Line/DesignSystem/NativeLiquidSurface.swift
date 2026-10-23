import SwiftUI

/// A single continuously morphing water contour. Bubble geometry is display-only.
struct NativeLiquidSurface: View {
    var progress: CGFloat
    var horizontal = false
    var burstAt: Date? = nil
    var active = true
    var horizontalAmount: CGFloat? = nil
    @State private var visible = false
    @State private var ambientSeed = UInt64.random(in: 1...UInt64.max)
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30, paused: reduceMotion || !active || !visible || scenePhase != .active)) { clock in
            let time = reduceMotion ? 0 : clock.date.timeIntervalSinceReferenceDate
            let morph = min(1,max(0,horizontalAmount ?? (horizontal ? 1 : 0)))
            Canvas { context, size in
                let level = min(1,max(0,progress))
                guard level > 0 else { return }
                let water = contour(size: size,level: level,morph: morph,time: time)
                context.fill(water,with: .linearGradient(Gradient(colors: [PaperTheme.waterTop.opacity(0.88),PaperTheme.waterBottom]),startPoint: .zero,endPoint: CGPoint(x: size.width*0.6,y: size.height)))
                context.clip(to: water)
                // A broad reflection belongs inside the liquid, without another horizontal edge.
                let sheen = Path(ellipseIn: CGRect(x: -size.width*0.25,y: -size.height*0.55,width: size.width*1.2,height: size.height*1.8))
                context.fill(sheen,with: .linearGradient(Gradient(colors: [.white.opacity(0.12),.clear]),startPoint: .zero,endPoint: CGPoint(x: size.width,y: size.height*0.6)))
                // Keep a recognisable liquid material even when its timeline is
                // paused or Reduce Motion is enabled. Only positions stop moving.
                let ambientTime = reduceMotion || !active ? 0 : time
                for pose in LiquidBubbleField.ambient(size: size, level: level, morph: morph, time: ambientTime, seed: ambientSeed) {
                    bubble(&context,center: pose.center,radius: pose.radius,opacity: pose.opacity * (active ? 1 : 0.5))
                }
                guard !reduceMotion && active else { return }
                if let burstAt {
                    let age=clock.date.timeIntervalSince(burstAt)
                    if age>=0 && age<5.2 {
                        var burst=VisualRandom(state: burstAt.timeIntervalSinceReferenceDate.bitPattern ^ ambientSeed)
                        for _ in 0..<32 {
                            let source=burst.next(),delay=burst.next()*0.85,life=2.4+burst.next()*1.9
                            let direction=(burst.next()-0.5)*size.width*0.4
                            let radius=1.4+burst.next()*3.1,phase=burst.next()*Double.pi*2
                            let t=(age-delay)/life
                            guard t>0 && t<1 else { continue }
                            let px=size.width*(0.08+source*0.84)+direction*t+sin(t*7+phase)*7
                            let py=size.height*(1.04-t*1.12)
                            bubble(&context,center: CGPoint(x: px,y: py),radius: radius*(0.55+0.6*t),opacity: min(1,t*8,(1-t)*5)*0.72)
                        }
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true).onAppear { visible=true }.onDisappear { visible=false }
    }

    private func contour(size: CGSize,level: CGFloat,morph: CGFloat,time: Double) -> Path {
        var path=Path()
        let vertical=size.height*(1-level),horizontal=size.width*level
        for i in 0...90 {
            let u=CGFloat(i)/90
            let wave=CGFloat(sin(Double(u)*7+time*0.9)+sin(Double(u)*11-time*0.63)*0.28)*3.5
            let a=CGPoint(x: u*size.width,y: vertical+wave)
            let b=CGPoint(x: horizontal+wave,y: u*size.height)
            let point=CGPoint(x: a.x+(b.x-a.x)*morph,y: a.y+(b.y-a.y)*morph)
            if i==0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.addLine(to: CGPoint(x: size.width*(1-morph),y: size.height))
        path.addLine(to: CGPoint(x: 0,y: size.height*(1-morph)))
        path.closeSubpath()
        return path
    }
    private func bubble(_ context: inout GraphicsContext,center: CGPoint,radius: Double,opacity: Double) {
        let ring=Path(ellipseIn: CGRect(x: center.x-radius,y: center.y-radius,width: radius*2,height: radius*2))
        context.stroke(ring,with: .color(PaperTheme.accent.opacity(opacity * 0.2)),lineWidth: 1.4)
        context.fill(ring,with: .radialGradient(Gradient(colors: [.white.opacity(opacity*0.24),.clear]),center: CGPoint(x: center.x-radius*0.4,y: center.y-radius*0.4),startRadius: 0,endRadius: radius*1.5))
        context.stroke(ring,with: .color(.white.opacity(opacity)),lineWidth: 0.7)
    }
}

nonisolated struct LiquidBubblePose {
    var center: CGPoint
    var radius: Double
    var opacity: Double
}

/// The ambient field lives inside the liquid volume at every level and keeps
/// cycling independently of the short insertion burst.
nonisolated enum LiquidBubbleField {
    static func ambient(size: CGSize, level: CGFloat, morph: CGFloat, time: Double, seed: UInt64) -> [LiquidBubblePose] {
        guard level > 0, size.width > 0, size.height > 0 else { return [] }
        let level = min(1, level), morph = min(1, max(0, morph))
        var random = VisualRandom(state: seed)
        return (0..<22).map { _ in
            let x = random.next(), phase = random.next(), pace = 6.8 + random.next() * 4.5
            let radius = 1.4 + random.next() * 1.9
            let cycle = time / pace + phase
            let t = cycle - floor(cycle)
            let drift = sin(t * 6 + phase * 12) * (2 + random.next() * 4)
            let verticalX = max(radius, min(size.width - radius, x * size.width + drift))
            let horizontalX = max(radius, min(size.width * level - radius, x * size.width * level + drift))
            let verticalY = size.height - radius - max(0, size.height * level - radius * 2) * t
            let horizontalY = size.height - radius - max(0, size.height - radius * 2) * t
            return LiquidBubblePose(center: CGPoint(x: verticalX + (horizontalX - verticalX) * morph,
                                                   y: verticalY + (horizontalY - verticalY) * morph),
                                    radius: radius, opacity: min(1, t * 9, (1 - t) * 8) * 0.68)
        }
    }
}

struct NativeGlassCard: ViewModifier {
    var radius: CGFloat = 28
    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Color.paper(light: 0xFAF8FC,dark: 0x38303F), Color.paper(light: 0xE4DAEE,dark: 0x29232F)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.12), PaperTheme.accent.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1) }
        .shadow(color: PaperTheme.accent.opacity(0.12), radius: 16,y: 9)
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
