import Foundation

nonisolated enum AgentUnderstandResult: Equatable, Sendable {
    case intent(AgentIntent)
    case needsClarification(field: String, options: [String])
}

private enum IDResolution: Equatable {
    case resolved(UUID)
    case needsClarification(field: String, options: [String])
}

nonisolated enum IntentValidator {
    static func validate(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger,
        now: Date,
        sourceType: SourceType
    ) -> AgentUnderstandResult {
        let type = candidate.intentType.trimmingCharacters(in: .whitespacesAndNewlines)
        if type == "needsClarification" {
            return .needsClarification(
                field: candidate.clarificationField ?? "input",
                options: candidate.clarificationOptions ?? []
            )
        }

        switch type {
        case "recommendPurchase":
            return .intent(.recommendPurchase)
        case "outOfScope":
            return .intent(.outOfScope)
        case "capture":
            return validateCapture(candidate, ledger: ledger, now: now, sourceType: sourceType)
        case "queryBudgetStatus":
            return validateQuery(candidate, ledger: ledger)
        case "createBudget":
            return validateCreateBudget(candidate, ledger: ledger, now: now)
        case "adjustPeriodAmount":
            return validateAdjust(candidate, ledger: ledger)
        case "deleteExpense":
            return validateDelete(candidate, ledger: ledger)
        case "settlePeriod":
            return validateSettle(candidate, ledger: ledger)
        case "redeemWish":
            return validateRedeem(candidate, ledger: ledger)
        case "lateExpense":
            return validateLate(candidate, ledger: ledger)
        default:
            return .needsClarification(field: "intentType", options: [])
        }
    }

    private static func validateCapture(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger,
        now: Date,
        sourceType: SourceType
    ) -> AgentUnderstandResult {
        let amount: Decimal?
        if let raw = candidate.amount {
            guard let parsed = parseAmount(raw) else {
                return .needsClarification(field: "amount", options: [])
            }
            amount = parsed
        } else {
            amount = nil
        }

        let periodUUID: UUID?
        if let raw = nonempty(candidate.periodID) {
            guard let id = UUID(uuidString: raw), ledger.periods[id] != nil else {
                return .needsClarification(field: "periodID", options: periodOptions(ledger))
            }
            periodUUID = id
        } else {
            periodUUID = nil
        }

        let budgetUUID: UUID?
        if let raw = nonempty(candidate.budgetID) {
            guard let id = UUID(uuidString: raw), ledger.budgets[id] != nil else {
                return .needsClarification(field: "budgetID", options: budgetNameOptions(ledger))
            }
            budgetUUID = id
        } else if let name = nonempty(candidate.budgetName) {
            switch resolveBudget(named: name, ledger: ledger) {
            case .resolved(let id):
                budgetUUID = id
            case .needsClarification(let field, let options):
                return .needsClarification(field: field, options: options)
            }
        } else {
            budgetUUID = nil
        }

        let occurredAt: Date
        if let raw = nonempty(candidate.occurredAt) {
            guard let parsed = parseDate(raw) else {
                return .needsClarification(field: "occurredAt", options: [])
            }
            occurredAt = parsed
        } else {
            occurredAt = now
        }

        return .intent(
            .capture(
                CaptureDraft(
                    amount: amount,
                    currencyCode: nonempty(candidate.currencyCode),
                    occurredAt: occurredAt,
                    merchant: nonempty(candidate.merchant),
                    note: nonempty(candidate.note),
                    periodID: periodUUID,
                    budgetID: budgetUUID,
                    tagNames: candidate.tagNames ?? [],
                    isMultiItem: candidate.isMultiItem ?? false,
                    sourceType: sourceType
                )
            )
        )
    }

    private static func validateQuery(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger
    ) -> AgentUnderstandResult {
        switch resolveBudget(candidate, ledger: ledger) {
        case .resolved(let id):
            return .intent(.queryBudgetStatus(budgetID: id))
        case .needsClarification(let field, let options):
            return .needsClarification(field: field, options: options)
        }
    }

    private static func validateCreateBudget(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger,
        now: Date
    ) -> AgentUnderstandResult {
        guard let name = nonempty(candidate.name) else {
            return .needsClarification(field: "name", options: [])
        }
        guard let amount = parseAmount(candidate.amount) else {
            return .needsClarification(field: "amount", options: [])
        }
        let currency = nonempty(candidate.currencyCode) ?? ledger.walletSettings.walletCurrencyCode
        guard let cycle = parseCycle(candidate.cycleType) else {
            return .needsClarification(field: "cycleType", options: [CycleType.repeating.rawValue, CycleType.oneShot.rawValue])
        }
        let calendar = Calendar.current
        let start: Date
        if let explicit = parseDate(candidate.startDate) {
            start = explicit
        } else if cycle == .repeating {
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        } else {
            start = now
        }
        let end: Date?
        if let explicit = parseDate(candidate.endDate) {
            end = explicit
        } else if cycle == .repeating,
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) {
            end = calendar.date(byAdding: .day, value: -1, to: nextMonth)
        } else {
            end = nil
        }
        let recurrence: RecurrenceRule? = cycle == .repeating ? .monthly : nil
        return .intent(
            .createBudget(
                CreateBudgetDraft(
                    name: name,
                    amount: amount,
                    currencyCode: currency,
                    cycleType: cycle,
                    recurrence: recurrence,
                    startDate: start,
                    endDate: end
                )
            )
        )
    }

    private static func validateAdjust(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger
    ) -> AgentUnderstandResult {
        switch requirePeriod(candidate.periodID, ledger: ledger) {
        case .needsClarification(let field, let options):
            return .needsClarification(field: field, options: options)
        case .resolved(let id):
            guard let amount = parseAmount(candidate.newAmount ?? candidate.amount) else {
                return .needsClarification(field: "newAmount", options: [])
            }
            return .intent(.adjustPeriodAmount(periodID: id, newAmount: amount))
        }
    }

    private static func validateDelete(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger
    ) -> AgentUnderstandResult {
        guard let raw = nonempty(candidate.expenseID), let id = UUID(uuidString: raw), ledger.expenses[id] != nil else {
            return .needsClarification(field: "expenseID", options: [])
        }
        return .intent(.deleteExpense(expenseID: id))
    }

    private static func validateSettle(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger
    ) -> AgentUnderstandResult {
        switch requirePeriod(candidate.periodID, ledger: ledger) {
        case .needsClarification(let field, let options):
            return .needsClarification(field: field, options: options)
        case .resolved(let id):
            return .intent(.settlePeriod(periodID: id, quote: nil))
        }
    }

    private static func validateRedeem(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger
    ) -> AgentUnderstandResult {
        guard let raw = nonempty(candidate.wishID), let id = UUID(uuidString: raw), ledger.wishes[id] != nil else {
            return .needsClarification(field: "wishID", options: [])
        }
        guard let amount = parseAmount(candidate.actualAmount ?? candidate.amount) else {
            return .needsClarification(field: "actualAmount", options: [])
        }
        guard let currency = nonempty(candidate.currencyCode) else {
            return .needsClarification(field: "currencyCode", options: [])
        }
        return .intent(.redeemWish(wishID: id, actualAmount: amount, currencyCode: currency, quote: nil))
    }

    private static func validateLate(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger
    ) -> AgentUnderstandResult {
        switch requirePeriod(candidate.periodID, ledger: ledger) {
        case .needsClarification(let field, let options):
            return .needsClarification(field: field, options: options)
        case .resolved(let periodID):
            guard let raw = nonempty(candidate.expenseID), let expenseID = UUID(uuidString: raw), ledger.expenses[expenseID] != nil else {
                return .needsClarification(field: "expenseID", options: [])
            }
            return .intent(.lateExpense(periodID: periodID, expenseID: expenseID, quote: nil))
        }
    }

    private static func parseAmount(_ raw: String?) -> Decimal? {
        guard let trimmed = nonempty(raw) else { return nil }
        return MoneyFormat.parseAmount(trimmed)
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let trimmed = nonempty(raw) else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: trimmed) {
            return date
        }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: trimmed)
    }

    private static func parseCycle(_ raw: String?) -> CycleType? {
        guard let trimmed = nonempty(raw) else { return nil }
        return CycleType(rawValue: trimmed)
    }

    private static func nonempty(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    private static func requirePeriod(_ raw: String?, ledger: Ledger) -> IDResolution {
        guard let value = nonempty(raw), let id = UUID(uuidString: value), ledger.periods[id] != nil else {
            return .needsClarification(field: "periodID", options: periodOptions(ledger))
        }
        return .resolved(id)
    }

    private static func resolveBudget(
        _ candidate: AgentIntentCandidate,
        ledger: Ledger
    ) -> IDResolution {
        if let raw = nonempty(candidate.budgetID) {
            guard let id = UUID(uuidString: raw), ledger.budgets[id] != nil else {
                return .needsClarification(field: "budgetID", options: budgetNameOptions(ledger))
            }
            return .resolved(id)
        }
        if let name = nonempty(candidate.budgetName) {
            return resolveBudget(named: name, ledger: ledger)
        }
        return .needsClarification(field: "budgetName", options: budgetNameOptions(ledger))
    }

    private static func resolveBudget(named name: String, ledger: Ledger) -> IDResolution {
        let matches = ledger.budgets.values.filter {
            ($0.state == .active || $0.state == .pendingSettlement) && $0.name == name
        }
        if matches.count == 1, let budget = matches.first {
            return .resolved(budget.id)
        }
        return .needsClarification(field: "budgetName", options: budgetNameOptions(ledger))
    }

    private static func budgetNameOptions(_ ledger: Ledger) -> [String] {
        ledger.budgets.values
            .filter { $0.state == .active || $0.state == .pendingSettlement }
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(\.name)
    }

    private static func periodOptions(_ ledger: Ledger) -> [String] {
        ledger.periods.values
            .filter { $0.state == .active || $0.state == .pendingSettlement }
            .compactMap { period in ledger.budgets[period.budgetID]?.name }
    }
}
