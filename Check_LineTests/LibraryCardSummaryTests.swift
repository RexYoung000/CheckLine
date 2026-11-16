import Foundation
import Testing
@testable import CheckLine

struct LibraryCardSummaryTests {
    private let now = TestDates.day(2026, 11, 13)

    @Test("待开始的预算只显示额度和空液位")
    func upcomingCardShowsBudgetLimit() throws {
        let start = TestDates.day(2026, 11, 20)
        let (initialLedger, period) = try makeBudget(start: start)
        var ledger = initialLedger
        _ = try ledger.record(amount: 20, currencyCode: "CNY", occurredAt: start, now: now,
                              decision: .confirmed(periodID: period.id))
        let card = try #require(HomeProjector.card(budgetID: period.budgetID, periodID: period.id, in: ledger))
        #expect(BudgetPresentation.remaining(card) == 80)
        let summary = LibraryCardSummary(card: card, now: now)

        #expect(summary.label == String(localized: "native.library.card.upcoming"))
        #expect(summary.label != String(localized: "v1.card.remaining"))
        #expect(summary.amount == 100)
        #expect(summary.amountText == MoneyFormat.string(100, currencyCode: "CNY"))
        #expect(summary.fill == 0)
        #expect(!summary.isRisk)
    }

    @Test("待确认消费确认为已越线前保留可能越线文案")
    func pendingAndConfirmedOverrunsHaveDifferentLabels() throws {
        let (initialLedger, period) = try makeBudget()
        var ledger = initialLedger
        _ = try ledger.record(amount: 80, currencyCode: "CNY", occurredAt: now, now: now,
                              decision: .confirmed(periodID: period.id))
        let pending = try ledger.record(amount: 30, currencyCode: "CNY", occurredAt: now, now: now,
                                        decision: .pending(periodID: period.id, confidence: 0.4))
        let possible = try summary(in: ledger)

        #expect(possible.label == String(localized: "wallet.possibleOverrun"))
        #expect(possible.amount == -10)
        #expect(possible.fill == 0)
        #expect(possible.isRisk)

        ledger = try AttributionEngine.confirmPending(ledger: ledger, expenseID: pending.id, now: now)
        let certain = try summary(in: ledger)

        #expect(certain.label == String(localized: "wallet.overrun"))
        #expect(certain.amount == -10)
        #expect(certain.fill == 0)
        #expect(certain.isRisk)
    }

    @Test("待确认退款使暂计剩余转正时仍显示已确认的越线额")
    func pendingRefundKeepsConfirmedOverrun() throws {
        let (initialLedger, period) = try makeBudget()
        var ledger = initialLedger
        let purchase = try ledger.record(amount: 110, currencyCode: "CNY", occurredAt: now, now: now,
                                         decision: .confirmed(periodID: period.id))
        let refund = ledger.insertExpense(amount: 20, currencyCode: "CNY", occurredAt: now, now: now,
                                          kind: .refund, reversesExpenseID: purchase.id)
        ledger = try AttributionEngine.apply(ledger: ledger, expenseID: refund.id,
                                              decision: .pending(periodID: period.id, confidence: 0.4), now: now,
                                              calendar: TestDates.calendar)
        let card = try #require(HomeProjector.cards(in: ledger, now: now).first)
        #expect(BudgetPresentation.remaining(card) == 10)

        let summary = LibraryCardSummary(card: card, now: now)
        #expect(summary.label == String(localized: "wallet.overrun"))
        #expect(summary.amount == -10)
        #expect(summary.fill == 0)
        #expect(summary.isRisk)
    }

    @Test("恰好用完时液位为零且没有越线")
    func exactlyAtLimitHasEmptyLiquidAndNoRisk() throws {
        let (initialLedger, period) = try makeBudget()
        var ledger = initialLedger
        _ = try ledger.record(amount: 100, currencyCode: "CNY", occurredAt: now, now: now,
                              decision: .confirmed(periodID: period.id))
        let summary = try summary(in: ledger)

        #expect(summary.label == String(localized: "v1.card.remaining"))
        #expect(summary.amount == 0)
        #expect(summary.fill == 0)
        #expect(!summary.isRisk)
    }

    private func makeBudget(start: Date? = nil) throws -> (Ledger, BudgetPeriod) {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let (_, period) = try ledger.insertBudgetCard(name: "日常", amount: 100, currencyCode: "CNY",
                                                      cycleType: .oneShot, recurrence: nil, startDate: start ?? now,
                                                      endDate: nil, now: now)
        return (ledger, period)
    }

    private func summary(in ledger: Ledger) throws -> LibraryCardSummary {
        let card = try #require(HomeProjector.cards(in: ledger, now: now).first)
        return LibraryCardSummary(card: card, now: now)
    }
}
