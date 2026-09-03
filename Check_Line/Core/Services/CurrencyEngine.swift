import Foundation

nonisolated struct ConvertedWalletAmount: Equatable, Sendable {
    var walletSignedAmount: Decimal
    var snapshot: ConversionSnapshot
}

nonisolated enum CurrencyEngine {
    static func budgetSettlementAmount(expense: Expense, periodCurrencyCode: String) -> Decimal? {
        if let posted = expense.postedAmount, expense.postedCurrencyCode == periodCurrencyCode {
            return posted
        }
        if let estimated = expense.estimatedBudgetAmount {
            return estimated
        }
        if expense.originalCurrencyCode == periodCurrencyCode {
            return expense.originalAmount
        }
        return nil
    }

    static func convertToWallet(
        sourceSignedAmount: Decimal,
        sourceCurrencyCode: String,
        walletCurrencyCode: String,
        quote: ExchangeQuote?,
        at date: Date
    ) throws -> ConvertedWalletAmount {
        if sourceCurrencyCode == walletCurrencyCode {
            return ConvertedWalletAmount(
                walletSignedAmount: sourceSignedAmount,
                snapshot: ExchangeQuote.identity(at: date).snapshot
            )
        }

        guard let quote, quote.kind != .identity else {
            throw LedgerError.missingExchangeRate(source: sourceCurrencyCode, target: walletCurrencyCode)
        }

        return ConvertedWalletAmount(
            walletSignedAmount: sourceSignedAmount * quote.rate,
            snapshot: quote.snapshot
        )
    }
}
