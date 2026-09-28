import Foundation

nonisolated enum CloudMascotState: String, CaseIterable, Sendable {
    case idle, thinking, waiting, success, error

    var label: String {
        switch self {
        case .idle: String(localized: "wallet.mascot.idle")
        case .thinking: String(localized: "wallet.mascot.thinking")
        case .waiting: String(localized: "wallet.mascot.waiting")
        case .success: String(localized: "wallet.mascot.success")
        case .error: String(localized: "wallet.mascot.error")
        }
    }
}

/// Native port of the approved material study. Cloud geometry derives from bloub (MIT).
/// Coordinates stay in the study's 224 × 208 viewport; money never enters this sampler.
nonisolated enum CloudMascotMotion {
    static let thinkingPeriod = 1.5
    static let transitionDuration = 0.48
    static let tau = Double.pi * 2
    struct Point: Equatable, Sendable {
        var x: Double
        var y: Double
        func mixed(with p: Self, by k: Double) -> Self { .init(x: mix(x, p.x, k), y: mix(y, p.y, k)) }
    }
    struct Light: Equatable, Sendable {
        var position: Point
        var angle: Double = 0
        var sx: Double = 1
        var sy: Double = 1
        var opacity: Double = 1
        var contour: [Point]
        func mixed(with p: Self, by k: Double) -> Self {
            .init(position: position.mixed(with: p.position, by: k), angle: mix(angle, p.angle, k), sx: mix(sx, p.sx, k), sy: mix(sy, p.sy, k), opacity: mix(opacity, p.opacity, k), contour: zip(contour, p.contour).map { $0.mixed(with: $1, by: k) })
        }
    }
    struct Eye: Equatable, Sendable {
        var center: Point
        var rx: Double = 6.1
        var ry: Double = 12
        func mixed(with p: Self, by k: Double) -> Self {
            .init(center: center.mixed(with: p.center, by: k), rx: mix(rx, p.rx, k), ry: mix(ry, p.ry, k))
        }
    }
    struct Frame: Equatable, Sendable {
        var outline: [Point]
        var lights: [Light]
        var eyes: [Eye]
        var offset: Point
        var badge: Double = 0
        var error: Double = 0
        func mixed(with p: Self, by k: Double) -> Self {
            .init(outline: zip(outline, p.outline).map { $0.mixed(with: $1, by: k) }, lights: zip(lights, p.lights).map { $0.mixed(with: $1, by: k) }, eyes: zip(eyes, p.eyes).map { $0.mixed(with: $1, by: k) }, offset: offset.mixed(with: p.offset, by: k), badge: mix(badge, p.badge, k), error: mix(error, p.error, k))
        }
    }

    static func mix(_ a: Double, _ b: Double, _ k: Double) -> Double { a + (b - a) * k }
    static func smooth(_ value: Double) -> Double { let x = min(1, max(0, value)); return x * x * (3 - 2 * x) }
    private static func seed(_ n: Int, _ k: Int) -> Double {
        var x = (UInt32(truncatingIfNeeded: n + 19) &* 374761393) ^ (UInt32(truncatingIfNeeded: k + 7) &* 668265263)
        x = (x ^ (x >> 13)) &* 1274126177
        return Double(x ^ (x >> 16)) / 4294967295
    }
    static func wander(_ t: Double, _ key: Int, _ seconds: Double = 4.7) -> Double {
        let p = t / seconds, n = Int(floor(p))
        return mix(seed(n, key), seed(n + 1, key), smooth(p - Double(n))) * 2 - 1
    }
    private static let radii: [Double] = {
        let circles: [(Double, Double, Double)] = [(-0.44, 0.2, 0.54), (0.46, 0.2, 0.5), (0.02, 0.3, 0.6), (-0.24, -0.3, 0.48), (0.3, -0.24, 0.44)]
        let raw = (0..<64).map { i -> Double in
            let a = Double(i) / 64 * tau
            return circles.map { x, y, r -> Double in
                let b = cos(a) * x + sin(a) * y
                let d = b * b - (x * x + y * y - r * r)
                return d >= 0 ? b + sqrt(d) : 0
            }.max() ?? 0
        }
        let peak = raw.max() ?? 1
        return raw.map { $0 / peak * 1.02 }
    }()
    private static func contour(_ t: Double, _ key: Int) -> [Point] {
        (0..<10).map { i in
            let a = Double(i) / 10 * tau, r = 1 + 0.13 * wander(t, key + i, 2.8 + Double(i) * 0.19)
            return Point(x: cos(a) * 23 * r, y: sin(a) * 22 * r)
        }
    }
    private static func lights(_ t: Double, thinking: Bool, reduced: Bool) -> [Light] {
        (0..<2).map { i in
            var l = Light(position: .init(x: i == 0 ? -13 : 10, y: i == 0 ? -15 : 19), sx: i == 0 ? 1 : 1.08, sy: i == 0 ? 1 : 0.8, opacity: thinking ? (i == 0 ? 0.94 : 1) : 0, contour: contour(t, 21 + i * 24))
            guard !reduced else { return l }
            if thinking {
                let phase = tau * t / thinkingPeriod + 0.32 * sin(t * 0.76) + 0.16 * sin(t * 1.37)
                let p = phase + (i == 0 ? -2.15 : 0.65) + 0.22 * sin(t * (i == 0 ? 1.1 : 0.83))
                l.position = .init(x: cos(p) * (19 + 3 * wander(t, 31 + i, 4.2)) + 2 * sin(t * 0.59), y: 3 + sin(p) * (16 + 2.5 * wander(t, 37 + i, 5)))
                l.angle = 38 * sin(p + 0.4)
                l.sx = (i == 0 ? 1.02 : 1.12) + 0.25 * sin(p * 0.94 + 0.7)
                l.sy = 0.86 + 0.19 * cos(p + 0.6)
                l.contour = contour(t * 1.3, 21 + i * 24)
            } else {
                let p = i == 0 ? -1.4 : 1.5
                l.position.x += 16 * sin(t * (i == 0 ? 0.91 : 1.13) + p) + 6 * wander(t, 1 + i, 3.1)
                l.position.y += 13 * cos(t * (i == 0 ? 0.73 : 0.91) + p) + 5 * wander(t, 5 + i, 2.8)
                l.angle = 18 * sin(t * 0.63 + p) + 13 * wander(t, 9 + i, 4.3)
                l.sx *= 1 + 0.16 * wander(t, 13 + i, 2.7)
                l.sy *= 1 + 0.17 * wander(t, 17 + i, 3.2)
            }
            return l
        }
    }
    private static func gaze(_ t: Double) -> Point {
        let points: [(Double, Double, Double)] = [(0,-2,-3), (0.16,-2,-3), (0.34,3,-1), (0.48,3,-1), (0.66,1,-4), (0.82,1,-4), (1,-2,-3)]
        let u = (t / thinkingPeriod).truncatingRemainder(dividingBy: 1)
        let j = points.firstIndex { $0.0 > u } ?? 6
        let a = points[max(0, j - 1)], b = points[j], k = smooth((u - a.0) / (b.0 - a.0))
        return .init(x: mix(a.1, b.1, k), y: mix(a.2, b.2, k))
    }
    // Uneven blink intervals, with occasional double blinks; no per-frame randomness.
    private static let blinks: [Double] = {
        var result: [Double] = [], t = 1.4, n = 0
        while t < 900 {
            result.append(t)
            t += 1.9 + seed(n, 93) * 2.7
            if seed(n, 94) < 0.18 { result.append(t); t += 0.24 }
            n += 1
        }
        return result
    }()
    private static func blink(_ time: Double) -> Double {
        let t = time.truncatingRemainder(dividingBy: 890)
        guard let start = blinks.last(where: { $0 <= t }), t - start <= 0.18 else { return 1 }
        let k = (t - start) / 0.18
        return 0.06 + 0.94 * (k < 0.45 ? 1 - k / 0.45 : (k - 0.45) / 0.55)
    }
    static func sample(_ state: CloudMascotState, elapsed: Double, stateTime: Double = 0, reduced: Bool = false) -> Frame {
        let t = reduced ? 0 : max(0, elapsed), thinking = state == .thinking
        let phase = tau * t / thinkingPeriod + 0.32 * sin(t * 0.76) + 0.16 * sin(t * 1.37) - 2.55
        let outline = radii.enumerated().map { i, radius -> Point in
            let a = Double(i) / 64 * tau
            let swell = thinking && !reduced ? 4.1 * exp((cos(a - phase) - 1) * 3.8) - 1.65 * exp((cos(a - phase + 0.8) - 1) * 5) : 0
            return .init(x: (radius * 80 + swell) * cos(a), y: (radius * 80 + swell) * sin(a))
        }
        var eyes = [Eye(center: .init(x: -12, y: -5)), Eye(center: .init(x: 14, y: -5))]
        if thinking {
            let look = reduced ? Point(x: 1, y: -3) : gaze(t)
            for i in eyes.indices { eyes[i].center.x += look.x; eyes[i].center.y += look.y; eyes[i].ry *= 0.88 * (reduced ? 1 : blink(t)) }
        } else {
            for i in eyes.indices {
                if !reduced {
                    eyes[i].center.x += 2 * sin(t * tau / 11.3 + 0.4) + 0.6 * sin(t * tau / 3.7 + 2.1)
                    eyes[i].center.y -= 1.4 * sin(t * tau / 9.1 + 1.3)
                    eyes[i].ry *= blink(t)
                }
            }
            if state == .success {
                eyes[1].ry = reduced ? 2.6 : mix(2.6, eyes[1].ry, smooth((stateTime - 0.9) / 0.25))
            }
            if state == .waiting { for i in eyes.indices { eyes[i].ry *= 0.9 } }
        }
        let offset = reduced ? Point(x: 0, y: 0) : Point(x: 1.6 * sin(t * 0.53) + 0.65 * sin(t * 0.91), y: 3.1 * sin(t * 0.82) + 0.85 * sin(t * 0.37))
        return .init(outline: outline, lights: lights(t, thinking: thinking, reduced: reduced), eyes: eyes, offset: offset, badge: state == .waiting || state == .error ? 1 : 0, error: state == .error ? 1 : 0)
    }
}

/// Uses monotonic visible time. Interruptions capture the currently blended pose.
nonisolated struct CloudMascotPlayer {
    private var accumulated: Double = 0
    private var startedAt: Double?
    private var enteredAt: Double = 0
    private var from: CloudMascotMotion.Frame?
    private(set) var state: CloudMascotState = .idle
    private(set) var reduced = false

    func elapsed(at time: Double) -> Double { accumulated + (startedAt.map { max(0, time - $0) } ?? 0) }
    mutating func setRunning(_ running: Bool, at time: Double) {
        if running && !reduced { if startedAt == nil { startedAt = time } }
        else { accumulated = elapsed(at: time); startedAt = nil }
    }
    mutating func select(_ value: CloudMascotState, at time: Double) {
        guard value != state else { return }
        from = frame(at: time); enteredAt = elapsed(at: time); state = value
    }
    mutating func setReduced(_ value: Bool, at time: Double) {
        guard value != reduced else { return }
        setRunning(false, at: time)
        reduced = value; from = nil; enteredAt = elapsed(at: time)
    }
    func frame(at time: Double) -> CloudMascotMotion.Frame {
        let elapsed = elapsed(at: time), age = elapsed - enteredAt
        let target = CloudMascotMotion.sample(state, elapsed: elapsed, stateTime: age, reduced: reduced)
        guard let from, !reduced, age < CloudMascotMotion.transitionDuration else { return target }
        return from.mixed(with: target, by: CloudMascotMotion.smooth(age / CloudMascotMotion.transitionDuration))
    }
}
