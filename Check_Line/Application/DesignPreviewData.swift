import Foundation
import SwiftData

/// Explicit debug launch mode; never touches the user's persistent ledger.
enum DesignPreviewData {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-design-preview")
        #else
        false
        #endif
    }

    static var reducesMotion: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains("-design-reduce-motion")
    }

    static var runsMotionTour: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains("-design-motion-tour")
    }

    static var screen: String {
        guard isEnabled, let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-design-screen"), ProcessInfo.processInfo.arguments.indices.contains(index + 1) else { return "home" }
        return ProcessInfo.processInfo.arguments[index + 1]
    }

    #if DEBUG
    private static func record(ledger: inout Ledger, amount: Decimal, currencyCode: String, occurredAt: Date, now: Date, decision: AttributionDecision, merchant: String) throws {
        let expense = ledger.insertExpense(amount: amount, currencyCode: currencyCode, occurredAt: occurredAt, now: now, merchant: merchant)
        ledger = try AttributionEngine.apply(ledger: ledger, expenseID: expense.id, decision: decision, now: now)
    }
    #endif

    static func populate(_ context: ModelContext, now: Date = Date()) throws {
        #if DEBUG
        guard isEnabled, !["empty", "budget-empty", "analysis-empty", "settlement-receipt"].contains(screen) else { return }
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? now
        let end = calendar.date(byAdding: .day, value: -1, to: next) ?? now
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        if ["home-overdue", "attention-overdue"].contains(screen) {
            let previousStart = calendar.date(byAdding: .month, value: -1, to: start) ?? start
            let previousEnd = calendar.date(byAdding: .day, value: -1, to: start) ?? start
            let card = try ledger.insertBudgetCard(name: String(localized: "wallet.demo.trip"), amount: 500,
                                                   currencyCode: "CNY", cycleType: .repeating, recurrence: .monthly,
                                                   startDate: previousStart, endDate: previousEnd, now: previousStart)
            ledger = try CycleEngine.markDueIfNeeded(ledger: ledger, periodID: card.1.id, now: now, calendar: calendar)
            try LedgerStore.replaceAll(ledger, in: context)
            return
        }
        if screen == "settlement-fx" {
            ledger = try WalletLedger.setWalletCurrency(ledger: ledger, currencyCode: "CNY", now: now)
            let card = try ledger.insertBudgetCard(name: String(localized: "wallet.demo.trip"), amount: 100,
                                                   currencyCode: "USD", cycleType: .oneShot, recurrence: nil,
                                                   startDate: start, endDate: nil, now: now)
            try record(ledger: &ledger, amount: 25, currencyCode: "USD", occurredAt: now, now: now,
                       decision: .confirmed(periodID: card.1.id), merchant: String(localized: "wallet.demo.train"))
            ledger = try WalletLedger.append(ledger: ledger, type: .surplus, sourceSignedAmount: 860,
                                              sourceCurrencyCode: "CNY", quote: nil, at: now).0
            ledger = try CycleEngine.beginManualSettlement(ledger: ledger, periodID: card.1.id, now: now)
            try LedgerStore.replaceAll(ledger, in: context)
            return
        }
        if ["retrospective-record", "history-review"].contains(screen) {
            let previousStart = calendar.date(byAdding: .month, value: -1, to: start) ?? start
            let previousEnd = calendar.date(byAdding: .day, value: -1, to: start) ?? start
            let card = try ledger.insertBudgetCard(name: String(localized: "wallet.demo.daily"), amount: 1_000,
                                                   currencyCode: "CNY", cycleType: screen == "history-review" ? .repeating : .oneShot, recurrence: screen == "history-review" ? .monthly : nil,
                                                   startDate: previousStart, endDate: previousEnd, now: previousStart)
            try record(ledger: &ledger, amount: 250, currencyCode: "CNY", occurredAt: previousStart, now: previousStart,
                       decision: .confirmed(periodID: card.1.id), merchant: String(localized: "wallet.demo.train"))
            try record(ledger: &ledger, amount: 40, currencyCode: "CNY", occurredAt: previousEnd, now: previousEnd,
                       decision: .pending(periodID: card.1.id, confidence: DecimalMath.parse("0.4")), merchant: String(localized: "wallet.demo.coffee"))
            ledger = try CycleEngine.markDueIfNeeded(ledger: ledger, periodID: card.1.id, now: now, calendar: calendar)
            ledger = try SettlementEngine.commit(ledger: ledger, periodID: card.1.id, now: now, calendar: calendar,
                                                  quote: nil, acceptedIncompleteData: true)
            try LedgerStore.replaceAll(ledger, in: context)
            return
        }
        if screen == "settlement-loop" {
            let card = try ledger.insertBudgetCard(
                name: String(localized: "wallet.demo.trip"), amount: 1_000,
                currencyCode: "CNY", cycleType: .oneShot, recurrence: nil,
                startDate: start, endDate: nil, now: now
            )
            try record(ledger: &ledger, amount: 250, currencyCode: "CNY", occurredAt: now,
                       now: now, decision: .confirmed(periodID: card.1.id), merchant: String(localized: "wallet.demo.train"))
            try LedgerStore.replaceAll(ledger, in: context)
            return
        }
        if ["limit-one-shot", "limit-weekly", "limit-custom"].contains(screen) {
            let oneShot = screen == "limit-one-shot"
            let first = calendar.startOfDay(for: now)
            let end = oneShot ? nil : calendar.date(byAdding: .day, value: screen == "limit-weekly" ? 6 : 9, to: first)
            let rule: RecurrenceRule? = oneShot ? nil : screen == "limit-weekly" ? .weekly : .everyNDays(10)
            let card = try ledger.insertBudgetCard(name: String(localized: oneShot ? "wallet.demo.trip" : "wallet.demo.daily"),
                amount: 100, currencyCode: "CNY", cycleType: oneShot ? .oneShot : .repeating, recurrence: rule,
                startDate: first, endDate: end, now: now)
            try record(ledger: &ledger, amount: 35, currencyCode: "CNY", occurredAt: now, now: now,
                       decision: .confirmed(periodID: card.1.id), merchant: String(localized: "wallet.demo.lunch"))
            try LedgerStore.replaceAll(ledger, in: context)
            return
        }
        let daily = try ledger.insertBudgetCard(name: String(localized: "wallet.demo.daily"), amount: 3_000, currencyCode: "CNY", cycleType: .repeating, recurrence: .monthly, startDate: start, endDate: end, now: now, sortIndex: 0)
        let trip = try ledger.insertBudgetCard(name: String(localized: "wallet.demo.trip"), amount: 2_400, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: start, endDate: nil, now: now, sortIndex: 1)
        if screen == "r34-home" {
            _ = try ledger.insertBudgetCard(name: String(localized: "wallet.demo.study"), amount: 800, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: start, endDate: nil, now: now, sortIndex: 2)
        }
        if screen == "analysis-no-records" {
            try LedgerStore.replaceAll(ledger, in: context)
            return
        }
        let samples: [(Decimal, String, Int)] = [(38, String(localized: "wallet.demo.lunch"), 0), (22, String(localized: "wallet.demo.coffee"), 1), (6, String(localized: "wallet.demo.train"), 2), (120, String(localized: "wallet.demo.grocery"), 3), (90, String(localized: "wallet.demo.lunch"), 4), (184, String(localized: "wallet.demo.grocery"), 6), (220, String(localized: "wallet.demo.grocery"), 8), (1_000, String(localized: "wallet.demo.grocery"), 12)]
        for (amount, merchant, days) in samples {
            let date = max(start, calendar.date(byAdding: .day, value: -days, to: now) ?? now)
            try record(ledger: &ledger, amount: amount, currencyCode: "CNY", occurredAt: date, now: now, decision: .confirmed(periodID: daily.1.id), merchant: merchant)
        }
        try record(ledger: &ledger, amount: 40, currencyCode: "CNY", occurredAt: now, now: now, decision: .pending(periodID: daily.1.id, confidence: DecimalMath.parse("0.4")), merchant: String(localized: "wallet.demo.coffee"))
        try record(ledger: &ledger, amount: 680, currencyCode: "CNY", occurredAt: now, now: now, decision: .confirmed(periodID: trip.1.id), merchant: String(localized: "wallet.demo.trip"))
        if screen == "wishes-empty" {
            try LedgerStore.replaceAll(ledger, in: context)
            return
        }
        ledger = try WalletLedger.append(ledger: ledger, type: .surplus, sourceSignedAmount: 860, sourceCurrencyCode: "CNY", quote: nil, at: now).0
        for (index, sample) in [("wallet.demo.headphones", "headphones", Decimal(699)), ("wallet.demo.camp", "tent", Decimal(1_200)), ("wallet.demo.book", "book", Decimal(89))].enumerated() {
            let (key, symbol, amount) = sample
            let fx = screen == "wishes-fx" && symbol == "headphones"
            ledger.upsert(Wish(id: UUID(), name: String(localized: String.LocalizationValue(key)), targetAmount: fx ? 100 : amount,
                currencyCode: fx ? "USD" : "CNY", referenceURL: nil, state: .active,
                createdAt: now.addingTimeInterval(Double(-index)), completedAt: nil, symbolName: symbol))
        }
        if screen == "collection", let book = ledger.wishes.values.first(where: { $0.symbolName == "book" }) {
            ledger = try WishRedemptionEngine.confirm(ledger: ledger, wishID: book.id, actualAmount: 89,
                currencyCode: "CNY", quote: nil, now: now)
        }
        try LedgerStore.replaceAll(ledger, in: context)
        #endif
    }
}
