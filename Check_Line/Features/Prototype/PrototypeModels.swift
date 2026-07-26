import Foundation
import Observation

enum PrototypeBudgetStatus: String, Hashable {
    case active
    case settling
    case archived
}

enum PrototypeCycleType: String, CaseIterable, Identifiable {
    case oneShot
    case repeating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneShot: String(localized: "cycle.oneShot")
        case .repeating: String(localized: "cycle.repeating")
        }
    }
}

enum PrototypeTemplate: String, CaseIterable, Identifiable {
    case monthly
    case travel
    case study
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: String(localized: "template.monthly")
        case .travel: String(localized: "template.travel")
        case .study: String(localized: "template.study")
        case .custom: String(localized: "template.custom")
        }
    }
}

struct PrototypeCategory: Identifiable, Hashable {
    let id: UUID
    var name: String
    var iconName: String
    var colorHex: UInt
    var limit: Decimal
    var spent: Decimal
}

struct PrototypeBudget: Identifiable, Hashable {
    let id: UUID
    var name: String
    var template: PrototypeTemplate
    var cycleType: PrototypeCycleType
    var total: Decimal
    var spent: Decimal
    var status: PrototypeBudgetStatus
    var startDate: Date
    var endDate: Date
    var categories: [PrototypeCategory]

    var remaining: Decimal { max(0, total - spent) }

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, decimalDouble(spent / total))
    }
}

struct PrototypeExpense: Identifiable, Hashable {
    let id: UUID
    var title: String
    var amount: Decimal
    var categoryName: String
    var occurredAt: Date
    var budgetIDs: Set<UUID>
    var note: String
}

struct PrototypeExpenseDraft {
    var amount: Decimal
    var categoryName: String
    var budgetIDs: Set<UUID>
    var note: String
}

struct PrototypeExpenseDeletion {
    let expense: PrototypeExpense
    let removedBudgetIDs: Set<UUID>
}

enum PrototypeSettlementChoice: String, CaseIterable, Identifiable, Hashable {
    case all
    case current

    var id: String { rawValue }
}

@MainActor
@Observable
final class PrototypeStore {
    var budgets: [PrototypeBudget]
    var expenses: [PrototypeExpense]

    init(budgets: [PrototypeBudget], expenses: [PrototypeExpense]) {
        self.budgets = budgets
        self.expenses = expenses
    }

    var activeBudgets: [PrototypeBudget] {
        budgets.filter { $0.status == .active }
    }

    var settlingBudgets: [PrototypeBudget] {
        budgets.filter { $0.status == .settling }
    }

    func budget(id: UUID) -> PrototypeBudget? {
        budgets.first { $0.id == id }
    }

    func expenses(for budgetID: UUID) -> [PrototypeExpense] {
        expenses
            .filter { $0.budgetIDs.contains(budgetID) }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    @discardableResult
    func record(_ draft: PrototypeExpenseDraft) -> PrototypeExpense {
        let expense = PrototypeExpense(
            id: UUID(),
            title: draft.note.isEmpty ? draft.categoryName : draft.note,
            amount: draft.amount,
            categoryName: draft.categoryName,
            occurredAt: prototypeDate(year: 2026, month: 7, day: 6),
            budgetIDs: draft.budgetIDs,
            note: draft.note
        )
        expenses.insert(expense, at: 0)

        for budgetID in draft.budgetIDs {
            updateBudget(id: budgetID, amountDelta: draft.amount, categoryName: draft.categoryName)
        }
        return expense
    }

    func undoExpense(id: UUID) {
        guard let expenseIndex = expenses.firstIndex(where: { $0.id == id }) else { return }
        let expense = expenses.remove(at: expenseIndex)
        for budgetID in expense.budgetIDs {
            updateBudget(id: budgetID, amountDelta: -expense.amount, categoryName: expense.categoryName)
        }
    }

    func addBudget(
        name: String,
        template: PrototypeTemplate,
        cycleType: PrototypeCycleType,
        total: Decimal,
        startDate: Date,
        endDate: Date
    ) -> UUID {
        let budgetID = UUID()
        let categorySeeds: [(String, String, UInt, Int)] = [
            (String(localized: "category.food"), "fork.knife", 0xF97316, 40),
            (String(localized: "category.transport"), "tram.fill", 0x135BEC, 25),
            (String(localized: "category.other"), "ellipsis", 0x94A3B8, 35)
        ]
        let categories = categorySeeds.map { name, icon, color, percentage in
            PrototypeCategory(
                id: UUID(),
                name: name,
                iconName: icon,
                colorHex: color,
                limit: total * Decimal(percentage) / 100,
                spent: 0
            )
        }
        budgets.insert(
            PrototypeBudget(
                id: budgetID,
                name: name,
                template: template,
                cycleType: cycleType,
                total: total,
                spent: 0,
                status: .active,
                startDate: startDate,
                endDate: endDate,
                categories: categories
            ),
            at: 0
        )
        return budgetID
    }

    @discardableResult
    func deleteExpense(
        id expenseID: UUID,
        from budgetID: UUID,
        deleteFromAllBudgets: Bool
    ) -> PrototypeExpenseDeletion? {
        guard let expenseIndex = expenses.firstIndex(where: { $0.id == expenseID }) else { return nil }
        let expense = expenses[expenseIndex]
        guard expense.budgetIDs.contains(budgetID) else { return nil }

        let removedBudgetIDs = deleteFromAllBudgets || expense.budgetIDs.count == 1
            ? expense.budgetIDs
            : Set([budgetID])

        for removedBudgetID in removedBudgetIDs {
            updateBudget(
                id: removedBudgetID,
                amountDelta: -expense.amount,
                categoryName: expense.categoryName
            )
        }

        if removedBudgetIDs == expense.budgetIDs {
            expenses.remove(at: expenseIndex)
        } else {
            expenses[expenseIndex].budgetIDs.subtract(removedBudgetIDs)
        }

        return PrototypeExpenseDeletion(expense: expense, removedBudgetIDs: removedBudgetIDs)
    }

    func restoreExpenseDeletion(_ deletion: PrototypeExpenseDeletion) {
        if let expenseIndex = expenses.firstIndex(where: { $0.id == deletion.expense.id }) {
            expenses[expenseIndex] = deletion.expense
        } else {
            expenses.insert(deletion.expense, at: 0)
        }

        for budgetID in deletion.removedBudgetIDs where budget(id: budgetID) != nil {
            updateBudget(
                id: budgetID,
                amountDelta: deletion.expense.amount,
                categoryName: deletion.expense.categoryName
            )
        }
    }

    func deleteExpenses(
        ids expenseIDs: Set<UUID>,
        from budgetID: UUID,
        deletingFromAllBudgets globalExpenseIDs: Set<UUID>
    ) {
        for expenseID in expenseIDs {
            deleteExpense(
                id: expenseID,
                from: budgetID,
                deleteFromAllBudgets: globalExpenseIDs.contains(expenseID)
            )
        }
    }

    func deleteBudget(
        id budgetID: UUID,
        deletingFromAllBudgets globalExpenseIDs: Set<UUID>
    ) {
        let expenseIDs = Set(expenses(for: budgetID).map(\.id))
        deleteExpenses(
            ids: expenseIDs,
            from: budgetID,
            deletingFromAllBudgets: globalExpenseIDs
        )
        budgets.removeAll { $0.id == budgetID }
    }

    func linkedExpenses(for budgetID: UUID) -> [PrototypeExpense] {
        expenses(for: budgetID).filter { $0.budgetIDs.count > 1 }
    }

    func completeSettlement(
        budgetID: UUID,
        choices: [UUID: PrototypeSettlementChoice]
    ) -> Decimal {
        for expense in linkedExpenses(for: budgetID) {
            guard choices[expense.id] == .current,
                  let expenseIndex = expenses.firstIndex(where: { $0.id == expense.id }) else { continue }

            let otherBudgetIDs = expenses[expenseIndex].budgetIDs.filter { $0 != budgetID }
            for otherBudgetID in otherBudgetIDs {
                updateBudget(
                    id: otherBudgetID,
                    amountDelta: -expense.amount,
                    categoryName: expense.categoryName
                )
            }
            expenses[expenseIndex].budgetIDs = [budgetID]
        }

        guard let budgetIndex = budgets.firstIndex(where: { $0.id == budgetID }) else { return 0 }
        budgets[budgetIndex].status = .archived
        return budgets[budgetIndex].remaining
    }

    private func updateBudget(id: UUID, amountDelta: Decimal, categoryName: String) {
        guard let budgetIndex = budgets.firstIndex(where: { $0.id == id }) else { return }
        budgets[budgetIndex].spent = max(0, budgets[budgetIndex].spent + amountDelta)

        let categoryIndex = budgets[budgetIndex].categories.firstIndex { $0.name == categoryName }
            ?? budgets[budgetIndex].categories.firstIndex { $0.name == String(localized: "category.other") }
        guard let categoryIndex else { return }
        budgets[budgetIndex].categories[categoryIndex].spent = max(
            0,
            budgets[budgetIndex].categories[categoryIndex].spent + amountDelta
        )
    }
}

extension PrototypeStore {
    static func sample() -> PrototypeStore {
        let livingID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        let travelID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        let studyID = UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()
        let juneID = UUID(uuidString: "00000000-0000-0000-0000-000000000004") ?? UUID()

        let budgets = [
            PrototypeBudget(
                id: livingID,
                name: String(localized: "sample.budget.living"),
                template: .monthly,
                cycleType: .repeating,
                total: 5000,
                spent: 3180,
                status: .active,
                startDate: prototypeDate(year: 2026, month: 7, day: 1),
                endDate: prototypeDate(year: 2026, month: 7, day: 31),
                categories: sampleCategories(food: (2200, 1420), transport: (800, 410), social: (1000, 820), other: (1000, 530))
            ),
            PrototypeBudget(
                id: travelID,
                name: String(localized: "sample.budget.travel"),
                template: .travel,
                cycleType: .oneShot,
                total: 8800,
                spent: 4560,
                status: .active,
                startDate: prototypeDate(year: 2026, month: 7, day: 10),
                endDate: prototypeDate(year: 2026, month: 7, day: 17),
                categories: sampleCategories(food: (1700, 620), transport: (2500, 1360), social: (1000, 380), other: (3600, 2200))
            ),
            PrototypeBudget(
                id: studyID,
                name: String(localized: "sample.budget.study"),
                template: .study,
                cycleType: .oneShot,
                total: 2600,
                spent: 940,
                status: .active,
                startDate: prototypeDate(year: 2026, month: 7, day: 1),
                endDate: prototypeDate(year: 2026, month: 9, day: 30),
                categories: sampleCategories(food: (500, 220), transport: (300, 80), social: (300, 0), other: (1500, 640))
            ),
            PrototypeBudget(
                id: juneID,
                name: String(localized: "sample.budget.june"),
                template: .monthly,
                cycleType: .repeating,
                total: 5000,
                spent: 4380,
                status: .settling,
                startDate: prototypeDate(year: 2026, month: 6, day: 1),
                endDate: prototypeDate(year: 2026, month: 6, day: 30),
                categories: sampleCategories(food: (2200, 1990), transport: (800, 650), social: (1000, 920), other: (1000, 820))
            )
        ]

        let expenses = [
            PrototypeExpense(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID(),
                title: String(localized: "sample.expense.transit"),
                amount: 38,
                categoryName: String(localized: "category.transport"),
                occurredAt: prototypeDate(year: 2026, month: 7, day: 6),
                budgetIDs: [livingID, travelID],
                note: String(localized: "sample.expense.transit.note")
            ),
            PrototypeExpense(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002") ?? UUID(),
                title: String(localized: "sample.expense.dinner"),
                amount: 150,
                categoryName: String(localized: "category.food"),
                occurredAt: prototypeDate(year: 2026, month: 7, day: 5),
                budgetIDs: [livingID],
                note: String(localized: "sample.expense.dinner.note")
            ),
            PrototypeExpense(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003") ?? UUID(),
                title: String(localized: "sample.expense.materials"),
                amount: 220,
                categoryName: String(localized: "category.other"),
                occurredAt: prototypeDate(year: 2026, month: 7, day: 3),
                budgetIDs: [studyID],
                note: String(localized: "sample.expense.materials.note")
            ),
            PrototypeExpense(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004") ?? UUID(),
                title: String(localized: "sample.expense.airport"),
                amount: 88,
                categoryName: String(localized: "category.transport"),
                occurredAt: prototypeDate(year: 2026, month: 6, day: 28),
                budgetIDs: [juneID, travelID],
                note: String(localized: "sample.expense.airport.note")
            )
        ]
        return PrototypeStore(budgets: budgets, expenses: expenses)
    }

    private static func sampleCategories(
        food: (Decimal, Decimal),
        transport: (Decimal, Decimal),
        social: (Decimal, Decimal),
        other: (Decimal, Decimal)
    ) -> [PrototypeCategory] {
        [
            PrototypeCategory(id: UUID(), name: String(localized: "category.food"), iconName: "fork.knife", colorHex: 0xF97316, limit: food.0, spent: food.1),
            PrototypeCategory(id: UUID(), name: String(localized: "category.transport"), iconName: "tram.fill", colorHex: 0x135BEC, limit: transport.0, spent: transport.1),
            PrototypeCategory(id: UUID(), name: String(localized: "category.social"), iconName: "person.2.fill", colorHex: 0x8B5CF6, limit: social.0, spent: social.1),
            PrototypeCategory(id: UUID(), name: String(localized: "category.other"), iconName: "ellipsis", colorHex: 0x94A3B8, limit: other.0, spent: other.1)
        ]
    }
}

func prototypeDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? .now
}

func decimalDouble(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
}
