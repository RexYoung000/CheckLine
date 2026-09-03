import Foundation

nonisolated enum AttributionDecision: Equatable, Sendable {
    case confirmed(periodID: UUID)
    case pending(periodID: UUID, confidence: Decimal)
    case unbudgeted
    case queued(budgetID: UUID)
}

nonisolated enum AttributionEngine {
    static func suggestPeriod(
        expense: Expense,
        ledger: Ledger,
        calendar: Calendar
    ) -> AttributionDecision {
        if expense.wishRedemptionID != nil {
            return .unbudgeted
        }

        if let merchant = expense.merchant?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           merchant.isEmpty == false {
            let matching = ledger.matchingRules.values.filter {
                $0.state == .active && $0.merchantEquals?.lowercased() == merchant
            }
            if let rule = matching.first, let budgetID = rule.targetBudgetID {
                if let period = currentBindablePeriod(budgetID: budgetID, at: expense.occurredAt, ledger: ledger, calendar: calendar) {
                    return .confirmed(periodID: period.id)
                }
                if let period = pendingPeriod(budgetID: budgetID, ledger: ledger),
                   CycleEngine.shouldQueue(expenseOccurredAt: expense.occurredAt, period: period, calendar: calendar) {
                    return .queued(budgetID: budgetID)
                }
            }
        }

        let activePeriods = ledger.periods.values.filter { $0.state == .active }
        if activePeriods.count == 1, let period = activePeriods.first {
            return .pending(periodID: period.id, confidence: DecimalMath.parse("0.4"))
        }

        return .unbudgeted
    }

    static func apply(
        ledger: Ledger,
        expenseID: UUID,
        decision: AttributionDecision,
        now: Date
    ) throws -> Ledger {
        var ledger = ledger
        var expense = try ledger.requireExpense(expenseID)

        if expense.wishRedemptionID != nil {
            switch decision {
            case .unbudgeted:
                break
            default:
                throw LedgerError.cannotBindWishRedemptionToBudget
            }
        }

        switch decision {
        case .confirmed(let periodID):
            let period = try ledger.requirePeriod(periodID)
            try validateBindable(period: period, expense: expense)
            expense.budgetPeriodID = periodID
            expense.queuedForBudgetID = nil
            expense.attributionState = .confirmed
            expense.attributionConfidence = 1
        case .pending(let periodID, let confidence):
            let period = try ledger.requirePeriod(periodID)
            try validateBindable(period: period, expense: expense)
            expense.budgetPeriodID = periodID
            expense.queuedForBudgetID = nil
            expense.attributionState = .pending
            expense.attributionConfidence = confidence
        case .unbudgeted:
            expense.budgetPeriodID = nil
            expense.queuedForBudgetID = nil
            expense.attributionState = .unbudgeted
            expense.attributionConfidence = nil
        case .queued(let budgetID):
            _ = try ledger.requireBudget(budgetID)
            if expense.budgetPeriodID != nil {
                throw LedgerError.queuedAndBoundAreExclusive
            }
            expense.queuedForBudgetID = budgetID
            expense.budgetPeriodID = nil
            expense.attributionState = .confirmed
        }

        expense.updatedAt = now
        ledger.upsert(expense)
        return ledger
    }

    static func confirmPending(ledger: Ledger, expenseID: UUID, now: Date) throws -> Ledger {
        var ledger = ledger
        var expense = try ledger.requireExpense(expenseID)
        guard expense.attributionState == .pending, expense.budgetPeriodID != nil else {
            return ledger
        }
        expense.attributionState = .confirmed
        expense.attributionConfidence = 1
        expense.updatedAt = now
        ledger.upsert(expense)
        return ledger
    }

    private static func validateBindable(period: BudgetPeriod, expense: Expense) throws {
        if period.state == .settled {
            throw LedgerError.cannotBindSettledPeriod
        }
        if expense.queuedForBudgetID != nil {
            throw LedgerError.queuedAndBoundAreExclusive
        }
        if let existing = expense.budgetPeriodID, existing != period.id {
            throw LedgerError.expenseAlreadyHasSettlementPeriod
        }
    }

    private static func currentBindablePeriod(
        budgetID: UUID,
        at date: Date,
        ledger: Ledger,
        calendar: Calendar
    ) -> BudgetPeriod? {
        ledger.periods.values.first { period in
            period.budgetID == budgetID
                && period.state == .active
                && date >= period.startDate
                && (CycleEngine.exclusiveEnd(of: period, calendar: calendar).map { date < $0 } ?? true)
        }
    }

    private static func pendingPeriod(budgetID: UUID, ledger: Ledger) -> BudgetPeriod? {
        ledger.periods.values.first { $0.budgetID == budgetID && $0.state == .pendingSettlement }
    }
}
