import SwiftUI

struct PrototypeHomeView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID
    let onShowBudgets: () -> Void
    let onCapture: () -> Void

    private var selectedBudget: PrototypeBudget {
        store.budget(id: selectedBudgetID) ?? store.activeBudgets[0]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("home.wallets")
                        .font(.headline)
                    Spacer()
                    Button("action.viewAll", action: onShowBudgets)
                }

                BudgetPager(
                    budgets: store.activeBudgets,
                    selectedBudgetID: $selectedBudgetID
                )

                walletContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(CheckLineColor.canvas)
        .navigationTitle(Text("home.title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("capture.title", systemImage: "plus", action: onCapture)
            }
        }
        .onAppear {
            if !store.activeBudgets.contains(where: { $0.id == selectedBudgetID }),
               let first = store.activeBudgets.first {
                selectedBudgetID = first.id
            }
        }
    }

    private var walletContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedBudget.name)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(selectedBudget.categories.prefix(3)) { category in
                    PrototypeCategoryRow(category: category)
                    Divider()
                }

                ForEach(Array(store.expenses(for: selectedBudget.id).prefix(3))) { expense in
                    PrototypeExpenseRow(expense: expense, store: store)
                    Divider()
                }
            }
        }
    }
}

struct BudgetPager: View {
    let budgets: [PrototypeBudget]
    @Binding var selectedBudgetID: UUID
    @State private var scrollID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(budgets) { budget in
                    PrototypeBudgetCard(budget: budget)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 12)
                        .id(budget.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID)
        .frame(height: 174)
        .onAppear { scrollID = selectedBudgetID }
        .onChange(of: scrollID) { _, newValue in
            guard let newValue, newValue != selectedBudgetID else { return }
            selectedBudgetID = newValue
            PrototypeHaptics.selection()
        }
        .onChange(of: selectedBudgetID) { _, newValue in
            guard scrollID != newValue else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollID = newValue
            }
        }
    }
}

struct PrototypeBudgetCard: View {
    let budget: PrototypeBudget

    private var progressColor: Color {
        budget.progress >= 0.95 ? CheckLineColor.danger : CheckLineColor.text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.name).font(.headline)
                    Text("\(budget.template.title) · \(budget.cycleType.title)")
                        .font(.caption)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("budget.remaining.label").font(.caption)
                    Text(currencyText(budget.remaining))
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(progressColor)
                }
            }

            HStack(spacing: 10) {
                BudgetProgressBar(progress: budget.progress)
                Text(budget.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
            }

            ForEach(budget.categories.prefix(2)) { category in
                HStack {
                    Text(category.name)
                    Spacer()
                    Text(currencyText(max(0, category.limit - category.spent)))
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }
}

struct PrototypeCategoryRow: View {
    let category: PrototypeCategory

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(category.name)
                Text("\(String(localized: "budget.used")) \(currencyText(category.spent)) / \(currencyText(category.limit))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: category.iconName)
                    .foregroundStyle(categoryColor(category))
            }
            .labelStyle(.titleAndIcon)
            Spacer()
            Text(currencyText(max(0, category.limit - category.spent)))
                .font(.subheadline.monospacedDigit())
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

struct PrototypeExpenseRow: View {
    let expense: PrototypeExpense
    let store: PrototypeStore

    private var budgetNames: String {
        expense.budgetIDs.compactMap { store.budget(id: $0)?.name }.joined(separator: " / ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(expense.title)
                    .lineLimit(1)
                Text("\(expense.occurredAt.formatted(.dateTime.month(.defaultDigits).day())) · \(budgetNames)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "receipt")
                    .foregroundStyle(CheckLineColor.brand)
            }
            .labelStyle(.titleAndIcon)
            Spacer()
            Text("−\(currencyText(expense.amount))")
                .font(.subheadline.monospacedDigit())
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
