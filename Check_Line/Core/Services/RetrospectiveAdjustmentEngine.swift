import Foundation

nonisolated struct RetrospectivePreview: Equatable, Sendable {
    var settlementID: UUID
    var periodID: UUID
    var reason: AdjustmentReason
    var amountDelta: Decimal
    var sourceCurrencyCode: String
    var sourceExpenseID: UUID?
    var newPostedAmount: Decimal?
    var walletSignedAmount: Decimal
    var conversion: ConversionSnapshot
    var effectiveSpentAfter: Decimal
    var effectiveSurplusAfter: Decimal
    var balanceAfter: Decimal
    var recoveryGapAfter: Decimal
}

nonisolated enum RetrospectiveAdjustmentEngine {
    static func previewLateExpense(
        ledger: Ledger,
        periodID: UUID,
        expenseID: UUID,
        quote: ExchangeQuote?,
        now: Date
    ) throws -> RetrospectivePreview {
        let expense = try ledger.requireExpense(expenseID)
        guard expense.kind == .purchase else { throw LedgerError.refundMustLinkOriginal }
        return try preview(
            ledger: ledger,
            periodID: periodID,
            reason: .lateExpense,
            amountDelta: try amount(for: expense, periodID: periodID, ledger: ledger),
            sourceExpenseID: expenseID,
            newPostedAmount: nil,
            quote: quote,
            now: now
        )
    }

    static func previewRefund(
        ledger: Ledger,
        originalExpenseID: UUID,
        refundAmount: Decimal,
        quote: ExchangeQuote?,
        now: Date
    ) throws -> RetrospectivePreview {
        let original = try ledger.requireExpense(originalExpenseID)
        guard let periodID = original.budgetPeriodID else {
            throw LedgerError.periodNotFound
        }
        return try preview(
            ledger: ledger,
            periodID: periodID,
            reason: .refund,
            amountDelta: -refundAmount,
            sourceExpenseID: originalExpenseID,
            newPostedAmount: nil,
            quote: quote,
            now: now
        )
    }

    static func previewPostedChange(
        ledger: Ledger,
        expenseID: UUID,
        newPostedAmount: Decimal,
        quote: ExchangeQuote?,
        now: Date
    ) throws -> RetrospectivePreview {
        let expense = try ledger.requireExpense(expenseID)
        guard let periodID = expense.budgetPeriodID else { throw LedgerError.periodNotFound }
        let period = try ledger.requirePeriod(periodID)
        let previous = CurrencyEngine.budgetSettlementAmount(expense: expense, periodCurrencyCode: period.currencyCode) ?? 0
        return try preview(
            ledger: ledger,
            periodID: periodID,
            reason: .postedAmountChange,
            amountDelta: newPostedAmount - previous,
            sourceExpenseID: expenseID,
            newPostedAmount: newPostedAmount,
            quote: quote,
            now: now
        )
    }

    static func confirm(
        ledger: Ledger,
        preview: RetrospectivePreview,
        quote: ExchangeQuote?,
        now: Date,
        adjustmentID: UUID = UUID(),
        walletEntryID: UUID = UUID(),
        bindLateExpense: Bool = true
    ) throws -> Ledger {
        var ledger = ledger
        guard ledger.settlements[preview.settlementID] != nil else {
            throw LedgerError.settlementNotFound
        }

        var walletEntryIDWritten: UUID?
        if preview.amountDelta != 0 {
            let result = try WalletLedger.append(
                ledger: ledger,
                type: preview.reason == .refund ? .refund : .retrospectiveAdjustment,
                sourceSignedAmount: -preview.amountDelta,
                sourceCurrencyCode: preview.sourceCurrencyCode,
                quote: quote,
                at: now,
                settlementID: preview.settlementID,
                adjustmentID: adjustmentID,
                id: walletEntryID
            )
            ledger = result.0
            walletEntryIDWritten = result.1.id
        }

        let adjustment = SettlementAdjustment(
            id: adjustmentID,
            settlementID: preview.settlementID,
            reason: preview.reason,
            amountDelta: preview.amountDelta,
            confirmedAt: now,
            sourceExpenseID: preview.sourceExpenseID,
            walletEntryID: walletEntryIDWritten
        )
        ledger.upsert(adjustment)

        if let expenseID = preview.sourceExpenseID {
            var expense = try ledger.requireExpense(expenseID)
            switch preview.reason {
            case .lateExpense where bindLateExpense:
                expense.budgetPeriodID = preview.periodID
                expense.queuedForBudgetID = nil
                expense.attributionState = .confirmed
                expense.attributionConfidence = 1
            case .postedAmountChange:
                if let newPostedAmount = preview.newPostedAmount {
                    expense.postedAmount = newPostedAmount
                    expense.postedCurrencyCode = preview.sourceCurrencyCode
                }
            default:
                break
            }
            expense.updatedAt = now
            ledger.upsert(expense)
        }

        return ledger
    }

    static func effectiveResult(settlement: Settlement, adjustments: [SettlementAdjustment]) -> (spent: Decimal, surplus: Decimal) {
        let delta = adjustments.reduce(Decimal.zero) { $0 + $1.amountDelta }
        let spent = settlement.confirmedSpent + delta
        return (spent, settlement.budgetAmountSnapshot - spent)
    }

    private static func preview(
        ledger: Ledger,
        periodID: UUID,
        reason: AdjustmentReason,
        amountDelta: Decimal,
        sourceExpenseID: UUID,
        newPostedAmount: Decimal?,
        quote: ExchangeQuote?,
        now: Date
    ) throws -> RetrospectivePreview {
        let period = try ledger.requirePeriod(periodID)
        guard period.state == .settled else { throw LedgerError.periodNotSettled }
        guard let settlement = ledger.settlement(forPeriod: periodID) else {
            throw LedgerError.settlementNotFound
        }

        _ = try ledger.requireExpense(sourceExpenseID)
        let existing = ledger.adjustments.values.filter { $0.settlementID == settlement.id }
        let effective = effectiveResult(settlement: settlement, adjustments: Array(existing))
        let spentAfter = effective.spent + amountDelta
        let surplusAfter = settlement.budgetAmountSnapshot - spentAfter

        let conversion: ConvertedWalletAmount
        if amountDelta == 0 {
            conversion = ConvertedWalletAmount(
                walletSignedAmount: 0,
                snapshot: ExchangeQuote.identity(at: now).snapshot
            )
        } else {
            conversion = try CurrencyEngine.convertToWallet(
                sourceSignedAmount: -amountDelta,
                sourceCurrencyCode: period.currencyCode,
                walletCurrencyCode: ledger.walletSettings.walletCurrencyCode,
                quote: quote,
                at: now
            )
        }
        let netAfter = WalletLedger.projection(ledger: ledger).net + conversion.walletSignedAmount

        return RetrospectivePreview(
            settlementID: settlement.id,
            periodID: periodID,
            reason: reason,
            amountDelta: amountDelta,
            sourceCurrencyCode: period.currencyCode,
            sourceExpenseID: sourceExpenseID,
            newPostedAmount: newPostedAmount,
            walletSignedAmount: conversion.walletSignedAmount,
            conversion: conversion.snapshot,
            effectiveSpentAfter: spentAfter,
            effectiveSurplusAfter: surplusAfter,
            balanceAfter: max(netAfter, 0),
            recoveryGapAfter: max(-netAfter, 0)
        )
    }

    private static func amount(for expense: Expense, periodID: UUID, ledger: Ledger) throws -> Decimal {
        let period = try ledger.requirePeriod(periodID)
        guard let value = CurrencyEngine.budgetSettlementAmount(expense: expense, periodCurrencyCode: period.currencyCode) else {
            throw LedgerError.missingExchangeRate(source: expense.originalCurrencyCode, target: period.currencyCode)
        }
        return value
    }

}
