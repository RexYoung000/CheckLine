import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor
struct WalletInteractionTests {
    private let now = TestDates.day(2026, 9, 22)

    @Test("旧记录撤销不会抹掉之后创建的心愿或置顶顺序")
    func undoExpiresAfterAnotherWrite() throws {
        let (workspace, context) = try makeWorkspace()
        record(in: workspace)
        #expect(workspace.lastUndo != nil)
        try workspace.createWish(name: "耳机", amountText: "699", symbolName: "headphones", now: now)
        #expect(workspace.lastUndo == nil)
        let afterWish = workspace.ledger
        let storedAfterWish = try LedgerStore.load(from: context, now: now)
        workspace.undoLast(now: now)
        #expect(workspace.ledger == afterWish)
        #expect(try LedgerStore.load(from: context, now: now) == storedAfterWish)

        workspace.createBudget(name: "旅行", amountText: "1000", currencyCode: "CNY", cycleType: .oneShot, now: now)
        let trip = try #require(workspace.selectedCard)
        record(in: workspace, merchant: "车票")
        workspace.pinBudget(trip.id)
        #expect(workspace.lastUndo == nil)
        workspace.undoLast(now: now)
        #expect(workspace.cards.first?.id == trip.id)
        #expect(workspace.ledger.wishes.count == 1)
        #expect(workspace.ledger.expenses.count == 2)
    }

    @Test("查询和打开表单不覆盖撤销说明或上次 Agent 回复")
    func independentFeedback() async throws {
        let (workspace, _) = try makeWorkspace()
        record(in: workspace)
        workspace.draftText = "还能花多少"
        await workspace.submitText(now: now)
        let reply = workspace.agentBanner
        #expect(reply == .queryRemaining(amount: 965, currencyCode: "CNY"))
        #expect(workspace.undoBanner == .recorded)
        #expect(workspace.lastUndo != nil)
        workspace.openComposer(.record)
        #expect(workspace.banner == nil)
        #expect(workspace.agentBanner == reply)
        workspace.undoLast(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("撤销保存失败时保留账本和入口，重试成功后才报告完成")
    func failedUndoIsAtomic() throws {
        enum SaveFailure: Error { case simulated }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        var shouldFail = false
        let workspace = CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar, saveLedger: { ledger, context in
            if shouldFail { throw SaveFailure.simulated }
            try LedgerStore.replaceAll(ledger, in: context)
        })
        workspace.createBudget(name: "日常", amountText: "1000", currencyCode: "CNY", cycleType: .oneShot, now: now)
        record(in: workspace)
        let before = workspace.ledger
        let storedBefore = try LedgerStore.load(from: context, now: now)
        shouldFail = true
        workspace.undoLast(now: now)
        #expect(workspace.banner == .failed)
        #expect(workspace.actionFeedback == .failed)
        #expect(workspace.lastUndo != nil)
        #expect(workspace.ledger == before)
        #expect(try LedgerStore.load(from: context, now: now) == storedBefore)
        shouldFail = false
        workspace.undoLast(now: now)
        #expect(workspace.banner == .undone)
        #expect(workspace.ledger.expenses.isEmpty)
        #expect(try LedgerStore.load(from: context, now: now).expenses.isEmpty)
    }

    @Test("Agent 已识别金额但缺币种时，确认按可见的修改值保存")
    func confirmationUsesVisibleValues() async throws {
        let (workspace, context) = try makeWorkspace()
        workspace.draftText = "午餐 35"
        await workspace.submitText(now: now)
        #expect(workspace.captureProposal?.amount == 35)
        #expect(workspace.confirmAmountText == "35")
        #expect(workspace.confirmCurrencyCode == "CNY")
        #expect(workspace.canConfirmProposal)
        workspace.confirmAmountText = "36.75"
        workspace.confirmStructured(now: now)
        #expect(workspace.banner == .recorded)
        let record = try #require(workspace.ledger.expenses.values.first)
        #expect(record.originalAmount == DecimalMath.parse("36.75"))
        #expect(record.originalCurrencyCode == "CNY")
        #expect(record.budgetPeriodID == workspace.selectedCard?.periodID)
        #expect(try LedgerStore.load(from: context, now: now).expenses[record.id] == record)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.count == 1)
    }

    @Test("缺金额不沿用上一轮数字，取消草稿不写账本")
    func missingAmountAndCancellation() async throws {
        let (workspace, _) = try makeWorkspace()
        workspace.draftText = "午餐 35"
        await workspace.submitText(now: now)
        workspace.draftText = "咖啡"
        await workspace.submitText(now: now)
        #expect(workspace.confirmAmountText.isEmpty)
        #expect(!workspace.canConfirmProposal)
        workspace.confirmAmountText = "22"
        #expect(workspace.canConfirmProposal)
        workspace.cancelAgentProposal()
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
        #expect(workspace.draftText == "咖啡")
        #expect(!workspace.showsStructuredConfirm)
        workspace.lastTurn = AgentTurn(understand: .needsClarification(field: "amount", options: []), evaluation: nil, isOfflineMode: true)
        #expect(!workspace.showsStructuredConfirm)
    }

    @Test("新建选中新卡，Agent 保持原话题，显式切换才清除旧回复")
    func selectionAndDiscussionStaySeparate() async throws {
        let (workspace, _) = try makeWorkspace()
        let daily = try #require(workspace.selectedCard)
        workspace.draftText = "还能花多少"
        await workspace.submitText(now: now)
        workspace.createBudget(name: "旅行", amountText: "200", currencyCode: "USD", cycleType: .oneShot, now: now)
        let trip = try #require(workspace.selectedCard)
        #expect(trip.name == "旅行")
        #expect(workspace.agentBudgetID == daily.id)
        #expect(workspace.agentBanner == .queryRemaining(amount: 1000, currencyCode: "CNY"))
        workspace.discussBudget(trip.id)
        #expect(workspace.agentBanner == nil)
        workspace.draftText = "还能花多少"
        await workspace.submitText(now: now)
        #expect(workspace.agentBanner == .queryRemaining(amount: 200, currencyCode: "USD"))
    }

    private func makeWorkspace() throws -> (CheckLineWorkspace, ModelContext) {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar)
        workspace.createBudget(name: "日常", amountText: "1000", currencyCode: "CNY", cycleType: .oneShot, now: now)
        return (workspace, context)
    }

    private func record(in workspace: CheckLineWorkspace, merchant: String = "午餐") {
        let choice = workspace.attributionChoices.first { $0.periodID == workspace.selectedCard?.periodID }
        workspace.recordExpense(amountText: "35", merchant: merchant, note: "", attributionID: choice?.id ?? "unbudgeted", occurredAt: now, now: now)
    }
}

struct LiquidMotionClockTests {
    @Test("暂停后长时间经过仍停在原相位，恢复无跳动")
    func pauseResume() {
        var clock = LiquidMotionClock()
        clock.setRunning(true, at: 10)
        let before = clock.phase(at: 12)
        clock.setRunning(false, at: 12)
        #expect(clock.phase(at: 100) == before)
        clock.setRunning(true, at: 100)
        #expect(clock.phase(at: 100) == before)
        #expect(clock.phase(at: 101) != before)
    }

    @Test("连续周期接缝一致，重复恢复不会重置时钟")
    func repeatWithoutRestart() {
        var clock = LiquidMotionClock()
        clock.setRunning(true, at: 0)
        clock.setRunning(true, at: 2)
        let first = clock.phase(at: 3)
        let repeated = clock.phase(at: 3 + 10 * LiquidMotionClock.period)
        #expect(abs(first - repeated) < 0.000001)
        #expect(abs(first - 3 / LiquidMotionClock.period * .pi * 2) < 0.000001)
    }
}
