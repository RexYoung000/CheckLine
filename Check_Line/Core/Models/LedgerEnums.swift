import Foundation

nonisolated enum CycleType: String, Equatable, Sendable {
    case repeating
    case oneShot
}

nonisolated enum BudgetState: String, Equatable, Sendable {
    case draft
    case active
    case pendingSettlement
    case archived
}

nonisolated enum PeriodState: String, Equatable, Sendable {
    case active
    case pendingSettlement
    case settled
}

nonisolated enum AttributionState: String, Equatable, Sendable {
    case confirmed
    case pending
    case unbudgeted
}

nonisolated enum ExpenseKind: String, Equatable, Sendable {
    case purchase
    case refund
}

nonisolated enum SourceType: String, Equatable, Sendable {
    case manual
    case agentText
    case voice
    case image
    case applePay
    case sms
    case email
    case statement
}

nonisolated enum DataSourceState: String, Equatable, Sendable {
    case disconnected
    case connected
    case needsAttention
}

nonisolated enum WalletEntryType: String, Equatable, Sendable {
    case surplus
    case overrun
    case wishRedemption
    case refund
    case retrospectiveAdjustment
}

nonisolated enum ConversionKind: String, Equatable, Sendable, Codable {
    case identity
    case posted
    case estimated
}

nonisolated enum AdjustmentReason: String, Equatable, Sendable {
    case lateExpense
    case refund
    case postedAmountChange
}

nonisolated enum WishState: String, Equatable, Sendable {
    case active
    case completed
    case archived
}

nonisolated enum WishRedemptionState: String, Equatable, Sendable {
    case completed
    case refunded
}

nonisolated enum MatchingRuleState: String, Equatable, Sendable {
    case proposed
    case active
    case disabled
}

nonisolated enum RecurrenceRule: Equatable, Sendable {
    case weekly
    case monthly
    case everyNDays(Int)

    var stored: String {
        switch self {
        case .weekly:
            return "weekly"
        case .monthly:
            return "monthly"
        case .everyNDays(let days):
            return "everyNDays:\(days)"
        }
    }

    static func parse(_ raw: String?) -> RecurrenceRule? {
        guard let raw else { return nil }
        if raw == "weekly" { return .weekly }
        if raw == "monthly" { return .monthly }
        if raw.hasPrefix("everyNDays:") {
            let value = raw.dropFirst("everyNDays:".count)
            guard let days = Int(value), days > 0 else { return nil }
            return .everyNDays(days)
        }
        return nil
    }
}

nonisolated enum DecimalMath {
    static func parse(_ string: String) -> Decimal {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
}
