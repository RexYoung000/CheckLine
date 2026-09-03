import Foundation

nonisolated struct SettlementPreview: Equatable, Sendable {
    var periodID: UUID
    var budgetAmount: Decimal
    var currencyCode: String
    var confirmedSpent: Decimal
    var pendingAmount: Decimal
    var pendingCount: Int
    var unbudgetedCount: Int
    var baseSurplus: Decimal
    var coverage: CoverageSnapshot
    var hasCoverageGap: Bool
    var hasBlockingPending: Bool
    var walletSignedAmount: Decimal
    var conversion: ConversionSnapshot
    var balanceAfter: Decimal
    var recoveryGapAfter: Decimal
}

nonisolated enum SettlementEngine {
    static func preview(
        ledger: Ledger,
        periodID: UUID,
        now: Date,
        calendar: Calendar,
        quote: ExchangeQuote?
    ) throws -> SettlementPreview {
        let period = try ledger.requirePeriod(periodID)
        guard period.state == .pendingSettlement else {
            throw LedgerError.periodNotReadyToSettle
        }

        let snapshot = BudgetEngine.periodSnapshot(period: period, expenses: Array(ledger.expenses.values))
        let pendingItems = ledger.expenses(inPeriod: periodID).filter { $0.attributionState == .pending }
        let unbudgeted = ledger.expenses.values.filter {
            $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil
        }
        let coverage = coverageSnapshot(ledger: ledger)
        let hasCoverageGap = coverage.sources.contains { source in
            source.stateRaw == DataSourceState.connected.rawValue
                && gapAfterPeriod(source.lastCoveredAt, period: period, calendar: calendar)
        }

        let walletBefore = WalletLedger.projection(ledger: ledger)
        let conversion: ConvertedWalletAmount
        if snapshot.remaining == 0 {
            conversion = ConvertedWalletAmount(
                walletSignedAmount: 0,
                snapshot: ExchangeQuote.identity(at: now).snapshot
            )
        } else {
            conversion = try CurrencyEngine.convertToWallet(
                sourceSignedAmount: snapshot.remaining,
                sourceCurrencyCode: period.currencyCode,
                walletCurrencyCode: ledger.walletSettings.walletCurrencyCode,
                quote: quote,
                at: now
            )
        }
        let netAfter = walletBefore.net + conversion.walletSignedAmount

        return SettlementPreview(
            periodID: periodID,
            budgetAmount: period.budgetAmount,
            currencyCode: period.currencyCode,
            confirmedSpent: snapshot.confirmedSpent,
            pendingAmount: snapshot.pendingAmount,
            pendingCount: pendingItems.count,
            unbudgetedCount: unbudgeted.count,
            baseSurplus: snapshot.remaining,
            coverage: coverage,
            hasCoverageGap: hasCoverageGap,
            hasBlockingPending: snapshot.pendingAmount != 0,
            walletSignedAmount: conversion.walletSignedAmount,
            conversion: conversion.snapshot,
            balanceAfter: max(netAfter, 0),
            recoveryGapAfter: max(-netAfter, 0)
        )
    }

    static func commit(
        ledger: Ledger,
        periodID: UUID,
        now: Date,
        calendar: Calendar,
        quote: ExchangeQuote?,
        acceptedIncompleteData: Bool,
        settlementID: UUID = UUID(),
        walletEntryID: UUID = UUID(),
        nextPeriodID: UUID = UUID()
    ) throws -> Ledger {
        let preview = try preview(
            ledger: ledger,
            periodID: periodID,
            now: now,
            calendar: calendar,
            quote: quote
        )

        if (preview.hasBlockingPending || preview.hasCoverageGap) && acceptedIncompleteData == false {
            throw LedgerError.incompleteSettlementNotAccepted
        }

        var ledger = ledger
        let period = try ledger.requirePeriod(periodID)
        var budget = try ledger.requireBudget(period.budgetID)

        var walletEntryIDWritten: UUID?
        if preview.baseSurplus != 0 {
            let type: WalletEntryType = preview.baseSurplus > 0 ? .surplus : .overrun
            let result = try WalletLedger.append(
                ledger: ledger,
                type: type,
                sourceSignedAmount: preview.baseSurplus,
                sourceCurrencyCode: period.currencyCode,
                quote: quote,
                at: now,
                settlementID: settlementID,
                note: nil,
                id: walletEntryID
            )
            ledger = result.0
            walletEntryIDWritten = result.1.id
        }

        let settlement = Settlement(
            id: settlementID,
            periodID: periodID,
            settledAt: now,
            budgetAmountSnapshot: period.budgetAmount,
            currencyCode: period.currencyCode,
            confirmedSpent: preview.confirmedSpent,
            baseSurplus: preview.baseSurplus,
            coverage: preview.coverage,
            acceptedIncompleteData: acceptedIncompleteData,
            createdWalletEntryID: walletEntryIDWritten
        )
        ledger.upsert(settlement)

        period.state = .settled
        ledger.upsert(period)

        if budget.cycleType == .repeating {
            ledger = try CycleEngine.openNextPeriod(
                ledger: ledger,
                settledPeriodID: periodID,
                now: now,
                calendar: calendar,
                newPeriodID: nextPeriodID
            )
        } else {
            budget.state = .archived
            budget.updatedAt = now
            ledger.upsert(budget)
        }

        return ledger
    }

    private static func coverageSnapshot(ledger: Ledger) -> CoverageSnapshot {
        let sources = ledger.dataSources.values
            .sorted { $0.sourceType.rawValue < $1.sourceType.rawValue }
            .map {
                SourceCoverage(
                    sourceTypeRaw: $0.sourceType.rawValue,
                    stateRaw: $0.state.rawValue,
                    lastCoveredAt: $0.lastCoveredAt
                )
            }
        return CoverageSnapshot(sources: sources)
    }

    private static func gapAfterPeriod(_ lastCoveredAt: Date?, period: BudgetPeriod, calendar: Calendar) -> Bool {
        guard let lastCoveredAt else { return true }
        guard let exclusiveEnd = CycleEngine.exclusiveEnd(of: period, calendar: calendar) else {
            return false
        }
        return lastCoveredAt < exclusiveEnd
    }
}
