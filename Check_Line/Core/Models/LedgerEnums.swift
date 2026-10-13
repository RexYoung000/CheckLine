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
    case monthlyCycle(Int)
    case monthlyWindow(startDay: Int, endDay: Int)
    case everyNDays(Int)

    var monthlySchedule: MonthlySchedule? {
        switch self {
        case .monthlyCycle(let day): MonthlySchedule(startDay: day)
        case .monthlyWindow(let start, let end): MonthlySchedule(kind: .window, startDay: start, endDay: end)
        default: nil
        }
    }

    var isMonthly: Bool { self == .monthly || monthlySchedule?.isValid == true }

    var stored: String {
        switch self {
        case .weekly:
            return "weekly"
        case .monthly:
            return "monthly"
        case .monthlyCycle(let day):
            return "monthlyCycle:\(day)"
        case .monthlyWindow(let start, let end):
            return "monthlyWindow:\(start):\(end)"
        case .everyNDays(let days):
            return "everyNDays:\(days)"
        }
    }

    static func parse(_ raw: String?) -> RecurrenceRule? {
        guard let raw else { return nil }
        if raw == "weekly" { return .weekly }
        if raw == "monthly" { return .monthly }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
        if parts.first == "monthlyCycle", parts.count == 2, let day = Int(parts[1]), (1...31).contains(day) {
            return .monthlyCycle(day)
        }
        if parts.first == "monthlyWindow", parts.count == 3,
           let start = Int(parts[1]), let end = Int(parts[2]), (1...31).contains(start), (1...31).contains(end) {
            return .monthlyWindow(startDay: start, endDay: end)
        }
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
