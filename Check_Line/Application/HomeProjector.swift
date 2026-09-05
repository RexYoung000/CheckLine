import Foundation

nonisolated struct HomeBudgetCardModel: Equatable, Identifiable, Sendable {
    var id: UUID
    var periodID: UUID
    var name: String
    var cycleType: CycleType
    var currencyCode: String
    var snapshot: PeriodBudgetSnapshot
    var periodState: PeriodState
}

nonisolated enum HomeProcessingKind: Equatable, Sendable {
    case pendingTransactions(Int)
    case unbudgetedTransactions(Int)
    case possibleOverrun(budgetName: String)
    case certainOverrun(budgetName: String)
    case noDataSources
}

nonisolated struct HomeProcessingItem: Equatable, Identifiable, Sendable {
    var id: String
    var kind: HomeProcessingKind
}

nonisolated enum HomeProjector {
    static func cards(in ledger: Ledger) -> [HomeBudgetCardModel] {
        ledger.budgets.values
            .filter { $0.state == .active || $0.state == .pendingSettlement }
            .sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex {
                    return lhs.sortIndex < rhs.sortIndex
                }
                return lhs.name < rhs.name
            }
            .compactMap { budget -> HomeBudgetCardModel? in
                guard let period = displayPeriod(for: budget.id, ledger: ledger) else { return nil }
                return HomeBudgetCardModel(
                    id: budget.id,
                    periodID: period.id,
                    name: budget.name,
                    cycleType: budget.cycleType,
                    currencyCode: period.currencyCode,
                    snapshot: BudgetEngine.periodSnapshot(
                        period: period,
                        expenses: Array(ledger.expenses.values)
                    ),
                    periodState: period.state
                )
            }
    }

    static func processingItems(in ledger: Ledger) -> [HomeProcessingItem] {
        var items: [HomeProcessingItem] = []
        let pending = ledger.expenses.values.filter { $0.attributionState == .pending }.count
        if pending > 0 {
            items.append(HomeProcessingItem(id: "pending", kind: .pendingTransactions(pending)))
        }
        let unbudgeted = ledger.expenses.values.filter {
            $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil
        }.count
        if unbudgeted > 0 {
            items.append(HomeProcessingItem(id: "unbudgeted", kind: .unbudgetedTransactions(unbudgeted)))
        }

        for card in cards(in: ledger) {
            if card.snapshot.certainOverrunAmount > 0 {
                items.append(
                    HomeProcessingItem(
                        id: "certain-\(card.id.uuidString)",
                        kind: .certainOverrun(budgetName: card.name)
                    )
                )
            } else if card.snapshot.possibleOverrunAmount > 0 {
                items.append(
                    HomeProcessingItem(
                        id: "possible-\(card.id.uuidString)",
                        kind: .possibleOverrun(budgetName: card.name)
                    )
                )
            }
        }

        return items
    }

    static func attributionChoices(in ledger: Ledger) -> [AttributionChoice] {
        var choices = cards(in: ledger).map { card in
            AttributionChoice(id: card.periodID.uuidString, periodID: card.periodID, title: card.name)
        }
        choices.append(AttributionChoice(id: "unbudgeted", periodID: nil, title: ""))
        return choices
    }

    static func displayPeriod(for budgetID: UUID, ledger: Ledger) -> BudgetPeriod? {
        let periods = ledger.periods(forBudget: budgetID)
        if let active = periods.first(where: { $0.state == .active }) {
            return active
        }
        return periods.first(where: { $0.state == .pendingSettlement })
    }
}

nonisolated struct AttributionChoice: Equatable, Identifiable, Sendable {
    var id: String
    var periodID: UUID?
    var title: String
}

nonisolated enum WorkspaceBanner: Equatable, Sendable {
    case recorded
    case undone
    case createdBudget
    case queryRemaining(amount: Decimal, currencyCode: String)
    case refusedRecommend
    case refusedOutOfScope
    case needsAmount
    case needsFullscreen
    case needsClarification(String)
    case failed
}
