import Foundation

nonisolated struct BudgetSnapshot: Equatable, Sendable {
    let spent: Decimal
    let remaining: Decimal
    let availableToSpend: Decimal
    let overrunAmount: Decimal
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
}
