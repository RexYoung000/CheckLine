import SwiftUI
import Charts

struct PrototypeInsightsView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID

    private var budget: PrototypeBudget? {
        store.activeBudgets.first { $0.id == selectedBudgetID } ?? store.activeBudgets.first
    }

    var body: some View {
        Group {
            if let budget {
                insightsContent(budget)
            } else {
                ContentUnavailableView(
                    "budget.empty.title",
                    systemImage: "chart.bar.xaxis",
                    description: Text("budget.empty.message")
                )
            }
        }
        .navigationTitle(Text("tab.insights"))
    }

    private func insightsContent(_ budget: PrototypeBudget) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                budgetPicker
                remainingCard(budget)
                comparisonSection(budget)
                categoriesSection(budget)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(CheckLineColor.canvas.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PrototypeCalendarView(store: store, selectedBudgetID: selectedBudgetID)
                } label: {
                    Label("insights.calendar", systemImage: "calendar")
                }
            }
        }
    }

    private var budgetPicker: some View {
        HStack {
            Text("insights.budgetPicker")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CheckLineColor.secondary)

            Spacer()

            Picker("insights.budgetPicker", selection: $selectedBudgetID) {
                ForEach(store.activeBudgets) { option in
                    Label(option.name, systemImage: "wallet.pass")
                        .tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .tint(CheckLineColor.text)
        }
    }

    private func remainingCard(_ budget: PrototypeBudget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: String(localized: "insights.remaining"), budget.name))
                .font(.caption.weight(.semibold))
                .foregroundStyle(CheckLineColor.secondary)

            MoneyText(amount: budget.remaining, size: 52)

            Text("\(dateRangeText(budget)) · \(String(localized: "budget.used")) \(currencyText(budget.spent))")
                .font(.subheadline)
                .foregroundStyle(CheckLineColor.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func comparisonSection(_ budget: PrototypeBudget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CheckLineSectionHeader("insights.comparison")
            CheckLineSurface {
                comparisonChart(budget)
            }
        }
    }

    private func categoriesSection(_ budget: PrototypeBudget) -> some View {
        let categories = budget.categories.sorted { $0.spent > $1.spent }

        return VStack(alignment: .leading, spacing: 12) {
            CheckLineSectionHeader("insights.categories")

            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: 12) {
                        Image(systemName: category.iconName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(categoryColor(category))
                            .frame(width: 34, height: 34)
                            .background(CheckLineColor.muted, in: Circle())

                        Text(category.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(CheckLineColor.text)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(currencyText(category.spent))
                                .font(.body.weight(.semibold).monospacedDigit())
                            Text(
                                category.spent / max(1, budget.spent),
                                format: .percent.precision(.fractionLength(0))
                            )
                            .font(.caption)
                            .foregroundStyle(CheckLineColor.secondary)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)

                    if index < categories.count - 1 {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .background(CheckLineColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.035), radius: 20, x: 0, y: 10)
        }
    }

    private func comparisonChart(_ budget: PrototypeBudget) -> some View {
        Chart {
            ForEach(Array(chartValues(budget).enumerated()), id: \.offset) { index, value in
                BarMark(
                    x: .value("month", String(format: String(localized: "month.short"), index + 3)),
                    y: .value("actual", Double(value))
                )
                .foregroundStyle(CheckLineColor.brand)
            }
        }
        .chartYScale(domain: 0 ... 1)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 180)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("insights.comparison.accessibility"))
    }

    private func chartValues(_ budget: PrototypeBudget) -> [CGFloat] {
        [0.58, 0.72, 0.46, 0.64, CGFloat(budget.progress)]
    }

}

private enum PrototypeCalendarFilter: String, CaseIterable, Identifiable {
    case all
    case current

    var id: String { rawValue }
}

struct PrototypeCalendarView: View {
    let store: PrototypeStore
    let selectedBudgetID: UUID
    @State private var filter: PrototypeCalendarFilter = .all
    @State private var selectedDate = prototypeDate(year: 2026, month: 7, day: 6)

    private let monthStart = prototypeDate(year: 2026, month: 7, day: 1)
    private let monthEnd = prototypeDate(year: 2026, month: 7, day: 31)

    private var visibleExpenses: [PrototypeExpense] {
        switch filter {
        case .all: store.expenses
        case .current: store.expenses(for: selectedBudgetID)
        }
    }

    private var selectedExpenses: [PrototypeExpense] {
        visibleExpenses.filter { Calendar.current.isDate($0.occurredAt, inSameDayAs: selectedDate) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Picker("calendar.filter", selection: $filter) {
                    Text("calendar.all").tag(PrototypeCalendarFilter.all)
                    Text(store.budget(id: selectedBudgetID)?.name ?? String(localized: "calendar.current"))
                        .tag(PrototypeCalendarFilter.current)
                }
                .pickerStyle(.segmented)

                CheckLineSurface {
                DatePicker(
                    "calendar.month.title",
                    selection: $selectedDate,
                    in: monthStart ... monthEnd,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        String(
                            format: String(localized: "calendar.records.day"),
                            Calendar.current.component(.day, from: selectedDate)
                        )
                    )
                    .font(.headline.weight(.semibold))

                    VStack(spacing: 0) {
                        if selectedExpenses.isEmpty {
                            Text("calendar.empty")
                                .font(.subheadline)
                                .foregroundStyle(CheckLineColor.secondary)
                                .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                                .padding(.horizontal, 18)
                        } else {
                            ForEach(Array(selectedExpenses.enumerated()), id: \.element.id) { index, expense in
                                PrototypeExpenseRow(expense: expense, store: store)
                                    .padding(.horizontal, 18)
                                if index < selectedExpenses.count - 1 {
                                    Divider()
                                        .padding(.leading, 62)
                                }
                            }
                        }
                    }
                    .background(CheckLineColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.035), radius: 20, x: 0, y: 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(CheckLineColor.canvas.ignoresSafeArea())
        .navigationTitle(Text("insights.calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: filter) { _, _ in PrototypeHaptics.selection() }
    }
}
