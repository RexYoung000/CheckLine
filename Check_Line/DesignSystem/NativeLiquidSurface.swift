import SwiftUI

/// One continuous contour and a masked, irregular bubble field; no static waterline overlays.
struct NativeLiquidSurface: View {
    var progress: CGFloat
    var horizontal = false
    var burstAt: Date? = nil
    var active = true
    @State private var visible = false
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30, paused: reduceMotion || !active || !visible || scenePhase != .active)) { clock in
            let time = reduceMotion ? 0 : clock.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let level = min(1, max(0, progress))
                var water = Path()
                let limit = horizontal ? size.width * level : size.height * (1-level)
                for i in 0...70 {
                    let u = CGFloat(i)/70
                    let wave = CGFloat(sin(Double(u)*7+time*0.9) + sin(Double(u)*11-time*0.63)*0.28) * (reduceMotion ? 0 : 3.5)
                    let point = horizontal ? CGPoint(x: limit+wave, y: u*size.height) : CGPoint(x: u*size.width, y: limit+wave)
                    if i == 0 { water.move(to: point) } else { water.addLine(to: point) }
                }
                if horizontal { water.addLine(to: CGPoint(x: 0,y: size.height)); water.addLine(to: .zero) }
                else { water.addLine(to: CGPoint(x: size.width,y: size.height)); water.addLine(to: CGPoint(x: 0,y: size.height)) }
                water.closeSubpath()
                guard level > 0 else { return }
                context.fill(water, with: .linearGradient(Gradient(colors: [PaperTheme.waterTop.opacity(0.8),PaperTheme.waterBottom]), startPoint: .zero, endPoint: CGPoint(x: size.width,y: size.height)))
                context.clip(to: water)
                guard !reduceMotion else { return }
                var random = VisualRandom(state: 71139)
                for _ in 0..<34 {
                    let x = random.next(), phase = random.next(), pace = 4.5+random.next()*5.5
                    let radius = 0.8+random.next()*2.2
                    let t = (time/pace+phase).truncatingRemainder(dividingBy: 1)
                    let px = x*size.width + sin(t*6+phase*12)*5
                    let py = size.height*(1-t)
                    let fade = min(1,t*8,(1-t)*7)*0.48
                    context.stroke(Path(ellipseIn: CGRect(x: px,y: py,width: radius*2,height: radius*2)), with: .color(.white.opacity(fade)), lineWidth: 0.65)
                }
                if let burstAt {
                    let age = clock.date.timeIntervalSince(burstAt)
                    if age >= 0 && age < 2.8 {
                        for _ in 0..<45 {
                            let delay = random.next()*0.85, direction = random.next()-0.5, spread = random.next()
                            let t = max(0,age-delay), life = 1.2+random.next()*1.3
                            guard t > 0 && t < life else { continue }
                            let p = t/life, r = 1.5+spread*4
                            let x = size.width*(0.15+spread*0.7)+direction*p*size.width*0.26+sin(p*7+delay)*7
                            let y = size.height*(1-p*1.1)
                            context.stroke(Path(ellipseIn: CGRect(x: x,y: y,width: r*2,height: r*2)), with: .color(.white.opacity(min(1,p*8,(1-p)*4)*0.7)), lineWidth: 0.9)
                        }
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true).onAppear { visible=true }.onDisappear { visible=false }
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

struct ComponentLightSweep: View {
    let startedAt: Date?
    var radius: CGFloat = 24
    @State private var playing = false
    @Environment(\.walletReduceMotion) private var reduceMotion
    var body: some View {
        if let startedAt, !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0/30,paused: !playing)) { clock in
                let t = clock.date.timeIntervalSince(startedAt)/0.8
                if t >= 0 && t < 1 && playing {
                    Canvas { context, size in
                        let rect = CGRect(origin: .zero,size: size).insetBy(dx: 1,dy: 1)
                        let opacity = min(1,t*6,(1-t)*4)*0.65
                        context.opacity = opacity
                        let r = min(radius,rect.height/2,rect.width/2)
                        for right in [false,true] {
                            let edge = right ? rect.maxX : rect.minX
                            let inner = right ? edge-r : edge+r
                            var path = Path()
                            path.move(to: CGPoint(x: rect.midX,y: rect.minY))
                            path.addLine(to: CGPoint(x: inner,y: rect.minY))
                            path.addQuadCurve(to: CGPoint(x: edge,y: rect.minY+r),control: CGPoint(x: edge,y: rect.minY))
                            path.addLine(to: CGPoint(x: edge,y: rect.maxY-r))
                            path.addQuadCurve(to: CGPoint(x: inner,y: rect.maxY),control: CGPoint(x: edge,y: rect.maxY))
                            path.addLine(to: CGPoint(x: rect.midX,y: rect.maxY))
                            context.stroke(path.trimmedPath(from: max(0,t-0.3),to: min(1,t)), with: .linearGradient(Gradient(colors: [Color(red: 0.55,green: 0.43,blue: 0.8),Color(red: 0.7,green: 0.88,blue: 0.86),.white]),startPoint: CGPoint(x: rect.midX,y: 0),endPoint: CGPoint(x: edge,y: rect.maxY)), lineWidth: 2.2)
                        }
                    }.blur(radius: 0.8)
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
                .task(id: startedAt) {
                    let remaining = max(0,0.8-Date().timeIntervalSince(startedAt))
                    playing=remaining>0
                    do { try await Task.sleep(for: .seconds(remaining));try Task.checkCancellation();playing=false } catch { }
                }
        }
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

struct ContactAmountText: View {
    let value: Decimal
    let currency: String
    let contact: Date?
    @State private var running = true
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30,paused: !running || reduceMotion || scenePhase != .active)) { clock in
            let elapsed = contact.map { clock.date.timeIntervalSince($0) } ?? 1
            let amount = !running || reduceMotion || scenePhase != .active ? value : RewardTiming.receivedAmount(before: 0,after: value,elapsed: 0.82+max(0,elapsed)/0.8*1.23)
            Text(MoneyFormat.string(amount,currencyCode: currency)).monospacedDigit()
                .accessibilityLabel(MoneyFormat.string(value,currencyCode: currency))
        }.task(id: contact) {
            running = !reduceMotion && contact.map { Date().timeIntervalSince($0)<0.8 } == true
            do { try await Task.sleep(for: .milliseconds(800));try Task.checkCancellation();running=false } catch { }
        }
    }
}
