import Foundation

nonisolated enum LocalRegexFallback {
    static func candidate(from text: String) -> AgentIntentCandidate {
        AgentIntentCandidate.capture(
            amount: extractAmount(from: text),
            currencyCode: extractCurrency(from: text),
            merchant: extractMerchant(from: text)
        )
    }

    static func extractAmount(from text: String) -> String? {
        let patterns = [
            #"¥\s*(\d+(?:\.\d+)?)"#,
            #"\$\s*(\d+(?:\.\d+)?)"#,
            #"€\s*(\d+(?:\.\d+)?)"#,
            #"£\s*(\d+(?:\.\d+)?)"#,
            #"(\d+(?:\.\d+)?)\s*元"#,
            #"(?i)(\d+(?:\.\d+)?)\s*(?:CNY|USD|EUR|GBP|HKD|JPY)"#,
            #"(\d+(?:\.\d+)?)"#,
        ]
        for pattern in patterns {
            if let value = firstCapture(pattern, in: text) {
                return value
            }
        }
        return nil
    }

    static func extractCurrency(from text: String) -> String? {
        let lowered = text.lowercased()
        if text.contains("¥") || text.contains("元") || lowered.contains("cny") || text.contains("人民币") {
            return "CNY"
        }
        if text.contains("€") || lowered.contains("eur") {
            return "EUR"
        }
        if text.contains("£") || lowered.contains("gbp") {
            return "GBP"
        }
        if lowered.contains("hkd") || text.contains("港币") || text.contains("港幣") {
            return "HKD"
        }
        if lowered.contains("jpy") || text.contains("日元") {
            return "JPY"
        }
        if text.contains("$") || lowered.contains("usd") {
            return "USD"
        }
        return nil
    }

    static func extractMerchant(from text: String) -> String? {
        if let named = firstCapture(#"在\s*([^0-9¥$€£，。,\s]{1,30}?)\s*(?:花了|花|消费|买了|买)"#, in: text) {
            return named
        }
        var remainder = text
        let stripPatterns = [
            #"¥\s*\d+(?:\.\d+)?"#,
            #"\$\s*\d+(?:\.\d+)?"#,
            #"€\s*\d+(?:\.\d+)?"#,
            #"£\s*\d+(?:\.\d+)?"#,
            #"\d+(?:\.\d+)?\s*元"#,
            #"(?i)\d+(?:\.\d+)?\s*(?:CNY|USD|EUR|GBP|HKD|JPY)"#,
            #"\d+(?:\.\d+)?"#,
        ]
        for pattern in stripPatterns {
            remainder = replacing(pattern, in: remainder, with: " ")
        }
        let stopwords = ["花了", "消费", "买了", "一共", "刚才", "今天", "昨天", "刚", "在", "买", "花"]
        for word in stopwords {
            remainder = remainder.replacingOccurrences(of: word, with: " ")
        }
        remainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        remainder = remainder.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard remainder.isEmpty == false, remainder.count <= 30 else { return nil }
        return remainder
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
            return nil
        }
        guard let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        let value = String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func replacing(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}
