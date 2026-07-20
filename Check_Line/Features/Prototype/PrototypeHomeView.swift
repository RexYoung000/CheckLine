import SwiftUI

struct PrototypeHomeView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID
    let onShowBudgets: () -> Void

    private var selectedBudget: PrototypeBudget {
        store.budget(id: selectedBudgetID) ?? store.activeBudgets[0]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                header

                PrototypeSectionHeader("home.wallets") {
                    Button("action.viewAll", action: onShowBudgets)
                        .font(.subheadline.bold())
                }

                BudgetCarousel(
                    budgets: store.activeBudgets,
                    selectedBudgetID: $selectedBudgetID
                )

                walletContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(CheckLineColor.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("home.date")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CheckLineColor.secondary)
                Text("home.title")
                    .font(.largeTitle.bold())
                    .foregroundStyle(CheckLineColor.text)
            }
            Spacer()
            Image(systemName: "line.3.horizontal.decrease")
                .font(.body.weight(.semibold))
                .foregroundStyle(CheckLineColor.brand)
                .frame(width: 44, height: 44)
                .background(CheckLineColor.card, in: Circle())
                .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
                .accessibilityHidden(true)
        }
    }

    private var walletContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrototypeSectionHeader(LocalizedStringKey(selectedBudget.name))

            VStack(spacing: 0) {
                ForEach(Array(selectedBudget.categories.prefix(3).enumerated()), id: \.element.id) { index, category in
                    PrototypeCategoryRow(category: category)
                    if index < min(2, selectedBudget.categories.count - 1) {
                        Divider().padding(.leading, 58)
                    }
                }

                let recent = Array(store.expenses(for: selectedBudget.id).prefix(3))
                if !recent.isEmpty {
                    Divider()
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, expense in
                        PrototypeExpenseRow(expense: expense, store: store)
                        if index < recent.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
            }
            .prototypeCard()
        }
    }
}

struct BudgetCarousel: View {
    let budgets: [PrototypeBudget]
    @Binding var selectedBudgetID: UUID
    @State private var scrollID: UUID?

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(budgets) { budget in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    scrollID = budget.id
                                    selectedBudgetID = budget.id
                                }
                                PrototypeHaptics.selection()
                            } label: {
                                PrototypeBudgetCard(
                                    budget: budget,
                                    isSelected: budget.id == selectedBudgetID
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(width: max(280, proxy.size.width - 44))
                            .id(budget.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrollID)
            }
            .frame(height: 210)
            .onAppear { scrollID = selectedBudgetID }
            .onChange(of: scrollID) { _, newValue in
                guard let newValue, newValue != selectedBudgetID else { return }
                selectedBudgetID = newValue
                PrototypeHaptics.selection()
            }
            .onChange(of: selectedBudgetID) { _, newValue in
                guard scrollID != newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) { scrollID = newValue }
            }

            HStack(spacing: 7) {
                ForEach(budgets) { budget in
                    Capsule()
                        .fill(budget.id == selectedBudgetID ? CheckLineColor.brand : CheckLineColor.divider)
                        .frame(width: budget.id == selectedBudgetID ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.18), value: selectedBudgetID)
                }
            }
            .accessibilityHidden(true)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.name)
                        .font(.headline.bold())
                        .foregroundStyle(CheckLineColor.text)
                    Text("\(budget.template.title) · \(budget.cycleType.title)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CheckLineColor.secondary)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("budget.remaining.label")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CheckLineColor.secondary)
                    MoneyText(amount: budget.remaining, color: progressColor, size: 31)
                }
            }

            HStack(spacing: 10) {
                BudgetProgressBar(progress: budget.progress)
                Text(budget.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.bold())
                    .foregroundStyle(CheckLineColor.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                ForEach(budget.categories.prefix(2)) { category in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(categoryColor(category))
                            .frame(width: 7, height: 7)
                        Text("\(category.name) \(currencyText(max(0, category.limit - category.spent)))")
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CheckLineColor.secondary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(CheckLineColor.muted, in: Capsule())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 202, alignment: .topLeading)
        .background(CheckLineColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? CheckLineColor.brand.opacity(0.55) : CheckLineColor.divider.opacity(0.8), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(budget.name), \(String(localized: "budget.remaining.label")) \(currencyText(budget.remaining))"))
        .accessibilityValue(Text(budget.progress, format: .percent.precision(.fractionLength(0))))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PrototypeCategoryRow: View {
    let category: PrototypeCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(categoryColor(category))
                .frame(width: 42, height: 42)
                .background(categoryColor(category).opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.subheadline.bold())
                Text("\(String(localized: "budget.used")) \(currencyText(category.spent)) / \(currencyText(category.limit))")
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
            }
            Spacer()
            Text(currencyText(max(0, category.limit - category.spent)))
                .font(.subheadline.bold())
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 66)
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
                .font(.body.weight(.semibold))
                .foregroundStyle(CheckLineColor.brand)
                .frame(width: 42, height: 42)
                .background(CheckLineColor.brandSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text("\(expense.occurredAt.formatted(.dateTime.month(.defaultDigits).day())) · \(budgetNames)")
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("−\(currencyText(expense.amount))")
                .font(.subheadline.bold())
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 66)
    }
}
