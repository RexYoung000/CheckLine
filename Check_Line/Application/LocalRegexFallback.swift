import Foundation

nonisolated enum LocalRegexFallback {
    static func candidate(from text: String) -> AgentIntentCandidate {
        if isBudgetCreationRequest(text) {
            return AgentIntentCandidate(
                intentType: "createBudget",
                amount: extractAmount(from: text),
                currencyCode: extractCurrency(from: text),
                name: extractBudgetName(from: text),
                cycleType: extractBudgetCycle(from: text)
            )
        }
        guard isCaptureRequest(text) else { return .clarification(field: "input") }
        return AgentIntentCandidate.capture(
            amount: extractAmount(from: text),
            currencyCode: extractCurrency(from: text),
            merchant: extractMerchant(from: text)
        )
    }

    /// Intent to start a record is not a merchant name, nor permission to save one.
    static func isExplicitRecordRequest(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return ["记一笔", "录一笔", "录入", "记录一笔", "再记", "另记", "record ", "log "]
            .contains { lowered.contains($0) }
    }

    static func isAmountReply(_ text: String) -> Bool {
        text.range(of: #"(?i)^\s*(?:(?:改成|改为|金额是?|花了|是|amount(?: is)?|change to)\s*)?[¥￥$€£]?\s*[0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?\s*(?:元|块|人民币|美元|日元|欧元|港币|CNY|USD|JPY|EUR|GBP|HKD)?\s*[。.!！]?\s*$"#, options: .regularExpression) != nil
    }

    static func isCurrencyReply(_ text: String) -> Bool {
        text.range(of: #"(?i)^\s*(?:(?:币种|货币|改成|改为|用|currency|change to)\s*)?(?:人民币|美元|日元|欧元|港币|CNY|USD|JPY|EUR|GBP|HKD)\s*[。.!！]?\s*$"#, options: .regularExpression) != nil
    }

    private static func isCaptureRequest(_ text: String) -> Bool {
        let lowered = text.lowercased()
        // Questions and unrelated numbers must not silently become expenses.
        if ["天气", "气温", "几度", "星期", "几点", "你好", "hello", "weather", "temperature"]
            .contains(where: { lowered.contains($0) }) { return false }
        if isExplicitRecordRequest(text) { return true }
        if ["花了", "消费", "买了", "付了", "支出", "午餐", "晚餐", "早餐", "咖啡", "打车", "车费", "spent", "paid", "lunch", "dinner", "coffee"]
            .contains(where: { lowered.contains($0) }) { return true }
        guard extractAmount(from: text) != nil, extractMerchant(from: text) != nil else { return false }
        if text.contains("?") || text.contains("？") { return false }
        return extractCurrency(from: text) != nil
            || text.range(of: #"^\s*[^0-9\s]{1,24}\s+[0-9]+(?:\.[0-9]+)?\s*$"#, options: .regularExpression) != nil
    }

    static func isBudgetCreationRequest(_ text: String) -> Bool {
        let lowered = text.lowercased()
        guard text.contains("预算") || lowered.contains("budget") else { return false }
        if ["还剩", "剩余", "还能花", "已用", "已花", "花了", "记到", "remaining", "spent"].contains(where: { lowered.contains($0) }) {
            return false
        }
        let createWords = ["创建", "新建", "建立", "设立", "设置", "设个", "设一个", "做个", "做一个", "做一张", "开个", "开一张", "create", "set up", "make a"]
        let cycleWords = ["每月", "每个月", "月度", "按月", "一次性", "单次", "monthly", "one-time", "one time"]
        return createWords.contains(where: { lowered.contains($0) })
            || (cycleWords.contains(where: { lowered.contains($0) }) && extractAmount(from: text) != nil)
    }

    static func extractBudgetName(from text: String) -> String? {
        var remainder = replacing(
            #"(?i)[¥￥$€£]?\s*(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\.[0-9]+)?\s*(?:元|人民币|CNY|USD|EUR|GBP|HKD|JPY)?"#,
            in: text,
            with: " "
        )
        let filler = ["我想要", "我想", "想要", "帮我", "给我", "请", "做一个", "做一张", "做个", "开一个", "开一张", "开个", "创建", "新建", "建立", "设立", "设置", "设定", "一个", "一张", "每个月", "每月", "月度", "按月", "一次性", "单次", "预算卡", "预算", "额度", "金额", "循环", "人民币", "美元", "日元", "欧元", "港币", "块钱", "块", "为", "是"]
        for word in filler { remainder = remainder.replacingOccurrences(of: word, with: " ") }
        remainder = replacing(#"(?i)\b(?:create|set up|make|a|an|monthly|one-time|one|time|budget|card|amount|cny|usd|eur|gbp|hkd|jpy|for)\b"#, in: remainder, with: " ")
        remainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        remainder = replacing(#"\s+"#, in: remainder, with: " ")
        return remainder.isEmpty ? nil : remainder
    }

    static func extractBudgetCycle(from text: String) -> String? {
        let lowered = text.lowercased()
        if ["每周", "每星期", "weekly"].contains(where: { lowered.contains($0) }) { return nil }
        if ["每月", "每个月", "月度", "按月", "monthly"].contains(where: { lowered.contains($0) }) { return CycleType.repeating.rawValue }
        if ["一次性", "单次", "one-time", "one time", "one-off"].contains(where: { lowered.contains($0) }) { return CycleType.oneShot.rawValue }
        return nil
    }

    static func extractAmount(from text: String) -> String? {
        let value = #"((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\.[0-9]+)?)"#
        let patterns = [
            #"[¥￥]\s*"# + value,
            #"\$\s*"# + value,
            #"€\s*"# + value,
            #"£\s*"# + value,
            value + #"\s*元"#,
            #"(?i)"# + value + #"\s*(?:CNY|USD|EUR|GBP|HKD|JPY)"#,
            value,
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
        if text.contains("€") || lowered.contains("eur") || text.contains("欧元") {
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
        if text.contains("$") || lowered.contains("usd") || text.contains("美元") {
            return "USD"
        }
        if text.contains("¥") || text.contains("￥") || text.contains("元") || lowered.contains("cny") || text.contains("人民币") {
            return "CNY"
        }
        return nil
    }

    static func extractMerchant(from text: String) -> String? {
        if isAmountReply(text) || isCurrencyReply(text) { return nil }
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
        let stopwords = ["我想要", "我想", "想要", "想", "帮我", "请", "再记一笔", "另记一笔", "记录一笔", "记一笔", "录一笔", "录入", "再记", "另记", "一笔", "花了", "消费", "买了", "付了", "一共", "刚才", "今天", "昨天", "美元", "日元", "欧元", "人民币", "刚", "在", "买", "花"]
        for word in stopwords {
            remainder = remainder.replacingOccurrences(of: word, with: " ")
        }
        remainder = replacing(#"(?i)\b(?:please|record|log|spent|paid|cny|usd|eur|gbp|hkd|jpy)\b"#, in: remainder, with: " ")
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
