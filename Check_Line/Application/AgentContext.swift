import Foundation

nonisolated struct AgentBudgetCardContext: Equatable, Sendable, Codable {
    var name: String
    var cycleType: String
    var currencyCode: String
}

/// Read-only projection sent to a model. Contains names only — never amounts or wallet figures.
nonisolated struct AgentContext: Equatable, Sendable, Codable {
    var budgetCards: [AgentBudgetCardContext]
    var recentMerchants: [String]
    var tagNames: [String]

    var jsonUTF8: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(self)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

nonisolated enum AgentContextBuilder {
    static let merchantLimit = 10

    static func build(_ ledger: Ledger) -> AgentContext {
        AgentContext(
            budgetCards: activeCards(in: ledger),
            recentMerchants: recentMerchants(in: ledger),
            tagNames: tagNames(in: ledger)
        )
    }

    private static func activeCards(in ledger: Ledger) -> [AgentBudgetCardContext] {
        ledger.budgets.values
            .filter { $0.state == .active || $0.state == .pendingSettlement }
            .sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex {
                    return lhs.sortIndex < rhs.sortIndex
                }
                return lhs.name < rhs.name
            }
            .map { budget in
                AgentBudgetCardContext(
                    name: budget.name,
                    cycleType: budget.cycleType.rawValue,
                    currencyCode: budget.defaultCurrencyCode
                )
            }
    }

    private static func recentMerchants(in ledger: Ledger) -> [String] {
        let ordered = ledger.expenses.values.sorted { lhs, rhs in
            if lhs.occurredAt != rhs.occurredAt {
                return lhs.occurredAt > rhs.occurredAt
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
        var seen: Set<String> = []
        var names: [String] = []
        for expense in ordered {
            guard let raw = expense.merchant?.trimmingCharacters(in: .whitespacesAndNewlines),
                  raw.isEmpty == false
            else { continue }
            if seen.insert(raw).inserted {
                names.append(raw)
            }
            if names.count == merchantLimit {
                break
            }
        }
        return names
    }

    private static func tagNames(in ledger: Ledger) -> [String] {
        Array(Set(ledger.tags.values.map(\.name))).sorted()
    }
}
