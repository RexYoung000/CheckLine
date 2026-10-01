import Foundation
import SwiftData
import Testing
@testable import CheckLine

struct BudgetAmountEditEngineTests {
    let day = TestDates.day(2026, 9, 22)

    @Test("同时改当前周期和未来默认额度，消费钱包及已结算历史不变")
    func atomicAmountAndHistory() throws {
        var (ledger, budgetID, periodID) = try makeLedger()
        let historyID = UUID()
        var history = try ledger.requirePeriod(periodID)
        history.id = historyID; history.state = .settled; history.sequence = 0; history.budgetAmount = 700
        ledger.upsert(history)
        ledger = try WalletLedger.append(ledger: ledger, type: .surplus, sourceSignedAmount: 80, sourceCurrencyCode: "CNY", quote: nil, at: day).0
        let before = ledger
        let preview = try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budgetID, periodID: periodID, newAmount: 1200)
        #expect(ledger == before)
        let after = try BudgetAmountEditEngine.confirm(ledger: ledger, preview: preview, now: day)
        var expected = before
        expected.budgets[budgetID]?.defaultAmount = 1200
        expected.budgets[budgetID]?.updatedAt = day
        expected.periods[periodID]?.budgetAmount = 1200
        #expect(after == expected)
        #expect(after.periods[historyID]?.budgetAmount == 700)
        #expect(WalletLedger.projection(ledger: after) == WalletLedger.projection(ledger: before))
        #expect(throws: LedgerError.staleBudgetAmountPreview) { try BudgetAmountEditEngine.confirm(ledger: after, preview: preview, now: day) }
    }

    @Test("确定支出与待确认越线分开，边界到分不舍入", arguments: ["80", "95", "110", "120.01"])
    func overrunClassification(_ text: String) throws {
        var (ledger, budgetID, periodID) = try makeLedger()
        _ = try ledger.record(amount: DecimalMath.parse("90.01"), currencyCode: "CNY", occurredAt: day, now: day, decision: .confirmed(periodID: periodID))
        _ = try ledger.record(amount: DecimalMath.parse("19.99"), currencyCode: "CNY", occurredAt: day, now: day, decision: .pending(periodID: periodID, confidence: DecimalMath.parse("0.4")))
        let amount = DecimalMath.parse(text)
        let preview = try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budgetID, periodID: periodID, newAmount: amount)
        let certain = max(DecimalMath.parse("90.01") - amount, 0)
        let possible = max(110 - amount, 0) - certain
        #expect(preview.snapshotAfter.certainOverrunAmount == certain)
        #expect(preview.snapshotAfter.possibleOverrunAmount == possible)
        #expect(preview.snapshotAfter.remaining - preview.snapshotAfter.pendingAmount == amount - 110)
    }

    @Test("到期待结算的同一卡可编辑，结算后下一月沿用新默认，原月额度被冻结")
    func nextMonthUsesDefault() throws {
        var (ledger, budgetID, periodID) = try makeLedger()
        let nextDay = TestDates.day(2026, 10, 1)
        ledger = try CycleEngine.markDueIfNeeded(ledger: ledger, periodID: periodID, now: nextDay, calendar: TestDates.calendar)
        let preview = try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budgetID, periodID: periodID, newAmount: DecimalMath.parse("1234.56"))
        ledger = try BudgetAmountEditEngine.confirm(ledger: ledger, preview: preview, now: nextDay)
        ledger = try SettlementEngine.commit(ledger: ledger, periodID: periodID, now: nextDay, calendar: TestDates.calendar, quote: nil, acceptedIncompleteData: true)
        let next = try #require(ledger.periods(forBudget: budgetID).first { $0.state == .active })
        #expect(next.budgetAmount == DecimalMath.parse("1234.56"))
        #expect(ledger.periods[periodID]?.budgetAmount == DecimalMath.parse("1234.56"))
        #expect(throws: LedgerError.budgetAmountEditUnavailable) { try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budgetID, periodID: periodID, newAmount: 500) }
        #expect(throws: LedgerError.staleBudgetAmountPreview) { try BudgetAmountEditEngine.confirm(ledger: ledger, preview: preview, now: nextDay) }
        let settled = ledger
        let nextPreview = try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budgetID, periodID: next.id, newAmount: 500)
        ledger = try BudgetAmountEditEngine.confirm(ledger: ledger, preview: nextPreview, now: nextDay)
        #expect(ledger.periods[periodID] == settled.periods[periodID])
        #expect(ledger.settlements == settled.settlements)
        #expect(ledger.walletEntries == settled.walletEntries)
    }

    @Test("预览后的消费、默认额度或周期变更均不能沿用旧确认", arguments: [0, 1, 2])
    func stalePreview(_ mutation: Int) throws {
        var (ledger, budgetID, periodID) = try makeLedger()
        let preview = try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budgetID, periodID: periodID, newAmount: 2000)
        switch mutation {
        case 0: _ = try ledger.record(amount: 1, currencyCode: "CNY", occurredAt: day, now: day, decision: .confirmed(periodID: periodID))
        case 1: ledger.budgets[budgetID]?.defaultAmount = 1500
        default: ledger.periods[periodID]?.state = .settled
        }
        #expect(throws: LedgerError.staleBudgetAmountPreview) { try BudgetAmountEditEngine.confirm(ledger: ledger, preview: preview, now: day) }
    }

    @Test("结构化服务不能绕过正数和两位小数校验", arguments: [Decimal.zero, -1, DecimalMath.parse("0.001"), Decimal.nan])
    func directAmountValidation(_ amount: Decimal) throws {
        let (ledger, budgetID, periodID) = try makeLedger()
        #expect(throws: LedgerError.invalidBudgetAmount) { try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budgetID, periodID: periodID, newAmount: amount) }
    }

    @Test("没有变化不提交；一次性和非每月卡不扩展编辑范围")
    func unchangedAndScope() throws {
        var (ledger, budgetID, periodID) = try makeLedger()
        #expect(throws: LedgerError.unchangedBudgetAmount) { try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budgetID, periodID: periodID, newAmount: 1000) }
        ledger.budgets[budgetID]?.recurrence = .weekly
        #expect(!BudgetAmountEditEngine.isEditable(budgetID: budgetID, periodID: periodID, ledger: ledger))
        ledger.budgets[budgetID]?.cycleType = .oneShot
        #expect(!BudgetAmountEditEngine.isEditable(budgetID: budgetID, periodID: periodID, ledger: ledger))
    }

    private func makeLedger() throws -> (Ledger, UUID, UUID) {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: day)
        let created = try ledger.insertBudgetCard(name: "每月饭费", amount: 1000, currencyCode: "CNY", cycleType: .repeating, recurrence: .monthly, startDate: TestDates.day(2026, 9, 1), endDate: TestDates.day(2026, 9, 30), now: day)
        return (ledger, created.0.id, created.1.id)
    }
}

struct BudgetEditInputTests {
    @Test("拒绝无效、隐藏精度与不可精确表达输入", arguments: ["0", "-1", "0.001", "1.230", "NaN", "1e3", "12,34", "1.2.3", "", "999999999999999999999999999999999999999.99"])
    func rejectsInvalid(_ input: String) { #expect(MoneyFormat.parseBudgetAmount(input) == nil) }

    @Test("两位小数、分组和正数最小边界精确保留", arguments: ["0.01", "1,234.56", "1200", " 0001.20 "])
    func exactInputs(_ input: String) { #expect(MoneyFormat.parseBudgetAmount(input) == MoneyFormat.parseAmount(input)) }
}

@MainActor
struct BudgetAmountEditWorkspaceTests {
    let day = TestDates.day(2026, 9, 22)

    @Test("预览取消不保存，成功清旧整账本撤销，重复确认不写")
    func reviewAndCommit() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: day, calendar: TestDates.calendar)
        workspace.createBudget(name: "饭费", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: day)
        let card = try #require(workspace.selectedCard)
        _ = workspace.recordExpense(amountText: "35.25", merchant: "午餐", note: "", attributionID: card.periodID.uuidString, occurredAt: day, now: day)
        #expect(workspace.lastUndo != nil)
        let before = workspace.ledger
        workspace.retainBudgetAmountDraft("30.20", for: card)
        #expect(workspace.budgetAmountDraft(for: card) == "30.20")
        let oldEvent = workspace.remainingAmountChange
        let preview = try workspace.previewBudgetAmount(budgetID: card.id, periodID: card.periodID, amountText: "30.20")
        #expect(workspace.ledger == before)
        try expectStoredLedger(before, in: context)
        #expect(workspace.remainingAmountChange == oldEvent)
        try workspace.saveBudgetAmount(preview, now: day)
        #expect(workspace.lastUndo == nil)
        #expect(workspace.budgetAmountDraft(for: card) == "1000", "Saved edits clear the old input draft; reopening uses a freshly projected card.")
        #expect(workspace.ledger.expenses == before.expenses)
        #expect(workspace.ledger.walletEntries == before.walletEntries)
        let saved = workspace.ledger
        #expect(saved.budgets[card.id]?.defaultAmount == DecimalMath.parse("30.20"))
        #expect(saved.periods[card.periodID]?.budgetAmount == DecimalMath.parse("30.20"))
        #expect(workspace.remainingAmountChange?.before == DecimalMath.parse("964.75"))
        #expect(workspace.remainingAmountChange?.after == DecimalMath.parse("-5.05"))
        workspace.undoLast(now: day)
        #expect(workspace.ledger == saved)
        #expect(throws: LedgerError.staleBudgetAmountPreview) { try workspace.saveBudgetAmount(preview, now: day) }
        try expectStoredLedger(saved, in: context)
    }

    @Test("保存失败回滚已暂改的数据库，输入预览可重试且旧撤销不丢")
    func failureRollsBackBothAmounts() throws {
        enum Failure: Error { case disk }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let failure = BudgetSaveFailureSwitch()
        let workspace = CheckLineWorkspace(context: context, now: day, calendar: TestDates.calendar, saveLedger: { ledger, context in
            if failure.fails {
                let records = try context.fetch(FetchDescriptor<PersistedBudget>())
                records.first?.defaultAmount = 999
                throw Failure.disk
            }
            try LedgerStore.replaceAll(ledger, in: context)
        })
        workspace.createBudget(name: "饭费", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: day)
        let card = try #require(workspace.selectedCard)
        _ = workspace.recordExpense(amountText: "35", merchant: "午餐", note: "", attributionID: card.periodID.uuidString, occurredAt: day, now: day)
        let before = workspace.ledger
        let undo = workspace.lastUndo
        let event = workspace.remainingAmountChange
        let amountText = "1200.25"
        let preview = try workspace.previewBudgetAmount(budgetID: card.id, periodID: card.periodID, amountText: amountText)
        failure.fails = true
        #expect(throws: Failure.disk) { try workspace.saveBudgetAmount(preview, now: day) }
        #expect(workspace.ledger == before)
        try expectStoredLedger(before, in: context)
        #expect(workspace.lastUndo == undo)
        #expect(workspace.remainingAmountChange == event)
        failure.fails = false
        try workspace.saveBudgetAmount(preview, now: day)
        #expect(workspace.ledger.budgets[card.id]?.defaultAmount == MoneyFormat.parseBudgetAmount(amountText))
    }

    @Test("真正关闭并重开磁盘 ModelContainer，默认和本月金额都保留")
    func diskReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("checkline-budget-edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration("BudgetEdit", schema: CheckLinePersistence.schema, url: directory.appendingPathComponent("ledger.store"), cloudKitDatabase: .none)
        var budgetID: UUID?; var periodID: UUID?
        do {
            let container = try ModelContainer(for: CheckLinePersistence.schema, configurations: config)
            let workspace = CheckLineWorkspace(context: ModelContext(container), now: day, calendar: TestDates.calendar)
            workspace.createBudget(name: "饭费", amountText: "1000", currencyCode: "USD", cycleType: .repeating, now: day)
            let card = try #require(workspace.selectedCard)
            budgetID = card.id; periodID = card.periodID
            _ = workspace.recordExpense(amountText: "20.05", merchant: "午餐", note: "", attributionID: card.periodID.uuidString, occurredAt: day, now: day)
            let preview = try workspace.previewBudgetAmount(budgetID: card.id, periodID: card.periodID, amountText: "1500.99")
            try workspace.saveBudgetAmount(preview, now: day)
        }
        let reopened = try ModelContainer(for: CheckLinePersistence.schema, configurations: config)
        let workspace = CheckLineWorkspace(context: ModelContext(reopened), now: day, calendar: TestDates.calendar)
        #expect(workspace.ledger.budgets[try #require(budgetID)]?.defaultAmount == DecimalMath.parse("1500.99"))
        #expect(workspace.ledger.periods[try #require(periodID)]?.budgetAmount == DecimalMath.parse("1500.99"))
        #expect(workspace.selectedCard?.snapshot.confirmedSpent == DecimalMath.parse("20.05"))
        #expect(workspace.remainingAmountChange == nil)
        #expect(workspace.wallet.balance == 0)
    }

    @Test("另一窗口新增消费或改额度后，旧窗口不能覆盖磁盘新状态", arguments: [false, true])
    func anotherWorkspaceCannotOverwrite(_ editAmount: Bool) throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let first = CheckLineWorkspace(context: ModelContext(container), now: day, calendar: TestDates.calendar)
        first.createBudget(name: "饭费", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: day)
        let card = try #require(first.selectedCard)
        let preview = try first.previewBudgetAmount(budgetID: card.id, periodID: card.periodID, amountText: "1500")
        let second = CheckLineWorkspace(context: ModelContext(container), now: day, calendar: TestDates.calendar)
        if editAmount {
            let newPreview = try second.previewBudgetAmount(budgetID: card.id, periodID: card.periodID, amountText: "1200")
            try second.saveBudgetAmount(newPreview, now: day)
        } else {
            _ = second.recordExpense(amountText: "25.25", merchant: "午餐", note: "", attributionID: card.periodID.uuidString, occurredAt: day, now: day)
        }
        #expect(throws: LedgerError.staleBudgetAmountPreview) { try first.saveBudgetAmount(preview, now: day) }
        var expected = second.ledger
        for id in expected.expenses.keys where expected.expenseTagIDs[id] == nil { expected.expenseTagIDs[id] = [] }
        #expect(first.ledger == expected)
        #expect(first.ledger.budgets[card.id]?.defaultAmount == (editAmount ? 1200 : 1000))
        let fresh = try first.previewBudgetAmount(budgetID: card.id, periodID: card.periodID, amountText: "1500")
        try first.saveBudgetAmount(fresh, now: day)
        #expect(first.ledger.expenses == second.ledger.expenses)
    }

    @Test("刚结算的钱包含亚秒时间时，不误判为另一窗口变更")
    func savedSnapshotPrecisionDoesNotInvalidatePreview() throws {
        let timestamp = day.addingTimeInterval(0.123456)
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: timestamp, calendar: TestDates.calendar)
        workspace.createBudget(name: "饭费", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: timestamp)
        let monthly = try #require(workspace.selectedCard)
        workspace.createBudget(name: "旅行", amountText: "100", currencyCode: "CNY", cycleType: .oneShot, now: timestamp)
        let trip = try #require(workspace.selectedCard)
        // Coverage also uses an ISO8601 JSON snapshot, unlike the source's native Date.
        var seed = workspace.ledger
        let source = DataSourceConnection(id: UUID(), sourceType: .manual, state: .connected, lastCoveredAt: timestamp, coverageNote: nil, lastErrorCode: nil, updatedAt: timestamp)
        seed.dataSources[source.id] = source
        try LedgerStore.replaceAll(seed, in: context)
        workspace.ledger = seed
        try workspace.settlePeriod(trip.periodID, quote: nil, reviewedLedger: workspace.ledger, acceptedIncompleteData: true, now: timestamp)
        let walletBefore = workspace.wallet
        let historyBefore = workspace.ledger.periods[trip.periodID]
        let preview = try workspace.previewBudgetAmount(budgetID: monthly.id, periodID: monthly.periodID, amountText: "1200")
        try workspace.saveBudgetAmount(preview, now: timestamp)
        #expect(workspace.ledger.budgets[monthly.id]?.defaultAmount == 1200)
        #expect(workspace.wallet == walletBefore)
        #expect(workspace.ledger.periods[trip.periodID] == historyBefore)
    }

    private func expectStoredLedger(_ expected: Ledger, in context: ModelContext) throws {
        // Store loading materializes empty tag relationships; absence and [] mean the same thing.
        var normalized = expected
        for id in normalized.expenses.keys where normalized.expenseTagIDs[id] == nil {
            normalized.expenseTagIDs[id] = []
        }
        #expect(try LedgerStore.load(from: context, now: day) == normalized)
    }

    @Test("记一笔失败/未纳入不发预算动效，成功后发送精确前后金额")
    func recordSuccessEvents() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: day, calendar: TestDates.calendar)
        workspace.createBudget(name: "饭费", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: day)
        #expect(workspace.remainingAmountChange == nil)
        let card = try #require(workspace.selectedCard)
        _ = workspace.recordExpense(amountText: "bad", merchant: "", note: "", attributionID: card.periodID.uuidString, occurredAt: day, now: day)
        #expect(workspace.remainingAmountChange == nil)
        _ = workspace.recordExpense(amountText: "5", merchant: "", note: "", attributionID: "unbudgeted", occurredAt: day, now: day)
        #expect(workspace.remainingAmountChange == nil)
        _ = workspace.recordExpense(amountText: "10.01", merchant: "", note: "", attributionID: card.periodID.uuidString, occurredAt: day, now: day)
        #expect(workspace.remainingAmountChange?.after == DecimalMath.parse("989.99"))
        let event = workspace.remainingAmountChange
        workspace.undoLast(now: day)
        #expect(workspace.remainingAmountChange == event)
    }
}

@MainActor
private final class BudgetSaveFailureSwitch { var fails = false }
