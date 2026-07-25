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
}
