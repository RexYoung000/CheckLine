import SwiftUI
import Charts
import PhotosUI

nonisolated enum BudgetDetailSection: String, Identifiable, Hashable {
    case overview, records, calendar, pending, history, information
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: String(localized: "wallet.used.title")
        case .records: String(localized: "wallet.records.all")
        case .calendar: String(localized: "wallet.calendar.title")
        case .pending: String(localized: "v1.card.pending")
        case .history: String(localized: "ui.workspace.history")
        case .information: String(localized: "ui.workspace.manage")
        }
    }
}

struct BudgetDetailSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    var budgetID: UUID
    var initialSection: BudgetDetailSection
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            HomeBudgetDetailView(workspace: workspace, budgetID: budgetID, initialSection: initialSection)
                .toolbar { ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "action.close"), iconSymbol: "xmark") { dismiss() }.labelStyle(.iconOnly)
                } }
            .environment(\.budgetWorkspacePush, { path.append($0) })
            .navigationDestination(for: BudgetWorkspaceRoute.self) { BudgetWorkspaceDestination(workspace: workspace, route: $0) }
        }.presentationDetents([.large]).presentationBackground(PaperTheme.canvas)
    }
}

struct HomeBudgetDetailView: View {
    @Bindable var workspace: CheckLineWorkspace
    var budgetID: UUID
    var initialSection: BudgetDetailSection = .overview
    @Environment(\.budgetWorkspacePush) private var push
    @State private var entered = false
    var body: some View {
        BudgetDetailContent(workspace: workspace, budgetID: budgetID, section: .overview)
            .onAppear {
                if !entered {
                    entered = true
                    if initialSection != .overview { push?(.budget(budgetID, nil, initialSection)) }
                }
            }
    }
}

struct BudgetDetailContent: View {
    @Bindable var workspace: CheckLineWorkspace
    var budgetID: UUID
    var section: BudgetDetailSection
    var periodID: UUID? = nil
    @Environment(\.dismiss) private var dismissDetail
    @Environment(\.shellChrome) private var chrome
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var settlementSelection: SettlementSelection?
    @State private var editingCard: HomeBudgetCardModel?
    @State private var pendingOnly = false
    @State private var managementHelpExpanded = false
    @State private var coverageExpanded = false
    private var card: HomeBudgetCardModel? { HomeProjector.card(budgetID: budgetID, periodID: periodID, in: workspace.ledger) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaperTheme.Space.l) {
                if let card {
                    if section == .overview { overview(card) }
                    else if section == .history { history }
                    else if section == .information { information(card) }
                    else if section == .calendar { BudgetCalendarView(card: card, ledger: workspace.ledger) }
                    else { records(card) }
                } else { ContentUnavailableView { Label { Text(String(localized: "budget.missing")) } icon: { CheckLineIcon(symbol: "wallet.pass", size: 48) } } }
            }.padding(22).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(PaperTheme.canvas.ignoresSafeArea()).foregroundStyle(PaperTheme.ink)
        .navigationTitle(section == .overview ? card?.name ?? String(localized: "ui.workspace.title") : section.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar, .bottomBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { chrome?.isShowingDetail = true; if section == .pending { pendingOnly = true } }
        .fullScreenCover(item: $editingCard) { BudgetAmountEditorView(workspace: workspace, card: $0) }
        .fullScreenCover(item: $settlementSelection) { selection in
            SettlementReviewView(workspace: workspace, periodID: selection.id) {
                settlementSelection = nil; dismissDetail(); chrome?.selectedTab = .wishes
            }
        }
    }

    private func overview(_ card: HomeBudgetCardModel) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                if card.periodState == .settled || dueForSettlement(card) {
                    CheckLineIconLabel(String(localized: card.periodState == .settled ? "ui.period.settled" : "ui.period.due"), symbol: card.periodState == .settled ? "checkmark.seal" : "calendar", size: 16)
                        .font(.caption).foregroundStyle(PaperTheme.muted)
                }
                periodDates(card)
            }
            LiquidBudgetCard(card: card, showsRemainingRatio: false)
            let metricsLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
            metricsLayout {
                amountMetric("v1.card.used", BudgetPresentation.used(card), card)
                amountMetric("wallet.budget.limit", card.snapshot.budgetAmount, card)
            }.padding(18).walletSurface()

            if card.periodState == .settled,
               let settlement = workspace.ledger.settlements.values.first(where: { $0.periodID == card.periodID }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "ui.history.snapshot")).font(.headline)
                    amountRow("ui.history.spent", settlement.confirmedSpent, card)
                    amountRow("ui.history.result", settlement.baseSurplus, card)
                    let adjustments = workspace.ledger.adjustments.values.filter { $0.settlementID == settlement.id }.sorted { $0.confirmedAt < $1.confirmedAt }
                    ForEach(adjustments) { adjustment in
                        HStack {
                            Text(adjustment.confirmedAt, format: .dateTime.year().month().day())
                            Spacer()
                            Text(MoneyFormat.string(adjustment.amountDelta, currencyCode: card.currencyCode)).monospacedDigit()
                        }.font(.subheadline)
                    }
                    Text(String(localized: "ui.history.snapshotNote")).font(.caption).foregroundStyle(PaperTheme.muted)
                }.padding(20).walletSurface()
            }

            if BudgetPresentation.pendingCount(card, in: workspace.ledger) > 0 {
                NavigationLink(value: BudgetWorkspaceRoute.budget(budgetID, card.periodID, .pending)) {
                    let pendingLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
                    pendingLayout {
                        CheckLineIconLabel(String(format: String(localized: "wallet.pending.count"), BudgetPresentation.pendingCount(card, in: workspace.ledger)), symbol: "clock")
                        if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                        Text(MoneyFormat.string(card.snapshot.pendingAmount, currencyCode: card.currencyCode)).monospacedDigit()
                        if !typeSize.isAccessibilitySize { CheckLineIcon(symbol: "chevron.right", size: 16) }
                    }.font(.subheadline).foregroundStyle(PaperTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(18).walletSurface()
                }.buttonStyle(.plain).accessibilityIdentifier("wallet.workspace.pending")
            }
            let missing = BudgetPresentation.expenses(card, in: workspace.ledger).filter { CurrencyEngine.budgetSettlementAmount(expense: $0, periodCurrencyCode: card.currencyCode) == nil }.count
            if missing > 0 { CheckLineIconLabel(String(format: String(localized: "ui.coverage.unconverted"), missing), symbol: "exclamationmark.circle").font(.subheadline) }
            if card.snapshot.certainOverrunAmount > 0 || card.snapshot.possibleOverrunAmount > 0 {
                CheckLineIconLabel(String(localized: card.snapshot.certainOverrunAmount > 0 ? "v1.card.status.certain" : "v1.card.status.possible"), symbol: "exclamationmark.circle").font(.subheadline)
            }
            if card.periodState != .settled {
                let actionLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
                actionLayout {
                    if dueForSettlement(card) {
                        settlementAction(card, primary: true)
                        recordAction(card, primary: false)
                    } else {
                        recordAction(card, primary: true)
                        settlementAction(card, primary: false)
                    }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                NavigationLink(value: BudgetWorkspaceRoute.budget(budgetID, card.periodID, .records)) { destinationBlock("wallet.records.all", "receipt") }
                    .accessibilityIdentifier("wallet.workspace.records")
                NavigationLink(value: BudgetWorkspaceRoute.budget(budgetID, card.periodID, .calendar)) { destinationBlock("wallet.calendar.title", "calendar") }
                NavigationLink(value: BudgetWorkspaceRoute.budget(budgetID, card.periodID, .history)) { destinationBlock("ui.workspace.history", "clock.arrow.circlepath") }
                NavigationLink(value: BudgetWorkspaceRoute.budget(budgetID, card.periodID, .information)) { destinationBlock("ui.workspace.manage", "slider.horizontal.3") }
            }.buttonStyle(.plain)
            DisclosureGroup(String(localized: "ui.coverage.title"), isExpanded: $coverageExpanded) {
                Text(String(localized: "wallet.coverage.note")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(.top, 8)
            }.font(.subheadline).tint(PaperTheme.accent)
        }
    }

    private func destinationBlock(_ key: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CheckLineIcon(symbol: symbol, size: 24).foregroundStyle(PaperTheme.accent)
                Spacer(minLength: 8)
                CheckLineIcon(symbol: "arrow.up.right", size: 16).foregroundStyle(PaperTheme.muted)
            }
            Text(String(localized: String.LocalizationValue(key))).font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }.padding(18).frame(maxWidth: .infinity, minHeight: 104, alignment: .leading).walletSurface()
    }

    private func amountMetric(_ key: LocalizedStringKey, _ amount: Decimal, _ card: HomeBudgetCardModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(key).font(.caption).foregroundStyle(PaperTheme.muted)
            Text(MoneyFormat.string(amount, currencyCode: card.currencyCode)).font(.title3.weight(.medium)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    @ViewBuilder private func recordAction(_ card: HomeBudgetCardModel, primary: Bool) -> some View {
        let button = Button { workspace.openComposer(.record, budgetID: card.id) } label: {
            CheckLineIconLabel(String(localized: "capture.title"), symbol: "plus").frame(maxWidth: .infinity)
        }
        if primary { button.buttonStyle(PaperSolidButtonStyle()) }
        else { button.buttonStyle(PaperQuietButtonStyle()) }
    }

    @ViewBuilder private func settlementAction(_ card: HomeBudgetCardModel, primary: Bool) -> some View {
        let button = Button { settlementSelection = SettlementSelection(id: card.periodID) } label: {
            CheckLineIconLabel(String(localized: settlementReady(card) ? "wallet.settlement.review" : "wallet.settlement.preview"), symbol: "checkmark.seal").frame(maxWidth: .infinity)
        }.accessibilityIdentifier("wallet.budget.settlement")
        if primary { button.buttonStyle(PaperSolidButtonStyle()) }
        else { button.buttonStyle(PaperQuietButtonStyle()) }
    }

    private func periodDates(_ card: HomeBudgetCardModel) -> some View {
        Group {
            if let end = card.periodEnd {
                Text(card.periodStart.formatted(.dateTime.year().month().day()) + " – " + end.formatted(.dateTime.year().month().day()))
            } else {
                Text(card.periodStart.formatted(.dateTime.year().month().day()) + " · " + String(localized: "wallet.noDeadline"))
            }
        }.font(.caption).foregroundStyle(PaperTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var history: some View {
        Group {
            VStack(spacing: 12) {
                let periods = workspace.ledger.periods(forBudget: budgetID).filter { $0.state == .settled }.reversed()
                if periods.isEmpty { ContentUnavailableView { Label { Text(String(localized: "ui.history.empty")) } icon: { CheckLineIcon(symbol: "clock.arrow.circlepath", size: 48) } } }
                ForEach(Array(periods), id: \.id) { period in
                    NavigationLink(value: BudgetWorkspaceRoute.budget(budgetID, period.id, .overview)) {
                        HStack { Text(period.startDate, format: .dateTime.year().month()); Spacer(); CheckLineIconLabel(String(localized: "ui.period.settled"), symbol: "checkmark.seal"); CheckLineIcon(symbol: "chevron.right") }.padding(18).walletSurface()
                    }.buttonStyle(.plain)
                }
            }.frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(PaperTheme.canvas).navigationTitle(String(localized: "ui.workspace.history")).navigationBarTitleDisplayMode(.inline)
    }

    private func information(_ card: HomeBudgetCardModel) -> some View {
        Group {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 18) {
                    BudgetDetailMetadataRow(title: String(localized: "budget.name"), value: card.name)
                    BudgetDetailMetadataRow(title: String(localized: "v1.budget.currency"), value: card.currencyCode)
                    BudgetDetailMetadataRow(title: String(localized: "v1.budget.cycle"), value: String(localized: card.cycleType == .repeating ? "wallet.cycle.monthly" : "v1.cycle.oneShot"))
                }.padding(20).walletSurface()
                if BudgetAmountEditEngine.isEditable(budgetID: budgetID, periodID: card.periodID, ledger: workspace.ledger) {
                    Button(String(localized: "wallet.budget.edit.title")) { editingCard = card }.buttonStyle(PaperSolidButtonStyle())
                }
                DisclosureGroup(String(localized: "ui.workspace.manageHelp"), isExpanded: $managementHelpExpanded) {
                    Text(String(localized: "ui.manage.boundary")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(.top, 8)
                }.font(.subheadline).tint(PaperTheme.accent)
            }.frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(PaperTheme.canvas).navigationTitle(String(localized: "ui.workspace.manage")).navigationBarTitleDisplayMode(.inline)
    }

    private func settlementReady(_ card: HomeBudgetCardModel) -> Bool {
        card.cycleType == .oneShot || dueForSettlement(card)
    }
    private func dueForSettlement(_ card: HomeBudgetCardModel) -> Bool {
        card.periodState == .pendingSettlement || workspace.ledger.periods[card.periodID].map { CycleEngine.isDue($0, now: Date(), calendar: .current) } == true
    }
    private func amountRow(_ key: LocalizedStringKey, _ amount: Decimal, _ card: HomeBudgetCardModel) -> some View {
        HStack { Text(key); Spacer(); Text(MoneyFormat.string(amount, currencyCode: card.currencyCode)).monospacedDigit() }.font(.subheadline)
    }
    private func records(_ card: HomeBudgetCardModel) -> some View {
        let all = BudgetPresentation.expenses(card, in: workspace.ledger)
        let rows = all.filter { !pendingOnly || $0.attributionState == .pending }
        let days = Array(Set(rows.map { Calendar.current.startOfDay(for: $0.occurredAt) })).sorted(by: >)
        return VStack(alignment: .leading, spacing: 16) {
            periodDates(card)
            Picker(String(localized: "ui.records.filter"), selection: $pendingOnly) {
                Text(String(localized: "wallet.records.all")).tag(false)
                Text(String(localized: "v1.card.pending") + " · \(all.filter { $0.attributionState == .pending }.count)").tag(true)
            }.pickerStyle(.segmented)
            if rows.isEmpty { ContentUnavailableView { Label { Text(String(localized: "v1.card.records.empty")) } icon: { CheckLineIcon(symbol: "receipt", size: 48) } } }
            ForEach(days, id: \.self) { day in
                let dayRows = rows.filter { Calendar.current.isDate($0.occurredAt, inSameDayAs: day) }
                Text(day, format: .dateTime.year().month().day()).font(.subheadline.weight(.semibold)).foregroundStyle(PaperTheme.muted)
                VStack(spacing: 0) {
                    ForEach(Array(dayRows.enumerated()), id: \.element.id) { index, row in
                        NavigationLink(value: BudgetWorkspaceRoute.expense(row.id)) { WalletExpenseRow(expense: row, showsDate: false).contentShape(Rectangle()) }
                            .buttonStyle(.plain)
                        if index < dayRows.count - 1 { Divider().overlay(PaperTheme.stroke) }
                    }
                }
            }
        }
    }
}

struct BudgetInlineDetails: View {
    @Bindable var workspace: CheckLineWorkspace
    var card: HomeBudgetCardModel
    @State private var expenseID: UUID?
    private var rows: [Expense] { BudgetPresentation.expenses(card, in: workspace.ledger) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.name).font(.headline)
                Spacer()
                Text(MoneyFormat.string(BudgetPresentation.remaining(card), currencyCode: card.currencyCode))
                    .font(.title2.weight(.medium)).monospacedDigit()
            }
            HStack {
                Text(String(localized: "wallet.budget.limit"))
                Spacer()
                Text(MoneyFormat.string(card.snapshot.budgetAmount, currencyCode: card.currencyCode)).monospacedDigit()
            }.font(.subheadline).foregroundStyle(PaperTheme.muted)
            HStack {
                Text(String(localized: "v1.card.used"))
                Spacer()
                Text(MoneyFormat.string(BudgetPresentation.used(card), currencyCode: card.currencyCode)).monospacedDigit()
            }.font(.subheadline).foregroundStyle(PaperTheme.muted)
            HStack {
                Text(card.cycleType == .repeating ? String(localized: "v1.cycle.repeating") : String(localized: "v1.cycle.oneShot"))
                Spacer()
                if let end = card.periodEnd {
                    Text(card.periodStart, format: .dateTime.month().day())
                    Text("–")
                    Text(end, format: .dateTime.month().day())
                } else { Text(String(localized: "wallet.noDeadline")) }
            }.font(.caption).foregroundStyle(PaperTheme.muted)
            if card.snapshot.pendingAmount > 0 {
                HStack {
                    Text(String(localized: "v1.card.pending"))
                    Spacer()
                    Text(MoneyFormat.string(card.snapshot.pendingAmount, currencyCode: card.currencyCode)).monospacedDigit()
                }.font(.subheadline).foregroundStyle(PaperTheme.accent)
            }
            BudgetDailyChart(card: card, ledger: workspace.ledger, height: 100)
            Text(String(localized: "wallet.records.all")).font(.headline)
            if rows.isEmpty { Text(String(localized: "v1.card.records.empty")).foregroundStyle(PaperTheme.muted) }
            ForEach(rows) { row in
                Button { expenseID = row.id } label: { WalletExpenseRow(expense: row) }.buttonStyle(.plain)
                Divider().overlay(PaperTheme.stroke)
            }
        }
        .padding(20)
        .walletSurface()
        .sheet(item: Binding(get: { expenseID.map { ExpenseSelection(id: $0) } }, set: { expenseID = $0?.id })) { item in
            WalletExpenseDetail(workspace: workspace, expenseID: item.id)
        }
    }
}

private struct BudgetDetailMetadataRow: View {
    let title: String
    let value: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 16))
        layout {
            Text(title).font(.subheadline).foregroundStyle(PaperTheme.muted)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(value).font(.subheadline).foregroundStyle(PaperTheme.ink)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}

private struct ExpenseSelection: Identifiable { let id: UUID }
private struct SettlementSelection: Identifiable { let id: UUID }

struct BudgetDailyChart: View {
    var card: HomeBudgetCardModel
    var ledger: Ledger
    var height: CGFloat = 160
    var body: some View {
        let days = BudgetPresentation.days(endingAt: BudgetPresentation.referenceDate(card, in: ledger), count: 14)
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
    var showsEmptyDayMessage: Bool
    @State private var month: Date
    @State private var selectedDay: Date
    @State private var coverageExpanded = false
    private var calendar: Calendar { .current }

    init(card: HomeBudgetCardModel, ledger: Ledger, showsEmptyDayMessage: Bool = true) {
        self.card = card
        self.ledger = ledger
        self.showsEmptyDayMessage = showsEmptyDayMessage
        let today = Calendar.current.startOfDay(for: Date())
        let initialDay = card.periodStart <= today && (card.periodEnd.map { today <= $0 } ?? true)
            ? today : Calendar.current.startOfDay(for: card.periodStart)
        _month = State(initialValue: initialDay)
        _selectedDay = State(initialValue: initialDay)
    }
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
                Button { changeMonth(-1) } label: { CheckLineIcon(symbol: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel(String(localized: "wallet.month.previous"))
                Button { changeMonth(1) } label: { CheckLineIcon(symbol: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel(String(localized: "wallet.month.next"))
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
                    let inPeriod = containsInSelectedPeriod(day)
                    let opacity = !inPeriod ? 0.025 : values[index] == 0 ? 0.06 : 0.16 + 0.45 * NSDecimalNumber(decimal: max(0, values[index]) / maximum).doubleValue
                    Button { selectedDay = day } label: {
                        Text(calendar.component(.day, from: day), format: .number)
                            .font(.subheadline.monospacedDigit()).frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selected ? PaperTheme.paperInk : PaperTheme.ink)
                            .background(selected ? PaperTheme.accent : PaperTheme.accent.opacity(opacity), in: RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain)
                        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(inPeriod ? MoneyFormat.string(values[index], currencyCode: card.currencyCode) : String(localized: "ui.calendar.outsidePeriod"))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            }
            let rows = BudgetPresentation.expenses(card, in: ledger).filter { calendar.isDate($0.occurredAt, inSameDayAs: selectedDay) }
            HStack {
                Text(selectedDay, format: .dateTime.month().day())
                Spacer()
                if containsInSelectedPeriod(selectedDay) && !rows.isEmpty {
                    Text(MoneyFormat.string(BudgetPresentation.dailyAmount(selectedDay, card: card, ledger: ledger), currencyCode: card.currencyCode)).monospacedDigit()
                }
            }.font(.subheadline).padding(.top, 6)
            if !containsInSelectedPeriod(selectedDay) {
                CheckLineIconLabel(String(localized: "ui.calendar.outsidePeriod"), symbol: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(PaperTheme.muted).padding(.vertical, 16)
            } else {
                if rows.isEmpty && showsEmptyDayMessage { Text(String(localized: "wallet.day.empty")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(.vertical, 16) }
                ForEach(rows) { row in
                    NavigationLink(value: BudgetWorkspaceRoute.expense(row.id)) { WalletExpenseRow(expense: row) }
                        .buttonStyle(.plain)
                }
            }
            DisclosureGroup(String(localized: "ui.coverage.title"), isExpanded: $coverageExpanded) {
                Text(String(localized: "wallet.coverage.note")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(.top, 8)
            }.font(.subheadline).tint(PaperTheme.accent)
        }
        .onChange(of: selectedDay) { _, day in
            if !calendar.isDate(day, equalTo: month, toGranularity: .month) { month = day }
        }
    }
    private func changeMonth(_ value: Int) {
        month = calendar.date(byAdding: .month, value: value, to: start) ?? month
        selectedDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }
    private func containsInSelectedPeriod(_ day: Date) -> Bool {
        let date = calendar.startOfDay(for: day)
        guard date >= calendar.startOfDay(for: card.periodStart) else { return false }
        return card.periodEnd.map { date <= calendar.startOfDay(for: $0) } ?? true
    }
}

struct WalletExpenseDetail: View {
    @Bindable var workspace: CheckLineWorkspace
    var expenseID: UUID
    var standalone = true
    @State private var extrasExpanded = false
    @State private var correctionHelpExpanded = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var attachments: [ExpenseAttachment] = []
    @State private var attachmentToDelete: UUID?
    @State private var errorText: String?
    @State private var retrospectivePreview: RetrospectivePreview?
    private var expense: Expense? { workspace.ledger.expenses[expenseID] }

    var body: some View {
        Group {
            if standalone { NavigationStack { detailContent } }
            else { detailContent }
        }
        .presentationDetents([.large]).presentationBackground(PaperTheme.canvas).presentationCornerRadius(PaperTheme.Radius.sheet)
        .onAppear { reloadAttachments() }
        .onChange(of: pickerItems) { _, items in Task { await importImages(items) } }
        .alert(String(localized: "wallet.expense.actionFailed"), isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button(String(localized: "action.close"), role: .cancel) { errorText = nil }
        } message: { Text(errorText ?? "") }
        .confirmationDialog(String(localized: "wallet.expense.deleteAttachment"), isPresented: Binding(get: { attachmentToDelete != nil }, set: { if !$0 { attachmentToDelete = nil } })) {
            Button(String(localized: "wallet.expense.deleteAttachment"), role: .destructive) {
                if let id = attachmentToDelete {
                    do { try workspace.attachmentStore.remove(id, from: expenseID); reloadAttachments() }
                    catch { errorText = String(localized: "wallet.expense.retrySave") }
                }
                attachmentToDelete = nil
            }
        }
        .fullScreenCover(isPresented: Binding(get: { retrospectivePreview != nil }, set: { if !$0 { retrospectivePreview = nil } })) {
            if let preview = retrospectivePreview { PendingExpenseImpactView(workspace: workspace, preview: preview) { retrospectivePreview = nil } }
        }
    }

    private var detailContent: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let expense {
                        WalletSymbol(name: BudgetPresentation.symbol(for: expense))
                        let amountLayout = typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
                        amountLayout {
                            Text(MoneyFormat.string(expense.kind == .refund ? expense.originalAmount : -expense.originalAmount, currencyCode: expense.originalCurrencyCode)).font(.largeTitle.weight(.medium)).monospacedDigit()
                                .fixedSize(horizontal: false, vertical: true)
                            Text(expense.originalCurrencyCode).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        }.accessibilityElement(children: .combine)
                        Text(expense.merchant ?? String(localized: "v1.card.record.untitled")).font(.title3)
                        Text(expense.occurredAt, format: .dateTime.year().month().day().hour().minute()).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        let sources = Array(Set(workspace.ledger.evidences(forExpense: expense.id).map { $0.sourceType.rawValue })).sorted()
                        VStack(alignment: .leading, spacing: 18) {
                            CheckLineIconLabel(String(localized: expense.attributionState == .pending ? "v1.card.pending" : expense.attributionState == .unbudgeted ? "v1.unbudgeted" : "ui.record.confirmed"), symbol: expense.attributionState == .pending ? "clock" : "checkmark.circle")
                                .font(.subheadline).foregroundStyle(PaperTheme.accent)
                            BudgetDetailMetadataRow(title: String(localized: "v1.agent.attribution"), value: attributionTitle(expense))
                            BudgetDetailMetadataRow(title: String(localized: "ui.record.source"), value: sources.isEmpty ? String(localized: "ui.source.unknown") : sources.map { String(localized: String.LocalizationValue("ui.source." + $0)) }.joined(separator: " · "))
                        }.padding(20).walletSurface()
                        if expense.attributionState == .pending { pendingActions(expense) }
                        DisclosureGroup(String(localized: "ui.record.extras"), isExpanded: $extrasExpanded) {
                            if let note = expense.note, !note.isEmpty { Text(note).font(.body).textSelection(.enabled) }
                            attachmentSection
                        }
                        if expense.attributionState != .pending {
                            DisclosureGroup(String(localized: "ui.record.correctionHelp"), isExpanded: $correctionHelpExpanded) {
                                Text(String(localized: "ui.record.correctionBoundary")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(.top, 8)
                            }.font(.subheadline).tint(PaperTheme.accent)
                        }

                    }
                }.frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity).padding(24)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "wallet.expense.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { if standalone { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), iconSymbol: "xmark") { dismiss() }.labelStyle(.iconOnly) } } }
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func pendingActions(_ expense: Expense) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: String(localized: "ui.record.confirmAttributionPrompt"), attributionTitle(expense)))
                .font(.subheadline).foregroundStyle(PaperTheme.muted)
            Button(String(localized: "wallet.expense.confirmAttribution")) {
                do {
                    if let id = expense.budgetPeriodID, workspace.ledger.periods[id]?.state == .settled {
                        retrospectivePreview = try workspace.previewPendingRetrospective(expenseID)
                    } else { try workspace.confirmPendingExpense(expenseID) }
                } catch LedgerError.missingExchangeRate { errorText = String(localized: "wallet.expense.exchangeRateNeeded") }
                catch { errorText = String(localized: "wallet.expense.actionFailed") }
            }.buttonStyle(PaperSolidButtonStyle())
            Menu(String(localized: "wallet.expense.changeAttribution")) {
                ForEach(workspace.attributionChoices) { choice in
                    if choice.periodID != expense.budgetPeriodID {
                        Button(choice.periodID == nil ? String(localized: "v1.unbudgeted") : choice.title) {
                            changeAttribution(to: choice.periodID, expense: expense)
                        }
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attributionTitle(_ expense: Expense) -> String {
        expense.budgetPeriodID.flatMap { workspace.ledger.periods[$0] }.flatMap { workspace.ledger.budgets[$0.budgetID]?.name } ?? String(localized: "v1.unbudgeted")
    }

    private func changeAttribution(to periodID: UUID?, expense: Expense) {
        if let oldID = expense.budgetPeriodID, workspace.ledger.periods[oldID]?.state == .settled {
            errorText = String(localized: "ui.record.historicalMoveBoundary")
        } else {
            do { try workspace.changePendingExpense(expenseID, to: periodID) }
            catch { errorText = String(localized: "wallet.expense.actionFailed") }
        }
    }

    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "wallet.expense.attachments")).font(.headline)
            ForEach(attachments) { attachment in
                HStack {
                    if let image = UIImage(contentsOfFile: attachment.url.path) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 240)
                    }
                    Button(role: .destructive) { attachmentToDelete = attachment.id } label: {
                        CheckLineIcon(symbol: "trash").frame(width: 44, height: 44)
                    }.accessibilityLabel(String(localized: "wallet.expense.deleteAttachment"))
                }
            }
            if attachments.count < ExpenseAttachmentStore.maximumPerExpense {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: ExpenseAttachmentStore.maximumPerExpense - attachments.count, matching: .images) {
                    CheckLineIconLabel(String(localized: "wallet.expense.addAttachment"), symbol: "photo.badge.plus")
                }
                Button {
                    if let data = UIPasteboard.general.image?.pngData() { saveAttachment(data) }
                    else { errorText = String(localized: "wallet.expense.noClipboardImage") }
                } label: { CheckLineIconLabel(String(localized: "wallet.expense.pasteImage"), symbol: "doc.on.clipboard") }
            }
        }
    }

    private func reloadAttachments() { attachments = workspace.attachmentStore.attachments(for: expenseID) }

    private func saveAttachment(_ data: Data) {
        do { try workspace.attachmentStore.add(imageData: data, to: expenseID); reloadAttachments() }
        catch { errorText = String(localized: "wallet.expense.retrySave") }
    }

    private func importImages(_ items: [PhotosPickerItem]) async {
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw ExpenseAttachmentError.unreadableImage }
                saveAttachment(data)
            } catch { errorText = String(localized: "wallet.expense.retrySave") }
        }
        pickerItems = []
    }
}

struct UnbudgetedRecordsView: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var selectedExpense: Expense?
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(workspace.ledger.expenses.values.filter { $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil }.sorted { $0.occurredAt > $1.occurredAt }) { row in
                    Button { selectedExpense = row } label: { WalletExpenseRow(expense: row) }.buttonStyle(.plain)
                }
            }.padding(22)
        }.background(PaperTheme.canvas.ignoresSafeArea()).navigationTitle(String(localized: "v1.unbudgeted"))
            .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar, .bottomBar)
            .sheet(item: $selectedExpense) { item in WalletExpenseDetail(workspace: workspace, expenseID: item.id) }
    }
}
