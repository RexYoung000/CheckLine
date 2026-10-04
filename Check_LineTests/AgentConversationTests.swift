import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor
struct AgentConversationTests {
    let now = TestDates.day(2026, 10, 4)

    private func workspace() throws -> CheckLineWorkspace {
        CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)), now: now, calendar: TestDates.calendar)
    }

    private func send(_ text: String, to workspace: CheckLineWorkspace) async {
        workspace.draftText = text
        await workspace.submitText(now: now)
    }

    @Test("泛化录入意向先问金额，补充消费后保留同一任务与原文")
    func recordClarifiesBeforeConfirming() async throws {
        let workspace = try workspace()
        await send("我想录一笔", to: workspace)
        let taskID = workspace.taskDraft.entityID
        #expect(!workspace.showsStructuredConfirm)
        #expect(workspace.taskDraft.pendingAgentField == "amount")
        #expect(workspace.taskDraft.merchant.isEmpty)
        #expect(workspace.draftText.isEmpty)
        #expect(workspace.ledger.expenses.isEmpty)

        await send("午餐 35 元", to: workspace)
        #expect(workspace.showsStructuredConfirm)
        #expect(workspace.taskDraft.entityID == taskID)
        #expect(workspace.captureProposal?.amount == 35)
        #expect(workspace.captureProposal?.merchant == "午餐")
        #expect(workspace.taskSourceText == "我想录一笔\n午餐 35 元")
        #expect(workspace.conversation.filter(\.isUser).map(\.text) == ["我想录一笔", "午餐 35 元"])
    }

    @Test("创建预算依次补名称金额周期，普通回答不会变成消费")
    func budgetAnswersStayInTheirTask() async throws {
        let workspace = try workspace()
        await send("创建预算卡", to: workspace)
        #expect(workspace.taskDraft.pendingAgentField == "name")
        await send("旅行", to: workspace)
        #expect(workspace.taskDraft.pendingAgentField == "amount")
        await send("1200 美元", to: workspace)
        #expect(workspace.taskDraft.pendingAgentField == "cycleType")
        await send("一次性", to: workspace)
        #expect(workspace.budgetProposal?.name == "旅行")
        #expect(workspace.budgetProposal?.amount == 1200)
        #expect(workspace.budgetProposal?.currencyCode == "USD")
        #expect(workspace.budgetProposal?.cycleType == .oneShot)
        workspace.confirmStructured(now: now)
        #expect(workspace.cards.first?.currencyCode == "USD")
        #expect(workspace.ledger.expenses.isEmpty)
        #expect(workspace.taskDraft.agentRequestText == nil)
        #expect(workspace.taskDraft.pendingAgentField == nil)
    }

    @Test("核对中补币种与金额仍使用同一消费，所见币种传入保存")
    func conversationalCorrectionsPreserveCurrency() async throws {
        let workspace = try workspace()
        await send("咖啡 35 元", to: workspace)
        let taskID = workspace.taskDraft.entityID
        await send("USD", to: workspace)
        await send("改成 40", to: workspace)
        #expect(workspace.taskDraft.entityID == taskID)
        #expect(workspace.captureProposal?.merchant == "咖啡")
        #expect(workspace.confirmAmountText == "40")
        #expect(workspace.confirmCurrencyCode == "USD")
        workspace.selectedAttributionID = "unbudgeted"
        workspace.confirmStructured(now: now)
        let saved = try #require(workspace.ledger.expenses.values.first)
        #expect(saved.originalCurrencyCode == "USD" && saved.originalAmount == 40)
        #expect(saved.merchant == "咖啡")
        #expect(workspace.ledger.expenses.count == 1)
        #expect(workspace.taskSourceText.isEmpty)
        #expect(workspace.taskDraft.mode == "agent")
        #expect(workspace.taskDraft.amount.isEmpty && workspace.taskDraft.merchant.isEmpty)
        #expect(workspace.lastUndo != nil)
    }

    @Test("创建追问可一次补齐多个字段，简短周期回答不覆盖名称")
    func combinedBudgetAnswerKeepsAllExplicitFields() async throws {
        let workspace = try workspace()
        await send("创建预算卡", to: workspace)
        await send("餐饮 1000 美元 每月", to: workspace)
        #expect(workspace.budgetProposal?.name == "餐饮")
        #expect(workspace.budgetProposal?.amount == 1000)
        #expect(workspace.budgetProposal?.currencyCode == "USD")
        await send("一次性就好", to: workspace)
        await send("改成 1200", to: workspace)
        #expect(workspace.budgetProposal?.name == "餐饮")
        #expect(workspace.budgetProposal?.cycleType == .oneShot)
        #expect(workspace.budgetProposal?.amount == 1200)
    }

    @Test("明确另记一笔不沿用上一笔金额或商家，跨创建任务同样隔离")
    func explicitTaskChangesDoNotReuseFields() async throws {
        let workspace = try workspace()
        await send("咖啡 35 元", to: workspace)
        let firstID = workspace.taskDraft.entityID
        await send("再记一笔午餐", to: workspace)
        #expect(workspace.taskDraft.entityID != firstID)
        #expect(workspace.taskDraft.amount.isEmpty)
        #expect(workspace.taskDraft.merchant == "午餐")
        #expect(!workspace.showsStructuredConfirm)
        await send("创建每月餐饮预算 1000 元", to: workspace)
        await send("我想录一笔", to: workspace)
        #expect(workspace.taskDraft.kind == "record")
        #expect(workspace.taskDraft.amount.isEmpty && workspace.taskDraft.merchant.isEmpty)
        #expect(workspace.taskDraft.pendingAgentField == "amount")
        #expect(workspace.ledger.expenses.isEmpty && workspace.ledger.budgets.isEmpty)
    }

    @Test("无关输入和拒答不能生成消费或覆盖正在补充的金额")
    func unknownAndRefusedRequestsNeverWrite() async throws {
        let workspace = try workspace()
        for text in ["你好", "今天 26 度", "明天几点开会", "推荐买 35 元的股票"] {
            await send(text, to: workspace)
            #expect(workspace.ledger.expenses.isEmpty)
            #expect(!workspace.showsStructuredConfirm)
            #expect(workspace.taskDraft.agentRequestText == nil)
        }
        await send("记一笔咖啡", to: workspace)
        await send("今天天气 26 度", to: workspace)
        #expect(workspace.taskDraft.amount.isEmpty)
        #expect(workspace.taskDraft.pendingAgentField == "amount")
        await send("35 元", to: workspace)
        #expect(workspace.captureProposal?.amount == 35)
        #expect(workspace.captureProposal?.merchant == "咖啡")
    }

    @Test("追问草稿跨重启续答，切换卡片不把上一卡字段带入")
    func clarificationRestoresAndRemainsScoped() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CheckLineConversation-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let first = CheckLineWorkspace(context: ModelContext(container), now: now, calendar: TestDates.calendar, draftStore: TaskDraftStore(root: root))
        first.createBudget(name: "A", amountText: "100", currencyCode: "USD", cycleType: .oneShot, now: now)
        let cardA = try #require(first.selectedCard)
        first.createBudget(name: "B", amountText: "200", currencyCode: "CNY", cycleType: .oneShot, now: now)
        let cardB = try #require(first.selectedCard)
        first.discussBudget(cardA.id)
        await send("记一笔咖啡", to: first)
        first.discussBudget(cardB.id)
        #expect(first.taskDraft.merchant.isEmpty && first.taskDraft.pendingAgentField == nil)
        first.discussBudget(cardA.id)
        #expect(first.taskDraft.pendingAgentField == "amount")
        #expect(first.taskDraft.merchant == "咖啡")

        let reopened = CheckLineWorkspace(context: ModelContext(container), now: now, calendar: TestDates.calendar, draftStore: TaskDraftStore(root: root))
        reopened.resumeAgentTask()
        #expect(reopened.conversation.isEmpty)
        #expect(reopened.taskDraft.pendingAgentField == "amount")
        await send("12", to: reopened)
        #expect(reopened.captureProposal?.merchant == "咖啡")
        #expect(reopened.captureProposal?.currencyCode == "USD")
        #expect(reopened.confirmAmountText == "12")
        #expect(reopened.taskDraft.contextBudgetID == cardA.id)
    }

    @Test("明确选卡的低风险记录继续直接保存并可撤销")
    func explicitLowRiskRecordRetainsUndo() async throws {
        let workspace = try workspace()
        workspace.createBudget(name: "餐饮", amountText: "100", currencyCode: "CNY", cycleType: .oneShot, now: now)
        let card = try #require(workspace.selectedCard)
        workspace.beginTask(.record, mode: "form", now: now, budgetID: card.id)
        workspace.taskDraft.formTouched = true
        workspace.taskDraft.explicitAttribution = true
        workspace.taskDraft.occurredAt = now.addingTimeInterval(-60)
        await send("咖啡 18 元", to: workspace)
        #expect(workspace.ledger.expenses.count == 1)
        #expect(!workspace.showsStructuredConfirm && workspace.lastUndo != nil)
        #expect(workspace.ledger.expenses.values.first?.occurredAt == now.addingTimeInterval(-60))
        workspace.undoLast(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("旧草稿不含新对话字段仍能读取，手动原文修改清除旧追问")
    func legacyDraftAndManualSourceEditing() throws {
        let oldDraft = TaskDraft(amount: "12", currency: "USD")
        let decoded = try JSONDecoder().decode(TaskDraft.self, from: JSONEncoder().encode(oldDraft))
        #expect(decoded.amount == "12" && decoded.agentRequestText == nil && decoded.pendingAgentField == nil)
        let workspace = try workspace()
        workspace.taskDraft.agentRequestText = "旧原文"
        workspace.taskDraft.pendingAgentField = "amount"
        workspace.taskSourceText = "手动修改后的原文"
        #expect(workspace.taskSourceText == "手动修改后的原文")
        #expect(workspace.taskDraft.agentRequestText == nil && workspace.taskDraft.pendingAgentField == nil)
    }

    @Test("首次用文字补充已有附件时保留附件和明确编辑的币种日期")
    func unsentUserFieldsSurviveFirstAgentMessage() async throws {
        let workspace = try workspace()
        workspace.beginTask(.record, mode: "agent", now: now)
        let attachment = TaskAttachment(data: Data([1, 2, 3]))
        workspace.taskDraft.attachments = [attachment]
        workspace.taskDraft.currency = "USD"
        workspace.taskDraft.occurredAt = now.addingTimeInterval(-60)
        await send("咖啡 12", to: workspace)
        #expect(workspace.taskDraft.attachments == [attachment])
        #expect(workspace.captureProposal?.currencyCode == "USD")
        #expect(workspace.captureProposal?.occurredAt == now.addingTimeInterval(-60))
    }

    @Test("重启后切手动不重解析旧原文覆盖已更正金额币种，未发短答只补对应字段")
    func manualHandoffDoesNotReplayOldSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CheckLineHandoff-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: now, draftStore: TaskDraftStore(root: root))
        await send("咖啡 35 USD", to: workspace)
        await send("CNY", to: workspace)
        await send("改成40", to: workspace)
        let reopened = CheckLineWorkspace(context: ModelContext(container), now: now, draftStore: TaskDraftStore(root: root))
        reopened.resumeAgentTask()
        #expect(reopened.lastTurn == nil)
        reopened.absorbUnsentAgentInputForManual()
        #expect(reopened.taskDraft.amount == "40" && reopened.taskDraft.currency == "CNY")
        #expect(reopened.taskDraft.merchant == "咖啡")
        reopened.draftText = "改成42"
        reopened.absorbUnsentAgentInputForManual()
        #expect(reopened.taskDraft.amount == "42" && reopened.taskDraft.currency == "CNY")
        #expect(reopened.taskDraft.merchant == "咖啡")
    }

    @Test("创建追问中未发的组合回答仍可带入手动表单")
    func unsentBudgetAnswerBridgesToManual() async throws {
        let workspace = try workspace()
        await send("创建预算卡", to: workspace)
        workspace.draftText = "餐饮 1000元 每月"
        workspace.absorbUnsentAgentInputForManual()
        #expect(workspace.taskDraft.name == "餐饮")
        #expect(workspace.taskDraft.amount == "1000")
        #expect(workspace.taskDraft.currency == "CNY" && workspace.taskDraft.repeating)
    }
}
