import Foundation

enum TestDates {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }
}

extension Ledger {
    mutating func record(
        amount: Decimal,
        currencyCode: String,
        occurredAt: Date,
        now: Date,
        decision: AttributionDecision,
        merchant: String? = nil,
        estimatedBudgetAmount: Decimal? = nil,
        id: UUID = UUID()
    ) throws -> Expense {
        var expense = insertExpense(
            amount: amount,
            currencyCode: currencyCode,
            occurredAt: occurredAt,
            now: now,
            merchant: merchant,
            estimatedBudgetAmount: estimatedBudgetAmount,
            id: id
        )
        self = try AttributionEngine.apply(
            ledger: self,
            expenseID: expense.id,
            decision: decision,
            now: now
        )
        expense = try requireExpense(expense.id)
        return expense
    }
}
