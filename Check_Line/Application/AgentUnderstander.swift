import Foundation

nonisolated enum AgentInput: Equatable, Sendable {
    case text(String)
    case speechTranscription(String)
    case ocrText(String)

    var text: String {
        switch self {
        case .text(let value), .speechTranscription(let value), .ocrText(let value):
            return value
        }
    }

    var sourceType: SourceType {
        switch self {
        case .text:
            return .agentText
        case .speechTranscription:
            return .voice
        case .ocrText:
            return .image
        }
    }
}

nonisolated struct AgentUnderstander: Sendable {
    var provider: any LLMProvider

    func understand(input: AgentInput, ledger: Ledger, now: Date) async -> AgentUnderstandResult {
        let text = input.text
        switch BudgetLoopInterpreter.interpret(text: text) {
        case .recommendPurchase:
            return .intent(.recommendPurchase)
        case .outOfScope:
            return .intent(.outOfScope)
        default:
            break
        }

        let prompt = AgentPrompt.make(
            userMessage: text,
            context: AgentContextBuilder.build(ledger)
        )
        let candidate: AgentIntentCandidate
        do {
            candidate = try await provider.complete(prompt: prompt)
        } catch {
            candidate = LocalRegexFallback.candidate(from: text)
        }
        return IntentValidator.validate(
            candidate,
            ledger: ledger,
            now: now,
            sourceType: input.sourceType
        )
    }
}
