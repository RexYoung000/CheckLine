import Foundation

nonisolated enum LLMProviderError: Error, Equatable, Sendable {
    case unavailable
    case invalidResponse
}

nonisolated protocol LLMProvider: Sendable {
    func complete(prompt: AgentPrompt) async throws -> AgentIntentCandidate
}

nonisolated struct MockLLMProvider: LLMProvider {
    private let handler: @Sendable (AgentPrompt) async throws -> AgentIntentCandidate

    init(handler: @escaping @Sendable (AgentPrompt) async throws -> AgentIntentCandidate) {
        self.handler = handler
    }

    func complete(prompt: AgentPrompt) async throws -> AgentIntentCandidate {
        try await handler(prompt)
    }

    static func stub(_ candidate: AgentIntentCandidate) -> MockLLMProvider {
        MockLLMProvider { _ in candidate }
    }

    static func unavailable() -> MockLLMProvider {
        MockLLMProvider { _ in throw LLMProviderError.unavailable }
    }
}
