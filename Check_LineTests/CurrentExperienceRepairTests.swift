import Foundation
import SwiftData
import Testing
import UIKit
@testable import CheckLine

@MainActor
struct CurrentExperienceRepairTests {
    let now = TestDates.day(2026, 10, 12)
    private func workspace(store: TaskDraftStore? = nil) throws -> CheckLineWorkspace {
        CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)), now: now,
                           calendar: TestDates.calendar, draftStore: store)
    }
    private func image() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).pngData {
            UIColor.purple.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
    }

    @Test("未到期预估只读，正式结算仍被阻止，到期前后采用同一公式")
    func estimateDoesNotWeakenSettlementGate() throws {
        let workspace = try workspace()
        workspace.createBudget(name: "Sample", amountText: "100", currencyCode: "CNY", cycleType: .repeating, now: now)
        let card = try #require(workspace.cards.first)
        _ = workspace.recordExpense(amountText: "20", merchant: "Sample", note: "", attributionID: card.periodID.uuidString, occurredAt: now, now: now)
        _ = try workspace.ledger.record(amount: 5, currencyCode: "CNY", occurredAt: now, now: now,
                                        decision: .pending(periodID: card.periodID, confidence: DecimalMath.parse("0.4")))
        let before = workspace.ledger
        let estimate = try workspace.estimateSettlement(card.periodID, now: now)
        #expect(estimate.baseSurplus == 80 && estimate.pendingAmount == 5 && estimate.balanceAfter == 80)
        #expect(workspace.ledger == before && workspace.wallet.balance == 0)
        #expect(throws: (any Error).self) { try workspace.previewSettlement(card.periodID, now: now) }
        #expect(throws: (any Error).self) {
            try workspace.settlePeriod(card.periodID, quote: nil, reviewedLedger: before, acceptedIncompleteData: true, now: now)
        }
        #expect(workspace.ledger == before)
        let later = TestDates.day(2026, 11, 1)
        let ready = try CycleEngine.markDueIfNeeded(ledger: before, periodID: card.periodID, now: later, calendar: TestDates.calendar)
        let formal = try SettlementEngine.preview(ledger: ready, periodID: card.periodID, now: later, calendar: TestDates.calendar, quote: nil)
        #expect(formal.baseSurplus == estimate.baseSurplus && formal.walletSignedAmount == estimate.walletSignedAmount)
    }

    @Test("异币种预估缺汇率不当零，提供汇率后仍不写钱包")
    func estimateCurrencyCoverage() throws {
        let workspace = try workspace()
        workspace.ledger = try WalletLedger.setWalletCurrency(ledger: workspace.ledger, currencyCode: "CNY", now: now)
        workspace.createBudget(name: "Sample", amountText: "100", currencyCode: "USD", cycleType: .repeating, now: now)
        let period = try #require(workspace.cards.first?.periodID)
        #expect(throws: LedgerError.missingExchangeRate(source: "USD", target: "CNY")) {
            try workspace.estimateSettlement(period, now: now)
        }
        let estimate = try workspace.estimateSettlement(period, quote: .estimated(rate: DecimalMath.parse("7.2"), at: now, sourceName: "user_provided_estimate"), now: now)
        #expect(estimate.walletSignedAmount == 720 && workspace.ledger.walletEntries.isEmpty)
    }

    @Test("退出核对保留全部草稿，重新核对不解析旧原文、不自动入账")
    func leaveAndReviewPreservesInput() async throws {
        let workspace = try workspace()
        workspace.draftText = "咖啡 35 元"
        await workspace.submitText(now: now)
        workspace.taskDraft.amount = "40"; workspace.taskDraft.currency = "USD"
        workspace.taskDraft.note = "Keep"; workspace.taskDraft.occurredAt = now
        workspace.taskDraft.attributionID = "unbudgeted"; workspace.taskDraft.explicitAttribution = true
        try workspace.addTaskAttachment(image())
        let before = workspace.taskDraft
        let conversation = workspace.conversation
        workspace.leaveTaskReview()
        #expect(workspace.taskDraft == before && workspace.conversation == conversation)
        #expect(!workspace.showsStructuredConfirm && workspace.retainedTaskAvailable)
        workspace.reviewRetainedTask(now: now)
        #expect(workspace.ledger.expenses.isEmpty && workspace.showsStructuredConfirm)
        #expect(workspace.confirmAmountText == "40" && workspace.confirmCurrencyCode == "USD")
        workspace.confirmStructured(now: now)
        let saved = try #require(workspace.ledger.expenses[before.entityID])
        #expect(saved.originalAmount == 40 && saved.originalCurrencyCode == "USD" && saved.note == "Keep")
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.count == 1)
    }

    @Test("恢复已确认字段即使可直接执行，也必须再次核对；旧归属失效保留输入")
    func restoreHasNoAutomaticWrite() throws {
        let store = TaskDraftStore(inMemory: true)
        var draft = TaskDraft(); draft.amount = "12"; draft.merchant = "Sample"; draft.occurredAt = now
        draft.currency = "CNY"; draft.explicitAttribution = true; draft.formTouched = true
        try store.save(draft)
        let workspace = try workspace(store: store)
        workspace.resumeAgentTask()
        #expect(workspace.retainedTaskAvailable && workspace.conversation.isEmpty)
        workspace.reviewRetainedTask(now: now)
        #expect(workspace.showsStructuredConfirm && workspace.ledger.expenses.isEmpty)
        workspace.leaveTaskReview()
        workspace.taskDraft.attributionID = UUID().uuidString
        workspace.reviewRetainedTask(now: now)
        #expect(workspace.banner == .needsPeriod && workspace.ledger.expenses.isEmpty && workspace.taskDraft.amount == "12")
    }

    @Test("预算缺周期恢复继续追问，不把默认每月当成用户选择")
    func restoreBudgetNeedsExplicitCycle() throws {
        let store = TaskDraftStore(inMemory: true)
        var draft = TaskDraft(kind: "budget"); draft.name = "Sample"; draft.amount = "100"
        draft.agentRequestText = "创建预算卡 Sample 100 元"
        try store.save(draft)
        let workspace = try workspace(store: store)
        workspace.resumeAgentTask(); workspace.reviewRetainedTask(now: now)
        #expect(workspace.taskDraft.pendingAgentField == "cycleType" && workspace.ledger.budgets.isEmpty)
    }

    @Test("账本已保存但草稿提交标识丢失，重启按稳定 ID 识别且不再核对创建")
    func savedBeforeMarkerRestoresAsSaved() throws {
        let store = TaskDraftStore(inMemory: true)
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: now, draftStore: store)
        workspace.beginTask(.record, mode: "form", now: now)
        workspace.taskDraft.amount = "12"
        let old = workspace.taskDraft
        _ = workspace.recordExpense(amountText: "12", merchant: "Sample", note: "", attributionID: "unbudgeted", occurredAt: now,
                                    keepComposerOpen: true, now: now, expenseID: old.entityID)
        try store.save(old)
        let reopened = CheckLineWorkspace(context: ModelContext(container), now: now, draftStore: store)
        reopened.resumeAgentTask(); reopened.reviewRetainedTask(now: now)
        #expect(reopened.taskDraft.committedEntityID == old.entityID && !reopened.showsStructuredConfirm)
        #expect(reopened.ledger.expenses.count == 1)
    }

    @Test("慢照片读取回调不能写入已经更换的任务")
    func staleAttachmentCallbackCannotCrossTasks() async throws {
        let workspace = try workspace()
        workspace.beginTask(.record, mode: "form", now: now)
        let gate = RepairImageGate()
        let controller = TaskAttachmentImportController()
        controller.start([TaskAttachmentImportItem(id: UUID()) { await gate.read() }], workspace: workspace)
        for _ in 0..<100 where gate.continuation == nil { await Task.yield() }
        #expect(gate.continuation != nil && workspace.attachmentImportBlocksSubmission)
        workspace.beginTask(.budget, mode: "form", now: now)
        gate.continuation?.resume(returning: image()); gate.continuation = nil
        await controller.waitForCompletion()
        #expect(workspace.taskDraft.attachments.isEmpty && !workspace.attachmentImportBlocksSubmission)
    }

    @Test("图片部分失败只重试失败项，成功图片与稳定 ID 不重复")
    func partialImageFailureRetriesOnlyFailure() async throws {
        let workspace = try workspace()
        workspace.beginTask(.record, mode: "agent", now: now)
        let controller = TaskAttachmentImportController()
        let data = image(), firstID = UUID(), secondID = UUID()
        var attempts = 0
        controller.start([
            TaskAttachmentImportItem(id: firstID) { data },
            TaskAttachmentImportItem(id: secondID) {
                attempts += 1
                if attempts == 1 { throw ExpenseAttachmentError.unreadableImage }
                return data
            }
        ], workspace: workspace)
        await controller.waitForCompletion()
        #expect(controller.failedCount == 1 && workspace.taskDraft.attachments.count == 1)
        workspace.draftText = "Sample 12 元"; await workspace.submitText(now: now)
        #expect(workspace.conversation.isEmpty && workspace.ledger.expenses.isEmpty)
        controller.retry(workspace: workspace); await controller.waitForCompletion()
        #expect(attempts == 2 && Set(workspace.taskDraft.attachments.map(\.id)) == [firstID, secondID])
        #expect(!workspace.attachmentImportBlocksSubmission)
    }

    @Test("心愿草稿与 Agent 分离，兑现按心愿隔离，重开仅恢复输入")
    func wishDraftScopes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("WishScopeRepair-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TaskDraftStore(root: root), wishID = UUID(), anotherID = UUID()
        let create = LocalTaskDraftSession(store: store, kind: "wishCreate", currency: "CNY")
        create.draft.name = "Sample"; create.draft.currency = "USD"
        let redemption = LocalTaskDraftSession(store: store, kind: "wishRedemption", currency: "CNY", wishID: wishID)
        redemption.draft.amount = "15"; redemption.draft.exchangeRateText = "7.2"; redemption.draft.exchangeQuotedAt = now
        let reopened = LocalTaskDraftSession(store: TaskDraftStore(root: root), kind: "wishRedemption", currency: "CNY", wishID: wishID)
        #expect(reopened.draft.amount == "15" && reopened.draft.exchangeRateText == "7.2" && reopened.draft.contextWishID == wishID)
        #expect(LocalTaskDraftSession(store: store, kind: "wishRedemption", currency: "CNY", wishID: anotherID).draft.amount.isEmpty)
        #expect(LocalTaskDraftSession(store: store, kind: "wishCreate", currency: "CNY").draft.currency == "USD")
        #expect(try store.recentScope() == nil)
    }

    @Test("心愿保存成功后草稿未清理，重试稳定创建不生成重复心愿")
    func stableWishCreation() throws {
        let workspace = try workspace(), id = UUID()
        let first = try workspace.createWish(name: "Sample", amountText: "12", currencyCode: "USD", now: now, wishID: id)
        let retry = try workspace.createWish(name: "Sample", amountText: "12", currencyCode: "USD", now: now, wishID: id)
        #expect(first == retry && workspace.ledger.wishes.count == 1 && workspace.wallet.balance == 0)
    }
}

@MainActor private final class RepairImageGate {
    var continuation: CheckedContinuation<Data, Never>?
    func read() async -> Data { await withCheckedContinuation { continuation = $0 } }
}
