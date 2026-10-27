import Foundation
import Observation

/// A user-entered reference for this wish and this exact currency pair, not a ledger quote.
nonisolated struct WishReferenceQuote: Codable, Equatable, Sendable {
    let wishID: UUID
    let sourceCurrency: String
    let walletCurrency: String
    let rate: Decimal
    let quotedAt: Date

    var isValid: Bool {
        !rate.isNaN && rate > 0 && sourceCurrency != walletCurrency
        && Locale.commonISOCurrencyCodes.contains(sourceCurrency)
        && Locale.commonISOCurrencyCodes.contains(walletCurrency)
        && quotedAt.timeIntervalSinceReferenceDate.isFinite
    }
    var quote: ExchangeQuote { .estimated(rate: rate, at: quotedAt, sourceName: "user_provided_estimate") }
    var key: String { [wishID.uuidString, sourceCurrency, walletCurrency].joined(separator: "_") }
    func matches(wishID: UUID, source: String, target: String) -> Bool {
        self.wishID == wishID && sourceCurrency == source && walletCurrency == target
    }
}

@MainActor @Observable
final class WishReferenceQuoteStore {
    private(set) var revision = 0
    @ObservationIgnored private var cache: [String: WishReferenceQuote] = [:]
    private let root: URL?

    init(root: URL? = nil, inMemory: Bool = false) {
        self.root = inMemory ? nil : root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WishReferenceQuotes", isDirectory: true)
    }

    func reference(for wishID: UUID, source: String, target: String) throws -> WishReferenceQuote? {
        _ = revision
        guard Locale.commonISOCurrencyCodes.contains(source), Locale.commonISOCurrencyCodes.contains(target), source != target else { return nil }
        let key = [wishID.uuidString, source, target].joined(separator: "_")
        if let cached = cache[key] { return cached }
        guard let root else { return nil }
        let url = root.appendingPathComponent(key).appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let reference = try JSONDecoder().decode(WishReferenceQuote.self, from: Data(contentsOf: url))
        guard reference.matches(wishID: wishID, source: source, target: target), reference.isValid else {
            throw CocoaError(.fileReadCorruptFile)
        }
        cache[key] = reference
        return reference
    }

    func apply(_ reference: WishReferenceQuote) throws {
        guard reference.isValid else { throw LedgerError.invalidExchangeRate }
        if var root {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try root.setResourceValues(values)
            try JSONEncoder().encode(reference).write(to: root.appendingPathComponent(reference.key).appendingPathExtension("json"),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        // Only expose a changed reference after the durable write succeeds.
        cache[reference.key] = reference
        revision += 1
    }
}
