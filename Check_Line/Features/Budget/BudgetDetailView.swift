import SwiftUI
import Charts

nonisolated enum BudgetDetailSection: String, Identifiable {
    case overview, records, calendar, pending
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: String(localized: "wallet.used.title")
        case .records: String(localized: "wallet.records.all")
        case .calendar: String(localized: "wallet.calendar.title")
        case .pending: String(localized: "v1.card.pending")
        }
    }
}

struct BudgetDetailSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    var budgetID: UUID
    var initialSection: BudgetDetailSection
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            BudgetDetailContent(workspace: workspace, budgetID: budgetID, section: initialSection)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                    }
                }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .presentationCornerRadius(30).presentationBackground(PaperTheme.canvas)
    }
}

struct HomeBudgetDetailView: View {
    @Bindable var workspace: CheckLineWorkspace
    var budgetID: UUID
    var body: some View {
        BudgetDetailContent(workspace: workspace, budgetID: budgetID, section: .overview)
            .toolbar(.visible, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar, .bottomBar)
    }
}

struct BudgetDetailContent: View {
    @Bindable var workspace: CheckLineWorkspace
    var budgetID: UUID
    var section: BudgetDetailSection
    @State private var expense: Expense?
    private var card: HomeBudgetCardModel? { workspace.cards.first { $0.id == budgetID } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let card {
                    Text(card.name).font(.subheadline).foregroundStyle(PaperTheme.muted)
                    switch section {
                    case .overview:
                        overview(card)
                    case .calendar:
                        BudgetCalendarView(card: card, ledger: workspace.ledger)
                    case .records, .pending:
                        records(card)
                    }
                } else {
                    ContentUnavailableView(String(localized: "budget.missing"), systemImage: "wallet.pass")
                }
            }
            .padding(22).frame(maxWidth: 760).frame(maxWidth: .infinity, alignment: .center)
        }
        .background(PaperTheme.canvas.ignoresSafeArea())
        .foregroundStyle(PaperTheme.ink)
        .navigationTitle(section.title).navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .bottomBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $expense) { item in WalletExpenseDetail(expense: item) }
    }

    private func overview(_ card: HomeBudgetCardModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(MoneyFormat.string(-BudgetPresentation.used(card), currencyCode: card.currencyCode))
                    .font(.largeTitle.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                HStack {
                    Text(String(localized: "wallet.budget.limit"))
                    Text(MoneyFormat.string(card.snapshot.budgetAmount, currencyCode: card.currencyCode)).monospacedDigit()
                }.font(.subheadline).foregroundStyle(PaperTheme.muted)
            }
            BudgetDailyChart(card: card, ledger: workspace.ledger)
            if BudgetPresentation.pendingCount(card, in: workspace.ledger) > 0 {
                PaperCard {
                    VStack(spacing: 12) {
                        amountRow("wallet.confirmed", card.snapshot.confirmedSpent, card)
                        amountRow("v1.card.pending", card.snapshot.pendingAmount, card)
                    }
                }
            }
            if card.snapshot.certainOverrunAmount > 0 || card.snapshot.possibleOverrunAmount > 0 {
                Label(card.snapshot.certainOverrunAmount > 0 ? String(localized: "v1.card.status.certain") : String(localized: "v1.card.status.possible"), systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(PaperTheme.accent)
            }
            VStack(spacing: 12) {
                NavigationLink { BudgetDetailContent(workspace: workspace, budgetID: budgetID, section: .records) } label: {
                    Label(String(localized: "wallet.records.all"), systemImage: "receipt").frame(maxWidth: .infinity)
                }.buttonStyle(PaperSolidButtonStyle())
                NavigationLink { BudgetDetailContent(workspace: workspace, budgetID: budgetID, section: .calendar) } label: {
                    Label(String(localized: "wallet.calendar.title"), systemImage: "calendar").frame(maxWidth: .infinity).frame(minHeight: 44)
                }.buttonStyle(.plain)
            }
            Text(String(localized: "wallet.coverage.note")).font(.caption).foregroundStyle(PaperTheme.muted)
        }
    }

    private func amountRow(_ key: LocalizedStringKey, _ amount: Decimal, _ card: HomeBudgetCardModel) -> some View {
        HStack { Text(key); Spacer(); Text(MoneyFormat.string(amount, currencyCode: card.currencyCode)).monospacedDigit() }.font(.subheadline)
    }

    private func records(_ card: HomeBudgetCardModel) -> some View {
        let rows = BudgetPresentation.expenses(card, in: workspace.ledger).filter { section != .pending || $0.attributionState == .pending }
        return LazyVStack(spacing: 0) {
            if rows.isEmpty { ContentUnavailableView(String(localized: "v1.card.records.empty"), systemImage: "receipt") }
            ForEach(rows) { row in
                Button { expense = row } label: { WalletExpenseRow(expense: row) }.buttonStyle(.plain)
                Divider().overlay(PaperTheme.stroke)
            }
        }
    }
}

struct BudgetDailyChart: View {
    var card: HomeBudgetCardModel
    var ledger: Ledger
    var height: CGFloat = 160
    var body: some View {
        let days = BudgetPresentation.days(count: 14)
        Chart(days, id: \.self) { day in
            let amount = BudgetPresentation.dailyAmount(day, card: card, ledger: ledger)
            BarMark(x: .value(String(localized: "wallet.date"), day, unit: .day), y: .value(String(localized: "v1.card.used"), NSDecimalNumber(decimal: amount).doubleValue))
                .cornerRadius(3).foregroundStyle(PaperTheme.accent.gradient)
                .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue(MoneyFormat.string(amount, currencyCode: card.currencyCode))
        }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 6)) { _ in AxisValueLabel(format: .dateTime.month().day()) } }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
        .frame(height: height)
    }
}

struct BudgetCalendarView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var card: HomeBudgetCardModel
    var ledger: Ledger
    @State private var month = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    private var calendar: Calendar { .current }
    private var start: Date { calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month }
    private var days: [Date] {
        (calendar.range(of: .day, in: .month, for: month) ?? 1..<29).compactMap { calendar.date(byAdding: .day, value: $0-1, to: start) }
    }
    private var leadingDays: Int { (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(month, format: .dateTime.year().month(.wide)).font(.headline)
                Spacer()
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel(String(localized: "wallet.month.previous"))
                Button { changeMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel(String(localized: "wallet.month.next"))
            }
            let values = days.map { BudgetPresentation.dailyAmount($0, card: card, ledger: ledger) }
            let maximum = max(values.max() ?? 0, 1)
            if typeSize.isAccessibilitySize {
                DatePicker(String(localized: "wallet.date"), selection: $selectedDay, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 5) {
                ForEach(0..<7, id: \.self) { offset in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + offset) % 7]).font(.caption).foregroundStyle(PaperTheme.muted)
                }
                ForEach(0..<leadingDays, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let selected = calendar.isDate(day, inSameDayAs: selectedDay)
                    let opacity = values[index] == 0 ? 0.06 : 0.16 + 0.45 * NSDecimalNumber(decimal: max(0, values[index]) / maximum).doubleValue
                    Button { selectedDay = day } label: {
                        Text(calendar.component(.day, from: day), format: .number)
                            .font(.subheadline.monospacedDigit()).frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selected ? PaperTheme.paperInk : PaperTheme.ink)
                            .background(selected ? PaperTheme.accent : PaperTheme.accent.opacity(opacity), in: RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain)
                        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(MoneyFormat.string(values[index], currencyCode: card.currencyCode))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            }
            HStack {
                Text(selectedDay, format: .dateTime.month().day())
                Spacer()
                Text(MoneyFormat.string(BudgetPresentation.dailyAmount(selectedDay, card: card, ledger: ledger), currencyCode: card.currencyCode)).monospacedDigit()
            }.font(.subheadline).padding(.top, 6)
            let rows = BudgetPresentation.expenses(card, in: ledger).filter { calendar.isDate($0.occurredAt, inSameDayAs: selectedDay) }
            if rows.isEmpty { Text(String(localized: "wallet.day.empty")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(.vertical, 16) }
            ForEach(rows) { WalletExpenseRow(expense: $0) }
            Text(String(localized: "wallet.coverage.note")).font(.caption).foregroundStyle(PaperTheme.muted)
        }
        .onChange(of: selectedDay) { _, day in
            if !calendar.isDate(day, equalTo: month, toGranularity: .month) { month = day }
        }
    }
    private func changeMonth(_ value: Int) {
        month = calendar.date(byAdding: .month, value: value, to: start) ?? month
        selectedDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }
}

struct WalletExpenseDetail: View {
    var expense: Expense
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    WalletSymbol(name: BudgetPresentation.symbol(for: expense))
                    Text(MoneyFormat.string(expense.kind == .refund ? expense.originalAmount : -expense.originalAmount, currencyCode: expense.originalCurrencyCode)).font(.largeTitle.weight(.medium)).monospacedDigit()
                    Text(expense.merchant ?? String(localized: "v1.card.record.untitled")).font(.title3)
                    Text(expense.occurredAt, format: .dateTime.year().month().day().hour().minute()).font(.subheadline).foregroundStyle(PaperTheme.muted)
                    if let note = expense.note, !note.isEmpty { Text(note).font(.body) }
                    if expense.attributionState == .pending { Label(String(localized: "v1.card.pending"), systemImage: "clock") }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "wallet.expense.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
            .toolbarBackground(.hidden, for: .navigationBar)
        }.presentationDetents([.medium, .large]).presentationBackground(PaperTheme.canvas).presentationCornerRadius(30)
    }
}

struct UnbudgetedRecordsView: View {
    @Bindable var workspace: CheckLineWorkspace
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(workspace.ledger.expenses.values.filter { $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil }.sorted { $0.occurredAt > $1.occurredAt }) { WalletExpenseRow(expense: $0) }
            }.padding(22)
        }.background(PaperTheme.canvas.ignoresSafeArea()).navigationTitle(String(localized: "v1.unbudgeted"))
            .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar, .bottomBar)
    }
}
