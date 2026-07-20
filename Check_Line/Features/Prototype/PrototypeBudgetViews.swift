import SwiftUI

struct PrototypeBudgetListView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID
    let onCreate: () -> Void
    let onCapture: (UUID) -> Void
    let onSettle: (UUID) -> Void

    var body: some View {
        List {
            summaryCard
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                .listRowBackground(Color.clear)

            Section("budget.active.section") {
                ForEach(store.activeBudgets) { budget in
                    budgetNavigationRow(budget)
                }
            }

            Section("budget.settling.section") {
                if store.settlingBudgets.isEmpty {
                    emptySettling
                } else {
                    ForEach(store.settlingBudgets) { budget in
                        budgetNavigationRow(budget)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CheckLineColor.canvas)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("budget.overview")
                .font(.caption.bold())
                .foregroundStyle(CheckLineColor.secondary)
            Text(String(format: String(localized: "budget.overview.summary"), store.activeBudgets.count, store.settlingBudgets.count))
                .font(.title3.bold())
                .foregroundStyle(CheckLineColor.text)
            HStack(spacing: 12) {
                summaryMetric(title: "budget.active.metric", value: String(format: String(localized: "count.budgets"), store.activeBudgets.count))
                summaryMetric(title: "budget.records.metric", value: String(format: String(localized: "count.records"), store.expenses.count))
            }
        }
        .padding(16)
        .prototypeCard()
    }

    private func summaryMetric(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CheckLineColor.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(CheckLineColor.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func budgetNavigationRow(_ budget: PrototypeBudget) -> some View {
        NavigationLink {
            PrototypeBudgetDetailView(
                store: store,
                budgetID: budget.id,
                onCapture: { onCapture(budget.id) },
                onSettle: { onSettle(budget.id) }
            )
            .onAppear { selectedBudgetID = budget.id }
        } label: {
            PrototypeBudgetListRow(budget: budget)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowBackground(CheckLineColor.card)
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
        .padding(16)
        .listRowBackground(CheckLineColor.card)
    }
}

struct PrototypeBudgetListRow: View {
    let budget: PrototypeBudget

    var body: some View {
        HStack(spacing: 12) {
            Text(String(budget.name.prefix(1)))
                .font(.headline.bold())
                .foregroundStyle(CheckLineColor.brand)
                .frame(width: 42, height: 42)
                .background(CheckLineColor.brandSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(budget.name)
                    .font(.subheadline.bold())
                Text("\(dateRangeText(budget)) · \(budget.cycleType.title)")
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
                BudgetProgressBar(progress: budget.progress, height: 6)
            }

            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 5) {
                Text(LocalizedStringKey(budget.status == .settling ? "budget.surplus" : "budget.remaining.short"))
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
                Text(currencyText(budget.remaining))
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(CheckLineColor.quiet)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 82)
        .contentShape(Rectangle())
    }
}

struct PrototypeBudgetDetailView: View {
    let store: PrototypeStore
    let budgetID: UUID
    let onCapture: () -> Void
    let onSettle: () -> Void

    private var budget: PrototypeBudget? { store.budget(id: budgetID) }

    var body: some View {
        Group {
            if let budget {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        summary(budget)
                        PrototypeSectionHeader("budget.categories")
                        categoryList(budget)
                        PrototypeSectionHeader("expense.recent.title")
                        expenseList
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                }
                .background(CheckLineColor.canvas)
                .navigationTitle(budget.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("budget.missing", systemImage: "wallet.pass")
            }
        }
    }

    private func summary(_ budget: PrototypeBudget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("budget.remaining.label")
                .font(.caption.bold())
                .foregroundStyle(CheckLineColor.secondary)
            MoneyText(amount: budget.remaining)
            Text("\(currencyText(budget.spent)) / \(currencyText(budget.total)) \(String(localized: "budget.used"))")
                .font(.caption)
                .foregroundStyle(CheckLineColor.secondary)
            HStack(spacing: 10) {
                BudgetProgressBar(progress: budget.progress)
                Text(budget.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.bold())
                    .foregroundStyle(CheckLineColor.secondary)
            }
            HStack(spacing: 10) {
                Button("capture.title", action: onCapture)
                    .buttonStyle(.borderedProminent)
                    .tint(CheckLineColor.brand)
                Button(budget.status == .active ? "settlement.preview" : "budget.settle", action: onSettle)
                    .buttonStyle(.bordered)
                    .tint(budget.status == .settling ? CheckLineColor.danger : CheckLineColor.brand)
            }
        }
        .padding(16)
        .prototypeCard()
    }

    private func categoryList(_ budget: PrototypeBudget) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(budget.categories.enumerated()), id: \.element.id) { index, category in
                VStack(spacing: 7) {
                    PrototypeCategoryRow(category: category)
                    BudgetProgressBar(
                        progress: category.limit > 0 ? min(1, decimalDouble(category.spent / category.limit)) : 0,
                        height: 5
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
                if index < budget.categories.count - 1 {
                    Divider().padding(.leading, 58)
                }
            }
        }
        .prototypeCard()
    }

    private var expenseList: some View {
        let expenses = store.expenses(for: budgetID)
        return Group {
            if expenses.isEmpty {
                Text("expense.empty")
                    .font(.subheadline)
                    .foregroundStyle(CheckLineColor.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .prototypeCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                        PrototypeExpenseRow(expense: expense, store: store)
                        if index < expenses.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .prototypeCard()
            }
        }
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
            Form {
                Section("budget.basic") {
                    TextField("budget.name", text: $name)
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

                Section("budget.amount.period") {
                    TextField("budget.total", text: $totalText)
                        .keyboardType(.decimalPad)
                    DatePicker("budget.start", selection: $startDate, displayedComponents: .date)
                    DatePicker("budget.end", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section {
                    Text("budget.template.note")
                        .font(.footnote)
                        .foregroundStyle(CheckLineColor.secondary)
                }
            }
            .navigationTitle(Text("budget.create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.create") { create() }
                        .disabled(!canSave)
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
