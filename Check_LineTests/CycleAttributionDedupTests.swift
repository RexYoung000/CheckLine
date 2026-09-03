import Foundation
import Testing
@testable import CheckLine

struct CycleEngineTests {
    @Test("循环卡到期后进入待结算，到期后的新消费进入下周期队列")
    func repeatingDueQueuesNewSpend() throws {
        let start = TestDates.day(2026, 1, 1)
        let end = TestDates.day(2026, 1, 31)
        let now = TestDates.day(2026, 1, 10)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: start,
            endDate: end,
            now: now
        )

        ledger = try CycleEngine.markDueIfNeeded(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 2, 1),
            calendar: TestDates.calendar
        )
        #expect(try ledger.requirePeriod(created.1.id).state == .pendingSettlement)

        let queued = try ledger.record(
            amount: 15,
            currencyCode: "CNY",
            occurredAt: TestDates.day(2026, 2, 2),
            now: TestDates.day(2026, 2, 2),
            decision: .queued(budgetID: created.0.id)
        )
        #expect(queued.budgetPeriodID == nil)
        #expect(queued.queuedForBudgetID == created.0.id)
        #expect(
            BudgetEngine.periodSnapshot(
                period: try ledger.requirePeriod(created.1.id),
                expenses: Array(ledger.expenses.values)
            ).confirmedSpent == 0
        )
    }

    @Test("无截止日期的一次性预算不会因日期自动待结算")
    func oneShotWithoutDeadlineStaysActive() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(
            name: "搬家",
            amount: 5_000,
            currencyCode: "CNY",
            cycleType: .oneShot,
            recurrence: nil,
            startDate: now,
            endDate: nil,
            now: now
        )

        ledger = try CycleEngine.markDueIfNeeded(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 12, 31),
            calendar: TestDates.calendar
        )
        let periodAfter = try ledger.requirePeriod(created.1.id)
        #expect(periodAfter.state == .active)
    }
}

struct AttributionEngineTests {
    @Test("一笔消费只能绑定一个结算周期")
    func uniqueSettlementPeriod() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let dining = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        let travel = try ledger.insertBudgetCard(
            name: "旅行",
            amount: 3_000,
            currencyCode: "CNY",
            cycleType: .oneShot,
            recurrence: nil,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 10),
            now: now
        )
        let expense = try ledger.record(
            amount: 50,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: dining.1.id)
        )

        #expect(throws: LedgerError.expenseAlreadyHasSettlementPeriod) {
            try AttributionEngine.apply(
                ledger: ledger,
                expenseID: expense.id,
                decision: .confirmed(periodID: travel.1.id),
                now: now
            )
        }
    }

    @Test("低置信归属暂计最可能周期且保持待确认")
    func pendingAttributionBindsButStaysPending() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        let expense = try ledger.record(
            amount: 30,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .pending(periodID: created.1.id, confidence: DecimalMath.parse("0.4"))
        )
        #expect(expense.budgetPeriodID == created.1.id)
        #expect(expense.attributionState == .pending)
        #expect(
            BudgetEngine.periodSnapshot(
                period: created.1,
                expenses: Array(ledger.expenses.values)
            ).pendingAmount == 30
        )
    }

    @Test("心愿兑现不能绑定普通预算周期")
    func wishRedemptionCannotBindBudget() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        var expense = ledger.insertExpense(
            amount: 200,
            currencyCode: "CNY",
            occurredAt: now,
            now: now
        )
        expense.wishRedemptionID = UUID()
        ledger.upsert(expense)

        #expect(throws: LedgerError.cannotBindWishRedemptionToBudget) {
            try AttributionEngine.apply(
                ledger: ledger,
                expenseID: expense.id,
                decision: .confirmed(periodID: created.1.id),
                now: now
            )
        }
    }
}

struct DeduplicationEngineTests {
    @Test("相同来源摘要自动合并")
    func sameHashMerges() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let expense = ledger.insertExpense(
            amount: 35,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            merchant: "Cafe"
        )
        ledger.upsert(
            SourceEvidence(
                id: UUID(),
                expenseID: expense.id,
                sourceType: .applePay,
                externalReferenceHash: "abc",
                capturedAt: now,
                coverageTimestamp: now
            )
        )

        let decision = DeduplicationEngine.classify(
            candidate: NormalizedTransactionCandidate(
                originalAmount: 35,
                originalCurrencyCode: "CNY",
                occurredAt: now,
                merchant: "Cafe",
                sourceType: .sms,
                externalReferenceHash: "abc"
            ),
            ledger: ledger
        )
        #expect(decision == .merge(existingExpenseID: expense.id))
        ledger = try DeduplicationEngine.mergeEvidence(
            ledger: ledger,
            existingExpenseID: expense.id,
            candidate: NormalizedTransactionCandidate(
                originalAmount: 35,
                originalCurrencyCode: "CNY",
                occurredAt: now,
                merchant: "Cafe",
                sourceType: .sms,
                externalReferenceHash: "abc"
            ),
            now: now
        )
        #expect(ledger.evidences(forExpense: expense.id).count == 2)
        #expect(ledger.expenses.count == 1)
    }

    @Test("金额接近但商家不同时进入待确认去重")
    func uncertainDuplicateIsPending() {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let expense = ledger.insertExpense(
            amount: 35,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            merchant: "Cafe A"
        )
        let decision = DeduplicationEngine.classify(
            candidate: NormalizedTransactionCandidate(
                originalAmount: 35,
                originalCurrencyCode: "CNY",
                occurredAt: now.addingTimeInterval(60 * 60),
                merchant: "Cafe B",
                sourceType: .sms,
                externalReferenceHash: nil
            ),
            ledger: ledger
        )
        #expect(decision == .pending(existingExpenseID: expense.id))
    }
}
