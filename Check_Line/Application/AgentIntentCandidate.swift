import Foundation

/// Untrusted model output. Monetary fields stay strings until `IntentValidator` parses them.
nonisolated struct AgentIntentCandidate: Equatable, Sendable, Codable {
    var intentType: String
    var amount: String? = nil
    var currencyCode: String? = nil
    var merchant: String? = nil
    var note: String? = nil
    var occurredAt: String? = nil
    var periodID: String? = nil
    var budgetID: String? = nil
    var budgetName: String? = nil
    var tagNames: [String]? = nil
    var isMultiItem: Bool? = nil
    var name: String? = nil
    var cycleType: String? = nil
    var startDate: String? = nil
    var endDate: String? = nil
    var newAmount: String? = nil
    var expenseID: String? = nil
    var wishID: String? = nil
    var actualAmount: String? = nil
    var clarificationField: String? = nil
    var clarificationOptions: [String]? = nil

    static func clarification(field: String, options: [String] = []) -> AgentIntentCandidate {
        AgentIntentCandidate(
            intentType: "needsClarification",
            clarificationField: field,
            clarificationOptions: options
        )
    }

    static func capture(amount: String? = nil, currencyCode: String? = nil, merchant: String? = nil) -> AgentIntentCandidate {
        AgentIntentCandidate(
            intentType: "capture",
            amount: amount,
            currencyCode: currencyCode,
            merchant: merchant
        )
    }
}
