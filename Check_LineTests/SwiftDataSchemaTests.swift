import Foundation
import SwiftData
import Testing
@testable import CheckLine

@MainActor
struct SwiftDataSchemaTests {
    @Test("V1 Schema 可在内存中打开，删除预算会级联周期且消费改为未绑定")
    func inMemoryInsertDeleteRelationships() throws {
        let schema = Schema(CheckLineSchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        let now = TestDates.day(2026, 1, 5)

        let budget = PersistedBudget(
            name: "餐饮",
            defaultAmount: 1_000,
            defaultCurrencyCode: "CNY",
            cycleTypeRaw: CycleType.repeating.rawValue,
            recurrenceRule: RecurrenceRule.monthly.stored,
            stateRaw: BudgetState.active.rawValue,
            sortIndex: 0,
            createdAt: now,
            updatedAt: now
        )
        let period = PersistedBudgetPeriod(
            budgetAmount: 1_000,
            currencyCode: "CNY",
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            stateRaw: PeriodState.active.rawValue,
            sequence: 1,
            createdAt: now,
            budget: budget
        )
        let expense = PersistedExpense(
            originalAmount: 80,
            originalCurrencyCode: "CNY",
            kindRaw: ExpenseKind.purchase.rawValue,
            occurredAt: now,
            attributionStateRaw: AttributionState.confirmed.rawValue,
            createdAt: now,
            updatedAt: now
        )
        expense.budgetPeriod = period
        let tag = PersistedExpenseTag(name: "人情", createdAt: now)
        expense.tags.append(tag)
        context.insert(budget)
        context.insert(period)
        context.insert(expense)
        context.insert(tag)
        try context.save()

        #expect(expense.tags.count == 1)
        #expect(period.budget?.id == budget.id)

        let expenseID = expense.id
        context.delete(budget)
        try context.save()

        let remainingBudgets = try context.fetch(FetchDescriptor<PersistedBudget>())
        let remainingPeriods = try context.fetch(FetchDescriptor<PersistedBudgetPeriod>())
        let remainingExpenses = try context.fetch(FetchDescriptor<PersistedExpense>())
        #expect(remainingBudgets.isEmpty)
        #expect(remainingPeriods.isEmpty)
        #expect(remainingExpenses.map(\.id) == [expenseID])
        #expect(remainingExpenses.first?.budgetPeriod == nil)
    }

    @Test("一笔消费在 SwiftData 里也只有一个结算周期关系")
    func expenseHasSinglePeriodRelationship() throws {
        let schema = Schema(CheckLineSchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        let now = TestDates.day(2026, 1, 5)
        let first = PersistedBudgetPeriod(
            budgetAmount: 1_000,
            currencyCode: "CNY",
            startDate: now,
            endDate: now,
            stateRaw: PeriodState.active.rawValue,
            sequence: 1,
            createdAt: now
        )
        let second = PersistedBudgetPeriod(
            budgetAmount: 2_000,
            currencyCode: "CNY",
            startDate: now,
            endDate: now,
            stateRaw: PeriodState.active.rawValue,
            sequence: 1,
            createdAt: now
        )
        let expense = PersistedExpense(
            originalAmount: 10,
            originalCurrencyCode: "CNY",
            kindRaw: ExpenseKind.purchase.rawValue,
            occurredAt: now,
            attributionStateRaw: AttributionState.confirmed.rawValue,
            createdAt: now,
            updatedAt: now
        )
        expense.budgetPeriod = first
        context.insert(first)
        context.insert(second)
        context.insert(expense)
        try context.save()

        expense.budgetPeriod = second
        try context.save()
        #expect(expense.budgetPeriod?.id == second.id)
        #expect(first.expenses.contains { $0.id == expense.id } == false)
        #expect(second.expenses.contains { $0.id == expense.id })
    }
}
