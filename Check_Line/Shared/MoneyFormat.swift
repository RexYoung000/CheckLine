import Foundation

nonisolated enum MoneyFormat {
    static func string(_ amount: Decimal, currencyCode: String) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0...2)))
    }

    // Budget editing must not store precision hidden by the two-place currency display.
    static func parseBudgetAmount(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        let significantDigits = normalized.replacingOccurrences(of: ".", with: "").drop(while: { $0 == "0" })
        guard significantDigits.count <= 38, let value = parseAmount(trimmed), isValidBudgetAmount(value) else { return nil }
        func canonical(_ text: String) -> String {
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            let integer = parts[0].drop(while: { $0 == "0" })
            let fraction = parts.count > 1 ? String(parts[1].reversed().drop(while: { $0 == "0" }).reversed()) : ""
            return (integer.isEmpty ? "0" : String(integer)) + (fraction.isEmpty ? "" : "." + fraction)
        }
        guard canonical(value.description) == canonical(normalized) else { return nil }
        return value
    }

    static func isValidBudgetAmount(_ amount: Decimal) -> Bool {
        guard !amount.isNaN, amount > 0 else { return false }
        var source = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded == amount
    }

    static func parseAmount(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]+)?$"#, options: .regularExpression) != nil else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), value > 0 else {
            return nil
        }
        return value
    }
}
