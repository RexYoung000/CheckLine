import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor struct WishCoverageTests {
    private let now = TestDates.day(2026, 10, 27)
    private func wish(target: Decimal? = 100, currency: String = "CNY") -> Wish {
        Wish(id: UUID(), name: "Reference fixture", targetAmount: target, currencyCode: currency,
             referenceURL: nil, state: .active, createdAt: now, completedAt: nil)
    }
    private func quote(_ wish: Wish, rate: Decimal, target: String = "CNY") -> WishReferenceQuote {
        WishReferenceQuote(wishID: wish.id, sourceCurrency: wish.currencyCode!, walletCurrency: target, rate: rate, quotedAt: now)
    }

    @Test("参考覆盖的 Decimal 门槛不被百分比四舍五入改变")
    func coverageBoundaries() {
        let item = wish()
        for (amount, state, percent) in [
            (Decimal.zero, WishCoverageState.insufficient, 0),
            (50, .insufficient, 50),
            (DecimalMath.parse("99.99"), .insufficient, 99),
            (100, .ready, 100), (120, .ready, 100)
        ] {
            let value = WishCoverage.calculate(wish: item, walletBalance: amount, walletCurrency: "CNY", reference: nil)
            #expect(value.state == state)
            #expect(value.displayPercent == percent)
            #expect(value.canRedeem == (amount >= 100))
        }
        #expect(WishCoverage.calculate(wish: wish(target: nil), walletBalance: 1000, walletCurrency: "CNY", reference: nil).state == .unpriced)
        var completed = item; completed.state = .completed
        let value = WishCoverage.calculate(wish: completed, walletBalance: 0, walletCurrency: "CNY", reference: nil)
        #expect(value.state == .completed && !value.canRedeem)
    }

    @Test("缺失、非法和不匹配报价不得借用历史汇率或开放兑换")
    func referencePairAndRate() {
        let item = wish(currency: "USD")
        let references: [WishReferenceQuote?] = [nil, quote(item, rate: 0), quote(item, rate: -1), quote(item, rate: .nan),
            quote(wish(currency: "USD"), rate: 7), quote(item, rate: 7, target: "EUR")]
        for reference in references {
            let value = WishCoverage.calculate(wish: item, walletBalance: 700, walletCurrency: "CNY", reference: reference)
            #expect(value.state == .needsQuote && value.progress == nil && !value.canRedeem)
        }
        let good = quote(item, rate: 7)
        #expect(WishCoverage.calculate(wish: item, walletBalance: DecimalMath.parse("699.99"), walletCurrency: "CNY", reference: good).state == .insufficient)
        #expect(WishCoverage.calculate(wish: item, walletBalance: 700, walletCurrency: "CNY", reference: good).state == .ready)
        var changed = item; changed.currencyCode = "EUR"
        #expect(WishCoverage.calculate(wish: changed, walletBalance: 700, walletCurrency: "CNY", reference: good).state == .needsQuote)
        #expect(WishCoverage.calculate(wish: item, walletBalance: 700, walletCurrency: "HKD", reference: good).state == .needsQuote)
    }

    @Test("参考应用独立持久化、按心愿币种对隔离且不改账本")
    func appliedReferencePersistence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let store = WishReferenceQuoteStore(root: root)
        let workspace = CheckLineWorkspace(context: container.mainContext, wishReferenceQuotes: store)
        let id = try workspace.createWish(name: "USD fixture", amountText: "100", currencyCode: "USD")
        let item = try #require(workspace.ledger.wishes[id])
        let before = workspace.ledger
        let first = quote(item, rate: 7)
        try workspace.applyWishReference(first)
        #expect(workspace.ledger == before)
        let restored = WishReferenceQuoteStore(root: root)
        #expect(try restored.reference(for: id, source: "USD", target: "CNY") == first)
        #expect(try restored.reference(for: id, source: "EUR", target: "CNY") == nil)
        #expect(try restored.reference(for: UUID(), source: "USD", target: "CNY") == nil)
        // Merely editing/cancelling has no store write; a failed apply preserves the reference.
        #expect(throws: LedgerError.invalidExchangeRate) { try workspace.applyWishReference(quote(item, rate: 0)) }
        #expect(try store.reference(for: id, source: "USD", target: "CNY") == first)
        try workspace.setWishPrice(id, amount: 100, currency: "EUR")
        #expect(workspace.wishCoverage(for: try #require(workspace.ledger.wishes[id])).state == .needsQuote)
    }

    @Test("写入失败不发布参考值，修复存储后可重试")
    func failedWriteDoesNotApply() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([0]).write(to: root)
        let store = WishReferenceQuoteStore(root: root)
        let item = wish(currency: "USD"), reference = quote(item, rate: 7)
        #expect(throws: (any Error).self) { try store.apply(reference) }
        #expect(store.revision == 0)
        try FileManager.default.removeItem(at: root)
        try store.apply(reference)
        #expect(try store.reference(for: item.id, source: "USD", target: "CNY") == reference)
        #expect(store.revision == 1)
    }

    @Test("购买只给新草稿预填参考，既有实际报价优先，缺失匹配不预填")
    func draftPrefillPriority() throws {
        let store = TaskDraftStore(inMemory: true), item = wish(currency: "USD")
        let first = LocalTaskDraftSession(store: store, kind: "wishRedemption", currency: "USD", wishID: item.id)
        first.prefillReference(quote(item, rate: 7))
        #expect(first.draft.exchangeRateText == "7")
        first.draft.amount = "100"; first.draft.exchangeRateText = "6.8"
        let restored = LocalTaskDraftSession(store: store, kind: "wishRedemption", currency: "USD", wishID: item.id)
        restored.prefillReference(quote(item, rate: 8))
        #expect(restored.draft.exchangeRateText == "6.8")
        let different = LocalTaskDraftSession(store: store, kind: "wishRedemption", currency: "EUR", wishID: UUID())
        different.prefillReference(quote(item, rate: 7))
        #expect(different.draft.exchangeRateText == nil)
    }

    @Test("覆盖达标不替代实际成交校验，保存失败可重试且重复确认不扣两次")
    func actualPurchaseAndPersistence() throws {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        var fail = false
        let workspace = CheckLineWorkspace(context: container.mainContext, saveLedger: { ledger, context in
            if fail { throw CocoaError(.fileWriteUnknown) }
            try LedgerStore.replaceAll(ledger, in: context)
        })
        let id = try workspace.createWish(name: "Atomic fixture", amountText: "100", currencyCode: "CNY")
        workspace.ledger = try WalletLedger.append(ledger: workspace.ledger, type: .surplus, sourceSignedAmount: 100, sourceCurrencyCode: "CNY", quote: nil, at: now).0
        let item = try #require(workspace.ledger.wishes[id])
        #expect(workspace.wishCoverage(for: item).canRedeem)
        let before = workspace.ledger
        #expect(throws: (any Error).self) { try workspace.redeemWish(id, actualAmount: 101, currencyCode: "CNY", realPurchaseConfirmed: true) }
        #expect(throws: (any Error).self) { try workspace.redeemWish(id, actualAmount: 90, currencyCode: "CNY", realPurchaseConfirmed: false) }
        fail = true
        #expect(throws: (any Error).self) { try workspace.redeemWish(id, actualAmount: 90, currencyCode: "CNY", realPurchaseConfirmed: true) }
        #expect(workspace.ledger == before)
        fail = false
        try workspace.redeemWish(id, actualAmount: 90, currencyCode: "CNY", realPurchaseConfirmed: true)
        let saved = workspace.ledger
        #expect(workspace.wallet.balance == 10)
        _ = try? workspace.redeemWish(id, actualAmount: 90, currencyCode: "CNY", realPurchaseConfirmed: true)
        #expect(workspace.ledger == saved)
    }
}
