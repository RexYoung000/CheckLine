import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor struct HomeProjectionCacheTests {
    private let now = TestDates.day(2026, 11, 14)

    @Test("卡库按呈现日期取投影，账本原地写入后同日缓存失效")
    func cacheUsesDateAndInvalidatesOnLedgerChange() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: container.mainContext, now: now)
        defer { withExtendedLifetime(container) {} }
        let day: TimeInterval = 24 * 60 * 60
        let (budget, period) = try workspace.ledger.insertBudgetCard(
            name: "Daily", amount: 200, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil,
            startDate: now.addingTimeInterval(-day), endDate: now.addingTimeInterval(day), now: now
        )

        let initial = try #require(workspace.cards(at: now).first)
        #expect(initial.id == budget.id)
        #expect(initial.cycleProgress == 0.5)
        let later = now.addingTimeInterval(day / 2)
        #expect(workspace.cards(at: later).first?.cycleProgress == 0.75)
        #expect(workspace.cards(at: now).first == initial)

        let expense = workspace.ledger.insertExpense(amount: 25, currencyCode: "CNY", occurredAt: now, now: now)
        workspace.ledger.expenses[expense.id]?.budgetPeriodID = period.id
        workspace.ledger.expenses[expense.id]?.attributionState = .confirmed
        let updated = try #require(workspace.cards(at: now).first)
        #expect(updated.id == budget.id)
        #expect(updated.cycleProgress == initial.cycleProgress)
        #expect(updated.snapshot.confirmedSpent == 25)
    }

    @Test("分组投影保留周期优先级、卡序和各自账本金额")
    func groupedProjectionPreservesSelectionAndAmounts() throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let (daily, dailyPeriod) = try ledger.insertBudgetCard(
            name: "Daily", amount: 250, currencyCode: "CNY", cycleType: .repeating, recurrence: .monthly,
            startDate: now, endDate: nil, now: now, sortIndex: 1
        )
        let (trip, tripPeriod) = try ledger.insertBudgetCard(
            name: "Trip", amount: 100, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil,
            startDate: now, endDate: nil, now: now, sortIndex: 0
        )
        let (archived, _) = try ledger.insertBudgetCard(
            name: "Archived", amount: 100, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil,
            startDate: now, endDate: nil, now: now, sortIndex: -1
        )
        ledger.budgets[archived.id]?.state = .archived
        let earlyPending = historyPeriod(from: dailyPeriod, sequence: 0, state: .pendingSettlement)
        let laterActive = historyPeriod(from: dailyPeriod, sequence: 2, state: .active)
        ledger.upsert(laterActive)
        ledger.upsert(earlyPending)
        ledger.periods[tripPeriod.id]?.state = .pendingSettlement
        let laterPending = historyPeriod(from: tripPeriod, sequence: 2, state: .pendingSettlement)
        ledger.upsert(laterPending)

        insertExpense(in: &ledger, amount: 38, periodID: dailyPeriod.id)
        insertExpense(in: &ledger, amount: 15, periodID: dailyPeriod.id, state: .pending)
        insertExpense(in: &ledger, amount: 9, periodID: tripPeriod.id)
        insertExpense(in: &ledger, amount: 25, periodID: laterPending.id)
        insertExpense(in: &ledger, amount: 30, periodID: earlyPending.id)
        insertExpense(in: &ledger, amount: 40, periodID: dailyPeriod.id, isWishPurchase: true)
        insertExpense(in: &ledger, amount: 70)

        let cards = HomeProjector.cards(in: ledger, now: now)
        #expect(cards.map(\.id) == [trip.id, daily.id])
        #expect(cards.map(\.periodID) == [tripPeriod.id, dailyPeriod.id])
        #expect(cards.map(\.snapshot.confirmedSpent) == [9, 38])
        #expect(cards.map(\.snapshot.pendingAmount) == [0, 15])
    }

    @Test("合成账本记录卡库投影计算时间")
    func measureProjectionWithSyntheticLedger() throws {
        let budgetCount = 24
        let periodsPerBudget = 25
        let expensesPerPeriod = 20
        let iterations = 20
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        for budgetIndex in 0..<budgetCount {
            let (_, currentPeriod) = try ledger.insertBudgetCard(
                name: "Budget \(budgetIndex)", amount: 300, currencyCode: "CNY", cycleType: .repeating,
                recurrence: .monthly, startDate: now, endDate: nil, now: now
            )
            for sequence in 1...periodsPerBudget {
                let period = sequence == 1 ? currentPeriod : historyPeriod(from: currentPeriod, sequence: sequence, state: .settled)
                ledger.upsert(period)
                for _ in 0..<expensesPerPeriod { insertExpense(in: &ledger, amount: 3, periodID: period.id) }
            }
        }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace = CheckLineWorkspace(context: container.mainContext, now: now)
        defer { withExtendedLifetime(container) {} }
        workspace.ledger = ledger

        let baseline = measure(reads: iterations) {
            ledger.budgets.values.sorted { $0.sortIndex < $1.sortIndex }
                .compactMap { HomeProjector.card(budgetID: $0.id, periodID: nil, in: ledger) }
        }
        let uncached = measure(reads: iterations) {
            HomeProjector.cards(in: ledger, now: now)
        }
        let expected = workspace.cards(at: now)
        let cached = measure(reads: iterations) {
            workspace.cards(at: now)
        }
        #expect(expected.count == budgetCount)
        #expect(baseline.cards == expected && uncached.cards == expected && cached.cards == expected)
        print("Card projection, \(budgetCount) budgets, \(ledger.periods.count) periods, \(ledger.expenses.count) expenses, \(iterations) reads: per-card uncached \(baseline.duration), grouped uncached \(uncached.duration), grouped warm cache \(cached.duration)")
    }

    private func measure(reads: Int, project: () -> [HomeBudgetCardModel]) -> (cards: [HomeBudgetCardModel], duration: Duration) {
        var cards: [HomeBudgetCardModel] = []
        let duration = ContinuousClock().measure {
            for _ in 0..<reads { cards = project() }
        }
        return (cards, duration)
    }

    private func historyPeriod(from current: BudgetPeriod, sequence: Int, state: PeriodState) -> BudgetPeriod {
        var period = current
        period.id = UUID()
        period.sequence = sequence
        period.state = state
        return period
    }

    private func insertExpense(in ledger: inout Ledger, amount: Decimal, periodID: UUID? = nil,
                               state: AttributionState = .confirmed, isWishPurchase: Bool = false) {
        var expense = ledger.insertExpense(amount: amount, currencyCode: "CNY", occurredAt: now, now: now)
        expense.budgetPeriodID = periodID
        expense.attributionState = periodID == nil ? .unbudgeted : state
        if isWishPurchase { expense.wishRedemptionID = UUID() }
        ledger.upsert(expense)
    }
}
