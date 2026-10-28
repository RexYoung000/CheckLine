import Foundation
import Testing
@testable import CheckLine

struct AgentDeduplicationRegressionTests {
    private let now = TestDates.day(2026, 10, 28)

    @Test("独立主动任务同金额同商家仍保存两笔并分别计入预算", arguments:
        [SourceType.manual, .agentText, .voice, .image],
        [SourceType.manual, .agentText, .voice, .image])
    func independentActiveTasks(firstSource: SourceType, secondSource: SourceType) throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let (_, period) = try ledger.insertBudgetCard(
            name: "Sample", amount: 100, currencyCode: "CNY", cycleType: .oneShot,
            recurrence: nil, startDate: now, endDate: nil, now: now
        )
        let coordinator = AgentActionCoordinator(calendar: TestDates.calendar)
        let firstID = UUID(), secondID = UUID()
        let first = CaptureDraft(
            amount: 35, currencyCode: "CNY", occurredAt: now, merchant: "Sample Cafe",
            periodID: period.id, sourceType: firstSource, expenseID: firstID
        )
        let savedFirst = try coordinator.execute(
            intent: .capture(first), ledger: ledger, now: now, confirmation: .accepted
        )
        let later = now.addingTimeInterval(3_600)
        let second = CaptureDraft(
            amount: 35, currencyCode: "CNY", occurredAt: later, merchant: "Sample Cafe",
            periodID: period.id, sourceType: secondSource, expenseID: secondID
        )
        #expect(coordinator.evaluate(intent: .capture(second), ledger: savedFirst.ledger, now: later).gate == .executeDirectly)
        let savedSecond = try coordinator.execute(
            intent: .capture(second), ledger: savedFirst.ledger, now: later, confirmation: .accepted
        )
        ledger = savedSecond.ledger
        #expect(savedFirst.savedEntityID == firstID)
        #expect(savedSecond.savedEntityID == secondID)
        #expect(ledger.expenses.count == 2 && ledger.evidences.count == 2)
        #expect(ledger.expenses[firstID]?.budgetPeriodID == period.id)
        #expect(ledger.expenses[secondID]?.budgetPeriodID == period.id)
        #expect(BudgetEngine.periodSnapshot(period: period, expenses: Array(ledger.expenses.values)).confirmedSpent == 70)
    }

    @Test("同一主动任务实体重试只保存一次且不增加来源", arguments: [SourceType.manual, .agentText, .voice, .image])
    func stableEntityRetry(source: SourceType) throws {
        let coordinator = AgentActionCoordinator(calendar: TestDates.calendar)
        let id = UUID()
        let draft = CaptureDraft(
            amount: 35, currencyCode: "CNY", occurredAt: now, merchant: "Sample Cafe",
            sourceType: source, expenseID: id
        )
        let saved = try coordinator.execute(
            intent: .capture(draft), ledger: .blank(walletCurrencyCode: "CNY", now: now),
            now: now, confirmation: .accepted
        )
        let retry = try coordinator.execute(
            intent: .capture(draft), ledger: saved.ledger, now: now.addingTimeInterval(3 * 86_400), confirmation: .none
        )
        #expect(retry.ledger == saved.ledger && retry.savedEntityID == id && retry.undo == nil)
        #expect(retry.ledger.expenses.count == 1 && retry.ledger.evidences.count == 1)
    }

    @Test("相同外部交易身份的同源重放及跨源证据仍合并", arguments: [false, true])
    func stableExternalIdentity(crossSource: Bool) {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let expense = addExpense(to: &ledger, source: .applePay, hash: "transaction-1")
        let candidate = transaction(
            source: crossSource ? .sms : .applePay, hash: "transaction-1",
            occurredAt: now.addingTimeInterval(3 * 86_400)
        )
        #expect(DeduplicationEngine.classify(candidate: candidate, ledger: ledger) == .merge(existingExpenseID: expense.id))
    }

    @Test("相同外部标识不能覆盖原币金额或币种冲突", arguments: [false, true])
    func externalIdentityChecksMoney(differentCurrency: Bool) {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let expense = addExpense(to: &ledger, source: .applePay, hash: "transaction-1")
        let before = ledger
        var candidate = transaction(source: .sms, hash: "transaction-1")
        if differentCurrency { candidate.originalCurrencyCode = "USD" }
        else { candidate.originalAmount = 36 }
        #expect(DeduplicationEngine.classify(candidate: candidate, ledger: ledger) == .pending(existingExpenseID: expense.id))
        #expect(ledger == before && ledger.expenses[expense.id] == expense)
    }

    @Test("外部标识指向已不存在的消费时不合并")
    func danglingExternalIdentity() {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let expense = addExpense(to: &ledger, source: .applePay, hash: "transaction-1")
        ledger.expenses[expense.id] = nil
        #expect(DeduplicationEngine.classify(candidate: transaction(source: .sms, hash: "transaction-1"), ledger: ledger) == .newExpense)
    }

    @Test("明确不同交易来源且商家金额时间相符时保留跨源去重")
    func knownCrossSourceDuplicate() throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let expense = addExpense(to: &ledger, source: .applePay)
        var candidate = transaction(source: .sms, occurredAt: now.addingTimeInterval(3_600))
        candidate.merchant = "  SAMPLE CAFE  "
        #expect(DeduplicationEngine.classify(candidate: candidate, ledger: ledger) == .merge(existingExpenseID: expense.id))
        ledger = try DeduplicationEngine.mergeEvidence(ledger: ledger, existingExpenseID: expense.id, candidate: candidate, now: now)
        #expect(ledger.expenses.count == 1 && ledger.expenses[expense.id] == expense)
        #expect(Set(ledger.evidences(forExpense: expense.id).map(\.sourceType.rawValue)) == ["applePay", "sms"])
    }

    @Test("无来源证据、同来源或主动来源不支持模糊自动合并", arguments:
        [nil, .sms, .manual, .agentText, .voice, .image] as [SourceType?])
    func uncertainSourceDoesNotAutoMerge(existingSource: SourceType?) {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let expense = addExpense(to: &ledger, source: existingSource)
        #expect(DeduplicationEngine.classify(candidate: transaction(source: .sms), ledger: ledger) == .pending(existingExpenseID: expense.id))
    }

    @Test("多个相符跨源消费不任取一笔合并", arguments: [false, true])
    func ambiguousMatchesStayPending(sharedIdentity: Bool) {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let hash = sharedIdentity ? "transaction-1" : nil
        let first = addExpense(to: &ledger, source: .applePay, hash: hash)
        let second = addExpense(to: &ledger, source: .email, hash: hash)
        let decision = DeduplicationEngine.classify(candidate: transaction(source: .sms, hash: hash), ledger: ledger)
        guard case .pending(let id) = decision else {
            Issue.record("Ambiguous evidence must remain pending")
            return
        }
        #expect(id == first.id || id == second.id)
    }

    @Test("主动任务无稳定实体标识时也不按相似字段吞并")
    func activeCaptureWithoutEntityID() throws {
        let coordinator = AgentActionCoordinator(calendar: TestDates.calendar)
        let draft = CaptureDraft(amount: 35, currencyCode: "CNY", occurredAt: now, merchant: "Sample Cafe")
        let first = try coordinator.execute(
            intent: .capture(draft), ledger: .blank(walletCurrencyCode: "CNY", now: now), now: now, confirmation: .accepted
        )
        let second = try coordinator.execute(intent: .capture(draft), ledger: first.ledger, now: now, confirmation: .accepted)
        #expect(second.ledger.expenses.count == 2 && first.savedEntityID != second.savedEntityID)
    }

    private func transaction(source: SourceType, hash: String? = nil, occurredAt: Date? = nil) -> NormalizedTransactionCandidate {
        NormalizedTransactionCandidate(
            originalAmount: 35, originalCurrencyCode: "CNY", occurredAt: occurredAt ?? now,
            merchant: "Sample Cafe", sourceType: source, externalReferenceHash: hash
        )
    }

    private func addExpense(to ledger: inout Ledger, source: SourceType?, hash: String? = nil) -> Expense {
        let expense = ledger.insertExpense(amount: 35, currencyCode: "CNY", occurredAt: now, now: now, merchant: "Sample Cafe")
        if let source {
            ledger.upsert(SourceEvidence(
                id: UUID(), expenseID: expense.id, sourceType: source, externalReferenceHash: hash,
                capturedAt: now, coverageTimestamp: now
            ))
        }
        return expense
    }
}
