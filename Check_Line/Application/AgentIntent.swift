import Foundation

nonisolated enum AgentRefusal: Error, Equatable, Sendable {
    case outOfScope
    case confirmationRequired
    case missingAmount
    case bindsSettledPeriod
    case cannotRecommendPurchases
    case domain(LedgerError)
}

nonisolated struct CaptureDraft: Equatable, Sendable {
    var amount: Decimal?
    var currencyCode: String?
    var occurredAt: Date
    var merchant: String?
    var note: String?
    var periodID: UUID?
    var budgetID: UUID?
    var tagNames: [String] = []
    var isMultiItem: Bool = false
    var sourceType: SourceType = .agentText
}

nonisolated struct CreateBudgetDraft: Equatable, Sendable {
    var name: String
    var amount: Decimal
    var currencyCode: String
    var cycleType: CycleType
    var recurrence: RecurrenceRule?
    var startDate: Date
    var endDate: Date?
}

nonisolated enum AgentIntent: Equatable, Sendable {
    case capture(CaptureDraft)
    case queryBudgetStatus(budgetID: UUID)
    case createBudget(CreateBudgetDraft)
    case adjustPeriodAmount(periodID: UUID, newAmount: Decimal)
    case deleteExpense(expenseID: UUID)
    case settlePeriod(periodID: UUID, quote: ExchangeQuote?)
    case redeemWish(wishID: UUID, actualAmount: Decimal, currencyCode: String, quote: ExchangeQuote?)
    case lateExpense(periodID: UUID, expenseID: UUID, quote: ExchangeQuote?)
    case recommendPurchase
    case outOfScope
}

nonisolated struct ImpactAcknowledgement: Equatable, Sendable {
    var acceptedIncompleteData: Bool = false
    var quote: ExchangeQuote? = nil
    var realPurchaseConfirmed: Bool = false
}

nonisolated enum AgentConfirmation: Equatable, Sendable {
    case none
    case accepted
    case attribution(AttributionDecision)
    case impact(ImpactAcknowledgement)
}

nonisolated enum AgentPresentation: Equatable, Sendable {
    case panel
    case confirmStructured
    case fullscreenImpact
}

nonisolated struct PeriodAmountImpact: Equatable, Sendable {
    var periodID: UUID
    var previousAmount: Decimal
    var newAmount: Decimal
    var snapshotAfter: PeriodBudgetSnapshot
}

nonisolated enum AgentImpact: Equatable, Sendable {
    case settlement(SettlementPreview)
    case wish(WishRedemptionPreview)
    case retrospective(RetrospectivePreview)
    case periodAmount(PeriodAmountImpact)
    case deleteExpense(periodSnapshotAfter: PeriodBudgetSnapshot?)
}

nonisolated struct AgentEvaluation: Equatable, Sendable {
    var presentation: AgentPresentation
    var gate: GateDecision
    var structuredProposal: AttributionDecision?
    var impact: AgentImpact?
    var query: PeriodBudgetSnapshot?
    var refusal: AgentRefusal?
}

nonisolated struct AgentExecution: Equatable, Sendable {
    var ledger: Ledger
    var undo: UndoToken?
    var query: PeriodBudgetSnapshot?
}
