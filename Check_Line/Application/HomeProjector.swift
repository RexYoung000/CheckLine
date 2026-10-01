import Foundation

nonisolated struct HomeBudgetCardModel: Equatable, Identifiable, Sendable {
    var id: UUID
    var periodID: UUID
    var name: String
    var cycleType: CycleType
    var currencyCode: String
    var snapshot: PeriodBudgetSnapshot
    var periodState: PeriodState
    var periodStart: Date
    var periodEnd: Date?
    var cycleProgress: Double?
}

nonisolated enum HomeProcessingKind: Equatable, Sendable {
    case pendingTransactions(Int)
    case unbudgetedTransactions(Int)
    case possibleOverrun(budgetName: String)
    case certainOverrun(budgetName: String)
    case settlementDue(budgetName: String)
    case noDataSources
}

nonisolated struct HomeProcessingItem: Equatable, Identifiable, Sendable {
    var id: String
    var kind: HomeProcessingKind
}

nonisolated enum HomeProjector {
    static func cards(in ledger: Ledger, now: Date = Date()) -> [HomeBudgetCardModel] {
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
                    periodState: period.state,
                    periodStart: period.startDate,
                    periodEnd: period.endDate,
                    cycleProgress: cycleProgress(period: period, now: now)
                )
            }
    }

    static func card(budgetID: UUID, periodID: UUID?, in ledger: Ledger) -> HomeBudgetCardModel? {
        if let periodID, ledger.periods[periodID] == nil { return nil }
        guard let budget = ledger.budgets[budgetID],
              let period = periodID.flatMap({ ledger.periods[$0] }) ?? displayPeriod(for: budgetID, ledger: ledger) ?? ledger.periods(forBudget: budgetID).last,
              period.budgetID == budgetID else { return nil }
        return HomeBudgetCardModel(id: budgetID, periodID: period.id, name: budget.name, cycleType: budget.cycleType,
                                   currencyCode: period.currencyCode,
                                   snapshot: BudgetEngine.periodSnapshot(period: period, expenses: Array(ledger.expenses.values)),
                                   periodState: period.state, periodStart: period.startDate, periodEnd: period.endDate,
                                   cycleProgress: cycleProgress(period: period, now: Date()))
    }

    static func cycleProgress(period: BudgetPeriod, now: Date) -> Double? {
        if period.state == .pendingSettlement {
            return 1
        }
        guard let endDate = period.endDate else { return nil }
        let duration = endDate.timeIntervalSince(period.startDate)
        guard duration > 0 else { return nil }
        return min(max(now.timeIntervalSince(period.startDate) / duration, 0), 1)
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
            if let period = ledger.periods[card.periodID],
               period.state == .pendingSettlement || CycleEngine.isDue(period, now: Date(), calendar: .current) {
                items.append(HomeProcessingItem(id: "settlement-\(card.id.uuidString)", kind: .settlementDue(budgetName: card.name)))
            }
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
    case needsConversion
    case needsPeriod

    var localizedText: String {
        switch self {
        case .recorded:
            String(localized: "v1.banner.recorded")
        case .undone:
            String(localized: "v1.banner.undone")
        case .createdBudget:
            String(localized: "v1.banner.created")
        case .queryRemaining(let amount, let currency):
            String(format: String(localized: "v1.banner.query"), locale: .current, MoneyFormat.string(amount, currencyCode: currency))
        case .refusedRecommend:
            String(localized: "v1.banner.refuseRecommend")
        case .refusedOutOfScope:
            String(localized: "v1.banner.refuseScope")
        case .needsAmount:
            String(localized: "v1.banner.needsAmount")
        case .needsFullscreen:
            String(localized: "v1.banner.needsFullscreen")
        case .needsClarification(let field):
            switch field {
            case "name": String(localized: "v1.agent.clarify.name")
            case "cycleType": String(localized: "v1.agent.clarify.cycle")
            case "currencyCode": String(localized: "v1.agent.clarify.currency")
            default: String(localized: "v1.banner.needsClarification")
            }
        case .needsPeriod:
            String(localized: "ui.draft.dateMismatch")
        case .needsConversion:
            String(localized: "ui.currency.unconverted")
        case .failed:
            String(localized: "v1.banner.failed")
        }
    }
}

enum ComposerIntent: String, CaseIterable, Identifiable {
    case budget
    case record

    var id: String { rawValue }
}
