import Foundation
import Observation
import Security

/// A single private test connection. Provider secrets are never provisioned to the App.
nonisolated struct PrivateAgentCredential: Codable, Equatable, Sendable {
    var endpoint: URL
    var token: String
    var expiresAt: Date

    func isValid(at now: Date) -> Bool {
        endpoint.scheme == "https" && endpoint.user == nil && endpoint.password == nil
            && endpoint.query == nil && endpoint.fragment == nil && endpoint.host != nil
            && endpoint.path == "/v1/agent/interpret" && token.count >= 32
            && !token.contains(where: \.isWhitespace) && expiresAt > now
    }
}

@MainActor @Observable final class CloudAgentSettings {
    private(set) var credential: PrivateAgentCredential?
    var consent: Bool? { didSet { defaults?.set(consent, forKey: "checkline.cloudAgentConsent") } }
    private let defaults: UserDefaults?
    @ObservationIgnored var httpClient: (any HTTPPerforming)?

    init(credential: PrivateAgentCredential? = nil, consent: Bool? = nil,
         defaults: UserDefaults? = nil, httpClient: (any HTTPPerforming)? = nil) {
        self.credential = credential; self.defaults = defaults; self.httpClient = httpClient
        self.consent = consent
    }
    var isConfigured: Bool { credential != nil }
    var isEnabled: Bool { consent == true }
    var isAvailable: Bool { credential?.isValid(at: Date()) == true }

    func provider(at now: Date) throws -> CloudLLMProvider {
        guard consent == true, let credential, credential.isValid(at: now) else { throw LLMProviderError.unauthorized }
        return CloudLLMProvider(endpoint: credential.endpoint, client: httpClient ?? URLSessionHTTPClient(), authorizationToken: credential.token)
    }

    static func loadForDevice() -> CloudAgentSettings {
        let defaults = UserDefaults.standard
        let consent = defaults.object(forKey: "checkline.cloudAgentConsent") as? Bool
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let importURL = applicationSupport.appendingPathComponent("CheckLineAgentProvisioning.json")
        if FileManager.default.fileExists(atPath: importURL.path) {
            // Remove the one-time transport file on both success and failure.
            defer { try? FileManager.default.removeItem(at: importURL) }
            if let bytes = try? Data(contentsOf: importURL),
               let credential = try? decoder.decode(PrivateAgentCredential.self, from: bytes),
               credential.isValid(at: Date()), let data = try? encoder.encode(credential) {
                _ = AgentCredentialKeychain.save(data)
            }
        }
        let credential = AgentCredentialKeychain.load().flatMap { try? decoder.decode(PrivateAgentCredential.self, from: $0) }
        return CloudAgentSettings(credential: credential, consent: consent, defaults: defaults)
    }
}

private enum AgentCredentialKeychain {
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "CheckLine.PrivateAgent",
         kSecAttrAccount as String: "connection-v1"]
    }
    static func save(_ data: Data) -> Bool {
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        return SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }
    static func load() -> Data? {
        var result: CFTypeRef?
        var request = query; request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
}
