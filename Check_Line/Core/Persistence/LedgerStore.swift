import Foundation
import SwiftData

enum LedgerStore {
    static func load(from context: ModelContext, now: Date = Date()) throws -> Ledger {
        let settingsRecords = try context.fetch(FetchDescriptor<PersistedWalletSettings>())
        let walletSettings: WalletSettings
        if let stored = settingsRecords.first {
            walletSettings = WalletSettings(
                id: stored.id,
                walletCurrencyCode: stored.walletCurrencyCode,
                userConfirmedCurrency: stored.userConfirmedCurrency,
                setAt: stored.setAt,
                updatedAt: stored.updatedAt
            )
        } else {
            walletSettings = WalletSettings(
                id: UUID(),
                walletCurrencyCode: "CNY",
                userConfirmedCurrency: false,
                setAt: now,
                updatedAt: now
            )
        }

        var ledger = Ledger(walletSettings: walletSettings)

        for record in try context.fetch(FetchDescriptor<PersistedBudget>()) {
            guard let cycleType = CycleType(rawValue: record.cycleTypeRaw),
                  let state = BudgetState(rawValue: record.stateRaw) else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.budgets[record.id] = Budget(
                id: record.id,
                name: record.name,
                defaultAmount: record.defaultAmount,
                defaultCurrencyCode: record.defaultCurrencyCode,
                cycleType: cycleType,
                recurrence: RecurrenceRule.parse(record.recurrenceRule),
                optionalDeadline: record.optionalDeadline,
                state: state,
                sortIndex: record.sortIndex,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }

        for record in try context.fetch(FetchDescriptor<PersistedBudgetPeriod>()) {
            guard let budgetID = record.budget?.id,
                  let state = PeriodState(rawValue: record.stateRaw) else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.periods[record.id] = BudgetPeriod(
                id: record.id,
                budgetID: budgetID,
                budgetAmount: record.budgetAmount,
                currencyCode: record.currencyCode,
                startDate: record.startDate,
                endDate: record.endDate,
                state: state,
                sequence: record.sequence,
                createdAt: record.createdAt
            )
        }

        for record in try context.fetch(FetchDescriptor<PersistedExpenseTag>()) {
            ledger.tags[record.id] = ExpenseTag(id: record.id, name: record.name, createdAt: record.createdAt)
        }

        for record in try context.fetch(FetchDescriptor<PersistedWish>()) {
            guard let state = WishState(rawValue: record.stateRaw) else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.wishes[record.id] = Wish(
                id: record.id,
                name: record.name,
                targetAmount: record.targetAmount,
                currencyCode: record.currencyCode,
                referenceURL: record.referenceURL,
                state: state,
                createdAt: record.createdAt,
                completedAt: record.completedAt,
                symbolName: record.symbolName
            )
        }

        for record in try context.fetch(FetchDescriptor<PersistedExpense>()) {
            guard let kind = ExpenseKind(rawValue: record.kindRaw),
                  let attribution = AttributionState(rawValue: record.attributionStateRaw) else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.expenses[record.id] = Expense(
                id: record.id,
                originalAmount: record.originalAmount,
                originalCurrencyCode: record.originalCurrencyCode,
                postedAmount: record.postedAmount,
                postedCurrencyCode: record.postedCurrencyCode,
                estimatedBudgetAmount: record.estimatedBudgetAmount,
                estimateRateSource: record.estimateRateSource,
                kind: kind,
                reversesExpenseID: record.reversesExpense?.id,
                occurredAt: record.occurredAt,
                merchant: record.merchant,
                note: record.note,
                budgetPeriodID: record.budgetPeriod?.id,
                queuedForBudgetID: record.queuedForBudget?.id,
                attributionState: attribution,
                attributionConfidence: record.attributionConfidence,
                wishRedemptionID: record.wishRedemption?.id,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            ledger.expenseTagIDs[record.id] = record.tags.map(\.id)
        }

        for record in try context.fetch(FetchDescriptor<PersistedSourceEvidence>()) {
            guard let expenseID = record.expense?.id,
                  let sourceType = SourceType(rawValue: record.sourceTypeRaw) else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.evidences[record.id] = SourceEvidence(
                id: record.id,
                expenseID: expenseID,
                sourceType: sourceType,
                externalReferenceHash: record.externalReferenceHash,
                capturedAt: record.capturedAt,
                coverageTimestamp: record.coverageTimestamp
            )
        }

        for record in try context.fetch(FetchDescriptor<PersistedDataSourceConnection>()) {
            guard let sourceType = SourceType(rawValue: record.sourceTypeRaw),
                  let state = DataSourceState(rawValue: record.stateRaw) else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.dataSources[record.id] = DataSourceConnection(
                id: record.id,
                sourceType: sourceType,
                state: state,
                lastCoveredAt: record.lastCoveredAt,
                coverageNote: record.coverageNote,
                lastErrorCode: record.lastErrorCode,
                updatedAt: record.updatedAt
            )
        }

        for record in try context.fetch(FetchDescriptor<PersistedWalletLedgerEntry>()) {
            guard let type = WalletEntryType(rawValue: record.typeRaw) else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.walletEntries[record.id] = WalletLedgerEntry(
                id: record.id,
                type: type,
                sourceSignedAmount: record.sourceSignedAmount,
                sourceCurrencyCode: record.sourceCurrencyCode,
                walletSignedAmount: record.walletSignedAmount,
                walletCurrencyCode: record.walletCurrencyCode,
                conversion: try PersistenceCoding.decodeConversion(record.conversionSnapshot),
                settlementID: record.settlement?.id,
                adjustmentID: record.adjustment?.id,
                wishRedemptionID: record.wishRedemption?.id,
                occurredAt: record.occurredAt,
                note: record.note
            )
        }

        for record in try context.fetch(FetchDescriptor<PersistedSettlement>()) {
            guard let periodID = record.period?.id else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.settlements[record.id] = Settlement(
                id: record.id,
                periodID: periodID,
                settledAt: record.settledAt,
                budgetAmountSnapshot: record.budgetAmountSnapshot,
                currencyCode: record.currencyCode,
                confirmedSpent: record.confirmedSpent,
                baseSurplus: record.baseSurplus,
                coverage: try PersistenceCoding.decodeCoverage(record.coverageSnapshot),
                acceptedIncompleteData: record.acceptedIncompleteData,
                createdWalletEntryID: record.createdWalletEntry?.id
            )
        }

        for record in try context.fetch(FetchDescriptor<PersistedSettlementAdjustment>()) {
            guard let settlementID = record.settlement?.id,
                  let reason = AdjustmentReason(rawValue: record.reasonRaw) else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.adjustments[record.id] = SettlementAdjustment(
                id: record.id,
                settlementID: settlementID,
                reason: reason,
                amountDelta: record.amountDelta,
                confirmedAt: record.confirmedAt,
                sourceExpenseID: record.sourceExpense?.id,
                walletEntryID: record.walletEntry?.id
            )
        }

        for record in try context.fetch(FetchDescriptor<PersistedWishRedemption>()) {
            guard let wishID = record.wish?.id,
                  let state = WishRedemptionState(rawValue: record.stateRaw),
                  let walletEntryID = record.walletEntry?.id else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.redemptions[record.id] = WishRedemption(
                id: record.id,
                wishID: wishID,
                expenseID: record.expense?.id,
                actualAmount: record.actualAmount,
                currencyCode: record.currencyCode,
                confirmedAt: record.confirmedAt,
                state: state,
                walletEntryID: walletEntryID
            )
        }

        for record in try context.fetch(FetchDescriptor<PersistedMatchingRule>()) {
            guard let state = MatchingRuleState(rawValue: record.stateRaw) else {
                throw PersistenceError.invalidStoredValue
            }
            ledger.matchingRules[record.id] = MatchingRule(
                id: record.id,
                humanReadableRule: record.humanReadableRule,
                merchantEquals: try PersistenceCoding.decodeMatchingPredicate(record.structuredPredicate),
                targetBudgetID: record.targetBudget?.id,
                state: state,
                confirmedAt: record.confirmedAt
            )
        }

        return ledger
    }

    static func replaceAll(_ ledger: Ledger, in context: ModelContext) throws {
        try deleteAll(in: context)
        try insert(ledger, into: context)
        try context.save()
    }

    private static func deleteAll(in context: ModelContext) throws {
        try delete(PersistedMatchingRule.self, in: context)
        try delete(PersistedSettlementAdjustment.self, in: context)
        try delete(PersistedWishRedemption.self, in: context)
        try delete(PersistedWalletLedgerEntry.self, in: context)
        try delete(PersistedSettlement.self, in: context)
        try delete(PersistedSourceEvidence.self, in: context)
        try delete(PersistedExpense.self, in: context)
        try delete(PersistedExpenseTag.self, in: context)
        try delete(PersistedBudgetPeriod.self, in: context)
        try delete(PersistedBudget.self, in: context)
        try delete(PersistedWish.self, in: context)
        try delete(PersistedDataSourceConnection.self, in: context)
        try delete(PersistedWalletSettings.self, in: context)
    }

    private static func delete<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<T>()) {
            context.delete(record)
        }
    }

    private static func insert(_ ledger: Ledger, into context: ModelContext) throws {
        let settings = PersistedWalletSettings(
            id: ledger.walletSettings.id,
            walletCurrencyCode: ledger.walletSettings.walletCurrencyCode,
            userConfirmedCurrency: ledger.walletSettings.userConfirmedCurrency,
            setAt: ledger.walletSettings.setAt,
            updatedAt: ledger.walletSettings.updatedAt
        )
        context.insert(settings)

        var budgets: [UUID: PersistedBudget] = [:]
        for budget in ledger.budgets.values {
            let record = PersistedBudget(
                id: budget.id,
                name: budget.name,
                defaultAmount: budget.defaultAmount,
                defaultCurrencyCode: budget.defaultCurrencyCode,
                cycleTypeRaw: budget.cycleType.rawValue,
                recurrenceRule: budget.recurrence?.stored,
                optionalDeadline: budget.optionalDeadline,
                stateRaw: budget.state.rawValue,
                sortIndex: budget.sortIndex,
                createdAt: budget.createdAt,
                updatedAt: budget.updatedAt
            )
            context.insert(record)
            budgets[budget.id] = record
        }

        var periods: [UUID: PersistedBudgetPeriod] = [:]
        for period in ledger.periods.values {
            let record = PersistedBudgetPeriod(
                id: period.id,
                budgetAmount: period.budgetAmount,
                currencyCode: period.currencyCode,
                startDate: period.startDate,
                endDate: period.endDate,
                stateRaw: period.state.rawValue,
                sequence: period.sequence,
                createdAt: period.createdAt,
                budget: budgets[period.budgetID]
            )
            context.insert(record)
            periods[period.id] = record
        }

        var tags: [UUID: PersistedExpenseTag] = [:]
        for tag in ledger.tags.values {
            let record = PersistedExpenseTag(id: tag.id, name: tag.name, createdAt: tag.createdAt)
            context.insert(record)
            tags[tag.id] = record
        }

        var wishes: [UUID: PersistedWish] = [:]
        for wish in ledger.wishes.values {
            let record = PersistedWish(
                id: wish.id,
                name: wish.name,
                stateRaw: wish.state.rawValue,
                createdAt: wish.createdAt
            )
            record.targetAmount = wish.targetAmount
            record.currencyCode = wish.currencyCode
            record.referenceURL = wish.referenceURL
            record.symbolName = wish.symbolName
            record.completedAt = wish.completedAt
            context.insert(record)
            wishes[wish.id] = record
        }

        var expenses: [UUID: PersistedExpense] = [:]
        for expense in ledger.expenses.values {
            let record = PersistedExpense(
                id: expense.id,
                originalAmount: expense.originalAmount,
                originalCurrencyCode: expense.originalCurrencyCode,
                kindRaw: expense.kind.rawValue,
                occurredAt: expense.occurredAt,
                attributionStateRaw: expense.attributionState.rawValue,
                createdAt: expense.createdAt,
                updatedAt: expense.updatedAt
            )
            record.postedAmount = expense.postedAmount
            record.postedCurrencyCode = expense.postedCurrencyCode
            record.estimatedBudgetAmount = expense.estimatedBudgetAmount
            record.estimateRateSource = expense.estimateRateSource
            record.merchant = expense.merchant
            record.note = expense.note
            record.attributionConfidence = expense.attributionConfidence
            record.budgetPeriod = expense.budgetPeriodID.flatMap { periods[$0] }
            record.queuedForBudget = expense.queuedForBudgetID.flatMap { budgets[$0] }
            record.tags = (ledger.expenseTagIDs[expense.id] ?? []).compactMap { tags[$0] }
            context.insert(record)
            expenses[expense.id] = record
        }

        for expense in ledger.expenses.values {
            expenses[expense.id]?.reversesExpense = expense.reversesExpenseID.flatMap { expenses[$0] }
        }

        for evidence in ledger.evidences.values {
            let record = PersistedSourceEvidence(
                id: evidence.id,
                sourceTypeRaw: evidence.sourceType.rawValue,
                capturedAt: evidence.capturedAt,
                expense: expenses[evidence.expenseID]
            )
            record.externalReferenceHash = evidence.externalReferenceHash
            record.coverageTimestamp = evidence.coverageTimestamp
            context.insert(record)
        }

        for source in ledger.dataSources.values {
            let record = PersistedDataSourceConnection(
                id: source.id,
                sourceTypeRaw: source.sourceType.rawValue,
                stateRaw: source.state.rawValue,
                updatedAt: source.updatedAt
            )
            record.lastCoveredAt = source.lastCoveredAt
            record.coverageNote = source.coverageNote
            record.lastErrorCode = source.lastErrorCode
            context.insert(record)
        }

        var walletEntries: [UUID: PersistedWalletLedgerEntry] = [:]
        for entry in ledger.walletEntries.values {
            let record = PersistedWalletLedgerEntry(
                id: entry.id,
                typeRaw: entry.type.rawValue,
                sourceSignedAmount: entry.sourceSignedAmount,
                sourceCurrencyCode: entry.sourceCurrencyCode,
                walletSignedAmount: entry.walletSignedAmount,
                walletCurrencyCode: entry.walletCurrencyCode,
                conversionSnapshot: try PersistenceCoding.encodeConversion(entry.conversion),
                occurredAt: entry.occurredAt
            )
            record.note = entry.note
            context.insert(record)
            walletEntries[entry.id] = record
        }

        var settlements: [UUID: PersistedSettlement] = [:]
        for settlement in ledger.settlements.values {
            let record = PersistedSettlement(
                id: settlement.id,
                settledAt: settlement.settledAt,
                budgetAmountSnapshot: settlement.budgetAmountSnapshot,
                currencyCode: settlement.currencyCode,
                confirmedSpent: settlement.confirmedSpent,
                baseSurplus: settlement.baseSurplus,
                acceptedIncompleteData: settlement.acceptedIncompleteData,
                createdAt: settlement.settledAt,
                period: periods[settlement.periodID]
            )
            record.coverageSnapshot = try PersistenceCoding.encodeCoverage(settlement.coverage)
            record.createdWalletEntry = settlement.createdWalletEntryID.flatMap { walletEntries[$0] }
            context.insert(record)
            settlements[settlement.id] = record
        }

        var adjustments: [UUID: PersistedSettlementAdjustment] = [:]
        for adjustment in ledger.adjustments.values {
            let record = PersistedSettlementAdjustment(
                id: adjustment.id,
                reasonRaw: adjustment.reason.rawValue,
                amountDelta: adjustment.amountDelta,
                confirmedAt: adjustment.confirmedAt,
                settlement: settlements[adjustment.settlementID]
            )
            record.sourceExpense = adjustment.sourceExpenseID.flatMap { expenses[$0] }
            record.walletEntry = adjustment.walletEntryID.flatMap { walletEntries[$0] }
            context.insert(record)
            adjustments[adjustment.id] = record
        }

        var redemptions: [UUID: PersistedWishRedemption] = [:]
        for redemption in ledger.redemptions.values {
            let record = PersistedWishRedemption(
                id: redemption.id,
                actualAmount: redemption.actualAmount,
                currencyCode: redemption.currencyCode,
                confirmedAt: redemption.confirmedAt,
                stateRaw: redemption.state.rawValue,
                wish: wishes[redemption.wishID]
            )
            record.expense = redemption.expenseID.flatMap { expenses[$0] }
            record.walletEntry = walletEntries[redemption.walletEntryID]
            context.insert(record)
            redemptions[redemption.id] = record
        }

        for expense in ledger.expenses.values {
            expenses[expense.id]?.wishRedemption = expense.wishRedemptionID.flatMap { redemptions[$0] }
        }

        for entry in ledger.walletEntries.values {
            let record = walletEntries[entry.id]
            record?.settlement = entry.settlementID.flatMap { settlements[$0] }
            record?.adjustment = entry.adjustmentID.flatMap { adjustments[$0] }
            record?.wishRedemption = entry.wishRedemptionID.flatMap { redemptions[$0] }
        }

        for rule in ledger.matchingRules.values {
            let record = PersistedMatchingRule(
                id: rule.id,
                humanReadableRule: rule.humanReadableRule,
                structuredPredicate: try PersistenceCoding.encodeMatchingPredicate(merchantEquals: rule.merchantEquals),
                stateRaw: rule.state.rawValue
            )
            record.confirmedAt = rule.confirmedAt
            record.targetBudget = rule.targetBudgetID.flatMap { budgets[$0] }
            context.insert(record)
        }
    }
}
