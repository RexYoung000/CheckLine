import Foundation

nonisolated enum WishCoverageState: Equatable, Sendable {
    case unpriced, needsQuote, insufficient, ready, completed
}

/// A presentation projection, never an allocation or a persisted balance.
nonisolated struct WishCoverage: Equatable, Sendable {
    let state: WishCoverageState
    let progress: Decimal?
    let displayPercent: Int?
    let targetInWallet: Decimal?
    var canRedeem: Bool { state == .ready }

    static func calculate(wish: Wish, walletBalance: Decimal, walletCurrency: String,
                          reference: WishReferenceQuote?) -> Self {
        if wish.state == .completed {
            return Self(state: .completed, progress: 1, displayPercent: 100, targetInWallet: nil)
        }
        guard let target = wish.targetAmount, !target.isNaN, target > 0 else {
            return Self(state: .unpriced, progress: nil, displayPercent: nil, targetInWallet: nil)
        }
        let source = wish.currencyCode ?? walletCurrency
        let quote = reference.flatMap { $0.matches(wishID: wish.id, source: source, target: walletCurrency) && $0.isValid ? $0.quote : nil }
        guard let converted = try? CurrencyEngine.convertToWallet(sourceSignedAmount: target,
            sourceCurrencyCode: source, walletCurrencyCode: walletCurrency, quote: quote, at: reference?.quotedAt ?? wish.createdAt),
              !converted.walletSignedAmount.isNaN, converted.walletSignedAmount > 0 else {
            return Self(state: .needsQuote, progress: nil, displayPercent: nil, targetInWallet: nil)
        }
        let required = converted.walletSignedAmount
        let balance = walletBalance.isNaN ? Decimal.zero : max(0, walletBalance)
        let ready = wish.state == .active && balance >= required
        let progress = min(1, max(0, balance / required))
        var percentage = progress * 100
        var floored = Decimal()
        NSDecimalRound(&floored, &percentage, 0, .down)
        // Readiness comes from the original Decimal comparison, never the label.
        let displayed = ready ? 100 : min(99, max(0, NSDecimalNumber(decimal: floored).intValue))
        return Self(state: ready ? .ready : .insufficient, progress: progress,
                    displayPercent: displayed, targetInWallet: required)
    }
}
