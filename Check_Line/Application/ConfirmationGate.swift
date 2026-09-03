import Foundation

nonisolated enum GateDecision: Equatable, Sendable {
    case executeDirectly
    case confirmStructured
    case confirmImpact
    case refuse(AgentRefusal)
}

nonisolated struct CaptureGateFacts: Equatable, Sendable {
    var hasAmountAndCurrency: Bool
    var isMultiItem: Bool
    var attributionNeedsConfirm: Bool
    var dedupNeedsConfirm: Bool
    var bindsSettledPeriod: Bool
}

nonisolated enum GateRequest: Equatable, Sendable {
    case query
    case capture(CaptureGateFacts)
    case createBudget
    case highImpactChange
    case settlementGrade
    case recommendPurchase
    case outOfScope
}

nonisolated enum ConfirmationGate {
    static func decide(_ request: GateRequest) -> GateDecision {
        switch request {
        case .query:
            return .executeDirectly
        case .capture(let facts):
            if facts.bindsSettledPeriod {
                return .refuse(.bindsSettledPeriod)
            }
            if facts.hasAmountAndCurrency == false {
                return .confirmStructured
            }
            if facts.isMultiItem || facts.attributionNeedsConfirm || facts.dedupNeedsConfirm {
                return .confirmStructured
            }
            return .executeDirectly
        case .createBudget:
            return .confirmStructured
        case .highImpactChange, .settlementGrade:
            return .confirmImpact
        case .recommendPurchase:
            return .refuse(.cannotRecommendPurchases)
        case .outOfScope:
            return .refuse(.outOfScope)
        }
    }
}
