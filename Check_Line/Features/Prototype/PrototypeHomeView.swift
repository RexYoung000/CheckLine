import SwiftUI

private enum PrototypeHomePalette {
    static let canvas = Color(hex: 0xF8F8F5)
    static let surface = Color.white
    static let control = Color(hex: 0xF0F0EC)
    static let ink = Color(hex: 0x1B1B1A)
    static let secondary = Color(hex: 0x74746E)
    static let quiet = Color(hex: 0x9A9A94)
}

struct PrototypeHomeView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID
    let onShowBudgets: () -> Void
    let onShowInsights: () -> Void
    let onCapture: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 54

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
        .background(PrototypeHomePalette.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(PrototypeHomePalette.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            if !store.activeBudgets.contains(where: { $0.id == selectedBudgetID }),
               let first = store.activeBudgets.first {
                selectedBudgetID = first.id
            }
        }
    }

    private func budgetContent(_ budget: PrototypeBudget) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                homeHeader
                    .padding(.horizontal, 28)

                budgetHero(budget)
                    .padding(.horizontal, 28)

                quickActions
                    .padding(.horizontal, 28)

                recentRecords(budget)
                    .padding(.horizontal, 16)
                    .padding(.top, 38)
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .accessibilityIdentifier("home.scroll")
    }

    private var homeHeader: some View {
        HStack(alignment: .center) {
            Text("home.title")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PrototypeHomePalette.ink)

            Spacer()

            Text("home.date")
                .font(.subheadline)
                .foregroundStyle(PrototypeHomePalette.secondary)
        }
        .frame(minHeight: 44)
    }

    private func budgetHero(_ budget: PrototypeBudget) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("budget.remaining.label")
                .font(.subheadline)
                .foregroundStyle(PrototypeHomePalette.secondary)
                .padding(.bottom, 7)

            Text(currencyText(budget.remaining))
                .font(.system(size: amountSize, weight: .regular, design: .default))
                .monospacedDigit()
                .foregroundStyle(PrototypeHomePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .contentTransition(.numericText(value: decimalDouble(budget.remaining)))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: budget.remaining)
                .accessibilityLabel(Text("budget.remaining.label"))
                .accessibilityValue(Text(currencyText(budget.remaining)))

            Menu {
                ForEach(store.activeBudgets) { candidate in
                    Button {
                        selectBudget(candidate.id)
                    } label: {
                        if candidate.id == selectedBudgetID {
                            Label(candidate.name, systemImage: "checkmark")
                        } else {
                            Text(candidate.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text(budget.name)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PrototypeHomePalette.ink)
                .padding(.horizontal, 15)
                .frame(minHeight: 38)
                .background(PrototypeHomePalette.control, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("home.budget.switch"))
            .accessibilityValue(Text(budget.name))
            .accessibilityIdentifier("home.budgetSelector")
            .padding(.top, 20)

            Text(
                String(
                    format: String(localized: "home.budget.summary"),
                    dateRangeText(budget),
                    currencyText(budget.spent),
                    currencyText(budget.total)
                )
            )
            .font(.footnote)
            .foregroundStyle(PrototypeHomePalette.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
        }
        .padding(.top, 36)
        .padding(.bottom, 38)
    }

    @ViewBuilder
    private var quickActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                PrototypeHomeAccessibleAction(
                    title: String(localized: "capture.title"),
                    systemImage: "plus",
                    isPrimary: true,
                    action: onCapture
                )
                PrototypeHomeAccessibleAction(
                    title: String(localized: "tab.budgets"),
                    systemImage: "square.stack.3d.up",
                    action: onShowBudgets
                )
                PrototypeHomeAccessibleAction(
                    title: String(localized: "tab.insights"),
                    systemImage: "chart.bar.xaxis",
                    action: onShowInsights
                )
            }
        } else {
            HStack(alignment: .top, spacing: 24) {
                Spacer(minLength: 0)
                PrototypeHomeAction(
                    title: String(localized: "capture.title"),
                    systemImage: "plus",
                    isPrimary: true,
                    action: onCapture
                )
                PrototypeHomeAction(
                    title: String(localized: "tab.budgets"),
                    systemImage: "square.stack.3d.up",
                    action: onShowBudgets
                )
                PrototypeHomeAction(
                    title: String(localized: "tab.insights"),
                    systemImage: "chart.bar.xaxis",
                    action: onShowInsights
                )
                Spacer(minLength: 0)
            }
        }
    }

    private func recentRecords(_ budget: PrototypeBudget) -> some View {
        let expenses = Array(store.expenses(for: budget.id).prefix(4))

        return VStack(alignment: .leading, spacing: 0) {
            Text("expense.recent.title")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PrototypeHomePalette.ink)
                .padding(.bottom, 18)

            if expenses.isEmpty {
                Text("expense.empty")
                    .font(.subheadline)
                    .foregroundStyle(PrototypeHomePalette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            } else {
                VStack(spacing: 18) {
                    ForEach(expenses) { expense in
                        PrototypeHomeExpenseRow(
                            expense: expense,
                            iconName: iconName(for: expense, in: budget)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(PrototypeHomePalette.surface)
        )
        .shadow(color: .black.opacity(0.035), radius: 22, x: 0, y: 10)
    }

    private func iconName(for expense: PrototypeExpense, in budget: PrototypeBudget) -> String {
        budget.categories.first { $0.name == expense.categoryName }?.iconName ?? "receipt"
    }

    private func selectBudget(_ id: UUID) {
        guard id != selectedBudgetID else { return }
        if reduceMotion {
            selectedBudgetID = id
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedBudgetID = id
            }
        }
        PrototypeHaptics.selection()
    }
}

private struct PrototypeHomeAction: View {
    let title: String
    let systemImage: String
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 64, height: 64)
                    .foregroundStyle(isPrimary ? .white : PrototypeHomePalette.ink)
                    .background(
                        isPrimary ? PrototypeHomePalette.ink : PrototypeHomePalette.control,
                        in: Circle()
                    )

                Text(title)
                    .font(.caption)
                    .foregroundStyle(PrototypeHomePalette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

private struct PrototypeHomeAccessibleAction: View {
    let title: String
    let systemImage: String
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(isPrimary ? .white : PrototypeHomePalette.ink)
                    .background(
                        isPrimary ? PrototypeHomePalette.ink : PrototypeHomePalette.control,
                        in: Circle()
                    )

                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(PrototypeHomePalette.ink)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PrototypeHomeExpenseRow: View {
    let expense: PrototypeExpense
    let iconName: String

    private var metadata: String {
        String(
            format: String(localized: "home.expense.metadata"),
            expense.categoryName,
            expense.occurredAt.formatted(
                .dateTime
                    .month(.defaultDigits)
                    .day()
            )
        )
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PrototypeHomePalette.ink)
                .frame(width: 42, height: 42)
                .background(PrototypeHomePalette.control, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PrototypeHomePalette.ink)
                    .lineLimit(1)

                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(PrototypeHomePalette.quiet)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(currencyText(-expense.amount))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(PrototypeHomePalette.ink)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                String(
                    format: String(localized: "home.expense.accessibility"),
                    expense.title,
                    metadata,
                    currencyText(expense.amount)
                )
            )
        )
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
