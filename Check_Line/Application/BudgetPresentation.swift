import Foundation

/// Display-only projections. Settlement keeps its existing confirmed-only rules.
nonisolated enum BudgetPresentation {
    static func used(_ card: HomeBudgetCardModel) -> Decimal {
        card.snapshot.confirmedSpent + card.snapshot.pendingAmount
    }

    static func remaining(_ card: HomeBudgetCardModel) -> Decimal {
        card.snapshot.budgetAmount - used(card)
    }

    static func fill(_ card: HomeBudgetCardModel) -> Double {
        guard card.snapshot.budgetAmount > 0 else { return 0 }
        let ratio = min(max(remaining(card) / card.snapshot.budgetAmount, 0), 1)
        return NSDecimalNumber(decimal: ratio).doubleValue
    }

    static func expenses(_ card: HomeBudgetCardModel, in ledger: Ledger) -> [Expense] {
        ledger.expenses.values.filter { $0.budgetPeriodID == card.periodID && $0.wishRedemptionID == nil }
            .sorted { $0.occurredAt == $1.occurredAt ? $0.createdAt > $1.createdAt : $0.occurredAt > $1.occurredAt }
    }

    static func pendingCount(_ card: HomeBudgetCardModel, in ledger: Ledger) -> Int {
        expenses(card, in: ledger).filter { $0.attributionState == .pending }.count
    }

    static func dailyAmount(_ date: Date, card: HomeBudgetCardModel, ledger: Ledger, calendar: Calendar = .current) -> Decimal {
        expenses(card, in: ledger).filter { calendar.isDate($0.occurredAt, inSameDayAs: date) }
            .reduce(Decimal.zero) { total, expense in
                let amount = CurrencyEngine.budgetSettlementAmount(expense: expense, periodCurrencyCode: card.currencyCode) ?? 0
                return total + (expense.kind == .refund ? -amount : amount)
            }
    }

    static func days(endingAt date: Date = Date(), count: Int = 7, calendar: Calendar = .current) -> [Date] {
        (0..<count).compactMap { calendar.date(byAdding: .day, value: $0 - count + 1, to: calendar.startOfDay(for: date)) }
    }

    static func symbol(for expense: Expense) -> String {
        if expense.kind == .refund { return "arrow.uturn.backward" }
        return "receipt"
    }
}
