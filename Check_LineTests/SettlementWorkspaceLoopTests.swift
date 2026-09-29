import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor
struct SettlementWorkspaceLoopTests {
    private let day = TestDates.day(2026, 9, 22)

    @Test("用户从预算卡结算后可用同一笔钱包余额真实兑现心愿，重开仍一致")
    func oneShotSettlementToPurchasePersists() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: day, calendar: TestDates.calendar)
        workspace.createBudget(name: "周末旅行", amountText: "1000", currencyCode: "CNY", cycleType: .oneShot, now: day)
        let card = try #require(workspace.cards.first)
        let recorded = workspace.recordExpense(
            amountText: "250", merchant: "车票", note: "", attributionID: card.periodID.uuidString,
            occurredAt: day, now: day
        )
        #expect(recorded != nil)
        let preview = try workspace.previewSettlement(card.periodID, now: day)
        #expect(preview.confirmedSpent == 250)
        #expect(preview.baseSurplus == 750)
        #expect(preview.balanceAfter == 750)
        #expect(workspace.wallet.balance == 0)

        let reviewed = workspace.ledger
        try workspace.settlePeriod(card.periodID, quote: nil, reviewedLedger: reviewed, acceptedIncompleteData: true, now: day)
        #expect(workspace.wallet.balance == 750)
        #expect(workspace.ledger.settlement(forPeriod: card.periodID) != nil)
        #expect(workspace.cards.isEmpty)
        #expect(workspace.ledger.budgets[card.id]?.state == .archived)

        try workspace.createWish(name: "耳机", amountText: "600", symbolName: "headphones", now: day)
        let wishID = try #require(workspace.ledger.wishes.values.first?.id)
        try workspace.redeemWish(wishID, actualAmount: 500, currencyCode: "CNY", realPurchaseConfirmed: true, now: TestDates.day(2026, 9, 23))
        #expect(workspace.wallet.balance == 250)
        #expect(workspace.ledger.redemptions.count == 1)
        #expect(workspace.ledger.expenses.values.filter { $0.wishRedemptionID != nil }.count == 1)

        let reopened = CheckLineWorkspace(context: context, now: day, calendar: TestDates.calendar)
        #expect(reopened.wallet.balance == 250)
        #expect(reopened.ledger.wishes[wishID]?.state == .completed)
        #expect(reopened.ledger.sortedWalletEntries.map(\.walletSignedAmount) == [750, -500])
    }

    @Test("结算前记录变化必须重新核对；循环卡未到期不可提前结算")
    func staleReviewAndRepeatingBoundary() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: day, calendar: TestDates.calendar)
        workspace.createBudget(name: "日常", amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: day)
        let repeating = try #require(workspace.cards.first)
        #expect(throws: AgentRefusal.domain(.periodNotReadyToSettle)) {
            try workspace.previewSettlement(repeating.periodID, now: day)
        }
        workspace.createBudget(name: "旅行", amountText: "800", currencyCode: "CNY", cycleType: .oneShot, now: day)
        let oneShot = try #require(workspace.cards.first { $0.name == "旅行" })
        let reviewed = workspace.ledger
        _ = workspace.recordExpense(amountText: "100", merchant: "车票", note: "", attributionID: oneShot.periodID.uuidString, occurredAt: day, now: day)
        #expect(throws: LedgerError.staleSettlementPreview) {
            try workspace.settlePeriod(oneShot.periodID, quote: nil, reviewedLedger: reviewed, acceptedIncompleteData: true, now: day)
        }
        #expect(workspace.ledger.settlements.isEmpty)
        let dueDay = TestDates.day(2026, 10, 1)
        let duePreview = try workspace.previewSettlement(repeating.periodID, now: dueDay)
        #expect(duePreview.baseSurplus == 1_000)
        try workspace.settlePeriod(repeating.periodID, quote: nil, reviewedLedger: workspace.ledger, acceptedIncompleteData: true, now: dueDay)
        #expect(workspace.ledger.periods(forBudget: repeating.id).count == 2)
        #expect(workspace.cards.contains { $0.id == repeating.id && $0.periodID != repeating.periodID })
    }

    @Test("跨币种必须使用正数且具来源的汇率；购买按确认快照扣钱包")
    func exchangeRateIsVisibleAndValidated() throws {
        let missing = Ledger.blank(walletCurrencyCode: "CNY", now: day)
        #expect(throws: LedgerError.missingExchangeRate(source: "USD", target: "CNY")) {
            try CurrencyEngine.convertToWallet(sourceSignedAmount: 10, sourceCurrencyCode: "USD", walletCurrencyCode: "CNY", quote: nil, at: day)
        }
        #expect(throws: LedgerError.invalidExchangeRate) {
            try CurrencyEngine.convertToWallet(sourceSignedAmount: 10, sourceCurrencyCode: "USD", walletCurrencyCode: "CNY", quote: .estimated(rate: 0, at: day, sourceName: "user_provided_estimate"), at: day)
        }
        let quote = ExchangeQuote.estimated(rate: DecimalMath.parse("7.2"), at: day, sourceName: "user_provided_estimate")
        let converted = try CurrencyEngine.convertToWallet(sourceSignedAmount: -10, sourceCurrencyCode: "USD", walletCurrencyCode: missing.walletSettings.walletCurrencyCode, quote: quote, at: day)
        #expect(converted.walletSignedAmount == -72)
        #expect(converted.snapshot.rate == DecimalMath.parse("7.2"))
        #expect(converted.snapshot.sourceName == "user_provided_estimate")
    }

    @Test("跨币种真实购买按核对汇率扣钱包并保存换算快照")
    func crossCurrencyPurchaseKeepsReviewedRate() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let workspace = CheckLineWorkspace(context: context, now: day, calendar: TestDates.calendar)
        workspace.createBudget(name: "短途", amountText: "300", currencyCode: "CNY", cycleType: .oneShot, now: day)
        let card = try #require(workspace.cards.first)
        try workspace.settlePeriod(card.periodID, quote: nil, reviewedLedger: workspace.ledger, acceptedIncompleteData: true, now: day)
        try workspace.createWish(name: "书", amountText: "100", symbolName: "books.vertical", now: day)
        let wishID = try #require(workspace.ledger.wishes.values.first?.id)
        let quote = ExchangeQuote.estimated(rate: DecimalMath.parse("7.2"), at: day, sourceName: "user_provided_estimate")
        try workspace.redeemWish(wishID, actualAmount: 10, currencyCode: "USD", realPurchaseConfirmed: true, quote: quote, now: day)
        #expect(workspace.wallet.balance == 228)
        let entry = try #require(workspace.ledger.sortedWalletEntries.first { $0.type == .wishRedemption })
        #expect(entry.sourceSignedAmount == -10)
        #expect(entry.sourceCurrencyCode == "USD")
        #expect(entry.walletSignedAmount == -72)
        #expect(entry.conversion.rate == DecimalMath.parse("7.2"))
        #expect(entry.conversion.sourceName == "user_provided_estimate")
    }

    @Test("结算保存失败时不改变账本，重试只写入一次")
    func failedSettlementCanRetry() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        var seed = Ledger.blank(walletCurrencyCode: "CNY", now: day)
        let (_, period) = try seed.insertBudgetCard(name: "短途", amount: 300, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil, startDate: day, endDate: nil, now: day)
        try LedgerStore.replaceAll(seed, in: context)
        let gate = SettlementSaveGate()
        let workspace = CheckLineWorkspace(context: context, now: day, calendar: TestDates.calendar, saveLedger: { changed, context in
            if gate.fail { throw SettlementSaveError.simulated }
            try LedgerStore.replaceAll(changed, in: context)
        })
        gate.fail = true
        #expect(throws: SettlementSaveError.simulated) {
            try workspace.settlePeriod(period.id, quote: nil, reviewedLedger: workspace.ledger, acceptedIncompleteData: true, now: day)
        }
        #expect(workspace.ledger.settlements.isEmpty)
        #expect(workspace.wallet.balance == 0)
        #expect(try LedgerStore.load(from: context, now: day).settlements.isEmpty)
        gate.fail = false
        try workspace.settlePeriod(period.id, quote: nil, reviewedLedger: workspace.ledger, acceptedIncompleteData: true, now: day)
        #expect(workspace.ledger.settlements.count == 1)
        #expect(workspace.ledger.walletEntries.count == 1)
        #expect(workspace.wallet.balance == 300)
    }
}

@MainActor
private final class SettlementSaveGate {
    var fail = false
}

private enum SettlementSaveError: Error, Equatable {
    case simulated
}
