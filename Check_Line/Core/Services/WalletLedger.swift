import Foundation

nonisolated struct WalletProjection: Equatable, Sendable {
    let net: Decimal
    let balance: Decimal
    let recoveryGap: Decimal
}

nonisolated enum WalletLedger {
    static func projection(entries: [WalletLedgerEntry]) -> WalletProjection {
        let net = entries.reduce(Decimal.zero) { $0 + $1.walletSignedAmount }
        return WalletProjection(
            net: net,
            balance: max(net, 0),
            recoveryGap: max(-net, 0)
        )
    }

    static func projection(ledger: Ledger) -> WalletProjection {
        projection(entries: Array(ledger.walletEntries.values))
    }

    static func setWalletCurrency(
        ledger: Ledger,
        currencyCode: String,
        now: Date
    ) throws -> Ledger {
        var ledger = ledger
        if ledger.walletEntries.isEmpty == false, ledger.walletSettings.walletCurrencyCode != currencyCode {
            throw LedgerError.walletCurrencyLocked
        }
        ledger.walletSettings.walletCurrencyCode = currencyCode
        ledger.walletSettings.userConfirmedCurrency = true
        ledger.walletSettings.updatedAt = now
        if ledger.walletEntries.isEmpty {
            ledger.walletSettings.setAt = now
        }
        return ledger
    }

    static func append(
        ledger: Ledger,
        type: WalletEntryType,
        sourceSignedAmount: Decimal,
        sourceCurrencyCode: String,
        quote: ExchangeQuote?,
        at date: Date,
        settlementID: UUID? = nil,
        adjustmentID: UUID? = nil,
        wishRedemptionID: UUID? = nil,
        note: String? = nil,
        id: UUID = UUID()
    ) throws -> (Ledger, WalletLedgerEntry) {
        if sourceSignedAmount == 0 {
            throw LedgerError.zeroOrNegativeAmount
        }

        let converted = try CurrencyEngine.convertToWallet(
            sourceSignedAmount: sourceSignedAmount,
            sourceCurrencyCode: sourceCurrencyCode,
            walletCurrencyCode: ledger.walletSettings.walletCurrencyCode,
            quote: quote,
            at: date
        )

        let entry = WalletLedgerEntry(
            id: id,
            type: type,
            sourceSignedAmount: sourceSignedAmount,
            sourceCurrencyCode: sourceCurrencyCode,
            walletSignedAmount: converted.walletSignedAmount,
            walletCurrencyCode: ledger.walletSettings.walletCurrencyCode,
            conversion: converted.snapshot,
            settlementID: settlementID,
            adjustmentID: adjustmentID,
            wishRedemptionID: wishRedemptionID,
            occurredAt: date,
            note: note
        )

        var ledger = ledger
        ledger.upsert(entry)
        return (ledger, entry)
    }
}
