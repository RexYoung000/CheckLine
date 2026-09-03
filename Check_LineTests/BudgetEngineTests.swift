import Foundation
import Testing
@testable import CheckLine

struct BudgetEngineTests {
    @Test("没有消费时保留全部可花金额")
    func emptyBudget() {
        let snapshot = BudgetEngine.snapshot(
            totalAmount: 1_000,
            recordedAmounts: []
        )

        #expect(snapshot.spent == 0)
        #expect(snapshot.remaining == 1_000)
        #expect(snapshot.availableToSpend == 1_000)
        #expect(snapshot.overrunAmount == 0)
        #expect(snapshot.progress == 0)
    }

    @Test("多笔关联金额正确汇总")
    func multipleBindings() {
        let snapshot = BudgetEngine.snapshot(
            totalAmount: 1_000,
            recordedAmounts: [120.50, 79.50, 300]
        )

        #expect(snapshot.spent == 500)
        #expect(snapshot.remaining == 500)
        #expect(snapshot.availableToSpend == 500)
        #expect(snapshot.overrunAmount == 0)
        #expect(snapshot.progress == 0.5)
    }

    @Test("刚好用完时还能花为零且进度完整")
    func exactBoundary() {
        let snapshot = BudgetEngine.snapshot(
            totalAmount: 1_000,
            recordedAmounts: [600, 400]
        )

        #expect(snapshot.spent == 1_000)
        #expect(snapshot.remaining == 0)
        #expect(snapshot.availableToSpend == 0)
        #expect(snapshot.overrunAmount == 0)
        #expect(snapshot.progress == 1)
    }

    @Test("超支时保留真实负结余并单独派生超出金额")
    func overrun() {
        let snapshot = BudgetEngine.snapshot(
            totalAmount: 1_000,
            recordedAmounts: [800, 350]
        )

        #expect(snapshot.spent == 1_150)
        #expect(snapshot.remaining == -150)
        #expect(snapshot.availableToSpend == 0)
        #expect(snapshot.overrunAmount == 150)
        #expect(snapshot.progress == 1)
    }

    @Test("总额为零时进度保持为零")
    func zeroTotal() {
        let snapshot = BudgetEngine.snapshot(
            totalAmount: 0,
            recordedAmounts: [25]
        )

        #expect(snapshot.spent == 25)
        #expect(snapshot.remaining == -25)
        #expect(snapshot.availableToSpend == 0)
        #expect(snapshot.overrunAmount == 25)
        #expect(snapshot.progress == 0)
    }

    @Test("待确认金额单独列出且不能形成确定越线")
    func pendingDoesNotCreateCertainOverrun() {
        let snapshot = BudgetEngine.periodSnapshot(
            budgetAmount: 100,
            confirmedAmounts: [90],
            pendingAmounts: [20]
        )

        #expect(snapshot.confirmedSpent == 90)
        #expect(snapshot.pendingAmount == 20)
        #expect(snapshot.remaining == 10)
        #expect(snapshot.availableToSpend == 10)
        #expect(snapshot.certainOverrunAmount == 0)
        #expect(snapshot.possibleOverrunAmount == 10)
        #expect(snapshot.progress == DecimalMath.parse("0.9"))
    }

    @Test("已确认超支才形成确定越线")
    func confirmedOverrunIsCertain() {
        let snapshot = BudgetEngine.periodSnapshot(
            budgetAmount: 100,
            confirmedAmounts: [130],
            pendingAmounts: [20]
        )

        #expect(snapshot.remaining == -30)
        #expect(snapshot.certainOverrunAmount == 30)
        #expect(snapshot.possibleOverrunAmount == 20)
        #expect(snapshot.progress == 1)
    }

    @Test("标签不进入周期金额")
    func tagsDoNotAffectPeriodSnapshot() throws {
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
            amount: 80,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: created.1.id)
        )
        let tag = ExpenseTag(id: UUID(), name: "人情", createdAt: now)
        ledger.tags[tag.id] = tag
        ledger.attach(tagID: tag.id, toExpense: expense.id)

        let beforeTags = BudgetEngine.periodSnapshot(period: created.1, expenses: Array(ledger.expenses.values))
        #expect(ledger.tags(forExpense: expense.id).map(\.name) == ["人情"])
        let afterTags = BudgetEngine.periodSnapshot(period: created.1, expenses: Array(ledger.expenses.values))
        #expect(beforeTags == afterTags)
        #expect(afterTags.confirmedSpent == 80)
    }
}
