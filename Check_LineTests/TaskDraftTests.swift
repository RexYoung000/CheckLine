import Foundation
import SwiftData
import Testing
import UIKit
@testable import CheckLine

@MainActor
struct TaskDraftTests {
    let now = TestDates.day(2026, 10, 1)
    func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("CheckLineTaskTest-" + UUID().uuidString) }

    @Test("本机草稿重开保留全部字段并按卡片周期隔离，完成后清除")
    func reopenAndScope() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = TaskDraftStore(root: root)
        var first = TaskDraft(kind: "record", contextBudgetID: UUID(), contextPeriodID: UUID())
        first.amount = "12.34"; first.currency = "USD"; first.merchant = "Sample"; first.note = "note"; first.text = "raw"
        first.occurredAt = now; first.explicitAttribution = true
        first.attachments = [TaskAttachment(data: Data([1, 2, 3]))]
        try store.save(first)
        let metadata = try Data(contentsOf: root.appendingPathComponent(first.key).appendingPathExtension("json"))
        let envelope = try #require(JSONSerialization.jsonObject(with: metadata) as? [String: Any])
        #expect(envelope["version"] as? Int == 2)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(first.key).appendingPathComponent(first.attachments[0].id.uuidString).appendingPathExtension("jpg").path))
        let reopened = TaskDraftStore(root: root)
        #expect(try reopened.load(first.key) == first)
        var other = first; other.contextPeriodID = UUID(); other.amount = "20"
        try reopened.save(other)
        #expect(try reopened.load(first.key)?.amount == "12.34")
        #expect(try reopened.load(other.key)?.amount == "20")
        try reopened.remove(first.key)
        #expect(try reopened.load(first.key) == nil)
        #expect(try reopened.load(other.key) != nil)
    }

    @Test("损坏草稿不会误提交或覆盖，隔离存储不读取正式目录")
    func corruptAndIsolation() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let draft = TaskDraft()
        try Data("bad".utf8).write(to: root.appendingPathComponent(draft.key).appendingPathExtension("json"))
        #expect(throws: (any Error).self) { try TaskDraftStore(root: root).load(draft.key) }
        #expect(try TaskDraftStore(root: root, inMemory: true).load(draft.key) == nil)
    }

    @Test("解析默认值不覆盖日期备注附件，明确字段可更新")
    func explicitPatch() {
        var draft = TaskDraft(); draft.amount = "12"; draft.occurredAt = now; draft.note = "keep"; draft.currency = "USD"
        draft.attachments = [TaskAttachment(data: Data([1]))]
        let before = draft
        draft.apply(.capture(amount: "35", merchant: "coffee"))
        #expect(draft.amount == "35" && draft.merchant == "coffee")
        #expect(draft.currency == "USD" && draft.occurredAt == now && draft.note == "keep")
        #expect(draft.attachments == before.attachments)
    }

    @Test("记录与创建重试返回稳定实体，不重复写入")
    func stableCommands() throws {
        let coordinator = AgentActionCoordinator(calendar: TestDates.calendar)
        let blank = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let budgetID = UUID(), periodID = UUID(), expenseID = UUID()
        let creation = AgentIntent.createBudget(CreateBudgetDraft(name: "Sample", amount: 100, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: now, endDate: nil, budgetID: budgetID, periodID: periodID))
        let created = try coordinator.execute(intent: creation, ledger: blank, now: now, confirmation: .accepted)
        let retry = try coordinator.execute(intent: creation, ledger: created.ledger, now: now, confirmation: .accepted)
        #expect(retry.ledger == created.ledger && retry.savedEntityID == budgetID && retry.undo == nil)
        let capture = AgentIntent.capture(CaptureDraft(amount: 12, currencyCode: "CNY", occurredAt: now, periodID: periodID, expenseID: expenseID))
        let recorded = try coordinator.execute(intent: capture, ledger: retry.ledger, now: now, confirmation: .accepted)
        let repeated = try coordinator.execute(intent: capture, ledger: recorded.ledger, now: now, confirmation: .accepted)
        #expect(repeated.ledger.expenses.count == 1 && repeated.savedEntityID == expenseID)
        #expect(repeated.ledger == recorded.ledger)
    }

    @Test("明确币种保留；缺少换算不能绑定为零，但可保存未纳入")
    func explicitCurrency() throws {
        let workspace = CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)), now: now)
        workspace.createBudget(name: "Sample", amountText: "100", currencyCode: "CNY", cycleType: .oneShot, now: now)
        let choice = try #require(workspace.attributionChoices.first { $0.periodID != nil })
        let failed = workspace.recordExpense(amountText: "15", merchant: "Sample", note: "", attributionID: choice.id, occurredAt: now, now: now, currencyCode: "USD")
        #expect(failed == nil && workspace.banner == .needsConversion && workspace.ledger.expenses.isEmpty)
        let id = try #require(workspace.recordExpense(amountText: "15", merchant: "Sample", note: "", attributionID: "unbudgeted", occurredAt: now, now: now, currencyCode: "USD"))
        #expect(workspace.ledger.expenses[id]?.originalCurrencyCode == "USD")
        #expect(workspace.ledger.expenses[id]?.originalAmount == 15)
    }

    @Test("提交后中断重开能续传附件且不重复记录和图片")
    func committedResume() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let drafts = root.appendingPathComponent("drafts"), images = root.appendingPathComponent("images")
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: now, attachmentStore: ExpenseAttachmentStore(root: images), draftStore: TaskDraftStore(root: drafts))
        workspace.beginTask(.record, mode: "form", now: now)
        workspace.taskDraft.amount = "20"; workspace.taskDraft.merchant = "Sample"
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let data = renderer.pngData { UIColor.red.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 16, height: 16)) }
        try workspace.addTaskAttachment(data)
        let attachmentID = try #require(workspace.taskDraft.attachments.first?.id)
        let key = workspace.taskDraft.key
        let id = try #require(workspace.recordExpense(amountText: "20", merchant: "Sample", note: "", attributionID: "unbudgeted", occurredAt: now, keepComposerOpen: true, now: now, currencyCode: "CNY", expenseID: workspace.taskDraft.entityID))
        // Mimic a crash after the first image was written but before clearing the draft.
        try workspace.attachmentStore.add(imageData: data, to: id, id: attachmentID)
        let reopened = CheckLineWorkspace(context: ModelContext(container), now: now, attachmentStore: ExpenseAttachmentStore(root: images), draftStore: TaskDraftStore(root: drafts))
        reopened.beginTask(.record, mode: "form", now: now)
        #expect(reopened.taskDraft.committedEntityID == id)
        try reopened.completeTaskAttachments(id)
        #expect(reopened.ledger.expenses.count == 1)
        #expect(reopened.attachmentStore.attachments(for: id).count == 1)
        #expect(try TaskDraftStore(root: drafts).load(key) == nil)
    }

    @Test("恢复旧周期草稿后新消费入下周期队列，早于周期的日期拒绝")
    func datesAreRevalidated() throws {
        let workspace = CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)), now: now, calendar: TestDates.calendar)
        let previous = TestDates.day(2026, 9, 15)
        workspace.createBudget(name: "Sample", amountText: "100", currencyCode: "CNY", cycleType: .repeating, now: previous)
        let card = try #require(workspace.selectedCard)
        let id = try #require(workspace.recordExpense(amountText: "8", merchant: "Sample", note: "", attributionID: card.periodID.uuidString, occurredAt: now, now: now, currencyCode: "CNY"))
        #expect(workspace.ledger.expenses[id]?.budgetPeriodID == nil)
        #expect(workspace.ledger.expenses[id]?.queuedForBudgetID == card.id)
        #expect(workspace.selectedCard?.snapshot.confirmedSpent == 0)
        let invalid = workspace.recordExpense(amountText: "10", merchant: "Sample", note: "", attributionID: card.periodID.uuidString, occurredAt: TestDates.day(2026, 8, 30), now: now, currencyCode: "CNY")
        #expect(invalid == nil && workspace.banner == .needsPeriod)
        #expect(workspace.ledger.expenses.count == 1)
    }

    @Test("手动切 Agent 后仍使用明确币种归属日期与备注")
    func manualAgentContract() async throws {
        let workspace = CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)), now: now)
        workspace.createBudget(name: "Sample", amountText: "100", currencyCode: "CNY", cycleType: .oneShot, now: now)
        workspace.beginTask(.record, mode: "form", now: now)
        workspace.taskDraft.amount = "15"; workspace.taskDraft.currency = "USD"
        workspace.taskDraft.attributionID = "unbudgeted"; workspace.taskDraft.explicitAttribution = true
        workspace.taskDraft.formTouched = true; workspace.taskDraft.note = "keep"
        workspace.taskDraft.occurredAt = now.addingTimeInterval(3600)
        workspace.taskDraft.text = "咖啡 15"
        await workspace.submitText(now: now)
        #expect(workspace.captureProposal?.currencyCode == "USD")
        #expect(workspace.selectedAttributionID == "unbudgeted")
        workspace.confirmStructured(now: now)
        let expense = try #require(workspace.ledger.expenses.values.first)
        #expect(expense.originalAmount == 15 && expense.originalCurrencyCode == "USD")
        #expect(expense.budgetPeriodID == nil && expense.note == "keep")
        #expect(expense.occurredAt == now.addingTimeInterval(3600))
    }

    @Test("额度编辑跨 Workspace 恢复输入，成功清理草稿且不恢复旧预览")
    func amountEditDraftReopen() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: now, draftStore: TaskDraftStore(root: root))
        workspace.createBudget(name: "Sample", amountText: "100", currencyCode: "CNY", cycleType: .repeating, now: now)
        let card = try #require(workspace.selectedCard)
        workspace.retainBudgetAmountDraft("123.45", for: card)
        let reopened = CheckLineWorkspace(context: ModelContext(container), now: now, draftStore: TaskDraftStore(root: root))
        #expect(reopened.budgetAmountDraft(for: card) == "123.45")
        let preview = try reopened.previewBudgetAmount(budgetID: card.id, periodID: card.periodID, amountText: reopened.budgetAmountDraft(for: card))
        try reopened.saveBudgetAmount(preview, now: now)
        let key = TaskDraft(kind: "budgetAmount", contextBudgetID: card.id, contextPeriodID: card.periodID).key
        #expect(try TaskDraftStore(root: root).load(key) == nil)
        #expect(reopened.selectedCard?.snapshot.budgetAmount == DecimalMath.parse("123.45"))
    }

    @Test("切换卡片不会覆盖另一张卡的任务草稿")
    func workspaceDraftScopes() throws {
        let workspace = CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)), now: now)
        workspace.createBudget(name: "A", amountText: "100", currencyCode: "CNY", cycleType: .oneShot, now: now)
        let first = try #require(workspace.selectedCard)
        workspace.createBudget(name: "B", amountText: "200", currencyCode: "USD", cycleType: .oneShot, now: now)
        let second = try #require(workspace.selectedCard)
        workspace.beginTask(.record, mode: "form", now: now, budgetID: first.id)
        workspace.taskDraft.amount = "12"; workspace.taskDraft.note = "first"
        workspace.beginTask(.record, mode: "form", now: now, budgetID: second.id)
        #expect(workspace.taskDraft.amount.isEmpty && workspace.taskDraft.currency == "USD")
        workspace.taskDraft.amount = "30"
        workspace.beginTask(.record, mode: "agent", now: now, budgetID: first.id)
        #expect(workspace.taskDraft.amount == "12" && workspace.taskDraft.note == "first")
        #expect(workspace.taskDraft.contextPeriodID == first.periodID)
    }

    @Test("重启 Agent 恢复最后任务的卡片上下文，明确聊当前卡才切换")
    func agentContextReopen() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: now, draftStore: TaskDraftStore(root: root))
        workspace.createBudget(name: "A", amountText: "100", currencyCode: "CNY", cycleType: .repeating, now: now)
        let first = try #require(workspace.selectedCard)
        workspace.createBudget(name: "B", amountText: "200", currencyCode: "USD", cycleType: .oneShot, now: now)
        let second = try #require(workspace.selectedCard)
        workspace.beginTask(.record, mode: "form", now: now, budgetID: second.id)
        workspace.taskDraft.amount = "30"; workspace.taskDraft.text = "raw"
        workspace.retainBudgetAmountDraft("120", for: first)
        let reopened = CheckLineWorkspace(context: ModelContext(container), now: now, draftStore: TaskDraftStore(root: root))
        reopened.resumeAgentTask()
        #expect(reopened.taskDraft.contextBudgetID == second.id)
        #expect(reopened.taskDraft.amount == "30" && reopened.taskDraft.currency == "USD")
        reopened.discussBudget(first.id); reopened.resumeAgentTask()
        #expect(reopened.taskDraft.contextBudgetID == first.id && reopened.taskDraft.amount.isEmpty)
        #expect(reopened.taskDraft.attributionID == first.periodID.uuidString)
    }

    @Test("附件磁盘失败保留已提交身份，重试不新增消费；草稿磁盘失败不提交")
    func fileFailureAndRetry() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let images = root.appendingPathComponent("images")
        try Data([1]).write(to: images)
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: now, attachmentStore: ExpenseAttachmentStore(root: images))
        workspace.beginTask(.record, mode: "form", now: now)
        workspace.taskDraft.amount = "8"
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let data = renderer.pngData { UIColor.red.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 16, height: 16)) }
        try workspace.addTaskAttachment(data)
        let id = try #require(workspace.recordExpense(amountText: "8", merchant: "Sample", note: "", attributionID: "unbudgeted", occurredAt: now, keepComposerOpen: true, now: now, currencyCode: "CNY", expenseID: workspace.taskDraft.entityID))
        #expect(throws: (any Error).self) { try workspace.completeTaskAttachments(id) }
        #expect(workspace.taskDraft.committedEntityID == id && workspace.taskDraft.attachments.count == 1)
        try FileManager.default.removeItem(at: images)
        try workspace.completeTaskAttachments(id)
        #expect(workspace.ledger.expenses.count == 1 && workspace.attachmentStore.attachments(for: id).count == 1)
        let blocked = root.appendingPathComponent("blocked")
        try Data([1]).write(to: blocked)
        let other = CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)), now: now, draftStore: TaskDraftStore(root: blocked))
        other.taskDraft.amount = "12"
        #expect(other.draftStorageFailed)
        _ = other.recordExpense(amountText: "12", merchant: "Sample", note: "", attributionID: "unbudgeted", occurredAt: now, now: now)
        #expect(other.ledger.expenses.isEmpty)
    }

    @Test("草稿提交失败保留输入，历史投影始终使用指定周期")
    func failedCommitAndHistory() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: now, saveLedger: { _, _ in throw CocoaError(.fileWriteUnknown) })
        workspace.taskDraft.amount = "35"; workspace.taskDraft.currency = "USD"; workspace.taskDraft.note = "keep"
        _ = workspace.recordExpense(amountText: "35", merchant: "Sample", note: "keep", attributionID: "unbudgeted", occurredAt: now, now: now, currencyCode: "USD")
        #expect(workspace.ledger.expenses.isEmpty && workspace.taskDraft.amount == "35" && workspace.taskDraft.note == "keep")
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let card = try ledger.insertBudgetCard(name: "Sample", amount: 100, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: now, endDate: nil, now: now)
        var history = card.1; history.id = UUID(); history.state = .settled; history.budgetAmount = 50; history.sequence = 0
        ledger.upsert(history)
        #expect(HomeProjector.card(budgetID: card.0.id, periodID: history.id, in: ledger)?.snapshot.budgetAmount == 50)
        #expect(HomeProjector.card(budgetID: card.0.id, periodID: UUID(), in: ledger) == nil)
    }
}
