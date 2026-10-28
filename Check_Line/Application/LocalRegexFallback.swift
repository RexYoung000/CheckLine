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
        guard !requiresConsumptionClarification(text) else { return .clarification(field: "input") }
        let captureText = textExcludingDateReferences(text)
        guard isCaptureRequest(captureText) else { return .clarification(field: "input") }
        return AgentIntentCandidate.capture(
            amount: extractAmount(from: captureText),
            currencyCode: extractCurrency(from: text),
            merchant: extractMerchant(from: captureText)
        )
    }

    enum CaptureDateReference: Equatable {
        case unspecified
        case dayOffset(Int)
        case requiresReview
    }

    // Only simple relative days are resolved locally. Other date language is a
    // reason to show the existing date review, never a default to today's date.
    private static let numericDatePattern = #"(?<![0-9])(?:[0-9]{4}[-/.年][0-9]{1,2}[-/.月][0-9]{1,2}[日号]?(?:T[0-9:.]+(?:Z|[+-][0-9]{2}:[0-9]{2}))?|[0-9]{1,2}月[0-9]{1,2}[日号]?|[0-9]{1,2}[/\-][0-9]{1,2})(?![0-9])"#
    private static let relativeDatePattern = #"(?i)(?:大前天|前天|昨天|今天|明天|后天|(?:上|下|本|这)(?:个)?(?:星期|礼拜|周|月)(?:[一二三四五六日天])?|(?:星期|礼拜|周)[一二三四五六日天末]|[一二三四五六七八九十]+月[一二三四五六七八九十]+[日号]|\b(?:day before yesterday|day after tomorrow|yesterday|today|tomorrow|(?:last|next|this)\s+(?:week|month|monday|tuesday|wednesday|thursday|friday|saturday|sunday))\b)"#

    static func captureDateReference(in text: String) -> CaptureDateReference {
        let hasNumericDate = text.range(of: numericDatePattern, options: .regularExpression) != nil
        let relative = (try? NSRegularExpression(pattern: relativeDatePattern))?
            .matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        let hasDateWording = text.range(of: #"(?i)日期|哪天|某天|几天前|几天后|\bdate\b"#, options: .regularExpression) != nil
        guard hasNumericDate || !relative.isEmpty || hasDateWording else { return .unspecified }
        let uncertain = text.range(of: #"(?i)不是|并非|不在|不确定|不清楚|记不清|不知道|忘了?|好像|可能|大概|也许|\b(?:not|wasn['’]?t|isn['’]?t|maybe|unsure|unknown|uncertain)\b"#, options: .regularExpression) != nil
        guard !hasNumericDate, !uncertain, relative.count == 1,
              let match = relative.first, let range = Range(match.range, in: text) else { return .requiresReview }
        switch text[range].lowercased() {
        case "今天", "today": return .dayOffset(0)
        case "昨天", "yesterday": return .dayOffset(-1)
        case "前天", "day before yesterday": return .dayOffset(-2)
        default: return .requiresReview
        }
    }

    static func isDateReply(_ text: String) -> Bool {
        guard captureDateReference(in: text) != .unspecified else { return false }
        let remainder = replacing(#"(?i)这笔|这次|该笔|日期|时间|不是|并非|不在|不确定|不清楚|记不清|不知道|忘了?|改为|改成|更正|的|是在|是|在|\b(?:date|not|wasn['’]?t|isn['’]?t|unsure|unknown|uncertain)\b"#,
                                  in: textExcludingDateReferences(text), with: " ")
        return remainder.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).isEmpty
    }

    private static func textExcludingDateReferences(_ text: String) -> String {
        let withoutNumericDates = replacing(numericDatePattern, in: text, with: " ")
        return replacing(#"(?:(?:日期|时间)?(?:不是|并非|不在|是|在)?\s*)?"# + relativeDatePattern + #"的?"#,
                         in: withoutNumericDates, with: " ")
    }

    /// An amount is not evidence that money was spent. These conservative
    /// language guards run before extracting fields or using an explicit budget.
    /// They ask the user to clarify; they never turn refunds into new actions.
    static func requiresConsumptionClarification(_ text: String) -> Bool {
        if text.contains("?") || text.contains("？") { return true }
        let patterns = [
            #"(?:还?没(?:有)?|并未|尚未|未曾|从未|不曾)\s*(?:实际|真的|已经|再)?\s*(?:花|买|消费|支出|支付|付款|付|扣款)"#,
            #"(?:不是|并非|不算(?:是)?|不属于)\s*(?:实际|真的|一笔)?\s*(?:消费|支出|支付|付款|扣款|花的|买的)"#,
            #"(?:不要|不用|别|先别|不必)\s*(?:再)?\s*(?:记|记录|录入|保存)"#,
            #"(?:是否|有没有|是不是|会不会)|(?:花|买|消费|支出|支付|付款).*(?:吗|么)\s*[。.!！]?$"#,
            #"(?:打算|计划|准备|预计|预估|估计|可能|大概|考虑)(?:(?!记一笔|记录|录入|录一笔|再记|另记)[^0-9，,。.!！?？;；]){0,24}(?:买|花|消费|支付|付款|[¥￥$€£]?\s*[0-9])"#,
            #"(?:想要|想)\s*(?:去|要|再)?\s*(?:买|购买|花|消费|支付|付款)"#,
            #"预算\s*(?:约|为|是)?\s*[¥￥$€£]?\s*[0-9]"#,
            #"报价|标价|售价|估价|参考价|价格|退款|退货|退回|报销|工资|收入"#,
            #"(?i)\b(?:did(?:n['’]?t| not)|have(?:n['’]?t| not)|has(?:n['’]?t| not)|had(?:n['’]?t| not)|never|not)\s+(?:actually\s+)?(?:spen[dt]|paid|bought|buy|pay|purchase[ds]?)\b"#,
            #"(?i)\b(?:not\s+(?:an?\s+)?(?:expense|purchase|payment)|(?:do not|don['’]?t)\s+(?:record|log|save)|(?:did|have)\s+i\s+(?:spend|pay|buy))\b"#,
            #"(?i)\b(?:(?:plan(?:ning|ned)?\s+to|intend\s+to|want\s+to|going\s+to)\s+(?!(?:(?:just|please|also)\s+)*(?:record|log)\b)|might\s+(?:spend|cost|buy)|would\s+(?:spend|cost|buy)|will\s+(?:spend|cost|buy)|quote[ds]?|price[ds]?|estimat(?:e[ds]?|ed)|refund(?:ed)?|reimburse(?:d|ment)?|chargeback|salary|income|costs)\b"#,
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
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
