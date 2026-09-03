import Foundation

nonisolated struct WishRedemptionPreview: Equatable, Sendable {
    var wishID: UUID
    var actualAmount: Decimal
    var currencyCode: String
    var walletSignedAmount: Decimal
    var conversion: ConversionSnapshot
    var balanceAfter: Decimal
    var recoveryGapAfter: Decimal
}

nonisolated enum WishRedemptionEngine {
    static func preview(
        ledger: Ledger,
        wishID: UUID,
        actualAmount: Decimal,
        currencyCode: String,
        quote: ExchangeQuote?,
        now: Date
    ) throws -> WishRedemptionPreview {
        let wish = try ledger.requireWish(wishID)
        guard wish.state == .active else { throw LedgerError.wishAlreadyCompleted }
        guard actualAmount > 0 else { throw LedgerError.zeroOrNegativeAmount }

        let converted = try CurrencyEngine.convertToWallet(
            sourceSignedAmount: -actualAmount,
            sourceCurrencyCode: currencyCode,
            walletCurrencyCode: ledger.walletSettings.walletCurrencyCode,
            quote: quote,
            at: now
        )
        let before = WalletLedger.projection(ledger: ledger)
        if before.balance < -converted.walletSignedAmount {
            throw LedgerError.insufficientWishWallet
        }
        let netAfter = before.net + converted.walletSignedAmount

        return WishRedemptionPreview(
            wishID: wishID,
            actualAmount: actualAmount,
            currencyCode: currencyCode,
            walletSignedAmount: converted.walletSignedAmount,
            conversion: converted.snapshot,
            balanceAfter: max(netAfter, 0),
            recoveryGapAfter: max(-netAfter, 0)
        )
    }

    static func confirm(
        ledger: Ledger,
        wishID: UUID,
        actualAmount: Decimal,
        currencyCode: String,
        quote: ExchangeQuote?,
        now: Date,
        expenseID: UUID = UUID(),
        redemptionID: UUID = UUID(),
        walletEntryID: UUID = UUID()
    ) throws -> Ledger {
        let preview = try preview(
            ledger: ledger,
            wishID: wishID,
            actualAmount: actualAmount,
            currencyCode: currencyCode,
            quote: quote,
            now: now
        )

        var ledger = ledger
        let result = try WalletLedger.append(
            ledger: ledger,
            type: .wishRedemption,
            sourceSignedAmount: -actualAmount,
            sourceCurrencyCode: currencyCode,
            quote: quote,
            at: now,
            wishRedemptionID: redemptionID,
            id: walletEntryID
        )
        ledger = result.0

        let expense = Expense(
            id: expenseID,
            originalAmount: actualAmount,
            originalCurrencyCode: currencyCode,
            postedAmount: nil,
            postedCurrencyCode: nil,
            estimatedBudgetAmount: nil,
            estimateRateSource: nil,
            kind: .purchase,
            reversesExpenseID: nil,
            occurredAt: now,
            merchant: nil,
            note: nil,
            budgetPeriodID: nil,
            queuedForBudgetID: nil,
            attributionState: .unbudgeted,
            attributionConfidence: nil,
            wishRedemptionID: redemptionID,
            createdAt: now,
            updatedAt: now
        )
        ledger.upsert(expense)

        let redemption = WishRedemption(
            id: redemptionID,
            wishID: wishID,
            expenseID: expenseID,
            actualAmount: actualAmount,
            currencyCode: currencyCode,
            confirmedAt: now,
            state: .completed,
            walletEntryID: result.1.id
        )
        ledger.upsert(redemption)

        var wish = try ledger.requireWish(wishID)
        wish.state = .completed
        wish.completedAt = now
        ledger.upsert(wish)
        return ledger
    }

    static func refund(
        ledger: Ledger,
        redemptionID: UUID,
        quote: ExchangeQuote?,
        now: Date,
        walletEntryID: UUID = UUID()
    ) throws -> Ledger {
        var ledger = ledger
        guard var redemption = ledger.redemptions[redemptionID] else {
            throw LedgerError.redemptionNotFound
        }
        guard redemption.state == .completed else {
            throw LedgerError.redemptionAlreadyRefunded
        }

        let result = try WalletLedger.append(
            ledger: ledger,
            type: .refund,
            sourceSignedAmount: redemption.actualAmount,
            sourceCurrencyCode: redemption.currencyCode,
            quote: quote,
            at: now,
            wishRedemptionID: redemptionID,
            id: walletEntryID
        )
        ledger = result.0

        redemption.state = .refunded
        ledger.upsert(redemption)

        var wish = try ledger.requireWish(redemption.wishID)
        wish.state = .active
        wish.completedAt = nil
        ledger.upsert(wish)
        return ledger
    }
}
