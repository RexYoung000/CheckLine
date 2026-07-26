import SwiftUI

struct PrototypeHomeView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID
    let onShowBudgets: () -> Void
    let onCapture: () -> Void

    private var selectedBudget: PrototypeBudget? {
        store.activeBudgets.first { $0.id == selectedBudgetID } ?? store.activeBudgets.first
    }

    var body: some View {
        Group {
            if let selectedBudget {
                budgetContent(selectedBudget)
            } else {
                ContentUnavailableView(
                    "budget.empty.title",
                    systemImage: "wallet.pass",
                    description: Text("budget.empty.message")
                )
            }
        }
        .background(CheckLineColor.canvas)
        .navigationTitle(Text("home.title"))
        .onAppear {
            if !store.activeBudgets.contains(where: { $0.id == selectedBudgetID }),
               let first = store.activeBudgets.first {
                selectedBudgetID = first.id
            }
        }
    }

    private func budgetContent(_ selectedBudget: PrototypeBudget) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("home.wallets")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Button("action.viewAll", action: onShowBudgets)
                        .font(.subheadline.weight(.semibold))
                }

                BudgetPager(
                    budgets: store.activeBudgets,
                    selectedBudgetID: $selectedBudgetID
                )

                walletContent(selectedBudget)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .accessibilityIdentifier("home.scroll")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()
                Button(action: onCapture) {
                    Label("capture.title", systemImage: "plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(CheckLineColor.brand)
                .shadow(color: CheckLineColor.brand.opacity(0.22), radius: 16, x: 0, y: 8)
                .accessibilityLabel(Text("capture.add.accessibility"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(CheckLineColor.canvas)
        }
    }

    private func walletContent(_ selectedBudget: PrototypeBudget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("budget.categories")
                    .font(.headline.weight(.bold))
                Spacer()
                Text(dateRangeText(selectedBudget))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CheckLineColor.secondary)
            }

            CheckLineSurface {
                VStack(spacing: 0) {
                    ForEach(Array(selectedBudget.categories.prefix(3).enumerated()), id: \.element.id) { index, category in
                        PrototypeCategoryRow(category: category)
                        if index < min(selectedBudget.categories.count, 3) - 1 {
                            Divider()
                                .overlay(CheckLineColor.divider)
                        }
                    }
                }
            }

            HStack {
                Text("expense.recent.title")
                    .font(.headline.weight(.bold))
                Spacer()
                Text(selectedBudget.cycleType.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CheckLineColor.secondary)
            }

            CheckLineSurface {
                let recentExpenses = Array(store.expenses(for: selectedBudget.id).prefix(3))
                VStack(spacing: 0) {
                    ForEach(Array(recentExpenses.enumerated()), id: \.element.id) { index, expense in
                        PrototypeExpenseRow(expense: expense, store: store)
                        if index < recentExpenses.count - 1 {
                            Divider()
                                .overlay(CheckLineColor.divider)
                        }
                    }
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
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(budgets) { budget in
                        PrototypeBudgetCard(
                            budget: budget,
                            isSelected: budget.id == selectedBudgetID
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 12)
                        .id(budget.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollID)
            .frame(height: 194)
            .accessibilityIdentifier("home.budgetPager")

            HStack(spacing: 7) {
                ForEach(budgets) { budget in
                    Capsule()
                        .fill(budget.id == selectedBudgetID ? CheckLineColor.brand : CheckLineColor.divider)
                        .frame(width: budget.id == selectedBudgetID ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedBudgetID)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
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
    let isSelected: Bool

    private var progressColor: Color {
        budget.progress >= 0.95 ? CheckLineColor.danger : CheckLineColor.text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.name)
                        .font(.headline.weight(.bold))
                    Text("\(budget.template.title) · \(budget.cycleType.title)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CheckLineColor.secondary)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("budget.remaining.label")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CheckLineColor.secondary)
                    MoneyText(amount: budget.remaining, color: progressColor, size: 34)
                }
            }

            HStack(spacing: 10) {
                BudgetProgressBar(progress: budget.progress)
                Text(budget.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(CheckLineColor.secondary)
                    .frame(minWidth: 34, alignment: .trailing)
            }

            HStack(spacing: 8) {
                ForEach(budget.categories.prefix(2)) { category in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(categoryColor(category))
                            .frame(width: 6, height: 6)
                        Text("\(category.name) \(currencyText(max(0, category.limit - category.spent)))")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CheckLineColor.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(CheckLineColor.muted, in: Capsule())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CheckLineColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isSelected ? CheckLineColor.brand.opacity(0.5) : CheckLineColor.surfaceStroke.opacity(0.8),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.075 : 0.045), radius: 20, x: 0, y: isSelected ? 9 : 7)
        .scaleEffect(isSelected ? 1 : 0.985)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isSelected)
    }
}

struct PrototypeCategoryRow: View {
    let category: PrototypeCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(categoryColor(category), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.body.weight(.semibold))
                Text("\(String(localized: "budget.used")) \(currencyText(category.spent)) / \(currencyText(category.limit))")
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
            }

            Spacer(minLength: 8)
            Text(currencyText(max(0, category.limit - category.spent)))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(CheckLineColor.text)
        }
        .padding(.vertical, 8)
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
            Image(systemName: "receipt")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CheckLineColor.brand)
                .frame(width: 32, height: 32)
                .background(CheckLineColor.brandSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("\(expense.occurredAt.formatted(.dateTime.month(.defaultDigits).day())) · \(budgetNames)")
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            Text("−\(currencyText(expense.amount))")
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(CheckLineColor.text)
        }
        .padding(.vertical, 8)
    }
}
