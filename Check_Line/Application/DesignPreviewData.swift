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
        guard isEnabled, !["empty", "budget-empty", "analysis-empty"].contains(screen) else { return }
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? now
        let end = calendar.date(byAdding: .day, value: -1, to: next) ?? now
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let daily = try ledger.insertBudgetCard(name: String(localized: "wallet.demo.daily"), amount: 3_000, currencyCode: "CNY", cycleType: .repeating, recurrence: .monthly, startDate: start, endDate: end, now: now, sortIndex: 0)
        let trip = try ledger.insertBudgetCard(name: String(localized: "wallet.demo.trip"), amount: 2_400, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: start, endDate: nil, now: now, sortIndex: 1)
        if screen == "analysis-no-records" {
            try LedgerStore.replaceAll(ledger, in: context)
            return
        }
        let samples: [(Decimal, String, Int)] = [(38, String(localized: "wallet.demo.lunch"), 0), (22, String(localized: "wallet.demo.coffee"), 1), (6, String(localized: "wallet.demo.train"), 2), (120, String(localized: "wallet.demo.grocery"), 3), (90, String(localized: "wallet.demo.lunch"), 4), (184, String(localized: "wallet.demo.grocery"), 6), (220, String(localized: "wallet.demo.grocery"), 8), (1_000, String(localized: "wallet.demo.grocery"), 12)]
        for (amount, merchant, days) in samples {
            let date = calendar.date(byAdding: .day, value: -days, to: now) ?? now
            try record(ledger: &ledger, amount: amount, currencyCode: "CNY", occurredAt: date, now: now, decision: .confirmed(periodID: daily.1.id), merchant: merchant)
        }
        try record(ledger: &ledger, amount: 40, currencyCode: "CNY", occurredAt: now, now: now, decision: .pending(periodID: daily.1.id, confidence: DecimalMath.parse("0.4")), merchant: String(localized: "wallet.demo.coffee"))
        try record(ledger: &ledger, amount: 680, currencyCode: "CNY", occurredAt: now, now: now, decision: .confirmed(periodID: trip.1.id), merchant: String(localized: "wallet.demo.trip"))
        if screen == "wishes-empty" {
            try LedgerStore.replaceAll(ledger, in: context)
            return
        }
        ledger = try WalletLedger.append(ledger: ledger, type: .surplus, sourceSignedAmount: 860, sourceCurrencyCode: "CNY", quote: nil, at: now).0
        for (key, symbol, amount) in [("wallet.demo.headphones", "headphones", Decimal(699)), ("wallet.demo.camp", "tent", Decimal(1_200)), ("wallet.demo.book", "book", Decimal(89))] {
            ledger.upsert(Wish(id: UUID(), name: String(localized: String.LocalizationValue(key)), targetAmount: amount, currencyCode: "CNY", referenceURL: nil, state: .active, createdAt: now, completedAt: nil, symbolName: symbol))
        }
        try LedgerStore.replaceAll(ledger, in: context)
        #endif
    }
}
