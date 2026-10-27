import Foundation
import SwiftData
import Testing
import UIKit
@testable import CheckLine

@MainActor struct PhoneFeedbackRepairTests {
    let now = TestDates.day(2026, 10, 23)
    private func workspace(save: (@MainActor (Ledger, ModelContext) throws -> Void)? = nil) throws -> CheckLineWorkspace {
        CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)), now: now,
                           calendar: TestDates.calendar, saveLedger: save)
    }
    private func seed(_ workspace: CheckLineWorkspace) throws -> UUID {
        workspace.createBudget(name: "Sample", amountText: "100", currencyCode: "CNY", cycleType: .repeating, now: now)
        let period = try #require(workspace.cards.first?.periodID)
        workspace.recordExpense(amountText: "35", merchant: "Sample", note: "note", attributionID: period.uuidString, occurredAt: now, now: now)
        return try #require(workspace.ledger.expenses.keys.first)
    }

    @Test("关闭录入明确恢复导航状态，并保留当前字段、对话和账本")
    func closeTaskPanelKeepsInputAndLedger() throws {
        let workspace = try workspace()
        _ = try seed(workspace)
        workspace.openComposer(.record)
        workspace.taskDraft.amount = "18"
        workspace.taskDraft.merchant = "Sample"
        workspace.showAgent = true
        let draft = workspace.taskDraft, ledger = workspace.ledger, conversation = workspace.conversation
        workspace.closeTaskPanel()
        #expect(!workspace.showComposer && !workspace.showAgent)
        #expect(workspace.taskDraft == draft && workspace.ledger == ledger)
        #expect(workspace.conversation.map(\.id) == conversation.map(\.id))
        workspace.openComposer(.record)
        #expect(workspace.showComposer && workspace.taskDraft.amount == "18")
    }

    @Test("手动删除核对只读，确认后更新预算并清附件，保留另一个Agent草稿")
    func manualDeleteIsIsolatedAndPersistent() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: ModelContext(container), now: now, calendar: TestDates.calendar)
        let id = try seed(workspace)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).pngData { UIColor.purple.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
        try workspace.attachmentStore.add(imageData: image, to: id)
        workspace.beginTask(.record, mode: "agent", now: now)
        workspace.taskDraft.text = "another task"; workspace.taskDraft.amount = "18"
        let draft = workspace.taskDraft, reviewed = workspace.ledger
        let evaluation = try #require(workspace.expenseDeletionPreview(id, in: reviewed, now: now))
        if case .deleteExpense(let snapshot) = evaluation.impact { #expect(snapshot?.remaining == 100) }
        else { Issue.record("Expected deletion preview") }
        #expect(workspace.ledger == reviewed && workspace.attachmentStore.attachments(for: id).count == 1)
        try workspace.confirmExpenseDeletion(id, reviewed: reviewed, now: now)
        #expect(workspace.ledger.expenses[id] == nil && workspace.cards.first?.snapshot.confirmedSpent == 0)
        #expect(workspace.wallet.balance == 0 && workspace.attachmentStore.attachments(for: id).isEmpty)
        #expect(workspace.taskDraft == draft)
        #expect(try LedgerStore.load(from: ModelContext(container), now: now).expenses[id] == nil)
        #expect(throws: WorkspaceInputError.staleExpenseDeletion) { try workspace.confirmExpenseDeletion(id, reviewed: reviewed, now: now) }
    }

    @Test("删除保存失败保留记录与附件，可用同一核对重试；账本改变则拒绝旧确认")
    func deleteFailureAndStaleReview() throws {
        var fail = false
        let workspace = try workspace { ledger, context in
            if fail { throw PhoneSaveFailure.failed }
            try LedgerStore.replaceAll(ledger, in: context)
        }
        let id = try seed(workspace), reviewed = workspace.ledger
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).pngData { UIColor.purple.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
        try workspace.attachmentStore.add(imageData: image, to: id)
        fail = true
        #expect(throws: PhoneSaveFailure.failed) { try workspace.confirmExpenseDeletion(id, reviewed: reviewed, now: now) }
        #expect(workspace.ledger == reviewed && workspace.attachmentStore.attachments(for: id).count == 1)
        fail = false
        _ = try workspace.createWish(name: "other", amountText: "", now: now)
        #expect(throws: WorkspaceInputError.staleExpenseDeletion) { try workspace.confirmExpenseDeletion(id, reviewed: reviewed, now: now) }
        let fresh = workspace.ledger
        try workspace.confirmExpenseDeletion(id, reviewed: fresh, now: now)
        #expect(workspace.ledger.expenses[id] == nil && workspace.attachmentStore.attachments(for: id).isEmpty)
    }

    @Test("已结算、心愿购买及存在退款的消费均不能直接删除")
    func deleteDoesNotBypassBoundaries() throws {
        let workspace = try workspace(), id = try seed(workspace), ordinary = workspace.ledger
        let period = try #require(ordinary.expenses[id]?.budgetPeriodID)
        workspace.ledger.periods[period]?.state = .settled
        #expect(workspace.expenseDeletionPreview(id, in: workspace.ledger, now: now) == nil)
        #expect(throws: WorkspaceInputError.expenseDeletionUnavailable) { try workspace.confirmExpenseDeletion(id, reviewed: workspace.ledger, now: now) }
        workspace.ledger = ordinary; workspace.ledger.expenses[id]?.wishRedemptionID = UUID()
        #expect(workspace.expenseDeletionPreview(id, in: workspace.ledger, now: now) == nil)
        workspace.ledger = ordinary
        var refund = try #require(ordinary.expenses[id]); refund.id = UUID(); refund.kind = .refund; refund.reversesExpenseID = id
        workspace.ledger.upsert(refund)
        #expect(workspace.expenseDeletionPreview(id, in: workspace.ledger, now: now) == nil)
        #expect(workspace.expenseDeletionPreview(refund.id, in: workspace.ledger, now: now) == nil)
    }

    @Test("常驻气泡在实际液体体积内持续循环，竖卡与横窗均不依赖插入喷涌")
    func ambientBubblesStayInLiquid() {
        let size = CGSize(width: 350, height: 258)
        for level: CGFloat in [0.15, 0.43, 1] {
            for morph: CGFloat in [0, 1] {
                for time in [0.0, 9, 35, 900000000] {
                    let particles = LiquidBubbleField.ambient(size: size, level: level, morph: morph, time: time, seed: 41)
                    #expect(particles.count == 28 && particles.filter { $0.opacity > 0.15 }.count > 10)
                    for particle in particles {
                        #expect(particle.center.x >= 0 && particle.center.x <= size.width)
                        #expect(particle.center.y >= 0 && particle.center.y <= size.height)
                        if morph == 0 { #expect(particle.center.y >= size.height * (1 - level)) }
                        else { #expect(particle.center.x <= size.width * level) }
                    }
                }
            }
        }
        let a = LiquidBubbleField.ambient(size: size, level: 0.4, morph: 0, time: 8, seed: 41)
        let b = LiquidBubbleField.ambient(size: size, level: 0.4, morph: 0, time: 11, seed: 41)
        #expect(a.map(\.center) != b.map(\.center))
    }
}
private enum PhoneSaveFailure: Error { case failed }
