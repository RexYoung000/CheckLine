import Foundation

nonisolated struct Ledger: Equatable, Sendable {
    var walletSettings: WalletSettings
    var budgets: [UUID: Budget] = [:]
    var periods: [UUID: BudgetPeriod] = [:]
    var expenses: [UUID: Expense] = [:]
    var tags: [UUID: ExpenseTag] = [:]
    var expenseTagIDs: [UUID: [UUID]] = [:]
    var evidences: [UUID: SourceEvidence] = [:]
    var dataSources: [UUID: DataSourceConnection] = [:]
    var settlements: [UUID: Settlement] = [:]
    var adjustments: [UUID: SettlementAdjustment] = [:]
    var walletEntries: [UUID: WalletLedgerEntry] = [:]
    var wishes: [UUID: Wish] = [:]
    var redemptions: [UUID: WishRedemption] = [:]
    var matchingRules: [UUID: MatchingRule] = [:]

    static func blank(walletCurrencyCode: String, now: Date, settingsID: UUID = UUID()) -> Ledger {
        Ledger(
            walletSettings: WalletSettings(
                id: settingsID,
                walletCurrencyCode: walletCurrencyCode,
                userConfirmedCurrency: false,
                setAt: now,
                updatedAt: now
            )
        )
    }

    var sortedWalletEntries: [WalletLedgerEntry] {
        walletEntries.values.sorted { lhs, rhs in
            if lhs.occurredAt != rhs.occurredAt {
                return lhs.occurredAt < rhs.occurredAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func periods(forBudget id: UUID) -> [BudgetPeriod] {
        periods.values.filter { $0.budgetID == id }.sorted { $0.sequence < $1.sequence }
    }

    func expenses(inPeriod id: UUID) -> [Expense] {
        expenses.values.filter { $0.budgetPeriodID == id }
    }

    func queuedExpenses(forBudget id: UUID) -> [Expense] {
        expenses.values.filter { $0.queuedForBudgetID == id }
    }

    func settlement(forPeriod id: UUID) -> Settlement? {
        settlements.values.first { $0.periodID == id }
    }

    func evidences(forExpense id: UUID) -> [SourceEvidence] {
        evidences.values.filter { $0.expenseID == id }
    }

    func tags(forExpense id: UUID) -> [ExpenseTag] {
        (expenseTagIDs[id] ?? []).compactMap { tags[$0] }
    }

    func requireBudget(_ id: UUID) throws -> Budget {
        guard let budget = budgets[id] else { throw LedgerError.budgetNotFound }
        return budget
    }

    func requirePeriod(_ id: UUID) throws -> BudgetPeriod {
        guard let period = periods[id] else { throw LedgerError.periodNotFound }
        return period
    }

    func requireExpense(_ id: UUID) throws -> Expense {
        guard let expense = expenses[id] else { throw LedgerError.expenseNotFound }
        return expense
    }

    func requireWish(_ id: UUID) throws -> Wish {
        guard let wish = wishes[id] else { throw LedgerError.wishNotFound }
        return wish
    }

    mutating func upsert(_ budget: Budget) {
        budgets[budget.id] = budget
    }

    mutating func upsert(_ period: BudgetPeriod) {
        periods[period.id] = period
    }

    mutating func upsert(_ expense: Expense) {
        expenses[expense.id] = expense
    }

    mutating func upsert(_ evidence: SourceEvidence) {
        evidences[evidence.id] = evidence
    }

    mutating func upsert(_ settlement: Settlement) {
        settlements[settlement.id] = settlement
    }

    mutating func upsert(_ adjustment: SettlementAdjustment) {
        adjustments[adjustment.id] = adjustment
    }

    mutating func upsert(_ entry: WalletLedgerEntry) {
        walletEntries[entry.id] = entry
    }

    mutating func upsert(_ wish: Wish) {
        wishes[wish.id] = wish
    }

    mutating func upsert(_ redemption: WishRedemption) {
        redemptions[redemption.id] = redemption
    }

    mutating func attach(tagID: UUID, toExpense expenseID: UUID) {
        var ids = expenseTagIDs[expenseID] ?? []
        if ids.contains(tagID) == false {
            ids.append(tagID)
            expenseTagIDs[expenseID] = ids
        }
    }
}

extension Ledger {
    mutating func insertBudgetCard(
        name: String,
        amount: Decimal,
        currencyCode: String,
        cycleType: CycleType,
        recurrence: RecurrenceRule?,
        startDate: Date,
        endDate: Date?,
        now: Date,
        id: UUID = UUID(),
        periodID: UUID = UUID(),
        sortIndex: Int? = nil
    ) throws -> (Budget, BudgetPeriod) {
        if walletEntries.isEmpty && budgets.isEmpty && walletSettings.userConfirmedCurrency == false {
            walletSettings.walletCurrencyCode = currencyCode
            walletSettings.setAt = now
            walletSettings.updatedAt = now
        }

        let budget = Budget(
            id: id,
            name: name,
            defaultAmount: amount,
            defaultCurrencyCode: currencyCode,
            cycleType: cycleType,
            recurrence: recurrence,
            optionalDeadline: cycleType == .oneShot ? endDate : nil,
            state: .active,
            sortIndex: sortIndex ?? budgets.count,
            createdAt: now,
            updatedAt: now
        )
        let period = BudgetPeriod(
            id: periodID,
            budgetID: budget.id,
            budgetAmount: amount,
            currencyCode: currencyCode,
            startDate: startDate,
            endDate: endDate,
            state: .active,
            sequence: 1,
            createdAt: now
        )
        upsert(budget)
        upsert(period)
        return (budget, period)
    }

    mutating func insertExpense(
        amount: Decimal,
        currencyCode: String,
        occurredAt: Date,
        now: Date,
        merchant: String? = nil,
        estimatedBudgetAmount: Decimal? = nil,
        postedAmount: Decimal? = nil,
        postedCurrencyCode: String? = nil,
        kind: ExpenseKind = .purchase,
        reversesExpenseID: UUID? = nil,
        id: UUID = UUID()
    ) -> Expense {
        let expense = Expense(
            id: id,
            originalAmount: amount,
            originalCurrencyCode: currencyCode,
            postedAmount: postedAmount,
            postedCurrencyCode: postedCurrencyCode,
            estimatedBudgetAmount: estimatedBudgetAmount,
            estimateRateSource: nil,
            kind: kind,
            reversesExpenseID: reversesExpenseID,
            occurredAt: occurredAt,
            merchant: merchant,
            note: nil,
            budgetPeriodID: nil,
            queuedForBudgetID: nil,
            attributionState: .unbudgeted,
            attributionConfidence: nil,
            wishRedemptionID: nil,
            createdAt: now,
            updatedAt: now
        )
        upsert(expense)
        return expense
    }
}
