import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor
struct WishCreationTests {
    private let now = TestDates.day(2026, 10, 4)

    @Test("心愿所选币种和金额持久化，不换算或占用钱包")
    func selectedCurrencyPersistsWithoutWalletChange() throws {
        let (workspace, context) = try makeWorkspace()
        let before = workspace.ledger
        try workspace.createWish(name: "耳机", amountText: "149.90", currencyCode: " usd ", now: now)

        let loaded = try LedgerStore.load(from: context, now: now)
        let wish = try #require(loaded.wishes.values.first)
        #expect(wish.currencyCode == "USD")
        #expect(wish.targetAmount == DecimalMath.parse("149.90"))
        #expect(wish.state == .active)
        #expect(workspace.ledger.wishes[wish.id] == wish)
        #expect(loaded.walletEntries == before.walletEntries)
        #expect(loaded.walletSettings == before.walletSettings)
        #expect(loaded.expenses == before.expenses)
        #expect(WalletLedger.projection(ledger: loaded) == WalletLedger.projection(ledger: before))
        #expect(loaded.redemptions.isEmpty)
    }

    @Test("预计花费可留空，仍保留明确选择的币种")
    func optionalAmountKeepsCurrency() throws {
        let (workspace, context) = try makeWorkspace()
        try workspace.createWish(name: "旅行", amountText: "  ", currencyCode: "EUR", now: now)
        let loaded = try LedgerStore.load(from: context, now: now)
        let wish = try #require(loaded.wishes.values.first)
        #expect(wish.targetAmount == nil)
        #expect(wish.currencyCode == "EUR")
        #expect(loaded.walletEntries == workspace.ledger.walletEntries)
    }

    @Test("未传币种的已有调用继续使用钱包基准币")
    func omittedCurrencyUsesWalletDefault() throws {
        let (workspace, context) = try makeWorkspace(currency: "HKD")
        try workspace.createWish(name: "书", amountText: "120", symbolName: "book", now: now)
        let wish = try #require(LedgerStore.load(from: context, now: now).wishes.values.first)
        #expect(wish.currencyCode == "HKD")
        #expect(wish.symbolName == "book")
    }

    @Test("非法心愿币种不会写入任何账本数据", arguments: ["", "RMB", "US$"])
    func invalidCurrencyIsAtomic(currency: String) throws {
        let (workspace, context) = try makeWorkspace()
        let before = workspace.ledger
        #expect(throws: WorkspaceInputError.invalidCurrency) {
            try workspace.createWish(name: "不应保存", amountText: "100", currencyCode: currency, now: now)
        }
        #expect(workspace.ledger == before)
        #expect(try LedgerStore.load(from: context, now: now) == before)
    }

    @Test("非法预计花费不会创建心愿或改变钱包", arguments: ["0", "-10", "1abc"])
    func invalidAmountIsAtomic(amount: String) throws {
        let (workspace, context) = try makeWorkspace()
        let before = workspace.ledger
        #expect(throws: LedgerError.zeroOrNegativeAmount) {
            try workspace.createWish(name: "不应保存", amountText: amount, currencyCode: "USD", now: now)
        }
        #expect(workspace.ledger == before)
        #expect(try LedgerStore.load(from: context, now: now) == before)
    }

    private func makeWorkspace(currency: String = "CNY") throws -> (CheckLineWorkspace, ModelContext) {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let initial = Ledger.blank(walletCurrencyCode: currency, now: now)
        let funded = try WalletLedger.append(ledger: initial, type: .surplus, sourceSignedAmount: 860,
                                             sourceCurrencyCode: currency, quote: nil, at: now).0
        try LedgerStore.replaceAll(funded, in: context)
        return (CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar), context)
    }
}
