import Foundation

nonisolated struct BudgetSnapshot: Equatable, Sendable {
    let spent: Decimal
    let remaining: Decimal
    let availableToSpend: Decimal
    let overrunAmount: Decimal
    let progress: Decimal
}

nonisolated struct PeriodBudgetSnapshot: Equatable, Sendable {
    let budgetAmount: Decimal
    let confirmedSpent: Decimal
    let pendingAmount: Decimal
    let remaining: Decimal
    let availableToSpend: Decimal
    let certainOverrunAmount: Decimal
    let possibleOverrunAmount: Decimal
    let progress: Decimal
}

nonisolated enum BudgetEngine {
    static func snapshot(
        totalAmount: Decimal,
        recordedAmounts: [Decimal]
    ) -> BudgetSnapshot {
        let spent = recordedAmounts.reduce(Decimal.zero, +)
        let remaining = totalAmount - spent
        let progress: Decimal

        if totalAmount > 0 {
            progress = min(max(spent / totalAmount, 0), 1)
        } else {
            progress = 0
        }

        return BudgetSnapshot(
            spent: spent,
            remaining: remaining,
            availableToSpend: max(remaining, 0),
            overrunAmount: max(-remaining, 0),
            progress: progress
        )
    }

    static func periodSnapshot(
        budgetAmount: Decimal,
        confirmedAmounts: [Decimal],
        pendingAmounts: [Decimal]
    ) -> PeriodBudgetSnapshot {
        let confirmedSpent = confirmedAmounts.reduce(Decimal.zero, +)
        let pendingAmount = pendingAmounts.reduce(Decimal.zero, +)
        let remaining = budgetAmount - confirmedSpent
        let certainOverrunAmount = max(-remaining, 0)
        let combinedOver = max(confirmedSpent + pendingAmount - budgetAmount, 0)
        let possibleOverrunAmount = max(combinedOver - certainOverrunAmount, 0)
        let progress: Decimal

        if budgetAmount > 0 {
            progress = min(max(confirmedSpent / budgetAmount, 0), 1)
        } else {
            progress = 0
        }

        return PeriodBudgetSnapshot(
            budgetAmount: budgetAmount,
            confirmedSpent: confirmedSpent,
            pendingAmount: pendingAmount,
            remaining: remaining,
            availableToSpend: max(remaining, 0),
            certainOverrunAmount: certainOverrunAmount,
            possibleOverrunAmount: possibleOverrunAmount,
            progress: progress
        )
    }

    static func periodSnapshot(period: BudgetPeriod, expenses: [Expense]) -> PeriodBudgetSnapshot {
        let inPeriod = expenses.filter { $0.budgetPeriodID == period.id && $0.wishRedemptionID == nil }
        let purchases = inPeriod.filter { $0.kind == .purchase }
        let refunds = inPeriod.filter { $0.kind == .refund }

        func amount(_ expense: Expense) -> Decimal {
            CurrencyEngine.budgetSettlementAmount(expense: expense, periodCurrencyCode: period.currencyCode) ?? 0
        }

        let confirmedPurchases = purchases.filter { $0.attributionState == .confirmed }.map(amount)
        let pendingPurchases = purchases.filter { $0.attributionState == .pending }.map(amount)
        let confirmedRefunds = refunds.filter { $0.attributionState == .confirmed }.map(amount)
        let pendingRefunds = refunds.filter { $0.attributionState == .pending }.map(amount)

        let confirmedNet = confirmedPurchases.reduce(Decimal.zero, +) - confirmedRefunds.reduce(Decimal.zero, +)
        let pendingNet = pendingPurchases.reduce(Decimal.zero, +) - pendingRefunds.reduce(Decimal.zero, +)

        return periodSnapshot(
            budgetAmount: period.budgetAmount,
            confirmedAmounts: [confirmedNet],
            pendingAmounts: [pendingNet]
        )
    }
}
