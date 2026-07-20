import SwiftUI
import Charts

struct PrototypeInsightsView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID

    private var budget: PrototypeBudget {
        store.budget(id: selectedBudgetID) ?? store.activeBudgets[0]
    }

    let onCapture: () -> Void

    var body: some View {
        List {
            Section {
                budgetPicker
                remainingCard
            }

            Section("insights.comparison") {
                comparisonChart
            }

            Section("insights.categories") {
                ForEach(budget.categories.sorted { $0.spent > $1.spent }) { category in
                    HStack {
                        Label(category.name, systemImage: category.iconName)
                            .foregroundStyle(categoryColor(category))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(currencyText(category.spent))
                                .monospacedDigit()
                            Text(category.spent / max(1, budget.spent), format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(Text("tab.insights"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("capture.title", systemImage: "plus", action: onCapture)
            }
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
        Picker("insights.budgetPicker", selection: $selectedBudgetID) {
            ForEach(store.activeBudgets) { option in
                Label(option.name, systemImage: "wallet.pass")
                    .tag(option.id)
            }
        }
        .pickerStyle(.menu)
        .tint(CheckLineColor.brand)
    }

    private var remainingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "insights.remaining"), budget.name))
                .font(.caption.bold())
                .foregroundStyle(CheckLineColor.secondary)
            MoneyText(amount: budget.remaining, color: CheckLineColor.success)
            Text("\(dateRangeText(budget)) · \(String(localized: "budget.used")) \(currencyText(budget.spent))")
                .font(.caption)
                .foregroundStyle(CheckLineColor.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var comparisonChart: some View {
        Chart {
            ForEach(Array(chartValues.enumerated()), id: \.offset) { index, value in
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

    private var chartValues: [CGFloat] {
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
        List {
            Section("calendar.filter") {
                Picker("calendar.filter", selection: $filter) {
                    Text("calendar.all").tag(PrototypeCalendarFilter.all)
                    Text(store.budget(id: selectedBudgetID)?.name ?? String(localized: "calendar.current"))
                        .tag(PrototypeCalendarFilter.current)
                }
                .pickerStyle(.segmented)
            }

            Section {
                DatePicker(
                    "calendar.month.title",
                    selection: $selectedDate,
                    in: monthStart ... monthEnd,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }

            Section(LocalizedStringKey(String(format: String(localized: "calendar.records.day"), Calendar.current.component(.day, from: selectedDate)))) {
                if selectedExpenses.isEmpty {
                    ContentUnavailableView("calendar.empty", systemImage: "calendar.badge.exclamationmark")
                } else {
                    ForEach(selectedExpenses) { expense in
                        PrototypeExpenseRow(expense: expense, store: store)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(Text("insights.calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: filter) { _, _ in PrototypeHaptics.selection() }
    }
}
