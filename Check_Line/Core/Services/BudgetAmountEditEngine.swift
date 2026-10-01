import Foundation

nonisolated struct BudgetAmountEditPreview: Equatable, Sendable {
    let budgetID: UUID
    let periodID: UUID
    let previousDefaultAmount: Decimal
    let previousAmount: Decimal
    let newAmount: Decimal
    let currencyCode: String
    let periodStart: Date
    let periodEnd: Date?
    let snapshotBefore: PeriodBudgetSnapshot
    let snapshotAfter: PeriodBudgetSnapshot
    fileprivate let reviewedLedger: Ledger
}

nonisolated enum BudgetAmountEditEngine {
    static func isEditable(budgetID: UUID, periodID: UUID, ledger: Ledger) -> Bool {
        guard let budget = ledger.budgets[budgetID],
              budget.cycleType == .repeating, budget.recurrence == .monthly,
              budget.state != .archived,
              let period = ledger.periods[periodID], period.budgetID == budgetID,
              period.state != .settled, period.currencyCode == budget.defaultCurrencyCode else { return false }
        let periods = ledger.periods(forBudget: budgetID)
        let current = periods.first { $0.state == .active } ?? periods.first { $0.state == .pendingSettlement }
        return current?.id == periodID
    }

    static func preview(ledger: Ledger, budgetID: UUID, periodID: UUID, newAmount: Decimal) throws -> BudgetAmountEditPreview {
        guard MoneyFormat.isValidBudgetAmount(newAmount) else { throw LedgerError.invalidBudgetAmount }
        guard isEditable(budgetID: budgetID, periodID: periodID, ledger: ledger) else { throw LedgerError.budgetAmountEditUnavailable }
        let budget = try ledger.requireBudget(budgetID)
        let period = try ledger.requirePeriod(periodID)
        guard newAmount != budget.defaultAmount || newAmount != period.budgetAmount else { throw LedgerError.unchangedBudgetAmount }
        var after = period
        after.budgetAmount = newAmount
        let expenses = Array(ledger.expenses.values)
        return BudgetAmountEditPreview(
            budgetID: budgetID, periodID: periodID,
            previousDefaultAmount: budget.defaultAmount, previousAmount: period.budgetAmount,
            newAmount: newAmount, currencyCode: period.currencyCode,
            periodStart: period.startDate, periodEnd: period.endDate,
            snapshotBefore: BudgetEngine.periodSnapshot(period: period, expenses: expenses),
            snapshotAfter: BudgetEngine.periodSnapshot(period: after, expenses: expenses),
            reviewedLedger: ledger
        )
    }

    static func confirm(ledger: Ledger, preview: BudgetAmountEditPreview, now: Date) throws -> Ledger {
        guard ledger == preview.reviewedLedger else { throw LedgerError.staleBudgetAmountPreview }
        guard try self.preview(ledger: ledger, budgetID: preview.budgetID, periodID: preview.periodID, newAmount: preview.newAmount) == preview else {
            throw LedgerError.staleBudgetAmountPreview
        }
        var changed = ledger
        changed.budgets[preview.budgetID]?.defaultAmount = preview.newAmount
        changed.budgets[preview.budgetID]?.updatedAt = now
        changed.periods[preview.periodID]?.budgetAmount = preview.newAmount
        return changed
    }
}
