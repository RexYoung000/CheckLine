import Foundation

/// Counts only visible animation time, so a covered card resumes at the same phase.
nonisolated struct LiquidMotionClock {
    static let period: TimeInterval = 6.83
    private var elapsed: TimeInterval = 0
    private var startedAt: TimeInterval?

    mutating func setRunning(_ running: Bool, at time: TimeInterval) {
        if running {
            if startedAt == nil { startedAt = time }
        } else if let start = startedAt {
            elapsed += max(0, time - start)
            startedAt = nil
        }
    }

    func phase(at time: TimeInterval) -> Double {
        let total = elapsed + (startedAt.map { max(0, time - $0) } ?? 0)
        return total.truncatingRemainder(dividingBy: Self.period) / Self.period * .pi * 2
    }
}
