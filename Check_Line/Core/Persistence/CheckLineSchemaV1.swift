import Foundation
import SwiftData

enum CheckLineSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            PersistedWalletSettings.self,
            PersistedBudget.self,
            PersistedBudgetPeriod.self,
            PersistedExpense.self,
            PersistedExpenseTag.self,
            PersistedSourceEvidence.self,
            PersistedDataSourceConnection.self,
            PersistedSettlement.self,
            PersistedSettlementAdjustment.self,
            PersistedWalletLedgerEntry.self,
            PersistedWish.self,
            PersistedWishRedemption.self,
            PersistedMatchingRule.self
        ]
    }
}

enum CheckLineMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CheckLineSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

@Model
final class PersistedWalletSettings {
    @Attribute(.unique) var id: UUID
    var walletCurrencyCode: String
    var userConfirmedCurrency: Bool
    var setAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        walletCurrencyCode: String,
        userConfirmedCurrency: Bool = false,
        setAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.walletCurrencyCode = walletCurrencyCode
        self.userConfirmedCurrency = userConfirmedCurrency
        self.setAt = setAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PersistedBudget {
    @Attribute(.unique) var id: UUID
    var name: String
    var defaultAmount: Decimal
    var defaultCurrencyCode: String
    var cycleTypeRaw: String
    var recurrenceRule: String?
    var optionalDeadline: Date?
    var stateRaw: String
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \PersistedBudgetPeriod.budget)
    var periods: [PersistedBudgetPeriod] = []
    @Relationship(deleteRule: .nullify, inverse: \PersistedExpense.queuedForBudget)
    var queuedExpenses: [PersistedExpense] = []

    init(
        id: UUID = UUID(),
        name: String,
        defaultAmount: Decimal,
        defaultCurrencyCode: String,
        cycleTypeRaw: String,
        recurrenceRule: String? = nil,
        optionalDeadline: Date? = nil,
        stateRaw: String,
        sortIndex: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.defaultAmount = defaultAmount
        self.defaultCurrencyCode = defaultCurrencyCode
        self.cycleTypeRaw = cycleTypeRaw
        self.recurrenceRule = recurrenceRule
        self.optionalDeadline = optionalDeadline
        self.stateRaw = stateRaw
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PersistedBudgetPeriod {
    @Attribute(.unique) var id: UUID
    var budgetAmount: Decimal
    var currencyCode: String
    var startDate: Date
    var endDate: Date?
    var stateRaw: String
    var sequence: Int
    var createdAt: Date
    var budget: PersistedBudget?
    @Relationship(deleteRule: .nullify, inverse: \PersistedExpense.budgetPeriod)
    var expenses: [PersistedExpense] = []
    @Relationship(deleteRule: .cascade, inverse: \PersistedSettlement.period)
    var settlements: [PersistedSettlement] = []

    init(
        id: UUID = UUID(),
        budgetAmount: Decimal,
        currencyCode: String,
        startDate: Date,
        endDate: Date?,
        stateRaw: String,
        sequence: Int,
        createdAt: Date,
        budget: PersistedBudget? = nil
    ) {
        self.id = id
        self.budgetAmount = budgetAmount
        self.currencyCode = currencyCode
        self.startDate = startDate
        self.endDate = endDate
        self.stateRaw = stateRaw
        self.sequence = sequence
        self.createdAt = createdAt
        self.budget = budget
    }
}

@Model
final class PersistedExpense {
    @Attribute(.unique) var id: UUID
    var originalAmount: Decimal
    var originalCurrencyCode: String
    var postedAmount: Decimal?
    var postedCurrencyCode: String?
    var estimatedBudgetAmount: Decimal?
    var estimateRateSource: String?
    var kindRaw: String
    var occurredAt: Date
    var merchant: String?
    var note: String?
    var attributionStateRaw: String
    var attributionConfidence: Decimal?
    var createdAt: Date
    var updatedAt: Date
    var budgetPeriod: PersistedBudgetPeriod?
    var queuedForBudget: PersistedBudget?
    var reversesExpense: PersistedExpense?
    var wishRedemption: PersistedWishRedemption?
    @Relationship(deleteRule: .cascade, inverse: \PersistedSourceEvidence.expense)
    var sourceEvidence: [PersistedSourceEvidence] = []
    var tags: [PersistedExpenseTag] = []

    init(
        id: UUID = UUID(),
        originalAmount: Decimal,
        originalCurrencyCode: String,
        kindRaw: String,
        occurredAt: Date,
        attributionStateRaw: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.originalAmount = originalAmount
        self.originalCurrencyCode = originalCurrencyCode
        self.kindRaw = kindRaw
        self.occurredAt = occurredAt
        self.attributionStateRaw = attributionStateRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PersistedExpenseTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(inverse: \PersistedExpense.tags)
    var expenses: [PersistedExpense] = []

    init(id: UUID = UUID(), name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class PersistedSourceEvidence {
    @Attribute(.unique) var id: UUID
    var sourceTypeRaw: String
    var externalReferenceHash: String?
    var capturedAt: Date
    var coverageTimestamp: Date?
    var metadataEnvelope: Data?
    var expense: PersistedExpense?

    init(
        id: UUID = UUID(),
        sourceTypeRaw: String,
        capturedAt: Date,
        expense: PersistedExpense? = nil
    ) {
        self.id = id
        self.sourceTypeRaw = sourceTypeRaw
        self.capturedAt = capturedAt
        self.expense = expense
    }
}

@Model
final class PersistedDataSourceConnection {
    @Attribute(.unique) var id: UUID
    var sourceTypeRaw: String
    var stateRaw: String
    var lastCoveredAt: Date?
    var coverageNote: String?
    var lastErrorCode: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sourceTypeRaw: String,
        stateRaw: String,
        updatedAt: Date
    ) {
        self.id = id
        self.sourceTypeRaw = sourceTypeRaw
        self.stateRaw = stateRaw
        self.updatedAt = updatedAt
    }
}

@Model
final class PersistedSettlement {
    @Attribute(.unique) var id: UUID
    var settledAt: Date
    var budgetAmountSnapshot: Decimal
    var currencyCode: String
    var confirmedSpent: Decimal
    var baseSurplus: Decimal
    var coverageSnapshot: Data?
    var acceptedIncompleteData: Bool
    var createdAt: Date
    var period: PersistedBudgetPeriod?
    var createdWalletEntry: PersistedWalletLedgerEntry?
    @Relationship(deleteRule: .cascade, inverse: \PersistedSettlementAdjustment.settlement)
    var adjustments: [PersistedSettlementAdjustment] = []

    init(
        id: UUID = UUID(),
        settledAt: Date,
        budgetAmountSnapshot: Decimal,
        currencyCode: String,
        confirmedSpent: Decimal,
        baseSurplus: Decimal,
        acceptedIncompleteData: Bool,
        createdAt: Date,
        period: PersistedBudgetPeriod? = nil
    ) {
        self.id = id
        self.settledAt = settledAt
        self.budgetAmountSnapshot = budgetAmountSnapshot
        self.currencyCode = currencyCode
        self.confirmedSpent = confirmedSpent
        self.baseSurplus = baseSurplus
        self.acceptedIncompleteData = acceptedIncompleteData
        self.createdAt = createdAt
        self.period = period
    }
}

@Model
final class PersistedSettlementAdjustment {
    @Attribute(.unique) var id: UUID
    var reasonRaw: String
    var amountDelta: Decimal
    var confirmedAt: Date
    var settlement: PersistedSettlement?
    var sourceExpense: PersistedExpense?
    var walletEntry: PersistedWalletLedgerEntry?

    init(
        id: UUID = UUID(),
        reasonRaw: String,
        amountDelta: Decimal,
        confirmedAt: Date,
        settlement: PersistedSettlement? = nil
    ) {
        self.id = id
        self.reasonRaw = reasonRaw
        self.amountDelta = amountDelta
        self.confirmedAt = confirmedAt
        self.settlement = settlement
    }
}

@Model
final class PersistedWalletLedgerEntry {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var sourceSignedAmount: Decimal
    var sourceCurrencyCode: String
    var walletSignedAmount: Decimal
    var walletCurrencyCode: String
    var conversionSnapshot: Data
    var occurredAt: Date
    var note: String?
    var settlement: PersistedSettlement?
    var adjustment: PersistedSettlementAdjustment?
    var wishRedemption: PersistedWishRedemption?

    init(
        id: UUID = UUID(),
        typeRaw: String,
        sourceSignedAmount: Decimal,
        sourceCurrencyCode: String,
        walletSignedAmount: Decimal,
        walletCurrencyCode: String,
        conversionSnapshot: Data,
        occurredAt: Date
    ) {
        self.id = id
        self.typeRaw = typeRaw
        self.sourceSignedAmount = sourceSignedAmount
        self.sourceCurrencyCode = sourceCurrencyCode
        self.walletSignedAmount = walletSignedAmount
        self.walletCurrencyCode = walletCurrencyCode
        self.conversionSnapshot = conversionSnapshot
        self.occurredAt = occurredAt
    }
}

@Model
final class PersistedWish {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Decimal?
    var currencyCode: String?
    var referenceURL: String?
    var symbolName: String? = nil
    var stateRaw: String
    var createdAt: Date
    var completedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \PersistedWishRedemption.wish)
    var redemptions: [PersistedWishRedemption] = []

    init(
        id: UUID = UUID(),
        name: String,
        stateRaw: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.stateRaw = stateRaw
        self.createdAt = createdAt
    }
}

@Model
final class PersistedWishRedemption {
    @Attribute(.unique) var id: UUID
    var actualAmount: Decimal
    var currencyCode: String
    var confirmedAt: Date
    var stateRaw: String
    var wish: PersistedWish?
    var expense: PersistedExpense?
    var walletEntry: PersistedWalletLedgerEntry?

    init(
        id: UUID = UUID(),
        actualAmount: Decimal,
        currencyCode: String,
        confirmedAt: Date,
        stateRaw: String,
        wish: PersistedWish? = nil
    ) {
        self.id = id
        self.actualAmount = actualAmount
        self.currencyCode = currencyCode
        self.confirmedAt = confirmedAt
        self.stateRaw = stateRaw
        self.wish = wish
    }
}

@Model
final class PersistedMatchingRule {
    @Attribute(.unique) var id: UUID
    var humanReadableRule: String
    var structuredPredicate: Data
    var stateRaw: String
    var confirmedAt: Date?
    var targetBudget: PersistedBudget?
    var targetTags: [PersistedExpenseTag] = []

    init(
        id: UUID = UUID(),
        humanReadableRule: String,
        structuredPredicate: Data,
        stateRaw: String
    ) {
        self.id = id
        self.humanReadableRule = humanReadableRule
        self.structuredPredicate = structuredPredicate
        self.stateRaw = stateRaw
    }
}
