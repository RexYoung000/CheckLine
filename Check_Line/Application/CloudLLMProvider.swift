import Foundation

nonisolated protocol HTTPPerforming: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

nonisolated struct URLSessionHTTPClient: HTTPPerforming {
    var session: URLSession = URLSession(configuration: .ephemeral, delegate: NoAgentRedirects(), delegateQueue: nil)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

private final class NoAgentRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
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

nonisolated struct CloudLLMProvider: LLMProvider {
    var endpoint: URL
    var client: any HTTPPerforming
    var timeout: TimeInterval = 15
    var authorizationToken: String? = nil

    nonisolated func complete(prompt: AgentPrompt) async throws -> AgentIntentCandidate {
        guard endpoint.scheme == "https", endpoint.user == nil, endpoint.password == nil else { throw LLMProviderError.unavailable }
        try Task.checkCancellation()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authorizationToken { request.setValue("Bearer " + authorizationToken, forHTTPHeaderField: "Authorization") }
        let payload = LLMRequestPayload(
            system: prompt.system,
            userMessage: prompt.userMessage,
            context: prompt.context
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await client.data(for: request)
        } catch is CancellationError { throw LLMProviderError.cancelled
        } catch let error as URLError where error.code == .cancelled { throw LLMProviderError.cancelled
        } catch let error as URLError where error.code == .timedOut { throw LLMProviderError.timedOut
        } catch {
            throw LLMProviderError.unavailable
        }

        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw LLMProviderError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw LLMProviderError.unauthorized }
        if http.statusCode == 429 { throw LLMProviderError.rateLimited }
        if http.statusCode == 504 { throw LLMProviderError.timedOut }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw LLMProviderError.unavailable
        }
        guard data.count <= 65_536 else { throw LLMProviderError.invalidResponse }
        do {
            return try JSONDecoder().decode(AgentIntentCandidate.self, from: data)
        } catch {
            throw LLMProviderError.invalidResponse
        }
    }
}
