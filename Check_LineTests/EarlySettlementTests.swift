import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor struct EarlySettlementTests {
    private let now = TestDates.day(2026, 10, 23)
    private var calendar: Calendar { TestDates.calendar }

    private func seed(recurrence: RecurrenceRule = .monthly, currency: String = "CNY",
                      start: Date = TestDates.day(2026, 10, 1), end: Date = TestDates.day(2026, 10, 31)) throws -> (Ledger, Budget, BudgetPeriod) {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        ledger.walletSettings.userConfirmedCurrency = true
        let (budget, period) = try ledger.insertBudgetCard(name: "Sample", amount: 100, currencyCode: currency,
            cycleType: .repeating, recurrence: recurrence, startDate: start, endDate: end, now: now)
        _ = try ledger.record(amount: 35, currencyCode: currency, occurredAt: now, now: now,
                              decision: .confirmed(periodID: period.id))
        return (ledger, budget, period)
    }

    @Test("提前核对只读，确认后保留原循环日期，间隔消费不能扣下一期，重开账本一致")
    func earlySettlementPreservesScheduleAndPersistence() throws {
        let (ledger, budget, period) = try seed()
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        try LedgerStore.replaceAll(ledger, in: container.mainContext)
        let workspace = CheckLineWorkspace(context: container.mainContext, now: now, calendar: calendar)
        let reviewed = workspace.ledger
        let preview = try workspace.previewEarlySettlement(period.id, now: now)
        #expect(preview.baseSurplus == 65 && preview.balanceAfter == 65)
        #expect(workspace.ledger == reviewed && workspace.wallet.balance == 0)
        try workspace.settlePeriod(period.id, quote: nil, reviewedLedger: reviewed, acceptedIncompleteData: true, endingEarly: true, now: now)
        let changed = workspace.ledger
        let next = try #require(changed.periods(forBudget: budget.id).first { $0.sequence == 2 })
        #expect(next.startDate == TestDates.day(2026, 11, 1, hour: 0))
        #expect(next.endDate == TestDates.day(2026, 11, 30, hour: 0))
        #expect(changed.periods[period.id]?.endDate == calendar.startOfDay(for: now))
        #expect(changed.budgets[budget.id]?.recurrence == .monthly)
        #expect(workspace.wallet.balance == 65 && changed.walletEntries.count == 1)
        let gap = TestDates.day(2026, 10, 24)
        #expect(CaptureAttributionResolver.resolve(budgetID: budget.id, occurredAt: gap, ledger: changed, calendar: calendar) == .unavailable)
        var attempt = changed
        let expense = attempt.insertExpense(amount: 10, currencyCode: "CNY", occurredAt: gap, now: gap)
        #expect(throws: LedgerError.captureDateOutsidePeriod) {
            try AttributionEngine.apply(ledger: attempt, expenseID: expense.id, decision: .confirmed(periodID: next.id), now: gap, calendar: calendar)
        }
        #expect(CaptureAttributionResolver.resolve(budgetID: budget.id, occurredAt: next.startDate, ledger: changed, calendar: calendar) == .period(next.id))
        let reloaded = try LedgerStore.load(from: ModelContext(container), now: now)
        #expect(reloaded == changed && WalletLedger.projection(ledger: reloaded).balance == 65)
    }

    @Test("默认结算门禁保留；显式提前也不能结算未来期或重复结算")
    func explicitGateAndDuplicateProtection() throws {
        let (ledger, budget, period) = try seed()
        #expect(throws: LedgerError.periodNotReadyToSettle) {
            try SettlementEngine.preview(ledger: ledger, periodID: period.id, now: now, calendar: calendar, quote: nil)
        }
        let changed = try SettlementEngine.commit(ledger: ledger, periodID: period.id, now: now, calendar: calendar,
                                                   quote: nil, acceptedIncompleteData: true, endingEarly: true)
        let next = try #require(changed.periods(forBudget: budget.id).first { $0.sequence == 2 })
        for id in [period.id, next.id] {
            #expect(throws: LedgerError.periodNotReadyToSettle) {
                try SettlementEngine.commit(ledger: changed, periodID: id, now: now, calendar: calendar,
                                            quote: nil, acceptedIncompleteData: true, endingEarly: true)
            }
        }
        let lastDay = TestDates.day(2026, 10, 31, hour: 23)
        #expect(SettlementEngine.canEndEarly(ledger: ledger, periodID: period.id, now: lastDay, calendar: calendar))
        #expect(!SettlementEngine.canEndEarly(ledger: ledger, periodID: period.id, now: TestDates.day(2026, 11, 1), calendar: calendar))
    }

    @Test("提前结束不挪动周度、自选跨月、短月和每N天的下一期")
    func recurrenceBoundariesStayAnchored() throws {
        let cases: [(RecurrenceRule, Date, Date, Date)] = [
            (.weekly, TestDates.day(2026, 10, 20), TestDates.day(2026, 10, 26), now),
            (.everyNDays(10), TestDates.day(2026, 10, 20), TestDates.day(2026, 10, 29), now),
            (.monthlyWindow(startDay: 20, endDay: 5), TestDates.day(2026, 10, 20), TestDates.day(2026, 11, 5), now),
            (.monthlyCycle(31), TestDates.day(2026, 1, 31), TestDates.day(2026, 2, 27), TestDates.day(2026, 2, 3))
        ]
        for (rule, start, end, date) in cases {
            var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: date)
            let (budget, period) = try ledger.insertBudgetCard(name: "Sample", amount: 100, currencyCode: "CNY", cycleType: .repeating,
                recurrence: rule, startDate: start, endDate: end, now: date)
            let originalNext = try CycleEngine.nextPeriodPlan(budget: budget, settledPeriod: period, calendar: calendar)
            let changed = try SettlementEngine.commit(ledger: ledger, periodID: period.id, now: date, calendar: calendar,
                                                       quote: nil, acceptedIncompleteData: true, endingEarly: true)
            let next = try #require(changed.periods(forBudget: budget.id).first { $0.sequence == 2 })
            #expect(next.startDate == originalNext.startDate && next.endDate == originalNext.endDate)
            #expect(changed.periods[period.id]?.endDate == calendar.startOfDay(for: date))
        }
    }

    @Test("未来日期记录必须先调整；预览和提交都拒绝且不忽略支出")
    func futureRecordsBlockEarlySettlement() throws {
        var (ledger, _, period) = try seed()
        _ = try ledger.record(amount: 10, currencyCode: "CNY", occurredAt: TestDates.day(2026, 10, 28), now: now,
                              decision: .confirmed(periodID: period.id))
        #expect(throws: LedgerError.futureRecordsBlockEarlySettlement) {
            try SettlementEngine.preview(ledger: ledger, periodID: period.id, now: now, calendar: calendar, quote: nil, endingEarly: true)
        }
        #expect(throws: LedgerError.futureRecordsBlockEarlySettlement) {
            try SettlementEngine.commit(ledger: ledger, periodID: period.id, now: now, calendar: calendar,
                                        quote: nil, acceptedIncompleteData: true, endingEarly: true)
        }
        #expect(ledger.expenses.count == 2 && ledger.settlements.isEmpty && ledger.walletEntries.isEmpty)
    }

    @Test("跨币种仍需报价，结余先补差额，再按Decimal写入钱包")
    func exchangeAndRecoveryRulesAreUnchanged() throws {
        var (ledger, _, period) = try seed(currency: "USD")
        ledger = try WalletLedger.append(ledger: ledger, type: .overrun, sourceSignedAmount: -50,
                                         sourceCurrencyCode: "CNY", quote: nil, at: now).0
        #expect(throws: LedgerError.missingExchangeRate(source: "USD", target: "CNY")) {
            try SettlementEngine.preview(ledger: ledger, periodID: period.id, now: now, calendar: calendar, quote: nil, endingEarly: true)
        }
        let quote = ExchangeQuote.estimated(rate: Decimal(string: "7.25")!, at: now, sourceName: "sample")
        let changed = try SettlementEngine.commit(ledger: ledger, periodID: period.id, now: now, calendar: calendar,
                                                   quote: quote, acceptedIncompleteData: true, endingEarly: true)
        #expect(WalletLedger.projection(ledger: changed).balance == Decimal(string: "421.25"))
        #expect(WalletLedger.projection(ledger: changed).recoveryGap == 0)
        #expect(changed.settlement(forPeriod: period.id)?.baseSurplus == 65)
        #expect(changed.walletEntries.count == 2)
    }

    @Test("早结算保存失败完整回滚，重试仅写一笔，陈旧确认拒绝")
    func atomicFailureRetryAndStaleReview() throws {
        let (ledger, _, period) = try seed()
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        try LedgerStore.replaceAll(ledger, in: container.mainContext)
        let gate = EarlySettlementSaveGate()
        let workspace = CheckLineWorkspace(context: container.mainContext, now: now, calendar: calendar, saveLedger: { value, context in
            if gate.fails { throw EarlySettlementSaveError.failed }
            try LedgerStore.replaceAll(value, in: context)
        })
        let reviewed = workspace.ledger
        gate.fails = true
        #expect(throws: EarlySettlementSaveError.failed) {
            try workspace.settlePeriod(period.id, quote: nil, reviewedLedger: reviewed, acceptedIncompleteData: true, endingEarly: true, now: now)
        }
        #expect(workspace.ledger == reviewed && workspace.wallet.balance == 0)
        #expect(try LedgerStore.load(from: ModelContext(container), now: now) == reviewed)
        gate.fails = false
        try workspace.settlePeriod(period.id, quote: nil, reviewedLedger: reviewed, acceptedIncompleteData: true, endingEarly: true, now: now)
        #expect(workspace.ledger.walletEntries.count == 1 && workspace.wallet.balance == 65)
        #expect(throws: LedgerError.staleSettlementPreview) {
            try workspace.settlePeriod(period.id, quote: nil, reviewedLedger: reviewed, acceptedIncompleteData: true, endingEarly: true, now: now)
        }
    }

    @Test("存在待确认金额时，提前结算也必须接受数据不完整")
    func pendingConfirmationGateIsPreserved() throws {
        var (ledger, _, period) = try seed()
        _ = try ledger.record(amount: 15, currencyCode: "CNY", occurredAt: now, now: now,
                              decision: .pending(periodID: period.id, confidence: Decimal(string: "0.4")!))
        #expect(throws: LedgerError.incompleteSettlementNotAccepted) {
            try SettlementEngine.commit(ledger: ledger, periodID: period.id, now: now, calendar: calendar,
                                        quote: nil, acceptedIncompleteData: false, endingEarly: true)
        }
        #expect(ledger.settlements.isEmpty)
    }
}

@MainActor private final class EarlySettlementSaveGate { var fails = false }
private enum EarlySettlementSaveError: Error { case failed }
