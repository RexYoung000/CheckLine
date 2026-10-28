import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor
struct AgentSafetyRegressionTests {
    private let now = TestDates.day(2026, 10, 28)

    private func workspace() throws -> CheckLineWorkspace {
        CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)),
                           now: now, calendar: TestDates.calendar)
    }

    private func explicitRecordWorkspace() throws -> CheckLineWorkspace {
        let workspace = try workspace()
        workspace.createBudget(name: "餐饮", amountText: "1000", currencyCode: "CNY", cycleType: .oneShot, now: now)
        let budgetID = try #require(workspace.selectedCard?.id)
        workspace.beginTask(.record, mode: "form", now: now, budgetID: budgetID)
        // The same explicit form scope retained by CreateComposerSheet.switchMode().
        workspace.taskDraft.formTouched = true
        workspace.taskDraft.explicitAttribution = true
        workspace.taskDraft.mode = "agent"
        return workspace
    }

    private func send(_ text: String, to workspace: CheckLineWorkspace) async {
        workspace.draftText = text
        await workspace.submitText(now: now)
    }

    @Test("否定、计划、报价、退款不能借明确预算直接写成支出", arguments: [
        "没有花35元", "并没有消费35元", "没买，预计35元", "不是消费35元", "不要记一笔午餐35元",
        "计划午餐35元", "打算花35元", "预算35元", "咖啡报价35元", "咖啡价格35元",
        "午餐退款35元", "退回35元", "I did not spend 35 USD", "I haven't paid 35 USD",
        "Lunch might cost 35 USD", "The quoted price is 35 USD", "refund 35 USD", "Did I spend 35 USD?"
    ])
    func nonExpenseCannotExecuteWithinExplicitBudget(_ text: String) async throws {
        let workspace = try explicitRecordWorkspace()
        let before = workspace.ledger
        let identity = workspace.taskIdentity
        await send(text, to: workspace)
        #expect(workspace.ledger == before)
        #expect(workspace.taskIdentity == identity)
        #expect(workspace.draftText == text)
        #expect(!workspace.showsStructuredConfirm)
        #expect(workspace.agentBanner == .needsClarification("input"))
        #expect(LocalRegexFallback.candidate(from: text).intentType == "needsClarification")
    }

    @Test("非消费回答使旧确认失效，保留同一任务的已知字段与附件")
    func nonExpenseReplyPreservesDraftAndInvalidatesPreviousReview() async throws {
        let workspace = try workspace()
        await send("午餐35元", to: workspace)
        #expect(workspace.showsStructuredConfirm)
        workspace.taskDraft.note = "用户已有备注"
        workspace.taskDraft.attachments = [TaskAttachment(data: Data([1, 2, 3]))]
        var expected = workspace.taskDraft
        expected.text = "咖啡退款99元"
        await send(expected.text, to: workspace)
        #expect(workspace.taskDraft == expected)
        #expect(!workspace.canConfirmProposal)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
        workspace.absorbUnsentAgentInputForManual()
        #expect(workspace.taskDraft == expected)
        await send("40元", to: workspace)
        #expect(workspace.taskDraft.entityID == expected.entityID)
        #expect(workspace.captureProposal?.amount == 40)
        #expect(workspace.captureProposal?.merchant == "午餐")
        #expect(workspace.taskDraft.attachments == expected.attachments)
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("明确肯定的低风险消费仍直接保存并可撤销", arguments: ["咖啡35元", "买了午餐35元", "paid 35 CNY for coffee"])
    func affirmativeLowRiskCaptureStillExecutes(_ text: String) async throws {
        let workspace = try explicitRecordWorkspace()
        await send(text, to: workspace)
        #expect(workspace.ledger.expenses.count == 1)
        #expect(workspace.ledger.expenses.values.first?.originalAmount == 35)
        #expect(workspace.agentBanner == .recorded)
        #expect(workspace.lastUndo != nil)
    }

    @Test("想记录和准备记录表达仍按明确消费处理，不误当购买计划")
    func requestToRecordIsNotAPurchasePlan() async throws {
        for (text, amountText) in [("我想记一笔午餐35元", "35"), ("想记录咖啡18元", "18"),
                                   ("准备记录咖啡18元", "18"), ("我想记录已经花了35元的午餐", "35"),
                                   ("I want to record lunch 35 CNY", "35")] {
            let workspace = try explicitRecordWorkspace()
            #expect(!LocalRegexFallback.requiresConsumptionClarification(text))
            await send(text, to: workspace)
            #expect(workspace.ledger.expenses.count == 1)
            #expect(workspace.ledger.expenses.values.first?.originalAmount == MoneyFormat.parseAmount(amountText))
            #expect(workspace.agentBanner == .recorded)
        }
    }

    @Test("当前消费的金额补充继续合并并执行")
    func amountAnswerStillCompletesCurrentTask() async throws {
        let workspace = try explicitRecordWorkspace()
        await send("记一笔午餐", to: workspace)
        let identity = workspace.taskIdentity
        #expect(workspace.taskDraft.pendingAgentField == "amount")
        await send("35元", to: workspace)
        #expect(workspace.ledger.expenses.count == 1)
        let expense = try #require(workspace.ledger.expenses[identity.entityID])
        #expect(expense.originalAmount == 35)
        #expect(expense.merchant == "午餐")
    }

    @Test("预算目标的计划表达仍走原有创建核对，不成为消费")
    func plannedBudgetCreationRemainsAvailable() async throws {
        let workspace = try workspace()
        await send("创建每月餐饮计划预算1000元", to: workspace)
        #expect(workspace.budgetProposal?.amount == 1000)
        #expect(workspace.budgetProposal?.name == "餐饮计划")
        #expect(workspace.showsStructuredConfirm)
        #expect(workspace.ledger.expenses.isEmpty)
    }
}
