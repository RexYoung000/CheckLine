import Foundation

nonisolated enum LLMProviderError: Error, Equatable, Sendable {
    case unavailable
    case invalidResponse
}

nonisolated protocol LLMProvider: Sendable {
    func complete(prompt: AgentPrompt) async throws -> AgentIntentCandidate
}

nonisolated struct UnavailableLLMProvider: LLMProvider {
    func complete(prompt: AgentPrompt) async throws -> AgentIntentCandidate {
        throw LLMProviderError.unavailable
    }
}

/// Production switch. Default is off — the App must not enable this until a provider
/// endpoint has passed privacy review and is wired from settings UI.
nonisolated struct LLMProviderSettings: Equatable, Sendable {
    var isEnabled: Bool
    var endpoint: URL?

    static let disabled = LLMProviderSettings(isEnabled: false, endpoint: nil)

    func makeProvider(client: (any HTTPPerforming)? = nil) -> any LLMProvider {
        guard isEnabled, let endpoint else {
            return UnavailableLLMProvider()
        }
        return CloudLLMProvider(endpoint: endpoint, client: client ?? URLSessionHTTPClient())
    }
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
