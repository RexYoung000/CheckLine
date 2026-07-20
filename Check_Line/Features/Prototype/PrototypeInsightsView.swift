import SwiftUI

struct PrototypeInsightsView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID

    private var budget: PrototypeBudget {
        store.budget(id: selectedBudgetID) ?? store.activeBudgets[0]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                budgetPicker
                remainingCard
                comparisonChart
                PrototypeSectionHeader("insights.categories")
                categoryList
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .background(CheckLineColor.canvas)
        .navigationTitle(Text("tab.insights"))
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
        VStack(alignment: .leading, spacing: 10) {
            PrototypeSectionHeader("insights.budgetPicker")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.activeBudgets) { option in
                        PrototypeChip(
                            title: option.name,
                            symbol: "wallet.pass",
                            isSelected: option.id == selectedBudgetID
                        ) {
                            selectedBudgetID = option.id
                            PrototypeHaptics.selection()
                        }
                    }
                }
            }
        }
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
        .padding(16)
        .prototypeCard()
    }

    private var comparisonChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("insights.comparison")
                    .font(.title3.bold())
                Spacer()
                Label("insights.actual.legend", systemImage: "circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CheckLineColor.secondary)
                    .symbolRenderingMode(.monochrome)
            }

            HStack(alignment: .bottom, spacing: 15) {
                ForEach(Array(chartValues.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom, spacing: 5) {
                            Capsule()
                                .fill(CheckLineColor.brandSoft)
                                .frame(width: 10, height: 72 + CGFloat(index * 7))
                            Capsule()
                                .fill(CheckLineColor.brand)
                                .frame(width: 10, height: max(24, 110 * value))
                        }
                        Text(String(format: String(localized: "month.short"), index + 3))
                            .font(.caption2.bold())
                            .foregroundStyle(CheckLineColor.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140, alignment: .bottom)
        }
        .padding(16)
        .prototypeCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("insights.comparison.accessibility"))
    }

    private var chartValues: [CGFloat] {
        [0.58, 0.72, 0.46, 0.64, CGFloat(budget.progress)]
    }

    private var categoryList: some View {
        VStack(spacing: 0) {
            ForEach(Array(budget.categories.sorted { $0.spent > $1.spent }.enumerated()), id: \.element.id) { index, category in
                HStack(spacing: 12) {
                    Image(systemName: category.iconName)
                        .foregroundStyle(categoryColor(category))
                        .frame(width: 42, height: 42)
                        .background(categoryColor(category).opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name).font(.subheadline.bold())
                        Text(currencyText(category.spent))
                            .font(.caption)
                            .foregroundStyle(CheckLineColor.secondary)
                    }
                    Spacer()
                    Text(category.spent / max(1, budget.spent), format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 66)
                if index < budget.categories.count - 1 {
                    Divider().padding(.leading, 58)
                }
            }
        }
        .prototypeCard()
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
    @State private var selectedDay = 6

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var visibleExpenses: [PrototypeExpense] {
        switch filter {
        case .all: store.expenses
        case .current: store.expenses(for: selectedBudgetID)
        }
    }

    private var selectedExpenses: [PrototypeExpense] {
        visibleExpenses.filter {
            Calendar.current.component(.day, from: $0.occurredAt) == selectedDay
                && Calendar.current.component(.month, from: $0.occurredAt) == 7
        }
    }

    private var daysWithExpenses: Set<Int> {
        Set(visibleExpenses.compactMap {
            Calendar.current.component(.month, from: $0.occurredAt) == 7
                ? Calendar.current.component(.day, from: $0.occurredAt)
                : nil
        })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                Picker("calendar.filter", selection: $filter) {
                    Text("calendar.all").tag(PrototypeCalendarFilter.all)
                    Text(store.budget(id: selectedBudgetID)?.name ?? String(localized: "calendar.current"))
                        .tag(PrototypeCalendarFilter.current)
                }
                .pickerStyle(.segmented)

                calendarCard

                PrototypeSectionHeader(LocalizedStringKey(String(format: String(localized: "calendar.records.day"), selectedDay)))
                if selectedExpenses.isEmpty {
                    Text("calendar.empty")
                        .font(.subheadline)
                        .foregroundStyle(CheckLineColor.secondary)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .prototypeCard()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(selectedExpenses.enumerated()), id: \.element.id) { index, expense in
                            PrototypeExpenseRow(expense: expense, store: store)
                            if index < selectedExpenses.count - 1 {
                                Divider().padding(.leading, 58)
                            }
                        }
                    }
                    .prototypeCard()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(CheckLineColor.canvas)
        .navigationTitle(Text("insights.calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: filter) { _, _ in PrototypeHaptics.selection() }
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("calendar.month.title")
                .font(.title3.bold())

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(weekdayKeys, id: \.self) { key in
                    Text(LocalizedStringKey(key))
                        .font(.caption2.bold())
                        .foregroundStyle(CheckLineColor.quiet)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                ForEach(0 ..< 2, id: \.self) { _ in Color.clear.frame(height: 44) }
                ForEach(1 ... 31, id: \.self) { day in
                    Button {
                        selectedDay = day
                        PrototypeHaptics.selection()
                    } label: {
                        ZStack(alignment: .bottom) {
                            Text("\(day)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(day == selectedDay ? Color.white : CheckLineColor.secondary)
                            if daysWithExpenses.contains(day), day != selectedDay {
                                Circle()
                                    .fill(CheckLineColor.brand)
                                    .frame(width: 5, height: 5)
                                    .padding(.bottom, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(day == selectedDay ? CheckLineColor.brand : CheckLineColor.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(CheckLineColor.divider.opacity(day == selectedDay ? 0 : 0.7), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String(format: String(localized: "calendar.day.accessibility"), day)))
                    .accessibilityAddTraits(day == selectedDay ? .isSelected : [])
                }
            }
        }
        .padding(16)
        .prototypeCard()
    }

    private var weekdayKeys: [String] {
        ["weekday.sun", "weekday.mon", "weekday.tue", "weekday.wed", "weekday.thu", "weekday.fri", "weekday.sat"]
    }
}
