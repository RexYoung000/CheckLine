import Foundation

nonisolated struct AgentPrompt: Equatable, Sendable {
    var system: String
    var userMessage: String
    var context: AgentContext

    static let systemText = """
    You are CheckLine's budget-loop action agent.
    Return exactly one JSON object that matches AgentIntentCandidate. No prose, no tools, no function calls.
    Do not compute balances, remaining, surplus, overrun, or wish-wallet figures. Do not invent amounts.
    Allowed intentType values:
    capture, queryBudgetStatus, createBudget, adjustPeriodAmount, deleteExpense, settlePeriod, redeemWish, lateExpense, recommendPurchase, outOfScope, needsClarification
    JSON fields (amounts are decimal strings, never numbers):
    intentType, amount, currencyCode, merchant, note, occurredAt, periodID, budgetID, budgetName, tagNames, isMultiItem, name, cycleType, startDate, endDate, newAmount, expenseID, wishID, actualAmount, clarificationField, clarificationOptions
    If the user asks for investment, loans, insurance, tax, or financial planning: intentType=outOfScope.
    If the user asks you to recommend what to buy: intentType=recommendPurchase.
    If a required field is missing or ambiguous: intentType=needsClarification with clarificationField and optional clarificationOptions.
    """

    static func make(userMessage: String, context: AgentContext) -> AgentPrompt {
        AgentPrompt(system: systemText, userMessage: userMessage, context: context)
    }

    var requestPayload: LLMRequestPayload {
        LLMRequestPayload(system: system, userMessage: userMessage, context: context)
    }
}
