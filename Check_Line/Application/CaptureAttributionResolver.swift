import Foundation

nonisolated enum CaptureAttributionTarget: Equatable {
    case period(UUID)
    case queued(UUID)
    case unavailable
}

/// A chosen budget is never replaced with a global suggestion. Dates select its actual period.
nonisolated enum CaptureAttributionResolver {
    static func resolve(budgetID: UUID, occurredAt: Date, ledger: Ledger, calendar: Calendar) -> CaptureAttributionTarget {
        guard let budget = ledger.budgets[budgetID], budget.state != .archived else { return .unavailable }
        let periods = ledger.periods(forBudget: budgetID)
        let covering = periods.filter {
            calendar.startOfDay(for: occurredAt) >= calendar.startOfDay(for: $0.startDate)
                && (CycleEngine.exclusiveEnd(of: $0, calendar: calendar).map { occurredAt < $0 } ?? true)
        }
        if covering.count == 1, let period = covering.first, period.state != .settled { return .period(period.id) }
        guard covering.isEmpty else { return .unavailable }
        let pending = periods.filter { $0.state == .pendingSettlement }
        if pending.count == 1, let period = pending.first,
           CycleEngine.shouldQueue(expenseOccurredAt: occurredAt, period: period, calendar: calendar, budget: budget) {
            return .queued(budgetID)
        }
        return .unavailable
    }
}
