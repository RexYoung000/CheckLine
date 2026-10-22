import Foundation
import CoreGraphics

/// Visual state only. No amounts or navigation callbacks are retained by gestures.
nonisolated enum BudgetStage: Int, CaseIterable {
    case records = -1, dashboard = 0, library = 1

    func destination(translation: CGSize, predicted: CGSize) -> Self {
        guard abs(translation.height) > 32, abs(translation.height) > abs(translation.width) * 1.25 else { return self }
        let distance = translation.height + max(-72, min(72, (predicted.height - translation.height) * 0.18))
        guard abs(distance) > 72 else { return self }
        if self == .library { return distance>0 ? .dashboard : .library }
        return Self(rawValue: max(-1, min(1, rawValue + (distance > 0 ? 1 : -1)))) ?? self
    }

    func position(translation: CGSize) -> CGFloat {
        guard abs(translation.height) > abs(translation.width) * 1.25 else { return CGFloat(rawValue) }
        if self == .library { return max(0,min(1,1-max(0,translation.height)/250)) }
        let value = CGFloat(rawValue) + translation.height / 250
        return max(-1, min(self == .records ? 0 : 1, value))
    }
}

nonisolated enum RewardTiming {
    static let wishDuration: TimeInterval = 3.2
    static let settlementDuration: TimeInterval = 2.75
    static let arrivalTimes: [TimeInterval] = [0.99, 1.18, 1.39, 1.6, 1.82, 2.05]
    static let arrivalParts: [Decimal] = [0.09, 0.23, 0.42, 0.64, 0.84, 1]

    /// Each actual receiving beat advances one Decimal clock. It never runs ahead
    /// of the arriving wave, overshoots, or mutates the already saved ledger.
    static func receivedAmount(before: Decimal, after: Decimal, elapsed: TimeInterval) -> Decimal {
        guard after > before else { return after }
        guard let index = arrivalTimes.lastIndex(where: { elapsed >= $0 }) else { return before }
        let previous = index == 0 ? Decimal.zero : arrivalParts[index - 1]
        let target = arrivalParts[index]
        let duration = index == arrivalTimes.count - 1 ? 0.24 : 0.165
        let p = min(1, max(0, (elapsed - arrivalTimes[index]) / duration))
        let eased = p * p * (3 - 2 * p)
        let fraction = Decimal(string: String(eased)) ?? 0
        let progress = previous + (target - previous) * fraction
        var amount = before + (after - before) * progress
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 2, .plain)
        return min(after, max(before, rounded))
    }

    static func wishPose(elapsed: TimeInterval) -> RewardWishPose {
        let ms = max(0, elapsed * 1000)
        if ms < 900 {
            let raw = min(1, max(0, (ms - 160) / 740))
            let p = raw * raw * (3 - 2 * raw)
            let shake = min(1, max(0, (ms - 500) / 400))
            return RewardWishPose(x: sin(ms * 0.067) * shake * 0.9,
                                  y: 7 * p + cos(ms * 0.081) * shake * 0.7,
                                  scale: 1 - 0.075 * p,
                                  angle: sin(ms * 0.051) * shake * 0.25)
        }
        let p = min(1, (ms - 900) / 650)
        let kick = sin(p * .pi) * exp(-p * 1.9)
        let decay = exp(-p * 12)
        return RewardWishPose(x: sin(900 * 0.067) * 0.9 * decay,
                              y: (7 + cos(900 * 0.081) * 0.7) * decay - 17 * kick,
                              scale: 1 - 0.075 * decay + 0.065 * kick,
                              angle: sin(900 * 0.051) * 0.25 * decay - 0.7 * kick)
    }
}

nonisolated struct RewardWishPose {
    var x: Double
    var y: Double
    var scale: Double
    var angle: Double
}

nonisolated struct VisualRandom {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64.max >> 11)
    }
}

nonisolated struct GlassFragment: Identifiable {
    let id: Int
    let points: [CGPoint]
    let center: CGPoint
    let speed: Double
    let rotation: Double
    let delay: Double
    let velocity: CGPoint
    let spinX: Double
    let spinY: Double
    let depth: Double
    let shade: Double
    let life: Double
}

nonisolated struct GlassCrack {
    let a: CGPoint
    let b: CGPoint
    let delay: Double
}

nonisolated struct GlassFractureScene {
    let impact: CGPoint
    let fragments: [GlassFragment]
    let cracks: [GlassCrack]
}

nonisolated enum GlassFracture {
    static func make(seed: UInt64, count: Int = 44) -> [GlassFragment] { makeScene(seed: seed, count: count).fragments }

    /// Spaced exterior sites and fine impact chips share exactly the same broken
    /// edge contour. The complete pane still tiles to area 1 before projection.
    static func makeScene(seed: UInt64, count: Int = 44) -> GlassFractureScene {
        var random = VisualRandom(state: seed)
        let impact = CGPoint(x: 0.4 + random.next() * 0.2, y: 0.38 + random.next() * 0.2)
        let wanted = max(4, count), innerCount = min(14, wanted / 2), outerCount = wanted - innerCount
        var sites: [CGPoint] = []
        for _ in 0..<900 where sites.count < outerCount {
            let point = CGPoint(x: 0.02 + random.next() * 0.96, y: 0.02 + random.next() * 0.96)
            if sites.allSatisfy({ hypot($0.x - point.x, $0.y - point.y) > 0.093 }) { sites.append(point) }
        }
        while sites.count < outerCount { sites.append(CGPoint(x: random.next(), y: random.next())) }
        for _ in 0..<innerCount {
            let angle = random.next() * .pi * 2, radius = 0.04 + sqrt(random.next()) * 0.21
            sites.append(CGPoint(x: impact.x + cos(angle) * radius, y: impact.y + sin(angle) * radius))
        }
        var cells: [(site: CGPoint, points: [CGPoint])] = []
        for (i, site) in sites.enumerated() {
            var polygon = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)]
            for (j, other) in sites.enumerated() where i != j {
                let nx = other.x - site.x, ny = other.y - site.y
                let limit = (other.x * other.x + other.y * other.y - site.x * site.x - site.y * site.y) / 2
                var output: [CGPoint] = []
                for k in polygon.indices {
                    let a = polygon[k], b = polygon[(k + 1) % polygon.count]
                    let da = a.x * nx + a.y * ny - limit, db = b.x * nx + b.y * ny - limit
                    if da <= 0 { output.append(a) }
                    if (da < 0) != (db < 0) {
                        let fraction = da / (da - db)
                        output.append(CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction))
                    }
                }
                polygon = output
                if polygon.isEmpty { break }
            }
            if polygon.count >= 3 { cells.append((site, polygon)) }
        }
        var nicks: [String: (start: CGPoint, mids: [CGPoint])] = [:]
        let fragments = cells.enumerated().map { i, cell -> GlassFragment in
            var chipped: [CGPoint] = []
            for k in cell.points.indices {
                let a = cell.points[k], b = cell.points[(k + 1) % cell.points.count]
                chipped.append(a)
                if boundary(a, b) { continue }
                let key = edgeKey(a, b, precision: 10000000)
                if nicks[key] == nil {
                    let dx = b.x - a.x, dy = b.y - a.y, length = max(0.000001, hypot(dx, dy))
                    let bend = (random.next() - 0.5) * length * 0.09
                    let first = CGPoint(x: a.x + dx * 0.33 - dy / length * bend, y: a.y + dy * 0.33 + dx / length * bend)
                    let second = CGPoint(x: a.x + dx * 0.68 + dy / length * bend * 0.6, y: a.y + dy * 0.68 - dx / length * bend * 0.6)
                    nicks[key] = (a, [first, second].map { CGPoint(x: min(1, max(0, $0.x)), y: min(1, max(0, $0.y))) })
                }
                if let nick = nicks[key] { chipped += hypot(nick.start.x - a.x, nick.start.y - a.y) < 0.00001 ? nick.mids : Array(nick.mids.reversed()) }
            }
            let center = cell.points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x / CGFloat(cell.points.count), y: $0.y + $1.y / CGFloat(cell.points.count)) }
            let dx = center.x - impact.x, dy = center.y - impact.y, distance = max(0.000001, hypot(dx, dy))
            let vx = dx / distance * (100 + random.next() * 270) + (random.next() - 0.5) * 70
            let vy = dy / distance * (110 + random.next() * 220) - 140
            let spinX = (random.next() - 0.5) * 6, spinY = (random.next() - 0.5) * 9, spinZ = (random.next() - 0.5) * 5
            return GlassFragment(id: i, points: chipped, center: center, speed: 1,
                                 rotation: spinZ, delay: distance * 0.13 + random.next() * 0.038,
                                 velocity: CGPoint(x: vx, y: vy), spinX: spinX, spinY: spinY,
                                 depth: 40 + random.next() * 155, shade: random.next(), life: 1 + random.next() * 0.55)
        }
        var uniqueEdges: Set<String> = [], cracks: [GlassCrack] = []
        for cell in fragments {
            for i in cell.points.indices {
                var a = cell.points[i], b = cell.points[(i + 1) % cell.points.count]
                if boundary(a, b) { continue }
                let key = edgeKey(a, b, precision: 100000)
                guard uniqueEdges.insert(key).inserted else { continue }
                if hypot(a.x - impact.x, a.y - impact.y) > hypot(b.x - impact.x, b.y - impact.y) { swap(&a, &b) }
                cracks.append(GlassCrack(a: a, b: b, delay: hypot(a.x - impact.x, a.y - impact.y) * 0.4 + random.next() * 0.05))
            }
        }
        return GlassFractureScene(impact: impact, fragments: fragments, cracks: cracks)
    }
    private static func boundary(_ a: CGPoint, _ b: CGPoint) -> Bool {
        (abs(a.x - b.x) < 0.000001 && (a.x < 0.000001 || a.x > 0.999999)) ||
        (abs(a.y - b.y) < 0.000001 && (a.y < 0.000001 || a.y > 0.999999))
    }
    private static func edgeKey(_ a: CGPoint, _ b: CGPoint, precision: CGFloat) -> String {
        let first = "\(Int((a.x * precision).rounded())),\(Int((a.y * precision).rounded()))"
        let second = "\(Int((b.x * precision).rounded())),\(Int((b.y * precision).rounded()))"
        return [first, second].sorted().joined(separator: "|")
    }
}

nonisolated enum WishPhrase {
    static func draft(from text: String, currency: String, now: Date) -> TaskDraft? {
        guard text.range(of: #"(?i)推荐|退款|删除|退掉|取消|refund|delete|recommend"#, options: .regularExpression) == nil else { return nil }
        let pattern = #"(?i)^\s*(?:想买|想要|想去|添加心愿[:：]?|新增心愿[:：]?|wish\s*[:：]|add (?:a )?wish[:：]?)\s*"#
        guard text.range(of: pattern, options: .regularExpression) != nil else { return nil }
        var name = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"(?i)[，,;；]?\s*(?:预算|大约|约)?\s*[¥￥$€]?\s*\d[\d,.]*\s*(?:元|美元|人民币|美金|USD|CNY|EUR|JPY|日元|欧元)?\s*$"#, with: "", options: .regularExpression)
        var draft = TaskDraft(kind: "agentWishCreate", currency: LocalRegexFallback.extractCurrency(from: text) ?? currency)
        draft.name = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        draft.amount = LocalRegexFallback.extractAmount(from: text) ?? ""
        draft.occurredAt = now; draft.fieldsTouched = true
        return draft
    }
}

nonisolated enum VisualLoop {
    static func wrap(_ value: CGFloat, span: CGFloat) -> CGFloat {
        guard span > 0, value.isFinite else { return 0 }
        return ((value+span/2).truncatingRemainder(dividingBy: span)+span).truncatingRemainder(dividingBy: span)-span/2
    }
}
