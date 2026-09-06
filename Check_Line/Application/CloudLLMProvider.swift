import Foundation

nonisolated protocol HTTPPerforming: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

nonisolated struct URLSessionHTTPClient: HTTPPerforming {
    var session: URLSession = .shared

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// Exact JSON body sent to a cloud model. Field set is the privacy allowlist.
nonisolated struct LLMRequestPayload: Equatable, Sendable, Codable {
    var system: String
    var userMessage: String
    var context: AgentContext

    var jsonUTF8: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(self)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

extension AgentPrompt {
    nonisolated var requestPayload: LLMRequestPayload {
        LLMRequestPayload(system: system, userMessage: userMessage, context: context)
    }
}

nonisolated struct CloudLLMProvider: LLMProvider {
    var endpoint: URL
    var client: any HTTPPerforming
    var timeout: TimeInterval = 15

    func complete(prompt: AgentPrompt) async throws -> AgentIntentCandidate {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(prompt.requestPayload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await client.data(for: request)
        } catch {
            throw LLMProviderError.unavailable
        }

        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw LLMProviderError.unavailable
        }
        do {
            return try JSONDecoder().decode(AgentIntentCandidate.self, from: data)
        } catch {
            throw LLMProviderError.invalidResponse
        }
    }
}
