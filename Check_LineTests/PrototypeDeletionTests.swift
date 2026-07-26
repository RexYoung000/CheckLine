import Foundation
import Testing
@testable import CheckLine

@MainActor
struct PrototypeDeletionTests {
    @Test("删除预算默认保留其他预算中的共享消费")
    func deletingBudgetPreservesSharedExpenseByDefault() {
        let fixture = makeFixture()

        fixture.store.deleteBudget(
            id: fixture.primaryBudgetID,
            deletingFromAllBudgets: []
        )

        #expect(fixture.store.budget(id: fixture.primaryBudgetID) == nil)
        #expect(fixture.store.expenses.contains { $0.id == fixture.exclusiveExpenseID } == false)
        #expect(
            fixture.store.expenses.first { $0.id == fixture.sharedExpenseID }?.budgetIDs
                == Set([fixture.otherBudgetID])
        )
        #expect(fixture.store.budget(id: fixture.otherBudgetID)?.spent == 200)
    }

    @Test("删除预算时勾选的共享消费会从全部预算删除")
    func deletingBudgetCanDeleteSelectedSharedExpenseEverywhere() {
        let fixture = makeFixture()

        fixture.store.deleteBudget(
            id: fixture.primaryBudgetID,
            deletingFromAllBudgets: [fixture.sharedExpenseID]
        )

        #expect(fixture.store.expenses.contains { $0.id == fixture.sharedExpenseID } == false)
        #expect(fixture.store.budget(id: fixture.otherBudgetID)?.spent == 0)
    }

    @Test("删除共享消费默认只解除当前预算关系")
    func deletingSharedExpenseOnlyRemovesCurrentBudget() {
        let fixture = makeFixture()

        fixture.store.deleteExpense(
            id: fixture.sharedExpenseID,
            from: fixture.primaryBudgetID,
            deleteFromAllBudgets: false
        )

        #expect(
            fixture.store.expenses.first { $0.id == fixture.sharedExpenseID }?.budgetIDs
                == Set([fixture.otherBudgetID])
        )
        #expect(fixture.store.budget(id: fixture.primaryBudgetID)?.spent == 100)
        #expect(fixture.store.budget(id: fixture.otherBudgetID)?.spent == 200)
    }

    @Test("普通消费单独删除后可以撤销")
    func exclusiveExpenseDeletionCanBeUndone() throws {
        let fixture = makeFixture()
        let deletion = try #require(
            fixture.store.deleteExpense(
                id: fixture.exclusiveExpenseID,
                from: fixture.primaryBudgetID,
                deleteFromAllBudgets: false
            )
        )

        #expect(fixture.store.budget(id: fixture.primaryBudgetID)?.spent == 200)
        #expect(fixture.store.expenses.contains { $0.id == fixture.exclusiveExpenseID } == false)

        fixture.store.restoreExpenseDeletion(deletion)

        #expect(fixture.store.budget(id: fixture.primaryBudgetID)?.spent == 300)
        #expect(fixture.store.expenses.contains { $0.id == fixture.exclusiveExpenseID })
    }

    private func makeFixture() -> Fixture {
        let primaryBudgetID = UUID()
        let otherBudgetID = UUID()
        let exclusiveExpenseID = UUID()
        let sharedExpenseID = UUID()
        let categoryName = "交通"
        let date = Date(timeIntervalSince1970: 0)

        func category(spent: Decimal) -> PrototypeCategory {
            PrototypeCategory(
                id: UUID(),
                name: categoryName,
                iconName: "tram.fill",
                colorHex: 0x135BEC,
                limit: 1_000,
                spent: spent
            )
        }

        let budgets = [
            PrototypeBudget(
                id: primaryBudgetID,
                name: "当前预算",
                template: .monthly,
                cycleType: .repeating,
                total: 1_000,
                spent: 300,
                status: .active,
                startDate: date,
                endDate: date,
                categories: [category(spent: 300)]
            ),
            PrototypeBudget(
                id: otherBudgetID,
                name: "其他预算",
                template: .travel,
                cycleType: .oneShot,
                total: 1_000,
                spent: 200,
                status: .active,
                startDate: date,
                endDate: date,
                categories: [category(spent: 200)]
            )
        ]

        let expenses = [
            PrototypeExpense(
                id: exclusiveExpenseID,
                title: "普通消费",
                amount: 100,
                categoryName: categoryName,
                occurredAt: date,
                budgetIDs: [primaryBudgetID],
                note: ""
            ),
            PrototypeExpense(
                id: sharedExpenseID,
                title: "共享消费",
                amount: 200,
                categoryName: categoryName,
                occurredAt: date,
                budgetIDs: [primaryBudgetID, otherBudgetID],
                note: ""
            )
        ]

        return Fixture(
            store: PrototypeStore(budgets: budgets, expenses: expenses),
            primaryBudgetID: primaryBudgetID,
            otherBudgetID: otherBudgetID,
            exclusiveExpenseID: exclusiveExpenseID,
            sharedExpenseID: sharedExpenseID
        )
    }
}

private struct Fixture {
    let store: PrototypeStore
    let primaryBudgetID: UUID
    let otherBudgetID: UUID
    let exclusiveExpenseID: UUID
    let sharedExpenseID: UUID
}
