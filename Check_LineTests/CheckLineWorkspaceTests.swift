import Foundation
import SwiftData
import Testing
@testable import CheckLine

struct HomeProjectorTests {
    @Test("已用与待确认分开，待确认只形成可能越线")
    func pendingIsSeparateFromConfirmed() throws {
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
        _ = try ledger.record(
            amount: 800,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: created.1.id)
        )
        _ = try ledger.record(
            amount: 300,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .pending(periodID: created.1.id, confidence: DecimalMath.parse("0.4"))
        )

        let cards = HomeProjector.cards(in: ledger)
        #expect(cards.count == 1)
        #expect(cards[0].snapshot.confirmedSpent == 800)
        #expect(cards[0].snapshot.pendingAmount == 300)
        #expect(cards[0].snapshot.availableToSpend == 200)
        #expect(cards[0].snapshot.certainOverrunAmount == 0)
        #expect(cards[0].snapshot.possibleOverrunAmount == 100)

        let items = HomeProjector.processingItems(in: ledger)
        #expect(items.contains { if case .pendingTransactions(1) = $0.kind { return true }; return false })
        #expect(items.contains { if case .possibleOverrun(let name) = $0.kind { return name == "餐饮" }; return false })
        #expect(items.contains { if case .certainOverrun = $0.kind { return true }; return false } == false)
    }

    @Test("金额格式化为货币字符串")
    func moneyFormatUsesCurrencyStyle() {
        let text = MoneyFormat.string(35, currencyCode: "CNY")
        #expect(text.contains("35"))
        #expect(MoneyFormat.parseAmount("35.50") == Decimal(string: "35.50", locale: Locale(identifier: "en_US_POSIX")))
        #expect(MoneyFormat.parseAmount("abc") == nil)
    }
}

@MainActor
struct CheckLineWorkspaceTests {
    @Test("创建预算卡后写入本地账本，重载后还能花等于额度")
    func createBudgetPersists() throws {
        let now = TestDates.day(2026, 1, 5)
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar)
        workspace.createBudget(name: "餐饮", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: now)
        #expect(workspace.banner == .createdBudget)
        #expect(workspace.cards.count == 1)
        #expect(workspace.cards[0].snapshot.confirmedSpent == 0)
        #expect(workspace.cards[0].snapshot.availableToSpend == 1_000)

        let reloaded = try LedgerStore.load(from: context, now: now)
        #expect(reloaded.budgets.count == 1)
        #expect(HomeProjector.cards(in: reloaded)[0].snapshot.availableToSpend == 1_000)
    }

    @Test("离线记一笔确认归属后写入，并可撤销")
    func offlineCaptureConfirmsAndUndo() async throws {
        let now = TestDates.day(2026, 1, 5)
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar)
        workspace.createBudget(name: "餐饮", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: now)
        workspace.draftText = "星巴克 35 元"
        await workspace.submitText(now: now)
        #expect(workspace.showsStructuredConfirm)
        workspace.selectedAttributionID = workspace.attributionChoices.first { $0.periodID != nil }?.id ?? "unbudgeted"
        workspace.confirmStructured(now: now)
        #expect(workspace.banner == .recorded)
        #expect(workspace.cards[0].snapshot.confirmedSpent == 35)
        #expect(workspace.cards[0].snapshot.availableToSpend == 965)

        workspace.undoLast(now: now)
        #expect(workspace.banner == .undone)
        #expect(workspace.cards[0].snapshot.confirmedSpent == 0)

        let reloaded = try LedgerStore.load(from: context, now: now)
        #expect(reloaded.expenses.isEmpty)
    }

    @Test("查询还能花走本地 Core，不写新消费")
    func localQueryDoesNotWrite() async throws {
        let now = TestDates.day(2026, 1, 5)
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar)
        workspace.createBudget(name: "餐饮", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: now)
        workspace.draftText = "餐饮还能花多少"
        await workspace.submitText(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
        guard case .queryRemaining(let amount, _) = workspace.banner else {
            Issue.record("expected query banner")
            return
        }
        #expect(amount == 1_000)
    }

    @Test("推荐购买被拒绝且不写账本")
    func recommendDoesNotWrite() async throws {
        let now = TestDates.day(2026, 1, 5)
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar)
        workspace.createBudget(name: "餐饮", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: now)
        workspace.draftText = "推荐买点什么"
        await workspace.submitText(now: now)
        #expect(workspace.banner == .refusedRecommend)
        #expect(workspace.ledger.expenses.isEmpty)
    }
}
