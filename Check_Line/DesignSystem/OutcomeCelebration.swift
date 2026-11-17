import SwiftUI

/// Immutable, read-only projection of an already committed wish purchase.
struct OutcomeReceipt: Identifiable {
    let id = UUID()
    let title: String
    let before: Decimal
    let after: Decimal
    let currency: String
    let originalAmount: Decimal
    let originalCurrency: String
    let date: Date
    var cover = WishCover()
    var progress: CGFloat?
    var net: Decimal { after - before }
    var duration: TimeInterval { RewardTiming.wishDuration }
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
    private var foreground: Color { PaperTheme.ink }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: settled || reduceMotion || scenePhase != .active)) { clock in
                let elapsed = (settled || reduceMotion) ? receipt.duration : min(receipt.duration, clock.date.timeIntervalSince(started))
                ZStack {
                    PaperTheme.canvas.ignoresSafeArea()
                    aurora(elapsed).ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading, spacing: geometry.size.height < 700 ? 18 : 26) {
                            header(elapsed)
                            wishScene(elapsed, compact: geometry.size.height < 650 || typeSize.isAccessibilitySize)
                        }
                        .padding(.horizontal, PaperTheme.Layout.sheetPadding)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                        .frame(maxWidth: PaperTheme.Layout.sheetMaxWidth)
                        .frame(maxWidth: .infinity)
                    }.scrollBounceBehavior(.basedOnSize)
                }
                .foregroundStyle(foreground)
                .safeAreaInset(edge: .bottom) {
                    Button(String(localized: "native.outcome.viewRealized"), action: finish)
                        .buttonStyle(WishGlazedButtonStyle(fullWidth: true))
                        .frame(maxWidth: PaperTheme.Layout.sheetMaxWidth)
                        .padding(.horizontal, PaperTheme.Layout.sheetPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [PaperTheme.canvas.opacity(0), PaperTheme.canvas.opacity(0.92), PaperTheme.canvas],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
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
        HStack(spacing: 10) {
            Spacer()
            if elapsed < receipt.duration {
                Button(String(localized: "native.outcome.skip")) { settled = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PaperTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(minWidth: 44, minHeight: 40)
                    .walletSurface(radius: 20)
                    .accessibilityIdentifier("native.outcome.skip")
            }
            Button(action: finish) {
                CheckLineIcon(symbol: "xmark", size: 17)
                    .foregroundStyle(PaperTheme.ink)
                    .paperHeaderCircleChrome()
            }
            .buttonStyle(PaperCirclePressStyle())
            .accessibilityLabel(String(localized: "action.close"))
        }
    }

    private func aurora(_ elapsed: Double) -> some View {
        let strength = elapsed < 0.9 ? reveal(elapsed, 0.1, 0.8) * 0.35 : 0.22 + pow(1 - reveal(elapsed, 0.9, 1.4), 2) * 0.65
        return ZStack {
            RadialGradient(
                colors: [
                    Color.paper(light: 0xB8E7F5, dark: 0x164E63).opacity(strength * 0.55),
                    Color.paper(light: 0xE6F7FC, dark: 0x0E2A36).opacity(strength * 0.30),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [
                    PaperTheme.gold.opacity(strength * 0.28),
                    .clear
                ],
                center: UnitPoint(x: 0.62, y: 0.36),
                startRadius: 8,
                endRadius: 230
            )
        }
    }

    private func wishScene(_ elapsed: TimeInterval, compact: Bool) -> some View {
        let pose = RewardTiming.wishPose(elapsed: elapsed)
        let height: CGFloat = compact ? 226 : 276
        return VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(String(localized: "native.outcome.fulfilled"))
                    .font(.system(size: compact ? 30 : 34, weight: .bold))
                Text(String(localized: "native.outcome.yourMoment"))
                    .font(.subheadline)
                    .foregroundStyle(PaperTheme.muted)
            }
            .opacity(reveal(elapsed, 1.72, 0.43))
            .offset(y: 7 * (1 - reveal(elapsed, 1.72, 0.43)))
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
                Image(systemName: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaperTheme.seaAction)
                    .scaleEffect(elapsed < 2.2 ? 0.65 : 1 + sin(reveal(elapsed, 2.2, 0.39) * .pi) * 0.14)
                Text(String(localized: "native.wish.realized"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PaperTheme.ink)
                Text("·")
                    .foregroundStyle(PaperTheme.muted)
                Text(receipt.date, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(PaperTheme.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .walletSurface(radius: 16)
            .opacity(reveal(elapsed, 2.2, 0.39))
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "v1.wish.balance")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                    Text(MoneyFormat.string(receipt.net, currencyCode: receipt.currency)).font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(PaperTheme.seaAction)
                }
                Spacer(minLength: 8)
                Text(MoneyFormat.string(receipt.after, currencyCode: receipt.currency)).font(.title.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            }
            .foregroundStyle(PaperTheme.ink)
            .padding(20)
            .walletSurface(radius: 22)
            .opacity(reveal(elapsed, 2.41, 0.39))
            .offset(y: 12 * (1 - reveal(elapsed, 2.41, 0.39)))
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

    private func reveal(_ t: Double, _ from: Double, _ duration: Double) -> Double { min(1, max(0, (t - from) / duration)) }
    private func smooth(_ value: Double) -> Double { value * value * (3 - 2 * value) }
}

private func rewardKeyframe(_ p: Double, _ times: [Double], _ values: [Double]) -> Double {
    guard p < 1, let i = times.indices.dropLast().first(where: { p < times[$0 + 1] }) else { return values.last ?? 0 }
    let f = max(0, (p - times[i]) / (times[i + 1] - times[i]))
    let eased = f * f * (3 - 2 * f)
    return values[i] + (values[i + 1] - values[i]) * eased
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
                rewardParticles(context, origin: origin, elapsed: age, seed: seed, strength: 0.8)
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

private func rewardParticles(_ original: GraphicsContext, origin: CGPoint, elapsed: Double, seed: UInt64, strength: Double) {
    var random = VisualRandom(state: seed &+ 9000)
    let colors = [
        Color(red: 0.15, green: 0.56, blue: 0.69),
        Color(red: 0.85, green: 0.68, blue: 0.41),
        Color(red: 0.47, green: 0.79, blue: 0.89),
        .white
    ]
    for i in 0..<64 {
        let angle = random.next() * .pi * 2
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
