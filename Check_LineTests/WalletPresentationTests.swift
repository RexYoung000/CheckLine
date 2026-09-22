import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor
struct WalletPresentationTests {
    private let now = TestDates.day(2026, 9, 22)

    @Test("暂计金额与液位一致，但待确认不造成确定越线")
    func provisionalBalance() throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let (_, period) = try ledger.insertBudgetCard(name: "日常", amount: 100, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: now, endDate: nil, now: now)
        _ = try ledger.record(amount: 80, currencyCode: "CNY", occurredAt: now, now: now, decision: .confirmed(periodID: period.id))
        _ = try ledger.record(amount: 30, currencyCode: "CNY", occurredAt: now, now: now, decision: .pending(periodID: period.id, confidence: DecimalMath.parse("0.4")))
        let card = try #require(HomeProjector.cards(in: ledger).first)
        #expect(BudgetPresentation.used(card) == 110)
        #expect(BudgetPresentation.remaining(card) == -10)
        #expect(BudgetPresentation.fill(card) == 0)
        #expect(card.snapshot.certainOverrunAmount == 0)
        #expect(card.snapshot.possibleOverrunAmount == 10)
        #expect(BudgetPresentation.dailyAmount(now, card: card, ledger: ledger, calendar: TestDates.calendar) == 110)
    }

    @Test("待确认互相抵消时仍保留处理入口")
    func pendingCountSurvivesZeroNet() throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let (_, period) = try ledger.insertBudgetCard(name: "日常", amount: 100, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: now, endDate: nil, now: now)
        let purchase = try ledger.record(amount: 40, currencyCode: "CNY", occurredAt: now, now: now, decision: .pending(periodID: period.id, confidence: DecimalMath.parse("0.4")))
        let refund = ledger.insertExpense(amount: 40, currencyCode: "CNY", occurredAt: now, now: now, kind: .refund, reversesExpenseID: purchase.id)
        ledger = try AttributionEngine.apply(ledger: ledger, expenseID: refund.id, decision: .pending(periodID: period.id, confidence: DecimalMath.parse("0.4")), now: now)
        let card = try #require(HomeProjector.cards(in: ledger).first)
        #expect(card.snapshot.pendingAmount == 0)
        #expect(BudgetPresentation.pendingCount(card, in: ledger) == 2)
        #expect(BudgetPresentation.remaining(card) == 100)
    }

    @Test("日历金额保留退款符号且不混入另一张卡")
    func dailyTotalsRespectCardAndRefund() throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let (_, period) = try ledger.insertBudgetCard(name: "日常", amount: 100, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: now, endDate: nil, now: now)
        let purchase = try ledger.record(amount: 70, currencyCode: "CNY", occurredAt: now, now: now, decision: .confirmed(periodID: period.id))
        let refund = ledger.insertExpense(amount: 20, currencyCode: "CNY", occurredAt: now, now: now, kind: .refund, reversesExpenseID: purchase.id)
        ledger = try AttributionEngine.apply(ledger: ledger, expenseID: refund.id, decision: .confirmed(periodID: period.id), now: now)
        _ = try ledger.record(amount: 88, currencyCode: "CNY", occurredAt: now, now: now, decision: .unbudgeted)
        let card = try #require(HomeProjector.cards(in: ledger).first)
        #expect(BudgetPresentation.dailyAmount(now, card: card, ledger: ledger, calendar: TestDates.calendar) == 50)
        #expect(BudgetPresentation.expenses(card, in: ledger).count == 2)
        #expect(BudgetPresentation.remaining(card) == 50)
        #expect(BudgetPresentation.fill(card) == 0.5)
    }

    @Test("置顶只改变顺序，选择卡片后查询采用对应币种与待确认口径")
    func selectionAndPin() async throws {
        let (workspace, context) = try makeWorkspace()
        workspace.createBudget(name: "日常", amountText: "100", currencyCode: "CNY", cycleType: .oneShot, now: now)
        workspace.createBudget(name: "旅行", amountText: "200", currencyCode: "USD", cycleType: .oneShot, now: now)
        let selected = try #require(workspace.cards.first { $0.currencyCode == "USD" })
        workspace.selectedBudgetID = selected.id
        let expensesBefore = workspace.ledger.expenses
        workspace.pinBudget(selected.id)
        #expect(workspace.cards.first?.id == selected.id)
        #expect(workspace.ledger.expenses == expensesBefore)
        #expect(HomeProjector.cards(in: try LedgerStore.load(from: context)).first?.id == selected.id)
        workspace.draftText = "还能花多少"
        await workspace.submitText(now: now)
        #expect(workspace.banner == .queryRemaining(amount: 200, currencyCode: "USD"))
        #expect(workspace.agentBudgetID == selected.id)
        workspace.selectedBudgetID = workspace.cards.last?.id
        workspace.draftText = "还能花多少"
        await workspace.submitText(now: now)
        #expect(workspace.banner == .queryRemaining(amount: 200, currencyCode: "USD"))
    }

    @Test("心愿创建保留预设符号；无效金额不会写入")
    func createWishAndSymbols() throws {
        let (workspace, context) = try makeWorkspace()
        try workspace.createWish(name: "耳机", amountText: "699.50", symbolName: "headphones", now: now)
        try workspace.createWish(name: "还没定金额", amountText: "", symbolName: "unknown", now: now)
        let reloaded = try LedgerStore.load(from: context)
        #expect(reloaded.wishes.values.first { $0.name == "耳机" }?.symbolName == "headphones")
        #expect(reloaded.wishes.values.first { $0.name == "耳机" }?.targetAmount == DecimalMath.parse("699.50"))
        #expect(reloaded.wishes.values.first { $0.name == "还没定金额" }?.symbolName == "star")
        let before = workspace.ledger
        #expect(throws: LedgerError.zeroOrNegativeAmount) { try workspace.createWish(name: "无效", amountText: "1abc", symbolName: "star", now: now) }
        #expect(workspace.ledger == before)
    }

    @Test("兑现先校验余额，只扣钱包一次，写入并保留完成状态")
    func redemptionIsAtomicAndPersistent() throws {
        let (workspace, context) = try makeWorkspace()
        workspace.createBudget(name: "日常", amountText: "3000", currencyCode: "CNY", cycleType: .oneShot, now: now)
        try workspace.createWish(name: "耳机", amountText: "699", symbolName: "headphones", now: now)
        let id = try #require(workspace.ledger.wishes.values.first?.id)
        let before = workspace.ledger
        #expect(throws: AgentRefusal.domain(.insufficientWishWallet)) { try workspace.redeemWish(id, actualAmount: 599, currencyCode: "CNY", realPurchaseConfirmed: true, now: now) }
        #expect(workspace.ledger == before)
        let funded = try WalletLedger.append(ledger: before, type: .surplus, sourceSignedAmount: 860, sourceCurrencyCode: "CNY", quote: nil, at: now).0
        try LedgerStore.replaceAll(funded, in: context)
        let fundedWorkspace = CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar)
        #expect(throws: AgentRefusal.confirmationRequired) { try fundedWorkspace.redeemWish(id, actualAmount: 599, currencyCode: "CNY", realPurchaseConfirmed: false, now: now) }
        #expect(fundedWorkspace.wallet.balance == 860)
        try fundedWorkspace.redeemWish(id, actualAmount: 599, currencyCode: "CNY", realPurchaseConfirmed: true, now: now)
        #expect(fundedWorkspace.wallet.balance == 261)
        #expect(fundedWorkspace.cards.first?.snapshot.confirmedSpent == 0)
        #expect(fundedWorkspace.ledger.wishes[id]?.state == .completed)
        #expect(fundedWorkspace.ledger.wishes[id]?.symbolName == "headphones")
        #expect(throws: AgentRefusal.domain(.wishAlreadyCompleted)) { try fundedWorkspace.redeemWish(id, actualAmount: 599, currencyCode: "CNY", realPurchaseConfirmed: true, now: now) }
        let loaded = try LedgerStore.load(from: context)
        #expect(loaded.redemptions.count == 1)
        #expect(WalletLedger.projection(ledger: loaded).balance == 261)
        #expect(loaded.wishes[id]?.state == .completed)
    }

    @Test("未指定图标的已有心愿仍可读写")
    func nilWishSymbolRoundTrip() throws {
        let (_, context) = try makeWorkspace()
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let wish = Wish(id: UUID(), name: "旧心愿", targetAmount: nil, currencyCode: nil, referenceURL: nil, state: .active, createdAt: now, completedAt: nil)
        ledger.upsert(wish)
        try LedgerStore.replaceAll(ledger, in: context)
        #expect(try LedgerStore.load(from: context).wishes[wish.id]?.symbolName == nil)
    }

    @Test("金额不接受部分解析或不规范分组")
    func strictAmountInput() {
        for invalid in ["1abc", "12,34", "-1", "0", "1.2.3", "", "NaN"] { #expect(MoneyFormat.parseAmount(invalid) == nil) }
        #expect(MoneyFormat.parseAmount("1,234.56") == DecimalMath.parse("1234.56"))
    }

    private func makeWorkspace() throws -> (CheckLineWorkspace, ModelContext) {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        return (CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar), context)
    }
}
