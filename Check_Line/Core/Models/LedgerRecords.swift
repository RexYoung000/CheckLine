import Foundation

nonisolated struct ConversionSnapshot: Equatable, Sendable, Codable {
    var kind: ConversionKind
    var rate: Decimal
    var quotedAt: Date
    var sourceName: String
}

nonisolated struct ExchangeQuote: Equatable, Sendable {
    var kind: ConversionKind
    var rate: Decimal
    var quotedAt: Date
    var sourceName: String

    var snapshot: ConversionSnapshot {
        ConversionSnapshot(kind: kind, rate: rate, quotedAt: quotedAt, sourceName: sourceName)
    }

    static func identity(at date: Date) -> ExchangeQuote {
        ExchangeQuote(kind: .identity, rate: 1, quotedAt: date, sourceName: "identity")
    }

    static func posted(rate: Decimal, at date: Date, sourceName: String) -> ExchangeQuote {
        ExchangeQuote(kind: .posted, rate: rate, quotedAt: date, sourceName: sourceName)
    }

    static func estimated(rate: Decimal, at date: Date, sourceName: String) -> ExchangeQuote {
        ExchangeQuote(kind: .estimated, rate: rate, quotedAt: date, sourceName: sourceName)
    }
}

nonisolated struct WalletSettings: Equatable, Sendable, Identifiable {
    var id: UUID
    var walletCurrencyCode: String
    var userConfirmedCurrency: Bool
    var setAt: Date
    var updatedAt: Date
}

nonisolated struct Budget: Equatable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var defaultAmount: Decimal
    var defaultCurrencyCode: String
    var cycleType: CycleType
    var recurrence: RecurrenceRule?
    var optionalDeadline: Date?
    var state: BudgetState
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date
}

nonisolated struct BudgetPeriod: Equatable, Sendable, Identifiable {
    var id: UUID
    var budgetID: UUID
    var budgetAmount: Decimal
    var currencyCode: String
    var startDate: Date
    var endDate: Date?
    var state: PeriodState
    var sequence: Int
    var createdAt: Date
}

nonisolated struct Expense: Equatable, Sendable, Identifiable {
    var id: UUID
    var originalAmount: Decimal
    var originalCurrencyCode: String
    var postedAmount: Decimal?
    var postedCurrencyCode: String?
    var estimatedBudgetAmount: Decimal?
    var estimateRateSource: String?
    var kind: ExpenseKind
    var reversesExpenseID: UUID?
    var occurredAt: Date
    var merchant: String?
    var note: String?
    var budgetPeriodID: UUID?
    var queuedForBudgetID: UUID?
    var attributionState: AttributionState
    var attributionConfidence: Decimal?
    var wishRedemptionID: UUID?
    var createdAt: Date
    var updatedAt: Date
}

nonisolated struct ExpenseTag: Equatable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
}

nonisolated struct SourceEvidence: Equatable, Sendable, Identifiable {
    var id: UUID
    var expenseID: UUID
    var sourceType: SourceType
    var externalReferenceHash: String?
    var capturedAt: Date
    var coverageTimestamp: Date?
}

nonisolated struct DataSourceConnection: Equatable, Sendable, Identifiable {
    var id: UUID
    var sourceType: SourceType
    var state: DataSourceState
    var lastCoveredAt: Date?
    var coverageNote: String?
    var lastErrorCode: String?
    var updatedAt: Date
}

nonisolated struct CoverageSnapshot: Equatable, Sendable, Codable {
    var sources: [SourceCoverage]
}

nonisolated struct SourceCoverage: Equatable, Sendable, Codable {
    var sourceTypeRaw: String
    var stateRaw: String
    var lastCoveredAt: Date?
}

nonisolated struct Settlement: Equatable, Sendable, Identifiable {
    var id: UUID
    var periodID: UUID
    var settledAt: Date
    var budgetAmountSnapshot: Decimal
    var currencyCode: String
    var confirmedSpent: Decimal
    var baseSurplus: Decimal
    var coverage: CoverageSnapshot
    var acceptedIncompleteData: Bool
    var createdWalletEntryID: UUID?
}

nonisolated struct SettlementAdjustment: Equatable, Sendable, Identifiable {
    var id: UUID
    var settlementID: UUID
    var reason: AdjustmentReason
    var amountDelta: Decimal
    var confirmedAt: Date
    var sourceExpenseID: UUID?
    var walletEntryID: UUID?
}

nonisolated struct WalletLedgerEntry: Equatable, Sendable, Identifiable {
    var id: UUID
    var type: WalletEntryType
    var sourceSignedAmount: Decimal
    var sourceCurrencyCode: String
    var walletSignedAmount: Decimal
    var walletCurrencyCode: String
    var conversion: ConversionSnapshot
    var settlementID: UUID?
    var adjustmentID: UUID?
    var wishRedemptionID: UUID?
    var occurredAt: Date
    var note: String?
}

nonisolated struct Wish: Equatable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var targetAmount: Decimal?
    var currencyCode: String?
    var referenceURL: String?
    var state: WishState
    var createdAt: Date
    var completedAt: Date?
    var symbolName: String? = nil
}

nonisolated struct WishRedemption: Equatable, Sendable, Identifiable {
    var id: UUID
    var wishID: UUID
    var expenseID: UUID?
    var actualAmount: Decimal
    var currencyCode: String
    var confirmedAt: Date
    var state: WishRedemptionState
    var walletEntryID: UUID
}

nonisolated struct MatchingRule: Equatable, Sendable, Identifiable {
    var id: UUID
    var humanReadableRule: String
    var merchantEquals: String?
    var targetBudgetID: UUID?
    var state: MatchingRuleState
    var confirmedAt: Date?
}

nonisolated struct NormalizedTransactionCandidate: Equatable, Sendable {
    var originalAmount: Decimal
    var originalCurrencyCode: String
    var occurredAt: Date
    var merchant: String?
    var sourceType: SourceType
    var externalReferenceHash: String?
}
