import SwiftUI

struct PrototypeBudgetListView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID
    let onCreate: () -> Void
    let onCapture: (UUID) -> Void
    let onSettle: (UUID) -> Void
    let onDeleteSingleExpense: (PrototypeExpense, UUID, Bool) -> Void
    let onDeleteBatchExpenses: (Set<UUID>, UUID, Set<UUID>) -> Void
    let onDeleteBudget: (UUID, Set<UUID>) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
            summaryCard

                budgetSection(
                    title: "budget.active.section",
                    budgets: store.activeBudgets
                )

                budgetSection(
                    title: "budget.settling.section",
                    budgets: store.settlingBudgets
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(CheckLineColor.canvas.ignoresSafeArea())
        .navigationTitle(Text("tab.budgets"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCreate) {
                    Label("budget.create", systemImage: "plus")
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("budget.overview")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CheckLineColor.secondary)

            Text(
                String(
                    format: String(localized: "budget.overview.summary"),
                    store.activeBudgets.count,
                    store.settlingBudgets.count
                )
            )
                .font(.title2.weight(.semibold))
                .foregroundStyle(CheckLineColor.text)

            Text(
                String(
                    format: String(localized: "count.records"),
                    store.expenses.count
                )
            )
                .font(.subheadline)
                .foregroundStyle(CheckLineColor.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func budgetSection(
        title: LocalizedStringKey,
        budgets: [PrototypeBudget]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CheckLineSectionHeader(title)

            VStack(spacing: 0) {
                if budgets.isEmpty {
                    emptySettling
                } else {
                    ForEach(Array(budgets.enumerated()), id: \.element.id) { index, budget in
                        budgetNavigationRow(budget)
                        if index < budgets.count - 1 {
                            Divider()
                                .padding(.leading, 18)
                        }
                    }
                }
            }
            .background(CheckLineColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.035), radius: 20, x: 0, y: 10)
        }
    }

    private func budgetNavigationRow(_ budget: PrototypeBudget) -> some View {
        NavigationLink {
            PrototypeBudgetDetailView(
                store: store,
                budgetID: budget.id,
                onCapture: { onCapture(budget.id) },
                onSettle: { onSettle(budget.id) },
                onDeleteSingleExpense: { expense, deleteFromAllBudgets in
                    onDeleteSingleExpense(expense, budget.id, deleteFromAllBudgets)
                },
                onDeleteBatchExpenses: { expenseIDs, globallyDeletedExpenseIDs in
                    onDeleteBatchExpenses(expenseIDs, budget.id, globallyDeletedExpenseIDs)
                },
                onDeleteBudget: { globallyDeletedExpenseIDs in
                    onDeleteBudget(budget.id, globallyDeletedExpenseIDs)
                }
            )
            .onAppear { selectedBudgetID = budget.id }
        } label: {
            PrototypeBudgetListRow(budget: budget)
        }
        .buttonStyle(.plain)
    }

    private var emptySettling: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("budget.settling.empty.title")
                .font(.subheadline.bold())
            Text("budget.settling.empty.message")
                .font(.caption)
                .foregroundStyle(CheckLineColor.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
    }
}

struct PrototypeBudgetListRow: View {
    let budget: PrototypeBudget

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(budget.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(CheckLineColor.text)
                Text("\(dateRangeText(budget)) · \(budget.cycleType.title)")
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
                BudgetProgressBar(progress: budget.progress)
            }

            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) {
                Text(LocalizedStringKey(budget.status == .settling ? "budget.surplus" : "budget.remaining.short"))
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
                Text(currencyText(budget.remaining))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(CheckLineColor.text)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CheckLineColor.quiet)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(minHeight: 86)
        .contentShape(Rectangle())
    }
}

struct PrototypeBudgetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let store: PrototypeStore
    let budgetID: UUID
    let onCapture: () -> Void
    let onSettle: () -> Void
    let onDeleteSingleExpense: (PrototypeExpense, Bool) -> Void
    let onDeleteBatchExpenses: (Set<UUID>, Set<UUID>) -> Void
    let onDeleteBudget: (Set<UUID>) -> Void

    @State private var showBudgetDeleteConfirmation = false
    @State private var showLinkedExpenseDeleteSheet = false

    private var budget: PrototypeBudget? { store.budget(id: budgetID) }

    var body: some View {
        if let budget {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    summary(budget)
                    categoriesSection(budget)
                    recordsSection(budget)

                    Button(role: .destructive) {
                        showBudgetDeleteConfirmation = true
                    } label: {
                        Label("delete.budget.action", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                    }

                    Text("delete.budget.footer")
                        .font(.caption)
                        .foregroundStyle(CheckLineColor.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 36)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(CheckLineColor.canvas.ignoresSafeArea())
            .navigationTitle(budget.name)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "delete.budget.title",
                isPresented: $showBudgetDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("delete.budget.continue", role: .destructive) {
                    continueBudgetDeletion()
                }
                Button("action.cancel", role: .cancel) {}
            } message: {
                Text(
                    String(
                        format: String(localized: "delete.budget.message"),
                        budget.name
                    )
                )
            }
            .sheet(isPresented: $showLinkedExpenseDeleteSheet) {
                PrototypeBudgetDeleteSheet(
                    store: store,
                    budgetID: budgetID
                ) { globallyDeletedExpenseIDs in
                    finishBudgetDeletion(globallyDeletedExpenseIDs)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        } else {
            ContentUnavailableView("budget.missing", systemImage: "wallet.pass")
        }
    }

    private func summary(_ budget: PrototypeBudget) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                MoneyText(amount: budget.remaining, size: 52)
                Text(
                    String(
                        format: String(localized: "home.budget.total.inline"),
                        currencyText(budget.total)
                    )
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(CheckLineColor.secondary)
                .fixedSize(horizontal: true, vertical: false)
            }

            Text(
                String(
                    format: String(localized: "budget.used.amount"),
                    currencyText(budget.spent)
                )
            )
            .font(.subheadline)
            .foregroundStyle(CheckLineColor.secondary)

            HStack(spacing: 10) {
                BudgetProgressBar(progress: budget.progress)
                Text(budget.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CheckLineColor.secondary)
            }

            HStack(spacing: 10) {
                Button("capture.title", action: onCapture)
                    .buttonStyle(CheckLinePrimaryButtonStyle())
                    .frame(maxWidth: .infinity)

                Button(budget.status == .active ? "settlement.preview" : "budget.settle", action: onSettle)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(budget.status == .settling ? CheckLineColor.danger : CheckLineColor.text)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func categoriesSection(_ budget: PrototypeBudget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CheckLineSectionHeader("budget.categories")

            VStack(spacing: 0) {
                ForEach(Array(budget.categories.enumerated()), id: \.element.id) { index, category in
                    VStack(alignment: .leading, spacing: 4) {
                        PrototypeCategoryRow(category: category)
                        BudgetProgressBar(
                            progress: category.limit > 0
                                ? decimalDouble(category.spent / category.limit)
                                : 0,
                            height: 4
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)

                    if index < budget.categories.count - 1 {
                        Divider()
                            .padding(.leading, 62)
                    }
                }
            }
            .padding(.vertical, 6)
            .background(CheckLineColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.035), radius: 20, x: 0, y: 10)
        }
    }

    private func recordsSection(_ budget: PrototypeBudget) -> some View {
        let expenses = store.expenses(for: budgetID)

        return VStack(alignment: .leading, spacing: 12) {
            CheckLineSectionHeader("expense.recent.title")

            VStack(spacing: 0) {
                if expenses.isEmpty {
                    Text("expense.empty")
                        .font(.subheadline)
                        .foregroundStyle(CheckLineColor.secondary)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .padding(.horizontal, 18)
                } else {
                    ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                        PrototypeExpenseRow(expense: expense, store: store)
                            .padding(.horizontal, 18)

                        if index < expenses.count - 1 {
                            Divider()
                                .padding(.leading, 62)
                        }
                    }

                    Divider()
                        .padding(.leading, 18)

                    NavigationLink {
                        PrototypeBudgetRecordsView(
                            store: store,
                            budgetID: budgetID,
                            onDeleteSingle: onDeleteSingleExpense,
                            onDeleteBatch: onDeleteBatchExpenses
                        )
                    } label: {
                        HStack {
                            Label("records.manage.action", systemImage: "list.bullet.rectangle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CheckLineColor.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CheckLineColor.quiet)
                        }
                        .padding(18)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(CheckLineColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.035), radius: 20, x: 0, y: 10)
        }
    }

    private func continueBudgetDeletion() {
        if store.linkedExpenses(for: budgetID).isEmpty {
            finishBudgetDeletion([])
        } else {
            showLinkedExpenseDeleteSheet = true
        }
    }

    private func finishBudgetDeletion(_ globallyDeletedExpenseIDs: Set<UUID>) {
        onDeleteBudget(globallyDeletedExpenseIDs)
        dismiss()
    }
}

struct PrototypeCreateBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: PrototypeStore
    let onCreated: (UUID) -> Void

    @State private var name = String(localized: "sample.budget.weekend")
    @State private var template: PrototypeTemplate = .travel
    @State private var cycleType: PrototypeCycleType = .oneShot
    @State private var totalText = "1200"
    @State private var startDate = prototypeDate(year: 2026, month: 7, day: 20)
    @State private var endDate = prototypeDate(year: 2026, month: 7, day: 21)

    private var total: Decimal? { Decimal(string: totalText) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (total ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    CheckLineSurface {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("budget.basic")
                                .font(.headline.weight(.semibold))

                            VStack(alignment: .leading, spacing: 7) {
                                Text("budget.name")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(CheckLineColor.secondary)
                                TextField("budget.name", text: $name)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                            }

                            Divider()

                            Picker("budget.template", selection: $template) {
                                ForEach(PrototypeTemplate.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }

                            Picker("budget.cycle", selection: $cycleType) {
                                ForEach(PrototypeCycleType.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    CheckLineSurface {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("budget.amount.period")
                                .font(.headline.weight(.semibold))

                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                Text("currency.cny")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(CheckLineColor.secondary)
                                TextField("budget.total", text: $totalText)
                                    .font(.system(size: 36, weight: .regular, design: .default))
                                    .keyboardType(.decimalPad)
                                    .monospacedDigit()
                                    .textFieldStyle(.plain)
                            }

                            Divider()
                            DatePicker("budget.start", selection: $startDate, displayedComponents: .date)
                            DatePicker("budget.end", selection: $endDate, in: startDate..., displayedComponents: .date)
                        }
                    }

                    Text("budget.template.note")
                        .font(.footnote)
                        .foregroundStyle(CheckLineColor.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 108)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(CheckLineColor.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("action.create", action: create)
                    .buttonStyle(CheckLinePrimaryButtonStyle())
                    .disabled(!canSave)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(CheckLineColor.canvas)
            }
            .navigationTitle(Text("budget.create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
            }
        }
    }

    private func create() {
        guard let total, total > 0 else { return }
        let budgetID = store.addBudget(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            template: template,
            cycleType: cycleType,
            total: total,
            startDate: startDate,
            endDate: endDate
        )
        PrototypeHaptics.success()
        onCreated(budgetID)
        dismiss()
    }
}
