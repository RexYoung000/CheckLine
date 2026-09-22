import Foundation

nonisolated enum MoneyFormat {
    static func string(_ amount: Decimal, currencyCode: String) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0...2)))
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
