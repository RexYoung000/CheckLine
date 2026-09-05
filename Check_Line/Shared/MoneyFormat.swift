import Foundation

nonisolated enum MoneyFormat {
    static func string(_ amount: Decimal, currencyCode: String) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0...2)))
    }

    static func parseAmount(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), value > 0 else {
            return nil
        }
        return value
    }
}
