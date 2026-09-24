import Foundation
import ImageIO
import SwiftData
import Testing
import UIKit
@testable import CheckLine

@MainActor
struct M4InteractionTests {
    @Test("待确认记录改归属并持久化，确认后金额进入正确预算")
    func pendingResolutionPersists() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let first = try ledger.insertBudgetCard(name: "日常", amount: 500, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: now, endDate: nil, now: now)
        let second = try ledger.insertBudgetCard(name: "出行", amount: 700, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: now, endDate: nil, now: now)
        let pending = try ledger.record(amount: 42, currencyCode: "CNY", occurredAt: now, now: now, decision: .pending(periodID: first.1.id, confidence: 0.4))
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try LedgerStore.replaceAll(ledger, in: context)
        let workspace = CheckLineWorkspace(context: context, now: now)

        try workspace.changePendingExpense(pending.id, to: second.1.id, now: now)
        let reloaded = try LedgerStore.load(from: context, now: now)
        #expect(reloaded.expenses[pending.id]?.budgetPeriodID == second.1.id)
        #expect(reloaded.expenses[pending.id]?.attributionState == .confirmed)
        #expect(HomeProjector.cards(in: reloaded).first { $0.id == first.0.id }?.snapshot.confirmedSpent == 0)
        #expect(HomeProjector.cards(in: reloaded).first { $0.id == second.0.id }?.snapshot.confirmedSpent == 42)
    }

    @Test("消费图片独立保存、重开可读、超过五张拒绝且可删除")
    func attachmentStorePersistsAndLimits() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let expenseID = UUID()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let data = renderer.pngData { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 32)) }
        let original = CGImageSourceCreateWithData(data as CFData, nil)!
        let tagged = NSMutableData()
        let writer = CGImageDestinationCreateWithData(tagged as CFMutableData, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImageFromSource(writer, original, 0, [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 22.5, kCGImagePropertyGPSLongitude: 113.9]] as CFDictionary)
        #expect(CGImageDestinationFinalize(writer))
        let inputData = tagged as Data
        let inputProperties = CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithData(inputData as CFData, nil)!, 0, nil) as? [CFString: Any]
        #expect(inputProperties?[kCGImagePropertyGPSDictionary] != nil)
        let store = ExpenseAttachmentStore(root: root)
        for _ in 0..<5 { try store.add(imageData: inputData, to: expenseID) }
        #expect(store.attachments(for: expenseID).count == 5)
        #expect(throws: ExpenseAttachmentError.limitReached) { try store.add(imageData: inputData, to: expenseID) }
        let reopened = ExpenseAttachmentStore(root: root)
        let saved = reopened.attachments(for: expenseID)
        #expect(saved.count == 5)
        let imageData = try Data(contentsOf: saved[0].url)
        #expect(UIImage(data: imageData) != nil)
        let source = CGImageSourceCreateWithData(imageData as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        #expect(properties?[kCGImagePropertyGPSDictionary] == nil)
        #expect((properties?[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifDateTimeOriginal] == nil)
        try reopened.remove(saved[0].id, from: expenseID)
        #expect(reopened.attachments(for: expenseID).count == 4)
        #expect(throws: ExpenseAttachmentError.unreadableImage) { try reopened.add(imageData: Data("bad".utf8), to: expenseID) }
        try reopened.removeOrphans(keeping: [])
        #expect(reopened.attachments(for: expenseID).isEmpty)
    }

    @Test("长备注完整保留，超一万字不写入")
    func longNoteDoesNotTruncate() throws {
        let now = TestDates.day(2026, 1, 5)
        let context = ModelContext(try CheckLinePersistence.makeContainer(inMemory: true))
        let workspace = CheckLineWorkspace(context: context, now: now)
        let note = String(repeating: "内容", count: 100)
        let id = workspace.recordExpense(amountText: "12", merchant: "", note: note, attributionID: "unbudgeted", occurredAt: now, now: now)
        #expect(id != nil)
        #expect(workspace.ledger.expenses[id!]?.note == note)
        let rejected = workspace.recordExpense(amountText: "13", merchant: "", note: String(repeating: "字", count: 10_001), attributionID: "unbudgeted", occurredAt: now, now: now)
        #expect(rejected == nil)
        #expect(workspace.ledger.expenses.count == 1)
    }

    @Test("已结算周期的待确认记录必须先预览钱包影响再确认")
    func settledPendingRequiresImpact() throws {
        let now = TestDates.day(2026, 1, 5)
        let settlementDate = TestDates.day(2026, 2, 1)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(name: "日常", amount: 1_000, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: now, endDate: TestDates.day(2026, 1, 31), now: now)
        let pending = try ledger.record(amount: 30, currencyCode: "CNY", occurredAt: now, now: now, decision: .pending(periodID: created.1.id, confidence: 0.4))
        ledger = try CycleEngine.markDueIfNeeded(ledger: ledger, periodID: created.1.id, now: settlementDate, calendar: TestDates.calendar)
        ledger = try SettlementEngine.commit(ledger: ledger, periodID: created.1.id, now: settlementDate, calendar: TestDates.calendar, quote: nil, acceptedIncompleteData: true)
        let context = ModelContext(try CheckLinePersistence.makeContainer(inMemory: true))
        try LedgerStore.replaceAll(ledger, in: context)
        let workspace = CheckLineWorkspace(context: context, now: settlementDate)

        #expect(throws: LedgerError.cannotBindSettledPeriod) { try workspace.confirmPendingExpense(pending.id, now: settlementDate) }
        #expect(workspace.ledger.expenses[pending.id]?.attributionState == .pending)
        let preview = try workspace.previewPendingRetrospective(pending.id, now: settlementDate)
        #expect(preview.amountDelta == 30)
        #expect(preview.balanceAfter == 970)
        try workspace.confirmPendingRetrospective(preview, now: settlementDate)
        #expect(workspace.ledger.expenses[pending.id]?.attributionState == .confirmed)
        #expect(workspace.ledger.expenses[pending.id]?.attributionConfidence == 1)
        #expect(WalletLedger.projection(ledger: workspace.ledger).balance == 970)
        #expect(throws: LedgerError.staleRetrospectivePreview) {
            try workspace.confirmPendingRetrospective(preview, now: settlementDate)
        }
    }
}
