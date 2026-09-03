import Foundation
import Testing
@testable import CheckLine

struct FullCycleTests {
    @Test("不依赖 AI 也能跑通一张循环卡和一张一次性卡")
    func repeatingAndOneShotCloseWithoutAgent() throws {
        let calendar = TestDates.calendar
        let january = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: january)

        let dining = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: january
        )
        let travel = try ledger.insertBudgetCard(
            name: "东京旅行",
            amount: 50_000,
            currencyCode: "JPY",
            cycleType: .oneShot,
            recurrence: nil,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 10),
            now: january
        )
        #expect(ledger.walletSettings.walletCurrencyCode == "CNY")

        _ = try ledger.record(
            amount: 80,
            currencyCode: "CNY",
            occurredAt: january,
            now: january,
            decision: .confirmed(periodID: dining.1.id),
            merchant: "面馆"
        )
        _ = try ledger.record(
            amount: 30,
            currencyCode: "CNY",
            occurredAt: january,
            now: january,
            decision: .pending(periodID: dining.1.id, confidence: DecimalMath.parse("0.4"))
        )
        _ = try ledger.record(
            amount: 20,
            currencyCode: "CNY",
            occurredAt: january,
            now: january,
            decision: .unbudgeted
        )
        _ = try ledger.record(
            amount: 10_000,
            currencyCode: "JPY",
            occurredAt: january,
            now: january,
            decision: .confirmed(periodID: travel.1.id),
            estimatedBudgetAmount: 10_000
        )

        ledger = try CycleEngine.markDueIfNeeded(
            ledger: ledger,
            periodID: dining.1.id,
            now: TestDates.day(2026, 2, 1),
            calendar: calendar
        )
        let queued = try ledger.record(
            amount: 15,
            currencyCode: "CNY",
            occurredAt: TestDates.day(2026, 2, 2),
            now: TestDates.day(2026, 2, 2),
            decision: .queued(budgetID: dining.0.id)
        )

        ledger = try SettlementEngine.commit(
            ledger: ledger,
            periodID: dining.1.id,
            now: TestDates.day(2026, 2, 3),
            calendar: calendar,
            quote: nil,
            acceptedIncompleteData: true
        )
        #expect(WalletLedger.projection(ledger: ledger).balance == 920)
        let nextDining = ledger.periods(forBudget: dining.0.id).first { $0.sequence == 2 }
        #expect(nextDining != nil)
        #expect(try ledger.requireExpense(queued.id).budgetPeriodID == nextDining?.id)
        #expect(try ledger.requireExpense(queued.id).queuedForBudgetID == nil)

        ledger = try CycleEngine.markDueIfNeeded(
            ledger: ledger,
            periodID: travel.1.id,
            now: TestDates.day(2026, 1, 11),
            calendar: calendar
        )
        #expect(throws: LedgerError.missingExchangeRate(source: "JPY", target: "CNY")) {
            try SettlementEngine.commit(
                ledger: ledger,
                periodID: travel.1.id,
                now: TestDates.day(2026, 1, 11),
                calendar: calendar,
                quote: nil,
                acceptedIncompleteData: false
            )
        }
        let yenQuote = ExchangeQuote.estimated(
            rate: DecimalMath.parse("0.05"),
            at: TestDates.day(2026, 1, 11),
            sourceName: "estimate"
        )
        ledger = try SettlementEngine.commit(
            ledger: ledger,
            periodID: travel.1.id,
            now: TestDates.day(2026, 1, 11),
            calendar: calendar,
            quote: yenQuote,
            acceptedIncompleteData: false
        )
        #expect(try ledger.requireBudget(travel.0.id).state == .archived)
        #expect(WalletLedger.projection(ledger: ledger).balance == 2_920)

        let wish = Wish(
            id: UUID(),
            name: "耳机",
            targetAmount: 3_000,
            currencyCode: "CNY",
            referenceURL: nil,
            state: .active,
            createdAt: TestDates.day(2026, 2, 3),
            completedAt: nil
        )
        ledger.upsert(wish)
        #expect(throws: LedgerError.insufficientWishWallet) {
            try WishRedemptionEngine.confirm(
                ledger: ledger,
                wishID: wish.id,
                actualAmount: 3_000,
                currencyCode: "CNY",
                quote: nil,
                now: TestDates.day(2026, 2, 4)
            )
        }
        ledger = try WishRedemptionEngine.confirm(
            ledger: ledger,
            wishID: wish.id,
            actualAmount: 400,
            currencyCode: "CNY",
            quote: nil,
            now: TestDates.day(2026, 2, 4)
        )
        #expect(WalletLedger.projection(ledger: ledger).balance == 2_520)

        let late = ledger.insertExpense(
            amount: 50,
            currencyCode: "CNY",
            occurredAt: TestDates.day(2026, 1, 20),
            now: TestDates.day(2026, 2, 5)
        )
        let latePreview = try RetrospectiveAdjustmentEngine.previewLateExpense(
            ledger: ledger,
            periodID: dining.1.id,
            expenseID: late.id,
            quote: nil,
            now: TestDates.day(2026, 2, 5)
        )
        ledger = try RetrospectiveAdjustmentEngine.confirm(
            ledger: ledger,
            preview: latePreview,
            quote: nil,
            now: TestDates.day(2026, 2, 5)
        )
        #expect(WalletLedger.projection(ledger: ledger).balance == 2_470)
        #expect(try ledger.requirePeriod(dining.1.id).state == .settled)
    }
}
