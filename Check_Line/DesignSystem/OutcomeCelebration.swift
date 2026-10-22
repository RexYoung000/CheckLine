import SwiftUI

/// Immutable, read-only projection of an already committed operation.
struct OutcomeReceipt: Identifiable {
    enum Kind { case wish, settlement }
    let id = UUID()
    let kind: Kind
    let title: String
    let before: Decimal
    let after: Decimal
    let currency: String
    let originalAmount: Decimal
    let originalCurrency: String
    let date: Date
    var cover = WishCover()
    var progress: CGFloat?
    var recoveryBefore: Decimal = 0
    var recoveryAfter: Decimal = 0
    var periodStart: Date?
    var periodEnd: Date?
    var net: Decimal { after-before }
    var duration: TimeInterval { kind == .wish ? RewardTiming.wishDuration : (net>0 ? RewardTiming.settlementDuration : 0.78) }
}

struct OutcomeCelebration: View {
    let receipt: OutcomeReceipt
    var onDone: ()->Void
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var started = Date()
    @State private var settled = false
    @State private var fragments = GlassFracture.make(seed: UInt64.random(in: 1...UInt64.max))
    private let pearl=Color(red: 0.97,green: 0.94,blue: 0.99)
    private let gold=Color(red: 0.91,green: 0.79,blue: 0.47)

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0/30,paused: settled || reduceMotion || scenePhase != .active)) { clock in
                let elapsed=(settled || reduceMotion) ? receipt.duration : min(receipt.duration,clock.date.timeIntervalSince(started))
                ZStack {
                    Color(red: 0.17,green: 0.145,blue: 0.21).ignoresSafeArea()
                    RadialGradient(colors: [PaperTheme.accent.opacity(0.44),.clear],center: .center,startRadius: 20,endRadius: geometry.size.width*0.85).ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading,spacing: typeSize.isAccessibilitySize ? 15 : 22) {
                            header(elapsed)
                            if receipt.kind == .wish { wishScene(elapsed,compact: geometry.size.height<650 || typeSize.isAccessibilitySize) }
                            else { settlementScene(elapsed) }
                        }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    }.scrollBounceBehavior(.basedOnSize)
                }.foregroundStyle(pearl)
                    .safeAreaInset(edge: .bottom) {
                        Button(action: onDone) {
                            Text(String(localized: receipt.kind == .wish ? "native.outcome.viewRealized" : "native.returnBudget"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PaperSolidButtonStyle(foreground: Color(red: 0.23,green: 0.17,blue: 0.30),background: Color(red: 0.84,green: 0.78,blue: 0.94)))
                        .frame(maxWidth: 560).padding(.horizontal,22).padding(.vertical,12)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.17,green: 0.145,blue: 0.21).opacity(0.96))
                    }
            }
            .onChange(of: geometry.size) { old,new in if old != new { settled=true } }
        }
        .accessibilityIdentifier("native.outcome.result")
        .onAppear { started=Date() }
        .task(id: receipt.id) {
            do { try await Task.sleep(for: .seconds(receipt.duration)); try Task.checkCancellation(); settled=true }
            catch { }
        }
        .onChange(of: scenePhase) { _,phase in if phase != .active { settled=true } }
        .onChange(of: reduceMotion) { _,value in if value { settled=true } }
    }

    private func header(_ elapsed: TimeInterval) -> some View {
        HStack {
            Text(String(localized: receipt.kind == .wish ? "native.outcome.wishSaved" : "native.outcome.settled")).font(.subheadline)
            Spacer()
            if elapsed<receipt.duration {
                Button(String(localized: "native.outcome.skip")) { settled=true }.font(.subheadline).frame(minWidth: 44,minHeight: 44).accessibilityIdentifier("native.outcome.skip")
            }
            Button(action: onDone) { Image(systemName: "xmark").font(.subheadline).frame(width: 44,height: 44).background(.white.opacity(0.08),in: Circle()) }
                .accessibilityLabel(String(localized: "action.close"))
        }
    }

    private func wishScene(_ elapsed: TimeInterval,compact: Bool) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(String(localized: "native.outcome.fulfilled")).font(.largeTitle.weight(.semibold))
                Text(String(localized: "native.outcome.yourMoment")).font(.caption).foregroundStyle(pearl.opacity(0.6))
            }.opacity(reveal(elapsed,1.72,0.35))
            ZStack {
                ZStack(alignment: .topLeading) {
                    WishCoverArtwork(cover: receipt.cover)
                    VStack(alignment: .leading) {
                        HStack { Text(receipt.title).font(.headline); Spacer(); Image(systemName: "checkmark.seal.fill").foregroundStyle(PaperTheme.accent) }
                        Spacer()
                        Text(MoneyFormat.string(receipt.originalAmount,currencyCode: receipt.originalCurrency)).font(.title2.weight(.medium)).monospacedDigit()
                    }.padding(20).opacity(reveal(elapsed,2.02,0.3))
                }.modifier(NativeGlassCard()).foregroundStyle(PaperTheme.ink)
                    .frame(height: compact ? 220 : 272)
                    .opacity(0.08+reveal(elapsed,0.81,1.05)*0.92)
                    .scaleEffect(0.94+reveal(elapsed,0.7,1.1)*0.06)
                if elapsed < 0.9, let progress = receipt.progress {
                    ZStack {
                        NativeLiquidSurface(progress: progress,active: false)
                        Text(progress,format: .percent.precision(.fractionLength(0))).font(.system(size: 48,weight: .medium,design: .rounded)).foregroundStyle(PaperTheme.ink)
                    }.frame(height: compact ? 220 : 272).clipShape(RoundedRectangle(cornerRadius: 28)).opacity(1-reveal(elapsed,0.52,0.35))
                }
                ShatteredGlassScene(fragments: fragments,elapsed: elapsed,progress: receipt.progress)
                    .padding(-50).allowsHitTesting(false).accessibilityHidden(true)
            }.frame(height: compact ? 220 : 272)
            Text(receipt.date,format: .dateTime.year().month().day()).font(.caption).foregroundStyle(pearl.opacity(0.65)).opacity(reveal(elapsed,2.25,0.2))
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading,spacing: 7) {
                    Text(String(localized: "v1.wish.balance")).font(.caption)
                    Text(MoneyFormat.string(receipt.net,currencyCode: receipt.currency)).font(.caption).foregroundStyle(PaperTheme.muted)
                }
                Spacer(minLength: 8)
                Text(MoneyFormat.string(receipt.after,currencyCode: receipt.currency)).font(.title.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            }.foregroundStyle(PaperTheme.ink).padding(20).walletSurface().opacity(reveal(elapsed,2.45,0.25))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "native.outcome.fulfilled")+" "+receipt.title+" "+MoneyFormat.string(receipt.originalAmount,currencyCode: receipt.originalCurrency))
    }

    private func settlementScene(_ elapsed: TimeInterval) -> some View {
        let value=RewardTiming.receivedAmount(before: receipt.before,after: receipt.after,elapsed: elapsed)
        return VStack(alignment: .leading,spacing: 18) {
            Text(receipt.title).font(.title2.weight(.semibold))
            if let start=receipt.periodStart {
                HStack { Text(start,format: .dateTime.year().month().day()); if let end=receipt.periodEnd { Text("–"); Text(end,format: .dateTime.year().month().day()) } }
                    .font(.caption).foregroundStyle(pearl.opacity(0.65))
            }
            ZStack {
                VStack(spacing: 100) {
                    VStack(alignment: .leading,spacing: 12) {
                        Text(String(localized: receipt.net>0 ? "native.outcome.transferred" : receipt.recoveryAfter<receipt.recoveryBefore ? "v1.wish.recovery" : "wallet.settlement.complete")).font(.caption).foregroundStyle(pearl.opacity(0.65))
                        Text((receipt.net > 0 ? "+" : "")+MoneyFormat.string(receipt.net,currencyCode: receipt.currency)).font(.system(size: 36,weight: .semibold)).monospacedDigit().foregroundStyle(receipt.net>0 ? gold : pearl).lineLimit(1).minimumScaleFactor(0.5)
                        if receipt.recoveryBefore>receipt.recoveryAfter {
                            Text(String(localized: "native.outcome.recovered")+" "+MoneyFormat.string(receipt.recoveryBefore-receipt.recoveryAfter,currencyCode: receipt.currency)).font(.caption)
                        }
                    }.frame(maxWidth: .infinity,alignment: .leading).padding(22).background(.white.opacity(0.08),in: RoundedRectangle(cornerRadius: 25)).overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.22),lineWidth: 0.8))
                    VStack(alignment: .leading,spacing: 14) {
                        Text(String(localized: "v1.wish.balance")).font(.caption).foregroundStyle(pearl.opacity(0.65))
                        Text(MoneyFormat.string(receipt.net>0 ? value : receipt.after,currencyCode: receipt.currency))
                            .font(.system(size: 44,weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
                            .transaction { $0.animation=nil }
                        HStack { Spacer(); Text(MoneyFormat.string(receipt.net>0 ? value-receipt.before : receipt.net,currencyCode: receipt.currency)).font(.caption).monospacedDigit() }
                    }.frame(maxWidth: .infinity,alignment: .leading).padding(22)
                        .background(LinearGradient(colors: [.white.opacity(0.12),PaperTheme.accent.opacity(0.18)],startPoint: .topLeading,endPoint: .bottomTrailing),in: RoundedRectangle(cornerRadius: 25))
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(elapsed>2.05 && elapsed<2.5 ? gold.opacity(0.65) : .white.opacity(0.25),lineWidth: 1))
                        .scaleEffect(receivePulse(elapsed))
                }
                if receipt.net>0 && elapsed<2.6 && !reduceMotion { CoinHarvestScene(elapsed: elapsed).allowsHitTesting(false).accessibilityHidden(true) }
            }
            if receipt.recoveryAfter>0 { Text(String(localized: "v1.wish.recovery")+" "+MoneyFormat.string(receipt.recoveryAfter,currencyCode: receipt.currency)).font(.subheadline) }
            Text(String(localized: receipt.net>0 ? "native.outcome.savedForWish" : "wallet.settlement.saved")).font(.subheadline).foregroundStyle(pearl.opacity(0.65)).frame(maxWidth: .infinity).padding(.top,8)
        }
    }
    private func reveal(_ t: Double,_ from: Double,_ duration: Double) -> Double { min(1,max(0,(t-from)/duration)) }
    private func receivePulse(_ elapsed: Double) -> CGFloat {
        guard !reduceMotion else { return 1 }
        let arrivals=[0.99,1.18,1.39,1.6,1.82,2.05]
        let a=arrivals.map { max(0,1-abs(elapsed-$0)/0.10) }.max() ?? 0
        return 1+CGFloat(a)*0.014
    }
}

private struct ShatteredGlassScene: View {
    let fragments: [GlassFragment]
    let elapsed: TimeInterval
    var progress: CGFloat?
    var body: some View {
        Canvas { context,size in
            let rect=CGRect(x: 50,y: 50,width: size.width-100,height: size.height-100)
            guard elapsed<2.35 else { return }
            if elapsed<0.9 { context.clip(to: Path(roundedRect: rect,cornerRadius: 28)) }
            for fragment in fragments {
                let age=max(0,elapsed-0.9-fragment.delay)
                let flight=age*fragment.speed
                let cx=rect.minX+fragment.center.x*rect.width, cy=rect.minY+fragment.center.y*rect.height
                let dx=(fragment.center.x-0.55)*flight*size.width*1.5
                let dy=(fragment.center.y-0.43)*flight*size.height*1.3-90*flight+100*flight*flight
                let angle=age*fragment.rotation
                let scaleX=cos(angle*0.85), scaleY=cos(angle*0.55)
                var path=Path()
                for (i,p) in fragment.points.enumerated() {
                    let x=(p.x-fragment.center.x)*rect.width*scaleX, y=(p.y-fragment.center.y)*rect.height*scaleY
                    let point=CGPoint(x: cx+dx+x*cos(angle)-y*sin(angle),y: cy+dy+x*sin(angle)+y*cos(angle))
                    if i==0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
                var layer=context
                layer.opacity=max(0,1-age/1.2)
                let opacity=elapsed<0.9 ? 0.72 : 0.65
                layer.fill(path,with: .linearGradient(Gradient(colors: [Color(red: 0.73,green: 0.64,blue: 0.83).opacity(opacity),Color(red: 0.44,green: 0.34,blue: 0.55).opacity(opacity)]),startPoint: CGPoint(x: cx,y: cy-40),endPoint: CGPoint(x: cx+50,y: cy+70)))
                if elapsed>0.28 {
                    let growth=min(1,max(0,(elapsed-0.28)/0.62))
                    layer.stroke(path.trimmedPath(from: 0,to: growth),with: .color(.white.opacity(elapsed<0.9 ? 0.55 : 0.8)),lineWidth: elapsed<0.9 ? 0.65 : 1.3)
                    layer.stroke(path,with: .color(Color(red: 0.3,green: 0.2,blue: 0.4).opacity(0.4)),lineWidth: 0.5)
                }
            }
        }
    }
}

private struct CoinHarvestScene: View {
    let elapsed: TimeInterval
    var body: some View {
        Canvas { context,size in
            var random=VisualRandom(state: 4398)
            for i in 0..<42 {
                let wave=Double(i/7), lane=random.next()-0.5, variation=random.next()
                let start=0.33+wave*0.18+variation*0.1, duration=0.68+variation*0.2
                let p=(elapsed-start)/duration
                guard p>0 && p<1 else { continue }
                let x=size.width*(0.5+lane*sin(p*Double.pi)*0.95)
                let y=size.height*(0.24+0.51*p)-sin(p*Double.pi)*size.height*(0.2+variation*0.12)
                let width=CGFloat(8+variation*7), squeeze=abs(cos(p*Double.pi*4+lane*3))*0.8+0.2
                let rect=CGRect(x: x-width*squeeze,y: y-width,width: width*2*squeeze,height: width*2)
                let face=i%3==0 ? Color(red: 0.91,green: 0.79,blue: 0.47) : Color(red: 0.77,green: 0.69,blue: 0.88)
                context.fill(Path(ellipseIn: rect.offsetBy(dx: 1.6,dy: 1.8)),with: .color(face.opacity(0.5)))
                context.fill(Path(ellipseIn: rect),with: .linearGradient(Gradient(colors: [.white,face,face.opacity(0.8)]),startPoint: rect.origin,endPoint: CGPoint(x: rect.maxX,y: rect.maxY)))
                context.stroke(Path(ellipseIn: rect.insetBy(dx: 2,dy: 2)),with: .color(.white.opacity(0.7)),lineWidth: 0.7)
                if squeeze>0.6 {
                    context.draw(Text("¥").font(.system(size: width,weight: .bold)).foregroundStyle(Color(red: 0.33,green: 0.24,blue: 0.4)),at: CGPoint(x: x,y: y))
                }
            }
            let t=(elapsed-2.05)/0.55
            if t>=0 && t<1 {
                for i in 0..<18 {
                    let a=Double(i)*Double.pi*2/18
                    var line=Path(); let center=CGPoint(x: size.width*0.5,y: size.height*0.77)
                    line.move(to: CGPoint(x: center.x+cos(a)*(30+t*30),y: center.y+sin(a)*(30+t*30)))
                    line.addLine(to: CGPoint(x: center.x+cos(a)*(45+t*90),y: center.y+sin(a)*(45+t*90)))
                    context.stroke(line,with: .color(Color(red: 0.91,green: 0.79,blue: 0.47).opacity((1-t)*0.6)),lineWidth: 1.5)
                }
            }
        }
    }
}
