import SwiftUI

struct PrototypeBudgetDeleteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: PrototypeStore
    let budgetID: UUID
    let onConfirm: (Set<UUID>) -> Void

    @State private var globallyDeletedExpenseIDs: Set<UUID> = []

    private var budget: PrototypeBudget? { store.budget(id: budgetID) }
    private var linkedExpenses: [PrototypeExpense] { store.linkedExpenses(for: budgetID) }
    private var allLinkedSelected: Bool {
        !linkedExpenses.isEmpty && globallyDeletedExpenseIDs == Set(linkedExpenses.map(\.id))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        String(
                            format: String(localized: "delete.budget.shared.message"),
                            budget?.name ?? String(localized: "budget.missing")
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(CheckLineColor.secondary)
                }

                Section {
                    Toggle(
                        "delete.shared.selectAll",
                        isOn: Binding(
                            get: { allLinkedSelected },
                            set: { selectAll($0) }
                        )
                    )
                    .tint(CheckLineColor.danger)

                    ForEach(linkedExpenses) { expense in
                        sharedExpenseToggle(expense)
                    }
                } header: {
                    Text("delete.shared.section")
                } footer: {
                    Text("delete.shared.default")
                }
            }
            .navigationTitle(Text("delete.budget.shared.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("delete.budget.confirm") {
                        onConfirm(globallyDeletedExpenseIDs)
                        dismiss()
                    }
                    .foregroundStyle(CheckLineColor.danger)
                }
            }
        }
    }

    private func sharedExpenseToggle(_ expense: PrototypeExpense) -> some View {
        Toggle(
            isOn: Binding(
                get: { globallyDeletedExpenseIDs.contains(expense.id) },
                set: { isSelected in
                    if isSelected {
                        globallyDeletedExpenseIDs.insert(expense.id)
                    } else {
                        globallyDeletedExpenseIDs.remove(expense.id)
                    }
                    PrototypeHaptics.selection()
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(expense.title) · \(currencyText(expense.amount))")
                    .font(.subheadline.weight(.semibold))
                Text(otherBudgetNames(for: expense))
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
            }
        }
        .tint(CheckLineColor.danger)
    }

    private func otherBudgetNames(for expense: PrototypeExpense) -> String {
        let names = expense.budgetIDs
            .filter { $0 != budgetID }
            .compactMap { store.budget(id: $0)?.name }
            .sorted()
            .joined(separator: " / ")
        return String(format: String(localized: "delete.shared.stillIn"), names)
    }

    private func selectAll(_ isSelected: Bool) {
        globallyDeletedExpenseIDs = isSelected ? Set(linkedExpenses.map(\.id)) : []
        PrototypeHaptics.selection()
    }
}

struct PrototypeBudgetRecordsView: View {
    @Environment(\.editMode) private var editMode
    let store: PrototypeStore
    let budgetID: UUID
    let onDeleteSingle: (PrototypeExpense, Bool) -> Void
    let onDeleteBatch: (Set<UUID>, Set<UUID>) -> Void

    @State private var selectedExpenseIDs: Set<UUID> = []
    @State private var pendingSharedExpense: PrototypeExpense?
    @State private var showBatchDelete = false

    private var budget: PrototypeBudget? { store.budget(id: budgetID) }
    private var expenses: [PrototypeExpense] { store.expenses(for: budgetID) }
    private var selectedExpenses: [PrototypeExpense] {
        expenses.filter { selectedExpenseIDs.contains($0.id) }
    }

    var body: some View {
        List(selection: $selectedExpenseIDs) {
            if expenses.isEmpty {
                ContentUnavailableView("expense.empty", systemImage: "tray")
            } else {
                ForEach(expenses) { expense in
                    recordRow(expense)
                        .tag(expense.id)
                        .swipeActions(edge: .trailing, allowsFullSwipe: expense.budgetIDs.count == 1) {
                            Button(role: .destructive) {
                                requestSingleDelete(expense)
                            } label: {
                                Label("action.delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle(Text("records.manage.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            if !selectedExpenseIDs.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showBatchDelete = true
                    } label: {
                        Label(
                            String(
                                format: String(localized: "records.delete.selected"),
                                selectedExpenseIDs.count
                            ),
                            systemImage: "trash"
                        )
                    }
                }
            }
        }
        .confirmationDialog(
            "delete.expense.shared.title",
            isPresented: Binding(
                get: { pendingSharedExpense != nil },
                set: { if !$0 { pendingSharedExpense = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingSharedExpense
        ) { expense in
            Button("delete.expense.currentOnly", role: .destructive) {
                onDeleteSingle(expense, false)
            }
            Button("delete.expense.everywhere", role: .destructive) {
                onDeleteSingle(expense, true)
            }
            Button("action.cancel", role: .cancel) {}
        } message: { expense in
            Text(sharedExpenseMessage(expense))
        }
        .sheet(isPresented: $showBatchDelete) {
            PrototypeBatchExpenseDeleteSheet(
                store: store,
                budgetID: budgetID,
                expenses: selectedExpenses
            ) { globallyDeletedExpenseIDs in
                onDeleteBatch(selectedExpenseIDs, globallyDeletedExpenseIDs)
                selectedExpenseIDs.removeAll()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: editMode?.wrappedValue) { _, newValue in
            if newValue != .active {
                selectedExpenseIDs.removeAll()
            }
        }
    }

    private func recordRow(_ expense: PrototypeExpense) -> some View {
        HStack(spacing: 12) {
            Image(systemName: expense.budgetIDs.count > 1 ? "link" : "doc.text")
                .foregroundStyle(expense.budgetIDs.count > 1 ? CheckLineColor.brand : CheckLineColor.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.subheadline.weight(.semibold))
                Text(expense.occurredAt, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
                if expense.budgetIDs.count > 1 {
                    Text(sharedBudgetNames(expense))
                        .font(.caption)
                        .foregroundStyle(CheckLineColor.brand)
                }
            }
            Spacer()
            Text(currencyText(expense.amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(minHeight: 48)
    }

    private func requestSingleDelete(_ expense: PrototypeExpense) {
        if expense.budgetIDs.count > 1 {
            pendingSharedExpense = expense
        } else {
            onDeleteSingle(expense, false)
        }
    }

    private func sharedBudgetNames(_ expense: PrototypeExpense) -> String {
        expense.budgetIDs
            .compactMap { store.budget(id: $0)?.name }
            .sorted()
            .joined(separator: " / ")
    }

    private func sharedExpenseMessage(_ expense: PrototypeExpense) -> String {
        let otherNames = expense.budgetIDs
            .filter { $0 != budgetID }
            .compactMap { store.budget(id: $0)?.name }
            .sorted()
            .joined(separator: " / ")
        return String(
            format: String(localized: "delete.expense.shared.message"),
            expense.title,
            otherNames
        )
    }
}

struct PrototypeBatchExpenseDeleteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: PrototypeStore
    let budgetID: UUID
    let expenses: [PrototypeExpense]
    let onConfirm: (Set<UUID>) -> Void

    @State private var globallyDeletedExpenseIDs: Set<UUID> = []

    private var linkedExpenses: [PrototypeExpense] {
        expenses.filter { $0.budgetIDs.count > 1 }
    }
    private var exclusiveCount: Int {
        expenses.count - linkedExpenses.count
    }
    private var allLinkedSelected: Bool {
        !linkedExpenses.isEmpty && globallyDeletedExpenseIDs == Set(linkedExpenses.map(\.id))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        String(
                            format: String(localized: "delete.batch.summary"),
                            expenses.count,
                            exclusiveCount
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(CheckLineColor.secondary)
                }

                if !linkedExpenses.isEmpty {
                    Section {
                        Toggle(
                            "delete.shared.selectAll",
                            isOn: Binding(
                                get: { allLinkedSelected },
                                set: { selectAll($0) }
                            )
                        )
                        .tint(CheckLineColor.danger)

                        ForEach(linkedExpenses) { expense in
                            Toggle(
                                isOn: Binding(
                                    get: { globallyDeletedExpenseIDs.contains(expense.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            globallyDeletedExpenseIDs.insert(expense.id)
                                        } else {
                                            globallyDeletedExpenseIDs.remove(expense.id)
                                        }
                                        PrototypeHaptics.selection()
                                    }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(expense.title) · \(currencyText(expense.amount))")
                                        .font(.subheadline.weight(.semibold))
                                    Text(otherBudgetNames(for: expense))
                                        .font(.caption)
                                        .foregroundStyle(CheckLineColor.secondary)
                                }
                            }
                            .tint(CheckLineColor.danger)
                        }
                    } header: {
                        Text("delete.shared.section")
                    } footer: {
                        Text("delete.shared.default")
                    }
                }
            }
            .navigationTitle(Text("delete.batch.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("delete.batch.confirm") {
                        onConfirm(globallyDeletedExpenseIDs)
                        dismiss()
                    }
                    .foregroundStyle(CheckLineColor.danger)
                }
            }
        }
    }

    private func otherBudgetNames(for expense: PrototypeExpense) -> String {
        let names = expense.budgetIDs
            .filter { $0 != budgetID }
            .compactMap { store.budget(id: $0)?.name }
            .sorted()
            .joined(separator: " / ")
        return String(format: String(localized: "delete.shared.stillIn"), names)
    }

    private func selectAll(_ isSelected: Bool) {
        globallyDeletedExpenseIDs = isSelected ? Set(linkedExpenses.map(\.id)) : []
        PrototypeHaptics.selection()
    }
}

struct PrototypeRecordBudgetPickerView: View {
    let store: PrototypeStore
    let onDeleteSingle: (PrototypeExpense, UUID, Bool) -> Void
    let onDeleteBatch: (Set<UUID>, UUID, Set<UUID>) -> Void

    var body: some View {
        List {
            ForEach(store.budgets.filter { $0.status != .archived }) { budget in
                NavigationLink {
                    PrototypeBudgetRecordsView(
                        store: store,
                        budgetID: budget.id,
                        onDeleteSingle: { expense, deleteFromAllBudgets in
                            onDeleteSingle(expense, budget.id, deleteFromAllBudgets)
                        },
                        onDeleteBatch: { expenseIDs, globallyDeletedExpenseIDs in
                            onDeleteBatch(expenseIDs, budget.id, globallyDeletedExpenseIDs)
                        }
                    )
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(budget.name)
                                .font(.subheadline.weight(.semibold))
                            Text(
                                String(
                                    format: String(localized: "count.records"),
                                    store.expenses(for: budget.id).count
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(CheckLineColor.secondary)
                        }
                        Spacer()
                        if !store.linkedExpenses(for: budget.id).isEmpty {
                            Image(systemName: "link")
                                .foregroundStyle(CheckLineColor.brand)
                                .accessibilityLabel(Text("records.shared.accessibility"))
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("settings.records"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
