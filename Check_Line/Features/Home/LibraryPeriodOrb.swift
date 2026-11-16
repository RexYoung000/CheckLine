import SwiftUI

nonisolated struct LibraryPeriodPresentation: Equatable {
    enum Status: Equatable {
        case remaining(days: Int)
        case endsToday
        case upcoming(days: Int)
        case due
        case settled
        case noDeadline
    }

    let status: Status
    let remainingFraction: Double?

    init(card: HomeBudgetCardModel, now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: card.periodStart)
        if card.periodState == .settled {
            status = .settled
            remainingFraction = 0
        } else if card.periodState == .pendingSettlement {
            status = .due
            remainingFraction = 0
        } else if BudgetPresentation.isUpcoming(card, now: now, calendar: calendar) {
            status = .upcoming(days: calendar.dateComponents([.day], from: today, to: start).day ?? 0)
            remainingFraction = nil
        } else if let endDate = card.periodEnd {
            let period = NextPeriodPlan(startDate: card.periodStart, endDate: endDate)
            guard period.contains(now, calendar: calendar) else {
                status = .due
                remainingFraction = 0
                return
            }
            let end = calendar.startOfDay(for: endDate)
            let days = calendar.dateComponents([.day], from: today, to: end).day ?? 0
            let span = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            status = days == 0 ? .endsToday : .remaining(days: days)
            // The displayed deadline is the last included day. Its slice stays
            // lit until the period's next-midnight boundary, even across DST.
            remainingFraction = Double(days + 1) / Double(span + 1)
        } else {
            status = .noDeadline
            remainingFraction = nil
        }
    }
}

/// The caller owns scene placement and passes visibility when the arc is covered.
struct LibraryPeriodOrb: View {
    var card: HomeBudgetCardModel
    var now: Date = Date()
    var diameter: CGFloat = 208
    var active = true
    var returnProgress: CGFloat = 0

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @ScaledMetric(relativeTo: .caption2) private var captionSize = 11.0
    @ScaledMetric(relativeTo: .caption) private var unitSize = 13.0
    @ScaledMetric(relativeTo: .title3) private var statusSize = 24.0
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 36.0
    @State private var visible = false
    @State private var clock = LiquidMotionClock()
    @State private var transition: OrbTransition?

    private var staticMode: Bool { reduceMotion || voiceOver }
    private var returning: CGFloat { min(1, max(0, returnProgress)) }
    private var running: Bool { visible && active && returning < 1 && !staticMode && scenePhase == .active }
    private var textScale: CGFloat { max(0.79, min(1, diameter / 208)) }
    private var centerCaptionSize: CGFloat { min(captionSize, diameter * 0.085) }
    private var ink: Color { .paper(light: 0x182B35, dark: 0xF5FAFC) }
    private var muted: Color { .paper(light: 0x657780, dark: 0xA2AFB5) }

    var body: some View {
        let period = LibraryPeriodPresentation(card: card, now: now, calendar: calendar)
        let target = OrbTarget(periodID: card.periodID, remaining: period.remainingFraction)
        let copy = OrbCopy(status: period.status)
        let dates = dateText
        VStack(spacing: 0) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { tick in
                    let elapsed = clock.elapsedTime(at: tick.date.timeIntervalSinceReferenceDate)
                    let level = running ? transition?.frame(at: elapsed) ?? OrbFrame(target: target) : OrbFrame(target: target)
                    LibraryPeriodLights(frame: level, elapsed: staticMode ? nil : elapsed, dark: scheme == .dark)
                        .accessibilityHidden(true)
                }
                center(copy)
                    .frame(width: diameter * 0.54)
                    .transaction { $0.animation = nil }
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(staticMode ? 1 : 1 - 0.08 * returning)

            Text(verbatim: dates)
                .font(.system(size: captionSize, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: max(diameter, 168))
        }
        .allowsHitTesting(false)
        .opacity(Double(1 - returning))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: card.name))
        .accessibilityValue(Text(verbatim: [copy.heading, copy.spokenValue(locale: locale), dates].joined(separator: "\n")))
        .accessibilityIdentifier("native.library.period")
        .accessibilityHidden(returning >= 1)
        .onAppear { visible = true }
        .onDisappear {
            visible = false
            clock.setRunning(false, at: Date().timeIntervalSinceReferenceDate)
            transition = nil
        }
        .onChange(of: running, initial: true) { _, running in
            clock.setRunning(running, at: Date().timeIntervalSinceReferenceDate)
            if !running { transition = nil }
        }
        .onChange(of: target) { previous, target in
            guard running else { return }
            let elapsed = clock.elapsedTime(at: Date().timeIntervalSinceReferenceDate)
            let current = transition?.frame(at: elapsed) ?? OrbFrame(target: previous)
            transition = OrbTransition(from: current, to: target, startedAt: elapsed)
        }
    }

    private func center(_ copy: OrbCopy) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: copy.heading)
                .font(.system(size: centerCaptionSize, weight: .medium))
                .foregroundStyle(muted)
                .lineLimit(2)
            if let days = copy.days {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(days, format: .number)
                        .font(.system(size: min(numberSize * textScale, diameter * 0.25), weight: .semibold))
                        .monospacedDigit()
                    Text(verbatim: copy.unit)
                        .font(.system(size: min(unitSize, diameter * 0.11), weight: .semibold))
                }
                .lineLimit(1)
            } else {
                Text(verbatim: copy.value)
                    .font(.system(size: min(statusSize * textScale, diameter * 0.14), weight: .semibold))
                    .lineLimit(2)
            }
        }
        .foregroundStyle(ink)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.65)
    }

    private var dateText: String {
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month().day()
        if !calendar.isDate(card.periodStart, equalTo: now, toGranularity: .year) { style = style.year() }
        if let end = card.periodEnd {
            if !calendar.isDate(card.periodStart, equalTo: end, toGranularity: .year) { style = style.year() }
            let startText = card.periodStart.formatted(style)
            guard !calendar.isDate(card.periodStart, inSameDayAs: end) else { return startText }
            return String(format: String(localized: "ui.schedule.dateRange"), locale: locale, startText, end.formatted(style))
        }
        return String(format: String(localized: "native.library.period.since"), locale: locale, card.periodStart.formatted(style))
    }
}

private struct OrbCopy {
    var heading: String
    var value = ""
    var days: Int?

    init(status: LibraryPeriodPresentation.Status) {
        switch status {
        case .remaining(let days):
            heading = String(localized: "native.library.period.remaining")
            self.days = days
        case .upcoming(let days):
            heading = String(localized: "native.library.period.upcoming")
            self.days = days
        case .endsToday:
            heading = String(localized: "native.library.period.current")
            value = String(localized: "native.library.period.endsToday")
        case .due:
            heading = String(localized: "native.library.period.ended")
            value = String(localized: "native.library.period.due")
        case .settled:
            heading = String(localized: "native.library.period.ended")
            value = String(localized: "native.library.period.settled")
        case .noDeadline:
            heading = String(localized: "native.library.period.oneShot")
            value = String(localized: "native.library.period.noDeadline")
        }
    }

    var unit: String {
        days == 1 ? String(localized: "native.library.period.day") : String(localized: "native.library.period.days")
    }

    func spokenValue(locale: Locale) -> String {
        guard let days else { return value }
        return "\(days.formatted(.number.locale(locale))) \(unit)"
    }
}

private struct OrbTarget: Equatable {
    var periodID: UUID
    var remaining: Double?
}

private struct OrbTransition {
    var from: OrbFrame
    var to: OrbTarget
    var startedAt: TimeInterval

    func frame(at elapsed: TimeInterval) -> OrbFrame {
        let age = max(0, elapsed - startedAt)
        let end = OrbFrame(target: to)
        let fraction = to.remaining ?? from.fraction
        guard age < 1.25 else { return end }
        return OrbFrame(
            fraction: fraction + (from.fraction - fraction) * exp(-age / 0.18),
            certainty: end.certainty + (from.certainty - end.certainty) * exp(-age / 0.16),
            passage: min(1, age / 0.72)
        )
    }
}

private struct OrbFrame {
    var fraction: Double
    var certainty: Double
    var passage: Double

    init(fraction: Double, certainty: Double, passage: Double) {
        self.fraction = fraction
        self.certainty = certainty
        self.passage = passage
    }

    init(target: OrbTarget) {
        self.init(fraction: target.remaining ?? 0, certainty: target.remaining == nil ? 0 : 1, passage: 1)
    }

    func light(at position: Double) -> Double {
        // A known but exhausted period has no bright slice at the seam.
        let edge = max(0, min(1, (fraction - position) * 32 + 0.5))
        return min(1, fraction * 32) * certainty * edge * edge * (3 - 2 * edge)
    }

    func sweep(at position: Double) -> Double {
        sin(passage * .pi) * max(0, 1 - abs(position / max(0.03, fraction) - passage) * 5)
    }
}

private struct LibraryPeriodLights: View {
    var frame: OrbFrame
    /// Nil selects the stationary drawing rather than sampling a live phase.
    var elapsed: TimeInterval?
    var dark: Bool

    private static let turn = Double.pi * 2
    private static let referenceDiameter = 208.0

    var body: some View {
        Canvas { context, size in
            var drawing = context
            let scale = min(size.width, size.height) / Self.referenceDiameter
            drawing.translateBy(x: size.width / 2, y: size.height / 2)
            drawing.scaleBy(x: scale, y: scale)
            if dark { drawDark(in: drawing) }
            else { drawLight(in: drawing) }
        }
    }

    // Fine grains and their twelve glint positions use a stable, independent
    // field. Changing the focus only changes the light falling on them.
    private struct Grain {
        var angle: Double
        var position: Double
        var spread: Double
        var depth: Double
        var radius: Double
        var phase: Double
        var rear: Bool
        var glint = false
    }

    private static let grains: [Grain] = {
        var grains = (0..<800).map { index in
            let angle = (Double(index) + hash(index + 1)) / 800 * turn
            let rear = index.isMultiple(of: 4)
            let spread = rear ? -0.09 - hash(index + 47) * 0.13 :
                (hash(index + 19) + hash(index + 47) + hash(index + 83) - 1.5) * 0.14
            return Grain(angle: angle, position: (angle + .pi / 2).truncatingRemainder(dividingBy: turn) / turn,
                         spread: spread, depth: hash(index + 131), radius: 0.38 + pow(hash(index + 251), 2) * 0.52,
                         phase: hash(index + 419) * turn, rear: rear)
        }
        let candidates = grains.indices.filter { !grains[$0].rear && abs(grains[$0].spread) < 0.09 }
            .sorted { grains[$0].depth > grains[$1].depth }
        var glintAngles: [Double] = []
        for index in candidates {
            let angle = grains[index].angle
            guard !glintAngles.contains(where: {
                let distance = abs($0 - angle)
                return min(distance, turn - distance) < 0.32
            }) else { continue }
            grains[index].glint = true
            glintAngles.append(angle)
            if glintAngles.count == 12 { break }
        }
        return grains
    }()

    private struct LightGrain {
        var point: CGPoint
        var radius: Double
        var depth: Double
        var lit: Double
        var alpha: Double
        var shine: Double
    }

    private func drawLight(in context: GraphicsContext) {
        let time = elapsed ?? 0
        let breathing = elapsed == nil ? 1 : 1 + sin(time * 0.28) * 0.009
        let grains = Self.grains.map { grain in
            let angle = grain.angle + (elapsed == nil ? 0 : sin(time * 0.22 + grain.phase) * 0.014)
            let ripple = elapsed == nil ? 0 : sin(grain.angle * 3 - time * 0.55) * 0.008
            let radial = Self.referenceDiameter * 0.394 * (1 + grain.spread + ripple) * breathing
            let x = cos(angle) * radial
            let y = sin(angle) * radial * 0.91 + x * 0.045
            let lit = frame.light(at: grain.position)
            let shimmer = elapsed == nil ? 1 : 0.86 + 0.14 * sin(time * 0.72 + grain.phase)
            let alpha = (0.42 + lit * 0.44) * shimmer * (0.65 + 0.35 * grain.depth) * (grain.rear ? 0.43 : 1)
            let sparkle = elapsed == nil ? 0.85 : 0.66 + 0.34 * pow(0.5 + 0.5 * sin(time * 0.9 + grain.phase), 2)
            let shine = grain.glint ? lit * sparkle * (1 + frame.sweep(at: grain.position) * 0.2) : 0
            return LightGrain(point: CGPoint(x: x, y: y), radius: grain.radius, depth: grain.depth,
                              lit: lit, alpha: alpha, shine: shine)
        }
        let glints = grains.filter { $0.shine >= 0.002 }
        for glint in glints {
            gradient(in: context, at: glint.point, radius: 5.5 + glint.depth * 1.5, stops: [
                stop(0x73B5D1, glint.shine * 0.52, at: 0),
                stop(0x73B5D1, glint.shine * 0.26, at: 0.28),
                stop(0x84BFD6, glint.shine * 0.09, at: 0.60),
                stop(0x96CADC, 0, at: 1)
            ])
        }
        for grain in grains {
            let color = Color(red: (109 - grain.lit * 63).rounded() / 255,
                              green: (131 - grain.lit * 12).rounded() / 255,
                              blue: (143 + grain.lit * 7).rounded() / 255, opacity: grain.alpha)
            context.fill(dot(at: grain.point, radius: grain.radius), with: .color(color))
        }
        for glint in glints {
            gradient(in: context, at: glint.point, radius: 1.06 + glint.depth * 0.25, stops: [
                stop(0x4693B1, min(1, glint.shine * 1.15), at: 0),
                stop(0x68AFC6, min(1, glint.shine), at: 0.62),
                stop(0x92C6D8, 0, at: 1)
            ])
        }
    }

    private struct Star {
        var position: Double
        var angle: Double
        var radius: Double
        var size: Double
        var depth: Double
        var phase: Double
        var faint: Bool
    }

    private static let stars: [Star] = {
        var seed: UInt32 = 713193
        func random() -> Double {
            seed = seed &* 1664525 &+ 1013904223
            return Double(seed) / 4294967296
        }
        var stars: [Star] = []
        var points: [CGPoint] = []
        for _ in 0..<5000 {
            let position = random()
            let angle = position * turn - .pi / 2
            let spread = (random() * 2 - 1) * (0.74 + 0.26 * sin(angle * 3 + 0.8))
            let radius = 0.361 + spread * 0.063 + sin(angle * 3 + 0.6) * 0.009
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            guard !points.contains(where: { hypot($0.x - point.x, $0.y - point.y) < 0.025 }) else { continue }
            points.append(point)
            stars.append(Star(position: position, angle: angle, radius: radius, size: 0.62 + random() * 0.92,
                              depth: random(), phase: random() * turn, faint: false))
            if stars.count == 88 { break }
        }
        for _ in 0..<28 {
            let position = random()
            stars.append(Star(position: position, angle: position * turn - .pi / 2,
                              radius: 0.36 + (random() - 0.5) * 0.16, size: 0.35 + random() * 0.35,
                              depth: random() * 0.5, phase: random() * turn, faint: true))
        }
        return stars.sorted { $0.depth < $1.depth }
    }()

    private struct DarkPoint {
        var point: CGPoint
        var depth: Double
        var lit: Double
        var strength: Double
        var core: Double
        var base: Double
        var faint: Bool
    }

    private func drawDark(in context: GraphicsContext) {
        let time = elapsed ?? 0
        let points = Self.stars.map { star in
            let drift = sin(time * 0.42 + star.phase)
            let angle = star.angle + sin(time * 0.27 + star.phase) * 0.012
            let radial = star.radius * Self.referenceDiameter + drift * 0.85
            let lit = frame.light(at: star.position)
            let breathe = elapsed == nil ? 1 : 0.85 + 0.15 * sin(time * 0.85 + star.phase)
            let strength = lit * breathe * (star.faint ? 0.35 : 0.75 + star.depth * 0.25) * (1 + frame.sweep(at: star.position) * 0.16)
            return DarkPoint(point: CGPoint(x: cos(angle) * radial, y: sin(angle) * radial * 0.98), depth: star.depth,
                             lit: lit, strength: strength, core: (star.faint ? 0.8 : 1.72) * star.size,
                             base: 0.5 + star.size * 0.36, faint: star.faint)
        }
        for point in points {
            let alpha = 0.40 * (point.faint ? 0.44 : 0.65 + point.depth * 0.35) * (1 - point.lit)
            let radius = point.base * (1.25 + (1 - frame.certainty) * 0.24)
            gradient(in: context, at: point.point, radius: radius, stops: [
                stop(0xA7BED1, alpha, at: 0), stop(0xA7BED1, alpha * 0.8, at: 0.45), stop(0xA7BED1, 0, at: 1)
            ])
        }
        let bright = points.filter { $0.lit >= 0.002 }
        var haloContext = context
        haloContext.blendMode = .screen
        for point in bright {
            let radius = min(point.faint ? 6 : 12 + point.depth * 3,
                             Self.referenceDiameter / 2 - max(abs(point.point.x), abs(point.point.y)) - 1)
            gradient(in: haloContext, at: point.point, radius: radius, stops: [
                stop(0x689EFF, point.strength * 0.82, at: 0),
                stop(0x689EFF, point.strength * 0.50, at: 0.22),
                stop(0x689EFF, point.strength * 0.22, at: 0.48),
                stop(0x689EFF, point.strength * 0.065, at: 0.75),
                stop(0x689EFF, 0, at: 1)
            ])
        }
        for point in bright {
            let opacity = min(1, point.strength * (point.faint ? 1 : 1.22))
            gradient(in: context, at: point.point, radius: point.core * 1.1, stops: [
                stop(0xFFFFFF, opacity, at: 0),
                stop(0xF7FCFF, opacity, at: 0.58),
                stop(0xDDEFFF, opacity * 0.88, at: 0.78),
                stop(0x9CCAFF, 0, at: 1)
            ])
        }
    }

    private static func hash(_ index: Int) -> Double {
        let value = sin(Double(index) * 127.1 + 311.7) * 43758.5453
        return value - floor(value)
    }

    private func dot(at point: CGPoint, radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    private func gradient(in context: GraphicsContext, at point: CGPoint, radius: Double, stops: [Gradient.Stop]) {
        context.fill(dot(at: point, radius: radius), with: .radialGradient(Gradient(stops: stops), center: point, startRadius: 0, endRadius: radius))
    }

    private func stop(_ hex: UInt32, _ alpha: Double, at location: CGFloat) -> Gradient.Stop {
        let color = Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                          blue: Double(hex & 0xFF) / 255, opacity: alpha)
        return Gradient.Stop(color: color, location: location)
    }
}
