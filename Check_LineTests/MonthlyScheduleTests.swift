import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor
struct MonthlyScheduleTests {
    let calendar = TestDates.calendar
    func day(_ year: Int, _ month: Int, _ day: Int) -> Date { calendar.startOfDay(for: TestDates.day(year, month, day)) }
    func period(_ plan: NextPeriodPlan, budgetID: UUID = UUID()) -> BudgetPeriod {
        BudgetPeriod(id: UUID(), budgetID: budgetID, budgetAmount: 100, currencyCode: "CNY", startDate: plan.startDate,
                     endDate: plan.endDate, state: .active, sequence: 1, createdAt: plan.startDate)
    }

    @Test("完整月周期跨短月及闰年保持原日，边界只计一次", arguments: [2024, 2026], [1, 15, 29, 30, 31])
    func fullCyclesRetainChosenDay(year: Int, chosenDay: Int) throws {
        let schedule = MonthlySchedule(startDay: chosenDay)
        var plan = try schedule.period(inMonthContaining: day(year, 1, 1), calendar: calendar)
        for _ in 0..<12 {
            let count = try #require(calendar.range(of: .day, in: .month, for: plan.startDate)?.count)
            #expect(calendar.component(.day, from: plan.startDate) == min(chosenDay, count))
            let next = try schedule.next(after: period(plan), calendar: calendar)
            let end = try #require(plan.endDate)
            #expect(calendar.date(byAdding: .day, value: 1, to: end) == next.startDate)
            #expect(!plan.contains(next.startDate, calendar: calendar))
            #expect(next.contains(next.startDate, calendar: calendar))
            plan = next
        }
        #expect(schedule.startDay == chosenDay)
    }

    @Test("指定区间同月、跨月、单日与月底相邻期不重叠", arguments: [
        MonthlySchedule(kind: .window, startDay: 5, endDay: 20),
        MonthlySchedule(kind: .window, startDay: 20, endDay: 5),
        MonthlySchedule(kind: .window, startDay: 31, endDay: 30),
        MonthlySchedule(kind: .window, startDay: 30, endDay: 29),
        MonthlySchedule(kind: .window, startDay: 30, endDay: 31),
        MonthlySchedule(kind: .window, startDay: 31, endDay: 31)
    ])
    func windowsNeverOverlap(schedule: MonthlySchedule) throws {
        var plan = try schedule.period(inMonthContaining: day(2024, 1, 1), calendar: calendar)
        for _ in 0..<36 {
            let next = try schedule.next(after: period(plan), calendar: calendar)
            let end = try #require(plan.endDate)
            #expect(end >= plan.startDate)
            #expect(try #require(calendar.date(byAdding: .day, value: 1, to: end)) <= next.startDate)
            #expect(!plan.contains(next.startDate, calendar: calendar))
            #expect(schedule.contains(plan.startDate, calendar: calendar))
            plan = next
        }
    }

    @Test("首期选当前区间，间隔选将开始的一期，结束日全天包含")
    func firstPeriodAndGap() throws {
        let window = MonthlySchedule(kind: .window, startDay: 5, endDay: 20)
        #expect(try window.period(containingOrFollowing: day(2026, 10, 1), calendar: calendar).startDate == day(2026, 10, 5))
        #expect(try window.period(containingOrFollowing: day(2026, 10, 10), calendar: calendar).startDate == day(2026, 10, 5))
        #expect(try window.period(containingOrFollowing: day(2026, 10, 21), calendar: calendar).startDate == day(2026, 11, 5))
        #expect(window.contains(day(2026, 10, 20).addingTimeInterval(86_399), calendar: calendar))
        #expect(!window.contains(day(2026, 10, 21), calendar: calendar))
        let cross = MonthlySchedule(kind: .window, startDay: 20, endDay: 5)
        let crossPlan = try cross.period(containingOrFollowing: day(2026, 11, 2), calendar: calendar)
        #expect(crossPlan.startDate == day(2026, 10, 20) && crossPlan.endDate == day(2026, 11, 5))
        let full = try MonthlySchedule(startDay: 15).period(containingOrFollowing: day(2026, 10, 13), calendar: calendar)
        #expect(full.startDate == day(2026, 9, 15) && full.endDate == day(2026, 10, 14))
    }

    @Test("月末截断只属新一期；完整周期和单日区间有不同含义")
    func clampedBoundaryAndSingleDay() throws {
        let window = MonthlySchedule(kind: .window, startDay: 31, endDay: 30)
        let january = try window.period(inMonthContaining: day(2026, 1, 1), calendar: calendar)
        let february = try window.next(after: period(january), calendar: calendar)
        #expect(january.endDate == day(2026, 2, 27))
        #expect(february.startDate == day(2026, 2, 28) && february.endDate == day(2026, 3, 30))
        let single = try MonthlySchedule(kind: .window, startDay: 1, endDay: 1).period(inMonthContaining: day(2026, 10, 1), calendar: calendar)
        let full = try MonthlySchedule(startDay: 1).period(inMonthContaining: day(2026, 10, 1), calendar: calendar)
        #expect(single.endDate == day(2026, 10, 1) && full.endDate == day(2026, 10, 31))
    }

    @Test("月度规则原字段往返，旧格式保持，非法日拒绝")
    func storedRules() throws {
        for rule in [RecurrenceRule.monthly, .weekly, .everyNDays(7), .monthlyCycle(31), .monthlyWindow(startDay: 20, endDay: 5)] {
            #expect(RecurrenceRule.parse(rule.stored) == rule)
        }
        for raw in ["monthlyCycle:0", "monthlyCycle:32", "monthlyWindow:5:32", "monthlyWindow:0:20", "monthlyWindow:5:20:1", "monthlyWindow:5::20"] {
            #expect(RecurrenceRule.parse(raw) == nil)
        }
        #expect(throws: LedgerError.repeatingBudgetNeedsRecurrence) {
            try MonthlySchedule(startDay: 32).period(inMonthContaining: day(2026, 10, 1), calendar: calendar)
        }
    }

    @Test("夏令时边界使用当地日历午夜而非固定小时")
    func daylightSavingBoundary() throws {
        var local = calendar; local.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let march = try #require(local.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        let plan = try MonthlySchedule().period(inMonthContaining: march, calendar: local)
        let next = try MonthlySchedule().next(after: period(plan), calendar: local)
        #expect(local.component(.hour, from: next.startDate) == 0)
        #expect(next.startDate.timeIntervalSince(plan.startDate) == 31 * 86_400 - 3_600)
        #expect(!plan.contains(next.startDate, calendar: local))
    }

    @Test("结构化日期必须与月度规则一致，失配不创建卡片")
    func creationDatesMustMatchRule() throws {
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: day(2026, 10, 10))
        let intent = AgentIntent.createBudget(CreateBudgetDraft(name: "Range", amount: 100, currencyCode: "CNY", cycleType: .repeating,
                                                               recurrence: .monthlyWindow(startDay: 5, endDay: 20),
                                                               startDate: day(2026, 10, 1), endDate: day(2026, 10, 20)))
        #expect(throws: LedgerError.repeatingBudgetNeedsRecurrence) {
            try AgentActionCoordinator(calendar: calendar).execute(intent: intent, ledger: ledger, now: day(2026, 10, 10), confirmation: .accepted)
        }
        #expect(ledger.budgets.isEmpty && ledger.walletEntries.isEmpty)
    }

    @Test("间隔消费不能绑定或排队，可明确保留未纳入")
    func gapCannotBindOrQueue() throws {
        let schedule = MonthlySchedule(kind: .window, startDay: 5, endDay: 20)
        let plan = try schedule.period(inMonthContaining: day(2026, 10, 1), calendar: calendar)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: day(2026, 10, 10))
        let created = try ledger.insertBudgetCard(name: "Range", amount: 100, currencyCode: "CNY", cycleType: .repeating,
                                                 recurrence: schedule.recurrence, startDate: plan.startDate, endDate: plan.endDate, now: plan.startDate)
        let coordinator = AgentActionCoordinator(calendar: calendar)
        let gap = day(2026, 10, 21)
        let capture = AgentIntent.capture(CaptureDraft(amount: 10, currencyCode: "CNY", occurredAt: gap, periodID: created.1.id))
        #expect(throws: LedgerError.captureDateOutsidePeriod) {
            try coordinator.execute(intent: capture, ledger: ledger, now: gap, confirmation: .accepted)
        }
        let expense = ledger.insertExpense(amount: 10, currencyCode: "CNY", occurredAt: gap, now: gap)
        #expect(AttributionEngine.suggestPeriod(expense: expense, ledger: ledger, calendar: calendar) == .unbudgeted)
        ledger = try CycleEngine.markDueIfNeeded(ledger: ledger, periodID: created.1.id, now: gap, calendar: calendar)
        #expect(throws: LedgerError.captureDateOutsidePeriod) {
            try AttributionEngine.apply(ledger: ledger, expenseID: expense.id, decision: .queued(budgetID: created.0.id), now: gap, calendar: calendar)
        }
        #expect(try ledger.requireExpense(expense.id).budgetPeriodID == nil)
        #expect(BudgetEngine.periodSnapshot(period: created.1, expenses: Array(ledger.expenses.values)).confirmedSpent == 0)
    }

    @Test("结算仅纳入下一有效区间，更远队列保留，异常间隔记录回到未纳入")
    func queueMovesOnlyIntoMatchingPeriod() throws {
        let schedule = MonthlySchedule(kind: .window, startDay: 5, endDay: 20)
        let plan = try schedule.period(inMonthContaining: day(2026, 10, 1), calendar: calendar)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: plan.startDate)
        let created = try ledger.insertBudgetCard(name: "Range", amount: 100, currencyCode: "CNY", cycleType: .repeating,
                                                 recurrence: schedule.recurrence, startDate: plan.startDate, endDate: plan.endDate, now: plan.startDate)
        let now = day(2026, 10, 21)
        ledger = try CycleEngine.markDueIfNeeded(ledger: ledger, periodID: created.1.id, now: now, calendar: calendar)
        let november = try ledger.record(amount: 10, currencyCode: "CNY", occurredAt: day(2026, 11, 7), now: now, decision: .queued(budgetID: created.0.id))
        let december = try ledger.record(amount: 20, currencyCode: "CNY", occurredAt: day(2026, 12, 7), now: now, decision: .queued(budgetID: created.0.id))
        var invalid = ledger.insertExpense(amount: 30, currencyCode: "CNY", occurredAt: day(2026, 11, 25), now: now)
        invalid.queuedForBudgetID = created.0.id; invalid.attributionState = .confirmed; ledger.upsert(invalid)
        ledger = try SettlementEngine.commit(ledger: ledger, periodID: created.1.id, now: now, calendar: calendar, quote: nil, acceptedIncompleteData: true)
        let next = try #require(ledger.periods(forBudget: created.0.id).first { $0.sequence == 2 })
        #expect(next.startDate == day(2026, 11, 5) && next.endDate == day(2026, 11, 20))
        #expect(ledger.expenses[november.id]?.budgetPeriodID == next.id)
        #expect(ledger.expenses[december.id]?.queuedForBudgetID == created.0.id && ledger.expenses[december.id]?.budgetPeriodID == nil)
        #expect(ledger.expenses[invalid.id]?.attributionState == .unbudgeted && ledger.expenses[invalid.id]?.queuedForBudgetID == nil)
        #expect(BudgetEngine.periodSnapshot(period: next, expenses: Array(ledger.expenses.values)).confirmedSpent == 10)
        #expect(BudgetAmountEditEngine.isEditable(budgetID: created.0.id, periodID: next.id, ledger: ledger))
        ledger = try CycleEngine.markDueIfNeeded(ledger: ledger, periodID: next.id, now: day(2026, 11, 21), calendar: calendar)
        ledger = try SettlementEngine.commit(ledger: ledger, periodID: next.id, now: day(2026, 11, 21), calendar: calendar, quote: nil, acceptedIncompleteData: true)
        let final = try #require(ledger.periods(forBudget: created.0.id).first { $0.sequence == 3 })
        #expect(ledger.expenses[december.id]?.budgetPeriodID == final.id)
        #expect(WalletLedger.projection(ledger: ledger).balance == 190)
    }
}

@MainActor
struct MonthlyScheduleWorkspaceTests {
    let now = TestDates.day(2026, 10, 21)

    @Test("只选择月度日期也构成可恢复草稿")
    func dateOnlyDraftIsRetained() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CheckLineDateOnly-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var draft = TaskDraft(kind: "budget")
        draft.monthlySchedule = MonthlySchedule(startDay: 31)
        #expect(draft.hasInput && !draft.fieldsTouched)
        try TaskDraftStore(root: root).save(draft)
        #expect(try TaskDraftStore(root: root).load(draft.key)?.monthlySchedule == draft.monthlySchedule)
    }

    @Test("月度规则跨重开与 Agent 核对保留，重新计算首期，保存后清理")
    func draftAndConfirmationPersistSchedule() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CheckLineMonthly-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let first = CheckLineWorkspace(context: ModelContext(container), now: now, calendar: TestDates.calendar, draftStore: TaskDraftStore(root: root))
        first.beginTask(.budget, mode: "form", now: now)
        first.taskDraft.name = "Window card"; first.taskDraft.amount = "100"; first.taskDraft.formTouched = true
        first.taskDraft.monthlySchedule = MonthlySchedule(kind: .window, startDay: 5, endDay: 20)
        let reopened = CheckLineWorkspace(context: ModelContext(container), now: now, calendar: TestDates.calendar, draftStore: TaskDraftStore(root: root))
        reopened.beginTask(.budget, mode: "agent", now: now)
        reopened.reviewRetainedTask(now: now)
        let proposal = try #require(reopened.budgetProposal)
        #expect(proposal.name == "Window card" && reopened.taskDraft.name == "Window card")
        #expect(proposal.recurrence == .monthlyWindow(startDay: 5, endDay: 20))
        #expect(proposal.startDate == TestDates.calendar.startOfDay(for: TestDates.day(2026, 11, 5)))
        reopened.taskDraft.repeating = false; reopened.reviewRetainedTask(now: now)
        #expect(reopened.budgetProposal?.cycleType == .oneShot)
        reopened.taskDraft.repeating = true; reopened.reviewRetainedTask(now: now)
        #expect(reopened.budgetProposal?.recurrence == proposal.recurrence)
        let key = reopened.taskDraft.key
        reopened.confirmStructured(now: now)
        #expect(reopened.banner == .createdBudget)
        let stored = try LedgerStore.load(from: ModelContext(container), now: now)
        #expect(stored.budgets.values.first?.recurrence == proposal.recurrence)
        #expect(stored.periods.values.first?.startDate == proposal.startDate)
        #expect(try TaskDraftStore(root: root).load(key) == nil)
        #expect(reopened.ledger.walletEntries.isEmpty)
    }

    @Test("旧版本草稿缺少月度字段仍能读取", arguments: [1, 2])
    func legacyDraftsRemainReadable(version: Int) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CheckLineLegacyMonthly-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var draft = TaskDraft(kind: "budget"); draft.name = "Legacy"; draft.amount = "100"
        var fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any])
        fields.removeValue(forKey: "monthlySchedule")
        let data = try JSONSerialization.data(withJSONObject: ["version": version, "draft": fields])
        try data.write(to: root.appendingPathComponent(draft.key).appendingPathExtension("json"))
        let loaded = try TaskDraftStore(root: root).load(draft.key)
        let restored = try #require(loaded)
        #expect(restored.name == "Legacy" && restored.monthlySchedule == nil && restored.repeating)
    }

    @Test("表单切到核对及继续修改后，金额补充仍修改原预算任务")
    func amountReplyKeepsBudgetAndSchedule() async throws {
        let workspace = CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)), now: now,
                                           calendar: TestDates.calendar, draftStore: TaskDraftStore(inMemory: true))
        workspace.beginTask(.budget, mode: "form", now: now)
        workspace.taskDraft.name = "Window card"; workspace.taskDraft.amount = "100"; workspace.taskDraft.formTouched = true
        workspace.taskDraft.monthlySchedule = MonthlySchedule(kind: .window, startDay: 5, endDay: 20)
        let id = workspace.taskDraft.entityID
        workspace.reviewRetainedTask(now: now)
        workspace.leaveTaskReview()
        workspace.draftText = "改成75元"
        await workspace.submitText(now: now)
        #expect(workspace.taskDraft.kind == "budget" && workspace.taskDraft.entityID == id)
        #expect(workspace.budgetProposal?.name == "Window card" && workspace.budgetProposal?.amount == 75)
        #expect(workspace.budgetProposal?.recurrence == .monthlyWindow(startDay: 5, endDay: 20))
        #expect(workspace.ledger.budgets.isEmpty && workspace.ledger.expenses.isEmpty)
    }
}
