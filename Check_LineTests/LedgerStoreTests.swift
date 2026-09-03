import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor
struct LedgerStoreTests {
    @Test("内存容器可以打开，本地配置关闭 CloudKit")
    func containerConfiguration() throws {
        let live = CheckLinePersistence.liveConfiguration()
        #expect(live.isStoredInMemoryOnly == false)
        #expect(live.cloudKitDatabase == .none)

        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let loaded = try LedgerStore.load(from: context, now: TestDates.day(2026, 1, 1))
        #expect(loaded.budgets.isEmpty)
        #expect(loaded.walletEntries.isEmpty)
    }

    @Test("空白账本可以写入并读回钱包设置")
    func emptyLedgerRoundTrip() throws {
        let now = TestDates.day(2026, 1, 1)
        let ledger = Ledger.blank(walletCurrencyCode: "USD", now: now, settingsID: UUID())
        let loaded = try roundTrip(ledger)
        #expect(loaded.walletSettings.walletCurrencyCode == "USD")
        #expect(loaded.walletSettings.id == ledger.walletSettings.id)
        #expect(loaded.walletSettings.userConfirmedCurrency == false)
        #expect(loaded.budgets.isEmpty)
    }

    @Test("结算后的循环卡账本写入后金额与钱包净额不变")
    func settledRepeatingLedgerRoundTrip() throws {
        let now = TestDates.day(2026, 1, 10)
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
            decision: .confirmed(periodID: created.1.id),
            merchant: "面馆"
        )
        let tag = ExpenseTag(id: UUID(), name: "人情", createdAt: now)
        ledger.tags[tag.id] = tag
        ledger.attach(tagID: tag.id, toExpense: expense.id)
        ledger.upsert(
            SourceEvidence(
                id: UUID(),
                expenseID: expense.id,
                sourceType: .manual,
                externalReferenceHash: "manual-1",
                capturedAt: now,
                coverageTimestamp: now
            )
        )
        ledger = try CycleEngine.markDueIfNeeded(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 2, 1),
            calendar: TestDates.calendar
        )
        ledger = try SettlementEngine.commit(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 2, 1),
            calendar: TestDates.calendar,
            quote: nil,
            acceptedIncompleteData: false
        )

        let loaded = try roundTrip(ledger)
        #expect(loaded.budgets.count == 1)
        #expect(loaded.periods.count == 2)
        #expect(loaded.expenses.count == 1)
        #expect(loaded.settlements.count == 1)
        #expect(loaded.tags(forExpense: expense.id).map(\.name) == ["人情"])
        #expect(loaded.evidences(forExpense: expense.id).count == 1)
        #expect(try loaded.requirePeriod(created.1.id).state == .settled)
        #expect(WalletLedger.projection(ledger: loaded) == WalletLedger.projection(ledger: ledger))
        #expect(WalletLedger.projection(ledger: loaded).balance == 920)

        let loadedExpense = try loaded.requireExpense(expense.id)
        #expect(loadedExpense.merchant == "面馆")
        #expect(loadedExpense.budgetPeriodID == created.1.id)
        #expect(loaded.walletEntries.values.first?.conversion.kind == .identity)
    }

    @Test("跨币种结算快照写入后仍可按原汇率派生钱包金额")
    func crossCurrencySnapshotRoundTrip() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        ledger = try WalletLedger.setWalletCurrency(ledger: ledger, currencyCode: "CNY", now: now)
        let travel = try ledger.insertBudgetCard(
            name: "东京旅行",
            amount: 50_000,
            currencyCode: "JPY",
            cycleType: .oneShot,
            recurrence: nil,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 10),
            now: now
        )
        _ = try ledger.record(
            amount: 10_000,
            currencyCode: "JPY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: travel.1.id),
            estimatedBudgetAmount: 10_000
        )
        ledger = try CycleEngine.markDueIfNeeded(
            ledger: ledger,
            periodID: travel.1.id,
            now: TestDates.day(2026, 1, 11),
            calendar: TestDates.calendar
        )
        ledger = try SettlementEngine.commit(
            ledger: ledger,
            periodID: travel.1.id,
            now: TestDates.day(2026, 1, 11),
            calendar: TestDates.calendar,
            quote: .estimated(
                rate: DecimalMath.parse("0.05"),
                at: TestDates.day(2026, 1, 11),
                sourceName: "estimate"
            ),
            acceptedIncompleteData: false
        )

        let loaded = try roundTrip(ledger)
        let entry = loaded.walletEntries.values.first
        #expect(entry?.conversion.kind == .estimated)
        #expect(entry?.conversion.rate == DecimalMath.parse("0.05"))
        #expect(entry?.sourceCurrencyCode == "JPY")
        #expect(entry?.walletCurrencyCode == "CNY")
        #expect(WalletLedger.projection(ledger: loaded).balance == 2_000)
    }

    private func roundTrip(_ ledger: Ledger) throws -> Ledger {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try LedgerStore.replaceAll(ledger, in: context)
        return try LedgerStore.load(from: context)
    }
}
