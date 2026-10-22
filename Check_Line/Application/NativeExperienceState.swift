import Foundation

/// Visual state only. No amounts or navigation callbacks are retained by gestures.
nonisolated enum BudgetStage: Int, CaseIterable {
    case records = -1, dashboard = 0, library = 1

    func destination(translation: CGSize, predicted: CGSize) -> Self {
        guard abs(translation.height) > 32, abs(translation.height) > abs(translation.width) * 1.25 else { return self }
        let distance = translation.height + max(-72, min(72, (predicted.height - translation.height) * 0.18))
        guard abs(distance) > 72 else { return self }
        if self == .library { return .dashboard }
        return Self(rawValue: max(-1, min(1, rawValue + (distance > 0 ? 1 : -1)))) ?? self
    }

    func position(translation: CGSize) -> CGFloat {
        guard abs(translation.height) > abs(translation.width) * 1.25 else { return CGFloat(rawValue) }
        if self == .library { return max(0,1-abs(translation.height)/250) }
        let value = CGFloat(rawValue) + translation.height / 250
        return max(-1, min(self == .records ? 0 : 1, value))
    }
}

nonisolated enum RewardTiming {
    static let wishDuration: TimeInterval = 3.2
    static let settlementDuration: TimeInterval = 2.75

    /// A single rounded Decimal amount clock avoids briefly constructing false values per digit.
    static func receivedAmount(before: Decimal, after: Decimal, elapsed: TimeInterval) -> Decimal {
        guard after > before else { return after }
        let times: [Double] = [0.82, 0.99, 1.18, 1.39, 1.6, 1.82, 2.05]
        let values: [Decimal] = [0, 0.09, 0.23, 0.42, 0.64, 0.84, 1]
        guard elapsed > times[0] else { return before }
        guard elapsed < times.last! else { return after }
        let i = (0..<times.count-1).first { elapsed < times[$0+1] } ?? 0
        let fraction = Decimal(string: String((elapsed - times[i]) / (times[i+1] - times[i]))) ?? 0
        let progress = values[i] + (values[i+1] - values[i]) * fraction
        var amount = before + (after - before) * progress
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 2, .plain)
        return min(after, max(before, rounded))
    }
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
}

nonisolated enum GlassFracture {
    /// Clipped Voronoi cells share their edges and cover the complete original surface.
    static func make(seed: UInt64, count: Int = 44) -> [GlassFragment] {
        var random = VisualRandom(state: seed)
        let sites = (0..<count).map { i in
            let clustered = i < count / 3
            return CGPoint(x: clustered ? 0.55 + (random.next()-0.5)*0.37 : random.next(),
                           y: clustered ? 0.43 + (random.next()-0.5)*0.43 : random.next())
        }
        return sites.enumerated().compactMap { i, site in
            var polygon = [CGPoint(x: 0,y: 0),CGPoint(x: 1,y: 0),CGPoint(x: 1,y: 1),CGPoint(x: 0,y: 1)]
            for (j, other) in sites.enumerated() where i != j {
                let nx = other.x - site.x, ny = other.y - site.y
                let limit = (other.x*other.x + other.y*other.y - site.x*site.x - site.y*site.y)/2
                var output: [CGPoint] = []
                for k in polygon.indices {
                    let a = polygon[k], b = polygon[(k+1)%polygon.count]
                    let da = a.x*nx + a.y*ny - limit, db = b.x*nx + b.y*ny - limit
                    if da <= 0 { output.append(a) }
                    if (da < 0) != (db < 0) {
                        let f = da / (da-db)
                        output.append(CGPoint(x: a.x+(b.x-a.x)*f, y: a.y+(b.y-a.y)*f))
                    }
                }
                polygon = output
                if polygon.isEmpty { break }
            }
            guard polygon.count >= 3 else { return nil }
            return GlassFragment(id: i, points: polygon, center: site, speed: 0.5+random.next()*0.9,
                                 rotation: (random.next()-0.5)*8, delay: random.next()*0.09)
        }
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
