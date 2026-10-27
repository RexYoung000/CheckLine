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
    var onDone: () -> Void
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var started = Date()
    @State private var settled = false
    @State private var seed = UInt64.random(in: 1...UInt64.max)
    @State private var fracture = GlassFracture.makeScene(seed: UInt64.random(in: 1...UInt64.max))
    private var pearl: Color { PaperTheme.ink }
    private let gold = Color(red: 0.91, green: 0.79, blue: 0.47)
    private var isWish: Bool { receipt.kind == .wish }
    private var foreground: Color { PaperTheme.ink }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: settled || reduceMotion || scenePhase != .active)) { clock in
                let elapsed = (settled || reduceMotion) ? receipt.duration : min(receipt.duration, clock.date.timeIntervalSince(started))
                ZStack {
                    WishFocusScrim()
                    if isWish { aurora(elapsed).ignoresSafeArea() }
                    ScrollView {
                        VStack(alignment: .leading, spacing: geometry.size.height < 700 ? 14 : 22) {
                            header(elapsed)
                            if isWish { wishScene(elapsed, compact: geometry.size.height < 650 || typeSize.isAccessibilitySize) }
                            else { settlementScene(elapsed,compact: geometry.size.height < 700) }
                        }.padding(geometry.size.height < 700 ? 18 : 22).frame(maxWidth: 560).frame(maxWidth: .infinity)
                    }.scrollBounceBehavior(.basedOnSize)
                }
                .overlayPreferenceValue(OutcomeAnchorPreference.self) { anchors in
                    GeometryReader { proxy in
                        if !isWish, receipt.net > 0, !reduceMotion, elapsed < 2.75,
                           let source = anchors[.source], let wallet = anchors[.wallet] {
                            RewardCoinHarvest(elapsed: elapsed, source: proxy[source], wallet: proxy[wallet], seed: seed, currency: receipt.currency)
                        }
                    }.allowsHitTesting(false).accessibilityHidden(true)
                }
                .foregroundStyle(foreground)
                .safeAreaInset(edge: .bottom) {
                    Button(action: finish) {
                        Text(String(localized: isWish ? "native.outcome.viewRealized" : "native.returnBudget")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PaperSolidButtonStyle(foreground: PaperTheme.primaryInk, background: PaperTheme.primary))
                    .frame(maxWidth: 560).padding(.horizontal, 22).padding(.vertical, 12).frame(maxWidth: .infinity)
                    .background(Color.clear)
                }
            }
            .onChange(of: geometry.size) { old, new in if old != new { settled = true } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("native.outcome.result")
        .onAppear { started = Date() }
        .task(id: receipt.id) {
            do { try await Task.sleep(for: .seconds(receipt.duration)); try Task.checkCancellation(); settled = true } catch { }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { settled = true } }
        .onChange(of: reduceMotion) { _, value in if value { settled = true } }
    }

    private func finish() { settled = true; onDone() }
    private func header(_ elapsed: TimeInterval) -> some View {
        HStack {
            Text(String(localized: isWish ? "native.outcome.wishSaved" : "native.outcome.settled")).font(.subheadline)
            Spacer()
            if elapsed < receipt.duration {
                Button(String(localized: "native.outcome.skip")) { settled = true }.font(.subheadline).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("native.outcome.skip")
            }
            Button(action: finish) { Image(systemName: "xmark").font(.subheadline).frame(width: 44, height: 44).background(foreground.opacity(0.06), in: Circle()) }
                .accessibilityLabel(String(localized: "action.close"))
        }.padding(10).background(PaperTheme.card.opacity(reduceTransparency ? 1 : 0.92), in: RoundedRectangle(cornerRadius: 20))
    }

    private func aurora(_ elapsed: Double) -> some View {
        let strength = elapsed < 0.9 ? reveal(elapsed, 0.1, 0.8) * 0.3 : 0.12 + pow(1 - reveal(elapsed, 0.9, 1.4), 2) * 0.68
        return RadialGradient(colors: [PaperTheme.accent.opacity(strength * 0.4), .white.opacity(strength * 0.2), .clear], center: UnitPoint(x: 0.5, y: 0.43), startRadius: 5, endRadius: 260)
    }

    private func wishScene(_ elapsed: TimeInterval, compact: Bool) -> some View {
        let pose = RewardTiming.wishPose(elapsed: elapsed)
        let height: CGFloat = compact ? 220 : 272
        return VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(String(localized: "native.outcome.fulfilled")).font(.largeTitle.weight(.semibold))
                Text(String(localized: "native.outcome.yourMoment")).font(.caption).foregroundStyle(pearl.opacity(0.6))
            }.opacity(reveal(elapsed, 1.72, 0.43)).offset(y: 7 * (1 - reveal(elapsed, 1.72, 0.43)))
            ZStack {
                wishRevealedCard(elapsed)
                if elapsed < 0.91 {
                    ZStack {
                        WishCardBackdrop(radius: 28, roll: pose.angle)
                        NativeLiquidSurface(progress: receipt.progress ?? 1, active: false).opacity(0.42)
                        WishGlassPane(radius: 28)
                        if let progress = receipt.progress { Text(progress, format: .percent.precision(.fractionLength(0))).font(.system(size: 48, weight: .medium)).foregroundStyle(PaperTheme.ink) }
                    }.clipShape(RoundedRectangle(cornerRadius: 28)).opacity(1 - reveal(elapsed, 0.69, 0.22))
                }
                if elapsed < 2.65 {
                    RewardGlassPane(fracture: fracture, elapsed: elapsed, seed: seed)
                        .padding(-100).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .frame(height: height)
            .scaleEffect(pose.scale).rotationEffect(.degrees(pose.angle)).offset(x: pose.x, y: pose.y)
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").font(.title3).foregroundStyle(PaperTheme.accent)
                    .scaleEffect(elapsed < 2.2 ? 0.65 : 1 + sin(reveal(elapsed, 2.2, 0.39) * .pi) * 0.13)
                Text(receipt.date, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(pearl.opacity(0.65))
            }.opacity(reveal(elapsed, 2.2, 0.39))
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(String(localized: "v1.wish.balance")).font(.caption)
                    Text(MoneyFormat.string(receipt.net, currencyCode: receipt.currency)).font(.caption).foregroundStyle(PaperTheme.muted)
                }
                Spacer(minLength: 8)
                Text(MoneyFormat.string(receipt.after, currencyCode: receipt.currency)).font(.title.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            }.foregroundStyle(PaperTheme.ink).padding(20).walletSurface()
                .opacity(reveal(elapsed, 2.41, 0.39)).offset(y: 12 * (1 - reveal(elapsed, 2.41, 0.39)))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "native.outcome.fulfilled") + " " + receipt.title + " " + MoneyFormat.string(receipt.originalAmount, currencyCode: receipt.originalCurrency))
    }

    private func wishRevealedCard(_ elapsed: Double) -> some View {
        let cardPose = RewardTiming.wishPose(elapsed: elapsed)
        let artProgress = reveal(elapsed, 0.81, 1.35)
        let artScale = rewardKeyframe(artProgress, [0, 0.27, 0.52, 0.79, 1], [0.74, 0.99, 1.24, 1.08, 1])
        let artY = rewardKeyframe(artProgress, [0, 0.27, 0.52, 0.79, 1], [9, -7, -11, -4, 0])
        let artRotation = rewardKeyframe(artProgress, [0, 0.27, 0.52, 0.79, 1], [-3, -1, 2, -0.7, 0])
        let isPhotoFill = receipt.cover.layout == .fill && receipt.cover.imageData != nil
        return ZStack(alignment: .topLeading) {
            if receipt.cover.layout != .none {
                WishCoverArtwork(cover: receipt.cover, large: true, materialRole: .collection)
                    .scaleEffect(artScale).offset(y: artY).rotationEffect(.degrees(artRotation))
                    .opacity(reveal(elapsed, 0.81, 0.37))
            }
            VStack(alignment: .leading) {
                Text(receipt.title).font(.headline).lineLimit(3)
                    .opacity(reveal(elapsed, receipt.cover.layout == .none ? 0.82 : 2.02, receipt.cover.layout == .none ? 0.5 : 0.37))
                    .offset(y: receipt.cover.layout == .none ? 60 * (1 - smooth(reveal(elapsed, 1.2, 0.94))) : 7 * (1 - reveal(elapsed, 2.02, 0.37)))
                Spacer()
                Text(MoneyFormat.string(receipt.originalAmount, currencyCode: receipt.originalCurrency)).font(.title2.weight(.medium)).monospacedDigit()
                    .opacity(reveal(elapsed, 2.02, 0.37)).offset(y: 7 * (1 - reveal(elapsed, 2.02, 0.37)))
            }.padding(20).foregroundStyle(isPhotoFill ? .white : WishMaterialPalette.ink)
            RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(max(0, (1 - reveal(elapsed, 1.22, 1.18))) * 0.75), lineWidth: 1.4)
                .blendMode(.plusLighter).opacity(reveal(elapsed, 0.93, 0.3))
        }
        .background {
            WishCardBackdrop(role: .collection, radius: 28, roll: cardPose.angle)
                .opacity(elapsed < 0.9 ? 0.015 : 0.015 + smooth(reveal(elapsed, 1.54, 0.58)) * 0.985)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(reveal(elapsed, 1.1, 0.9) * 0.6), lineWidth: 1) }
        .shadow(color: PaperTheme.accent.opacity(reveal(elapsed, 1.5, 0.9) * 0.16), radius: 18, y: 10)
    }

    private func settlementScene(_ elapsed: TimeInterval,compact: Bool) -> some View {
        let value = RewardTiming.receivedAmount(before: receipt.before, after: receipt.after, elapsed: elapsed)
        let sourcePose = rewardKeyframe(min(1, elapsed / 0.86), [0, 0.43, 0.66, 1], [0, 5, -6, 0])
        let sourceScale = rewardKeyframe(min(1, elapsed / 0.86), [0, 0.43, 0.66, 1], [1, 0.94, 1.025, 1])
        return VStack(alignment: .leading, spacing: compact ? 12 : 18) {
            Text(receipt.title).font(.title2.weight(.semibold))
            if let start = receipt.periodStart {
                HStack { Text(start, format: .dateTime.year().month().day()); if let end = receipt.periodEnd { Text(verbatim: "–"); Text(end, format: .dateTime.year().month().day()) } }.font(.caption).foregroundStyle(PaperTheme.muted)
            }
            VStack(spacing: compact ? 56 : 84) {
                settlementSource(elapsed,compact: compact)
                    .frame(maxWidth: 330).scaleEffect(receipt.net > 0 ? sourceScale : 1).offset(y: receipt.net > 0 ? sourcePose : 0)
                    .anchorPreference(key: OutcomeAnchorPreference.self, value: .bounds) { [.source: $0] }
                settlementWallet(elapsed, value: value,compact: compact)
                    .frame(maxWidth: 360)
                    .anchorPreference(key: OutcomeAnchorPreference.self, value: .bounds) { [.wallet: $0] }
            }.padding(.top, compact ? 10 : 18).frame(maxWidth: .infinity)
            if receipt.recoveryAfter > 0 { Text(String(localized: "v1.wish.recovery") + " " + MoneyFormat.string(receipt.recoveryAfter, currencyCode: receipt.currency)).font(.subheadline) }
            Text(String(localized: receipt.net > 0 ? "native.outcome.savedForWish" : "wallet.settlement.saved")).font(.caption).foregroundStyle(PaperTheme.muted).frame(maxWidth: .infinity).padding(.top, 8)
                .opacity(receipt.net > 0 ? reveal(elapsed, 2.05, 0.42) : 1)
        }
    }

    private func settlementSource(_ elapsed: Double,compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: receipt.net > 0 ? "native.outcome.transferred" : receipt.recoveryAfter < receipt.recoveryBefore ? "v1.wish.recovery" : "wallet.settlement.complete")).font(.caption).foregroundStyle(PaperTheme.muted)
            Text((receipt.net > 0 ? "+" : "") + MoneyFormat.string(receipt.net, currencyCode: receipt.currency))
                .font(.system(size: typeSize.isAccessibilitySize ? 31 : 34, weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                .opacity(receipt.net > 0 ? reveal(elapsed, 0, 0.34) : 1)
            if receipt.recoveryBefore > receipt.recoveryAfter {
                Text(String(localized: "native.outcome.recovered") + " " + MoneyFormat.string(receipt.recoveryBefore - receipt.recoveryAfter, currencyCode: receipt.currency)).font(.caption).foregroundStyle(PaperTheme.muted)
            }
        }.frame(maxWidth: .infinity, minHeight: compact ? 82 : 108, alignment: .leading).padding(compact ? 18 : 22)
            .background {
                ZStack {
                    PaperTheme.card
                    if receipt.net > 0 {
                        NativeLiquidSurface(progress: 0.64, active: false)
                            .opacity((1 - reveal(elapsed, 0.8, 0.65)) * 0.65)
                            .scaleEffect(y: 1 - reveal(elapsed, 0.28, 1.17) * 0.9, anchor: .bottom)
                            .offset(y: reveal(elapsed, 0.28, 1.17) * 65)
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 26))
            }
            .overlay { RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.7), lineWidth: 0.8) }
            .shadow(color: PaperTheme.accent.opacity(0.1), radius: 14, y: 8)
    }

    private func settlementWallet(_ elapsed: Double, value: Decimal,compact: Bool) -> some View {
        let beat=rewardPulse(elapsed)
        let pulse=sin(beat.progress * Double.pi)
        let scale: CGFloat=receipt.net>0 ? 1+CGFloat(pulse)*(beat.isFinal ? 0.055 : 0.025) : 1
        let lift: CGFloat=receipt.net>0 ? -CGFloat(pulse)*(beat.isFinal ? 5 : 2) : 0
        let glowing=elapsed>2.05 && elapsed<2.68 && receipt.net>0
        let fade=1-reveal(elapsed,2.05,0.63)
        let rim: Color=glowing ? gold.opacity(fade*0.85) : Color.white.opacity(0.6)
        let shadow: Color=receipt.net>0 && elapsed>2.05 ? gold.opacity(fade*0.2) : PaperTheme.accent.opacity(0.08)
        let shown=receipt.net>0 ? value : receipt.after
        let increment=receipt.net>0 ? value-receipt.before : receipt.net
        let incrementText=(receipt.net>0 ? "+" : "")+MoneyFormat.string(increment,currencyCode: receipt.currency)
        return VStack(alignment: .leading,spacing: 8) {
            Text(String(localized: "v1.wish.balance")).font(.caption).foregroundStyle(PaperTheme.muted)
            Text(MoneyFormat.string(shown,currencyCode: receipt.currency))
                .font(.system(size: typeSize.isAccessibilitySize ? 36 : 34,weight: .semibold))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
                .offset(y: -CGFloat(pulse)*2).transaction { $0.animation=nil }.accessibilityHidden(true)
            HStack { Spacer();Text(incrementText).font(.caption).monospacedDigit().foregroundStyle(PaperTheme.accent) }
        }
        .frame(maxWidth: .infinity,minHeight: compact ? 78 : 82,alignment: .leading).padding(compact ? 18 : 22)
        .background(LinearGradient(colors: [PaperTheme.card,PaperTheme.accent.opacity(0.13)],startPoint: .topLeading,endPoint: .bottomTrailing),in: RoundedRectangle(cornerRadius: 25))
        .background(PaperTheme.card, in: RoundedRectangle(cornerRadius: 25))
        .overlay { RoundedRectangle(cornerRadius: 25).stroke(rim,lineWidth: 1.2) }
        .shadow(color: shadow,radius: 22,y: 7).scaleEffect(scale).offset(y: lift)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "v1.wish.balance")+" "+MoneyFormat.string(receipt.after,currencyCode: receipt.currency))
        .accessibilityIdentifier("native.outcome.wallet")
    }
    private func reveal(_ t: Double, _ from: Double, _ duration: Double) -> Double { min(1, max(0, (t - from) / duration)) }
    private func smooth(_ value: Double) -> Double { value * value * (3 - 2 * value) }
}

private enum OutcomeAnchor: Hashable { case source, wallet }
private struct OutcomeAnchorPreference: PreferenceKey {
    static var defaultValue: [OutcomeAnchor: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [OutcomeAnchor: Anchor<CGRect>], nextValue: () -> [OutcomeAnchor: Anchor<CGRect>]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

private func rewardKeyframe(_ p: Double, _ times: [Double], _ values: [Double]) -> Double {
    guard p < 1, let i = times.indices.dropLast().first(where: { p < times[$0 + 1] }) else { return values.last ?? 0 }
    let f = max(0, (p - times[i]) / (times[i + 1] - times[i]))
    let eased = f * f * (3 - 2 * f)
    return values[i] + (values[i + 1] - values[i]) * eased
}
private func rewardPulse(_ elapsed: Double) -> (progress: Double, isFinal: Bool) {
    guard let i = RewardTiming.arrivalTimes.lastIndex(where: { elapsed >= $0 }) else { return (0, false) }
    return (min(1, max(0, (elapsed - RewardTiming.arrivalTimes[i]) / (i == 5 ? 0.42 : 0.19))), i == 5)
}

/// The pane and item share one pose. Cracks propagate from a random impact point;
/// each shared chipped edge tiles its neighbour before flying in perspective.
private struct RewardGlassPane: View {
    let fracture: GlassFractureScene
    let elapsed: TimeInterval
    let seed: UInt64
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(x: 100, y: 100, width: size.width - 200, height: size.height - 200)
            let origin = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.49)
            if elapsed < 0.9 { drawGather(context, origin: origin) }
            drawPane(context, rect: rect)
            if elapsed >= 0.9 {
                let age = elapsed - 0.9
                rewardBloom(context, origin: origin, elapsed: age, strength: 1, seed: seed)
                rewardParticles(context, origin: origin, elapsed: age, seed: seed, wish: true, strength: 0.8)
            }
        }
    }

    private func drawGather(_ original: GraphicsContext, origin: CGPoint) {
        var random = VisualRandom(state: seed &+ 700)
        let raw = max(0, min(1, (elapsed - 0.18) / 0.72)), progress = raw * raw * (3 - 2 * raw)
        for i in 0..<22 {
            let n = random.next(), angle = random.next() * .pi * 2
            let phase = (progress * (1.1 + n * 0.6) + n).truncatingRemainder(dividingBy: 1)
            let radius = (1 - phase) * (100 + n * 95) + 18
            var context = original
            context.opacity = sin(phase * .pi) * progress * 0.6
            context.translateBy(x: origin.x + cos(angle) * radius, y: origin.y + sin(angle) * radius * 0.75)
            context.rotate(by: .radians(angle + .pi / 2))
            context.fill(Path(ellipseIn: CGRect(x: -0.8 - n * 0.7, y: -1.6 - n * 1.3, width: 1.6 + n * 1.4, height: 3.2 + n * 2.6)), with: .color(i % 4 == 0 ? Color(red: 0.82, green: 0.9, blue: 0.88) : Color(red: 0.91, green: 0.97, blue: 1)))
        }
    }

    private func drawPane(_ original: GraphicsContext, rect: CGRect) {
        var context = original
        if elapsed < 0.9 { context.clip(to: Path(roundedRect: rect, cornerRadius: 28)) }
        let pressure = smooth((elapsed - 0.25) / 0.6)
        for cell in fracture.fragments {
            let age = max(0, elapsed - 0.9 - cell.delay)
            guard age <= cell.life else { continue }
            let points = projection(cell, rect: rect, age: age)
            guard !points.isEmpty else { continue }
            let fade = age == 0 ? 0.55 + pressure * 0.3 : pow(clamp(1 - age / cell.life), 0.75) * 0.9
            var layer = context
            layer.opacity = fade
            if age > 0.2 { layer.addFilter(.blur(radius: max(0, (cell.depth - 90) / 160) * age * 1.2)) }
            let path = polygonPath(points)
            let colors: [Gradient.Stop] = [
                .init(color: Color(red: 0.91, green: 0.97, blue: 0.99).opacity(0.66 + cell.shade * 0.3), location: 0),
                .init(color: Color(red: 0.61, green: 0.78, blue: 0.85).opacity(0.85), location: 0.35),
                .init(color: Color(red: 0.95, green: 0.99, blue: 1).opacity(0.63), location: 0.51),
                .init(color: Color(red: 0.46, green: 0.66, blue: 0.74).opacity(0.8), location: 0.55),
                .init(color: Color(red: 0.25, green: 0.44, blue: 0.53).opacity(0.89), location: 1)
            ]
            layer.fill(path, with: .linearGradient(Gradient(stops: colors), startPoint: CGPoint(x: rect.minX - cell.shade * 65, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
            if age > 0 {
                layer.stroke(path, with: .color(Color(red: 0.12, green: 0.29, blue: 0.37).opacity(0.38)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                var glint = layer; glint.translateBy(x: -0.55, y: -0.8)
                glint.stroke(path, with: .color(.white.opacity(0.52 + abs(sin(age * cell.spinY)) * 0.45)), lineWidth: 0.85)
                if cell.shade > 0.65 {
                    var sheen = layer; sheen.clip(to: path); sheen.opacity = fade * 0.3
                    let first = points[0]
                    sheen.fill(polygonPath([CGPoint(x: first.x - 20, y: first.y), CGPoint(x: first.x + 40, y: first.y + 2), CGPoint(x: first.x - 3, y: first.y + 80)]), with: .color(.white))
                }
            }
        }
        if elapsed < 1.03 {
            let flash = clamp((elapsed - 0.7) / 0.2), fade = elapsed > 0.9 ? clamp(1 - (elapsed - 0.9) / 0.13) : 1
            for edge in fracture.cracks {
                let progress = smooth((elapsed - 0.32 - edge.delay) / 0.43)
                guard progress > 0 else { continue }
                let a = CGPoint(x: rect.minX + edge.a.x * rect.width, y: rect.minY + edge.a.y * rect.height)
                let b = CGPoint(x: rect.minX + (edge.a.x + (edge.b.x - edge.a.x) * progress) * rect.width,
                                y: rect.minY + (edge.a.y + (edge.b.y - edge.a.y) * progress) * rect.height)
                var line = Path(); line.move(to: a); line.addLine(to: b)
                context.stroke(line, with: .color(Color(red: 0.13, green: 0.31, blue: 0.4).opacity(fade * 0.62)), lineWidth: 1.7)
                context.stroke(line, with: .color(.white.opacity(fade * (0.58 + flash * 0.4))), lineWidth: 0.52 + flash * 0.55)
            }
            context.stroke(Path(roundedRect: rect.insetBy(dx: 0.6, dy: 0.6), cornerRadius: 28), with: .color(.white.opacity(0.25 + pressure * 0.4)), lineWidth: 1.1)
        }
    }

    private func projection(_ cell: GlassFragment, rect: CGRect, age: Double) -> [CGPoint] {
        let scale = rect.width / 346, drag = age / (1 + age * 0.42)
        let tx = cell.velocity.x * drag * scale, ty = (cell.velocity.y * drag + 365 * age * age) * scale
        let z = cell.depth * sin(min(1, age / 0.6) * .pi / 2)
        let ax = cell.spinX * age, ay = cell.spinY * age, az = cell.rotation * age
        let cx = rect.minX + cell.center.x * rect.width, cy = rect.minY + cell.center.y * rect.height
        return cell.points.map { point in
            let x = (point.x - cell.center.x) * rect.width, y = (point.y - cell.center.y) * rect.height
            let y1 = y * cos(ax), z1 = y * sin(ax)
            let x1 = x * cos(ay) + z1 * sin(ay), z2 = -x * sin(ay) + z1 * cos(ay)
            let perspective = 700 / max(100, 700 - z - z2)
            return CGPoint(x: cx + tx + (x1 * cos(az) - y1 * sin(az)) * perspective,
                           y: cy + ty + (x1 * sin(az) + y1 * cos(az)) * perspective)
        }
    }
    private func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
    private func smooth(_ v: Double) -> Double { let p = clamp(v); return p * p * (3 - 2 * p) }
}

private struct RewardCoinHarvest: View {
    let elapsed: TimeInterval
    let source: CGRect
    let wallet: CGRect
    let seed: UInt64
    let currency: String
    private var symbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.currencySymbol ?? currency
    }
    var body: some View {
        let currencySymbol = symbol
        Canvas { context, _ in
            let start = CGPoint(x: source.midX, y: source.minY + source.height * 0.75)
            let end = CGPoint(x: wallet.midX, y: wallet.minY + 20)
            var random = VisualRandom(state: seed &+ 1300)
            for i in 0..<42 {
                let group = i / 7, slot = i % 7
                let arrival = RewardTiming.arrivalTimes[group] + Double(slot - 3) * 0.018
                let flight = 0.51 + random.next() * 0.13, launch = arrival - flight
                let sx = (random.next() - 0.5) * 52, ex = (random.next() - 0.5) * 38
                let bend = (i % 2 == 1 ? -1.0 : 1.0) * (40 + random.next() * 82), rise = 55 + random.next() * 60
                let radius = 7 + random.next() * 6, spin = 4 + random.next() * 6, phase = random.next() * 6.28
                let p = (elapsed - launch) / flight
                guard p >= 0, p <= 1 else { continue }
                let u = 1 - p
                let x = u * start.x + p * end.x + sx * u + ex * p + sin(p * .pi) * bend
                let y = u * start.y + p * end.y - sin(p * .pi) * rise
                let alpha = min(1, p / 0.06) * min(1, (1 - p) / 0.08)
                if p > 0.2 {
                    var trail = context; trail.opacity = alpha * 0.14
                    var path = Path(); path.move(to: CGPoint(x: x - bend * 0.14, y: y - 17)); path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 3, y: y - 7))
                    trail.stroke(path, with: .color(i % 3 == 0 ? Color(red: 0.96, green: 0.85, blue: 0.61) : Color(red: 0.77, green: 0.88, blue: 0.94)), style: StrokeStyle(lineWidth: radius * 0.65, lineCap: .round))
                }
                drawCoin(context, at: CGPoint(x: x, y: y), radius: radius, rotation: phase + p * spin,
                         tilt: (p - 0.5) * 0.65 + sin(p * 5 + phase) * 0.22, gold: i % 3 == 0, alpha: alpha, symbol: currencySymbol)
            }
            receiving(context, at: end)
        }
    }

    private func drawCoin(_ original: GraphicsContext, at point: CGPoint, radius: Double, rotation: Double, tilt: Double, gold: Bool, alpha: Double, symbol: String) {
        var context = original
        context.translateBy(x: point.x, y: point.y); context.rotate(by: .radians(tilt))
        let face = cos(rotation), squeeze = 0.14 + abs(face) * 0.86
        context.scaleBy(x: squeeze, y: 1); context.opacity = alpha
        let rect = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect.offsetBy(dx: 2.3, dy: 1.4)), with: .color(gold ? Color(red: 0.529, green: 0.4, blue: 0.227) : Color(red: 0.31, green: 0.42, blue: 0.48)))
        let stops: [Gradient.Stop] = gold ? [
            .init(color: Color(red: 1, green: 0.961, blue: 0.816), location: 0), .init(color: Color(red: 0.91, green: 0.788, blue: 0.471), location: 0.32),
            .init(color: Color(red: 1, green: 0.957, blue: 0.784), location: 0.52), .init(color: Color(red: 0.769, green: 0.588, blue: 0.29), location: 0.55), .init(color: Color(red: 0.886, green: 0.737, blue: 0.412), location: 1)
        ] : [
            .init(color: Color(red: 0.93, green: 0.97, blue: 1), location: 0), .init(color: Color(red: 0.72, green: 0.82, blue: 0.88), location: 0.32),
            .init(color: Color(red: 0.94, green: 0.98, blue: 1), location: 0.52), .init(color: Color(red: 0.46, green: 0.59, blue: 0.67), location: 0.55), .init(color: Color(red: 0.59, green: 0.72, blue: 0.79), location: 1)
        ]
        context.fill(Path(ellipseIn: rect), with: .linearGradient(Gradient(stops: stops), startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.8)), lineWidth: 0.8)
        context.stroke(Path(ellipseIn: rect.insetBy(dx: radius * 0.24, dy: radius * 0.24)), with: .color(gold ? Color(red: 0.65, green: 0.518, blue: 0.282) : Color(red: 0.41, green: 0.55, blue: 0.63)), lineWidth: 0.65)
        if abs(face) > 0.32 {
            context.draw(Text(verbatim: symbol).font(.system(size: radius * 1.2, weight: .semibold)).foregroundStyle(gold ? Color(red: 0.518, green: 0.392, blue: 0.22) : Color(red: 0.28, green: 0.41, blue: 0.49)), at: CGPoint(x: 0, y: radius * 0.06))
        }
    }

    private func receiving(_ original: GraphicsContext, at end: CGPoint) {
        for (index, beat) in RewardTiming.arrivalTimes.enumerated() {
            let age = elapsed - beat
            guard age >= 0, age <= 0.48 else { continue }
            let p = age / 0.48
            var context = original; context.opacity = pow(1 - p, 2) * 0.8
            var arc = Path()
            arc.addArc(center: .zero, radius: 1, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            let transform = CGAffineTransform(scaleX: 20 + p * 110, y: 6 + p * 20).concatenating(CGAffineTransform(translationX: end.x, y: end.y + 10))
            context.stroke(arc.applying(transform), with: .color(index == 5 ? Color(red: 1, green: 0.88, blue: 0.627) : Color(red: 0.82, green: 0.92, blue: 0.98)), lineWidth: 1.6)
        }
        if elapsed >= 2.05 {
            rewardBloom(original, origin: end, elapsed: elapsed - 2.05, strength: 1.15, seed: seed)
            rewardParticles(original, origin: end, elapsed: elapsed - 2.05, seed: seed, wish: false, strength: 1)
        }
        if elapsed > 0.76, elapsed < 2.5 {
            let intensity = smooth((elapsed - 0.76) / 0.5) * (1 - smooth((elapsed - 2.1) / 0.4))
            var context = original; context.opacity = intensity * 0.11
            let center = CGPoint(x: wallet.midX, y: wallet.minY + wallet.height * 0.4)
            for i in 0..<7 {
                let angle = -.pi / 2 + Double(i - 3) * 0.27 + Double(i + 1) * 0.11
                let a = CGPoint(x: center.x + cos(angle - 0.05) * 310, y: center.y + sin(angle - 0.05) * 310)
                let b = CGPoint(x: center.x + cos(angle + 0.05) * 310, y: center.y + sin(angle + 0.05) * 310)
                context.fill(polygonPath([center, a, b]), with: .linearGradient(Gradient(colors: [Color(red: 0.976, green: 0.867, blue: 0.608), .clear]), startPoint: center, endPoint: CGPoint(x: center.x + cos(angle) * 260, y: center.y + sin(angle) * 260)))
            }
        }
    }
    private func smooth(_ value: Double) -> Double { let p = min(1, max(0, value)); return p * p * (3 - 2 * p) }
}

private func polygonPath(_ points: [CGPoint]) -> Path {
    var path = Path(); for (i, point) in points.enumerated() { if i == 0 { path.move(to: point) } else { path.addLine(to: point) } }; path.closeSubpath(); return path
}

private func rewardBloom(_ original: GraphicsContext, origin: CGPoint, elapsed: Double, strength: Double, seed: UInt64) {
    let progress = min(1, max(0, elapsed / 0.64)), alpha = pow(1 - progress, 2) * strength
    guard alpha > 0 else { return }
    let radius = 35 + progress * 230
    var context = original
    context.fill(Path(ellipseIn: CGRect(x: origin.x - radius, y: origin.y - radius, width: radius * 2, height: radius * 2)), with: .radialGradient(Gradient(stops: [
        .init(color: Color(red: 1, green: 0.976, blue: 0.922).opacity(alpha * 0.62), location: 0),
        .init(color: Color(red: 0.9, green: 0.96, blue: 1).opacity(alpha * 0.4), location: 0.18),
        .init(color: Color(red: 0.58, green: 0.79, blue: 0.9).opacity(alpha * 0.2), location: 0.5),
        .init(color: .clear, location: 1)
    ]), center: origin, startRadius: 0, endRadius: radius))
    context.opacity = alpha * 0.6
    var random = VisualRandom(state: seed)
    for i in 0..<14 {
        let angle = Double(i) * 2.399963 + random.next() * 0.2, from = 18 + progress * 65, to = from + 30 + random.next() * 75
        var line = Path(); line.move(to: CGPoint(x: origin.x + cos(angle) * from, y: origin.y + sin(angle) * from * 0.8)); line.addLine(to: CGPoint(x: origin.x + cos(angle) * to, y: origin.y + sin(angle) * to * 0.8))
        context.stroke(line, with: .color(Color(red: 0.969, green: 0.914, blue: 0.769)), lineWidth: 0.85)
    }
}

private func rewardParticles(_ original: GraphicsContext, origin: CGPoint, elapsed: Double, seed: UInt64, wish: Bool, strength: Double) {
    var random = VisualRandom(state: seed &+ 9000)
    let colors = wish ? [Color(red: 0.92, green: 0.98, blue: 1), Color(red: 0.67, green: 0.82, blue: 0.91), .white, Color(red: 0.75, green: 0.9, blue: 0.97)] : [Color(red: 0.929, green: 0.808, blue: 0.522), Color(red: 0.7, green: 0.83, blue: 0.92), Color(red: 1, green: 0.961, blue: 0.875), Color(red: 0.824, green: 0.698, blue: 0.38)]
    for i in 0..<(wish ? 64 : 48) {
        let angle = wish ? random.next() * .pi * 2 : .pi + random.next() * .pi
        let speed = 80 + random.next() * 230, vx = cos(angle) * speed, vy = sin(angle) * speed * 0.68 - 110
        let size = 0.9 + random.next() * 4.6, life = 0.8 + random.next() * 0.75, delay = random.next() * 0.1
        let spin = (random.next() - 0.5) * 8, rotation = random.next() * 6.28, age = elapsed - delay
        guard age >= 0, age < life else { continue }
        let progress = age / life, drag = age / (1 + age * 0.65)
        var context = original
        context.translateBy(x: origin.x + vx * drag, y: origin.y + vy * drag + 95 * age * age)
        context.rotate(by: .radians(rotation + age * spin))
        context.opacity = pow(1 - progress, 1.2) * min(1, age / 0.04) * strength
        if i % 13 == 0 {
            var star = Path(); star.move(to: CGPoint(x: 0, y: -size * 2)); star.addQuadCurve(to: CGPoint(x: size * 1.4, y: 0), control: CGPoint(x: size * 0.2, y: -size * 0.2)); star.addQuadCurve(to: CGPoint(x: 0, y: size * 2), control: CGPoint(x: size * 0.2, y: size * 0.2)); star.addQuadCurve(to: CGPoint(x: -size * 1.4, y: 0), control: CGPoint(x: -size * 0.2, y: size * 0.2)); star.addQuadCurve(to: CGPoint(x: 0, y: -size * 2), control: CGPoint(x: -size * 0.2, y: -size * 0.2)); context.fill(star, with: .color(colors[i % 4]))
        } else {
            let width = size * (0.3 + abs(cos(age * spin + rotation)) * 0.7)
            context.fill(Path(ellipseIn: CGRect(x: -width, y: -size * 0.45, width: width * 2, height: size * 0.9)), with: .color(colors[i % 4]))
        }
    }
}
