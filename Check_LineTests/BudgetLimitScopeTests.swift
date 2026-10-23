import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor struct BudgetLimitScopeTests {
    private let now = TestDates.day(2026, 10, 23)
    private var calendar: Calendar { TestDates.calendar }

    @Test("每周、自定义和月度区间改本期及以后；结算沿用新上限且日期不变",
          arguments: [RecurrenceRule.weekly, .everyNDays(10), .monthlyCycle(15), .monthlyWindow(startDay: 20, endDay: 5)])
    func repeatingLimits(_ rule: RecurrenceRule) throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let start: Date
        let end: Date
        switch rule {
        case .weekly: start = TestDates.day(2026, 10, 19); end = TestDates.day(2026, 10, 25)
        case .monthlyCycle: start = TestDates.day(2026, 10, 15); end = TestDates.day(2026, 11, 14)
        case .monthlyWindow: start = TestDates.day(2026, 10, 20); end = TestDates.day(2026, 11, 5)
        default: start = TestDates.day(2026, 10, 20); end = TestDates.day(2026, 10, 29)
        }
        let (budget, period) = try ledger.insertBudgetCard(name: "Limit", amount: 100, currencyCode: "CNY",
            cycleType: .repeating, recurrence: rule, startDate: start, endDate: end, now: now)
        let plan = try CycleEngine.nextPeriodPlan(budget: budget, settledPeriod: period, calendar: calendar)
        let preview = try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budget.id, periodID: period.id, newAmount: DecimalMath.parse("123.45"))
        #expect(preview.cycleType == .repeating)
        #expect(ledger.periods[period.id]?.budgetAmount == 100)
        let changed = try BudgetAmountEditEngine.confirm(ledger: ledger, preview: preview, now: now)
        #expect(changed.periods[period.id]?.budgetAmount == DecimalMath.parse("123.45"))
        #expect(changed.budgets[budget.id]?.defaultAmount == DecimalMath.parse("123.45"))
        #expect(changed.budgets[budget.id]?.recurrence == rule)
        #expect(changed.periods[period.id]?.startDate == start && changed.periods[period.id]?.endDate == end)
        #expect(changed.walletEntries == ledger.walletEntries && changed.expenses == ledger.expenses)
        #expect(try SettlementEngine.estimate(ledger: changed, periodID: period.id, now: now, calendar: calendar, quote: nil).baseSurplus == DecimalMath.parse("123.45"))
        let dueDate = try #require(calendar.date(byAdding: .day, value: 1, to: end))
        let due = try CycleEngine.markDueIfNeeded(ledger: changed, periodID: period.id, now: dueDate, calendar: calendar)
        let settled = try SettlementEngine.commit(ledger: due, periodID: period.id, now: dueDate,
            calendar: calendar, quote: nil, acceptedIncompleteData: true)
        let next = try #require(settled.periods(forBudget: budget.id).first { $0.state == .active })
        #expect(next.startDate == plan.startDate && next.endDate == plan.endDate)
        #expect(next.budgetAmount == DecimalMath.parse("123.45"))
        #expect(settled.settlement(forPeriod: period.id)?.budgetAmountSnapshot == DecimalMath.parse("123.45"))
    }

    @Test("有无截止日的一次性卡只改本次，超支正确、钱包不扣，持久化不生成未来期", arguments: [false, true])
    func oneShotLimit(_ hasDeadline: Bool) throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let (budget, period) = try ledger.insertBudgetCard(name: "Trip", amount: 100, currencyCode: "CNY",
            cycleType: .oneShot, recurrence: nil, startDate: now,
            endDate: hasDeadline ? TestDates.day(2026, 10, 30) : nil, now: now)
        _ = try ledger.record(amount: DecimalMath.parse("35.25"), currencyCode: "CNY", occurredAt: now,
                              now: now, decision: .confirmed(periodID: period.id))
        // Persisted ledgers materialize empty tag relationships. Seed that same
        // canonical form so a full-ledger comparison tests the amount change.
        for id in ledger.expenses.keys { ledger.expenseTagIDs[id] = [] }
        ledger = try WalletLedger.append(ledger: ledger, type: .surplus, sourceSignedAmount: 80,
            sourceCurrencyCode: "CNY", quote: nil, at: now).0
        let before = ledger
        let preview = try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budget.id, periodID: period.id,
                                                        newAmount: DecimalMath.parse("30.20"))
        #expect(preview.cycleType == .oneShot && ledger == before)
        #expect(preview.snapshotAfter.certainOverrunAmount == DecimalMath.parse("5.05"))
        let changed = try BudgetAmountEditEngine.confirm(ledger: ledger, preview: preview, now: now)
        #expect(changed.periods.count == 1 && changed.settlements.isEmpty)
        #expect(changed.budgets[budget.id]?.recurrence == nil)
        #expect(changed.budgets[budget.id]?.optionalDeadline == budget.optionalDeadline)
        #expect(changed.periods[period.id]?.endDate == period.endDate)
        #expect(changed.walletEntries == before.walletEntries && changed.expenses == before.expenses)
        #expect(WalletLedger.projection(ledger: changed).balance == 80)
        #expect(try SettlementEngine.estimate(ledger: changed, periodID: period.id, now: now, calendar: calendar, quote: nil).baseSurplus == DecimalMath.parse("-5.05"))
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        try LedgerStore.replaceAll(changed, in: container.mainContext)
        let reopened = try LedgerStore.load(from: ModelContext(container), now: now)
        #expect(reopened == changed)
    }

    @Test("提前结算后只改待开始期，不回改已结算额度、快照和钱包，也不提前恢复使用")
    func waitingPeriodLimitLeavesHistoryUntouched() throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let (budget, period) = try ledger.insertBudgetCard(name: "Monthly", amount: 100, currencyCode: "CNY",
            cycleType: .repeating, recurrence: .monthly, startDate: TestDates.day(2026, 10, 1),
            endDate: TestDates.day(2026, 10, 31), now: now)
        ledger = try SettlementEngine.commit(ledger: ledger, periodID: period.id, now: now,
            calendar: calendar, quote: nil, acceptedIncompleteData: true, endingEarly: true)
        let next = try #require(ledger.periods(forBudget: budget.id).first { $0.state == .active })
        let preview = try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budget.id, periodID: next.id, newAmount: 250)
        let changed = try BudgetAmountEditEngine.confirm(ledger: ledger, preview: preview, now: now)
        #expect(changed.periods[period.id] == ledger.periods[period.id])
        #expect(changed.settlements == ledger.settlements && changed.walletEntries == ledger.walletEntries)
        #expect(changed.periods[next.id]?.startDate == next.startDate && changed.periods[next.id]?.budgetAmount == 250)
        #expect(!SettlementEngine.canEndEarly(ledger: changed, periodID: next.id, now: now, calendar: calendar))
        #expect(CaptureAttributionResolver.resolve(budgetID: budget.id, occurredAt: now, ledger: changed, calendar: calendar) == .unavailable)
        #expect(throws: LedgerError.budgetAmountEditUnavailable) {
            try BudgetAmountEditEngine.preview(ledger: changed, budgetID: budget.id, periodID: period.id, newAmount: 300)
        }
    }

    @Test("新增卡类型共用保存回滚、输入恢复、精确剩余事件与重复确认保护", arguments: ["oneShot", "weekly", "custom"])
    func workspaceSaveRecovery(_ kind: String) throws {
        enum Failure: Error { case disk }
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let oneShot = kind == "oneShot"
        let (budget, period) = try ledger.insertBudgetCard(name: "Limit", amount: 100, currencyCode: "CNY",
            cycleType: oneShot ? .oneShot : .repeating, recurrence: oneShot ? nil : kind == "weekly" ? .weekly : .everyNDays(10),
            startDate: now, endDate: oneShot ? nil : TestDates.day(2026, 10, 29), now: now)
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        try LedgerStore.replaceAll(ledger, in: container.mainContext)
        let failure = LimitSaveSwitch()
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: now, calendar: calendar, saveLedger: { changed, context in
            if failure.fails { throw Failure.disk }
            try LedgerStore.replaceAll(changed, in: context)
        })
        let card = try #require(workspace.selectedCard)
        workspace.retainBudgetAmountDraft("150.25", for: card)
        let before = workspace.ledger
        let preview = try workspace.previewBudgetAmount(budgetID: budget.id, periodID: period.id, amountText: "150.25")
        failure.fails = true
        #expect(throws: Failure.disk) { try workspace.saveBudgetAmount(preview, now: now) }
        #expect(workspace.ledger == before && workspace.remainingAmountChange == nil)
        #expect(workspace.budgetAmountDraft(for: card) == "150.25")
        #expect(try LedgerStore.load(from: ModelContext(container), now: now) == before)
        failure.fails = false
        try workspace.saveBudgetAmount(preview, now: now)
        #expect(workspace.remainingAmountChange?.before == 100)
        #expect(workspace.remainingAmountChange?.after == DecimalMath.parse("150.25"))
        let fresh = CheckLineWorkspace(context: ModelContext(container), now: now, calendar: calendar)
        #expect(fresh.selectedCard?.snapshot.budgetAmount == DecimalMath.parse("150.25"))
        #expect(fresh.remainingAmountChange == nil)
        #expect(throws: LedgerError.staleBudgetAmountPreview) { try workspace.saveBudgetAmount(preview, now: now) }
    }
}

@MainActor private final class LimitSaveSwitch { var fails = false }
