import Foundation

nonisolated enum LedgerError: Error, Equatable, Sendable {
    case captureDateOutsidePeriod
    case walletCurrencyLocked
    case missingExchangeRate(source: String, target: String)
    case invalidExchangeRate
    case invalidBudgetAmount
    case unchangedBudgetAmount
    case budgetAmountEditUnavailable
    case staleBudgetAmountPreview
    case staleSettlementPreview
    case insufficientWishWallet
    case periodNotSettled
    case periodAlreadySettled
    case periodNotReadyToSettle
    case incompleteSettlementNotAccepted
    case expenseAlreadyHasSettlementPeriod
    case cannotBindSettledPeriod
    case cannotBindWishRedemptionToBudget
    case cannotQueueOnActivePeriod
    case queuedAndBoundAreExclusive
    case originalExpenseMissing
    case refundMustLinkOriginal
    case budgetNotFound
    case periodNotFound
    case expenseNotFound
    case wishNotFound
    case redemptionNotFound
    case settlementNotFound
    case staleRetrospectivePreview
    case oneShotDoesNotOpenNextPeriod
    case repeatingBudgetNeedsRecurrence
    case walletCurrencyMismatch
    case zeroOrNegativeAmount
    case wishAlreadyCompleted
    case redemptionAlreadyRefunded
}
