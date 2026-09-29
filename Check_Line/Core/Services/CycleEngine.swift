import Foundation

nonisolated struct NextPeriodPlan: Equatable, Sendable {
    var startDate: Date
    var endDate: Date?
}

nonisolated enum CycleEngine {
    static func exclusiveEnd(of period: BudgetPeriod, calendar: Calendar) -> Date? {
        guard let endDate = period.endDate else { return nil }
        let start = calendar.startOfDay(for: endDate)
        return calendar.date(byAdding: .day, value: 1, to: start)
    }

    static func isDue(_ period: BudgetPeriod, now: Date, calendar: Calendar) -> Bool {
        guard period.state == .active, let exclusiveEnd = exclusiveEnd(of: period, calendar: calendar) else {
            return false
        }
        return now >= exclusiveEnd
    }

    static func markDueIfNeeded(
        ledger: Ledger,
        periodID: UUID,
        now: Date,
        calendar: Calendar
    ) throws -> Ledger {
        var ledger = ledger
        var period = try ledger.requirePeriod(periodID)
        var budget = try ledger.requireBudget(period.budgetID)
        guard isDue(period, now: now, calendar: calendar) else { return ledger }

        period.state = .pendingSettlement
        budget.state = .pendingSettlement
        budget.updatedAt = now
        ledger.upsert(period)
        ledger.upsert(budget)
        return ledger
    }

    static func beginManualSettlement(
        ledger: Ledger,
        periodID: UUID,
        now: Date
    ) throws -> Ledger {
        var ledger = ledger
        var period = try ledger.requirePeriod(periodID)
        var budget = try ledger.requireBudget(period.budgetID)
        guard period.state == .active else { throw LedgerError.periodAlreadySettled }
        guard budget.cycleType == .oneShot else { throw LedgerError.periodNotReadyToSettle }
        period.state = .pendingSettlement
        budget.state = .pendingSettlement
        budget.updatedAt = now
        ledger.upsert(period)
        ledger.upsert(budget)
        return ledger
    }

    static func nextPeriodPlan(
        budget: Budget,
        settledPeriod: BudgetPeriod,
        calendar: Calendar
    ) throws -> NextPeriodPlan {
        guard budget.cycleType == .repeating else {
            throw LedgerError.oneShotDoesNotOpenNextPeriod
        }
        guard let recurrence = budget.recurrence, let exclusiveEnd = exclusiveEnd(of: settledPeriod, calendar: calendar) else {
            throw LedgerError.repeatingBudgetNeedsRecurrence
        }

        let startDate = exclusiveEnd
        let endDate: Date?
        switch recurrence {
        case .weekly:
            endDate = calendar.date(byAdding: .day, value: 6, to: calendar.startOfDay(for: startDate))
        case .monthly:
            let nextStart = calendar.date(byAdding: .month, value: 1, to: startDate)
            endDate = nextStart.flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
        case .everyNDays(let days):
            endDate = calendar.date(byAdding: .day, value: days - 1, to: calendar.startOfDay(for: startDate))
        }
        return NextPeriodPlan(startDate: startDate, endDate: endDate)
    }

    static func openNextPeriod(
        ledger: Ledger,
        settledPeriodID: UUID,
        now: Date,
        calendar: Calendar,
        newPeriodID: UUID = UUID()
    ) throws -> Ledger {
        var ledger = ledger
        let settled = try ledger.requirePeriod(settledPeriodID)
        var budget = try ledger.requireBudget(settled.budgetID)
        guard budget.cycleType == .repeating else {
            throw LedgerError.oneShotDoesNotOpenNextPeriod
        }

        let plan = try nextPeriodPlan(budget: budget, settledPeriod: settled, calendar: calendar)
        let period = BudgetPeriod(
            id: newPeriodID,
            budgetID: budget.id,
            budgetAmount: budget.defaultAmount,
            currencyCode: budget.defaultCurrencyCode,
            startDate: plan.startDate,
            endDate: plan.endDate,
            state: .active,
            sequence: settled.sequence + 1,
            createdAt: now
        )
        ledger.upsert(period)

        for queued in ledger.queuedExpenses(forBudget: budget.id) {
            var expense = queued
            expense.queuedForBudgetID = nil
            expense.budgetPeriodID = period.id
            expense.updatedAt = now
            ledger.upsert(expense)
        }

        budget.state = .active
        budget.updatedAt = now
        ledger.upsert(budget)
        return ledger
    }

    static func archiveOneShot(ledger: Ledger, budgetID: UUID, now: Date) throws -> Ledger {
        var ledger = ledger
        var budget = try ledger.requireBudget(budgetID)
        guard budget.cycleType == .oneShot else { return ledger }
        budget.state = .archived
        budget.updatedAt = now
        ledger.upsert(budget)
        return ledger
    }

    static func shouldQueue(
        expenseOccurredAt: Date,
        period: BudgetPeriod,
        calendar: Calendar
    ) -> Bool {
        guard period.state == .pendingSettlement,
              let exclusiveEnd = exclusiveEnd(of: period, calendar: calendar) else {
            return false
        }
        return expenseOccurredAt >= exclusiveEnd
    }
}
