import SwiftUI
import Charts
import PhotosUI

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
                    if section != .overview {
                        Text(card.name).font(.subheadline).foregroundStyle(PaperTheme.muted)
                    }
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
        .toolbar(.hidden, for: .tabBar, .bottomBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $expense) { item in WalletExpenseDetail(workspace: workspace, expenseID: item.id) }
    }

    private func overview(_ card: HomeBudgetCardModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            LiquidBudgetCard(card: card, flows: true)
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

private struct ExpenseSelection: Identifiable { let id: UUID }

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
    @State private var month: Date
    @State private var selectedDay: Date
    private var calendar: Calendar { .current }

    init(card: HomeBudgetCardModel, ledger: Ledger) {
        self.card = card
        self.ledger = ledger
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
            let rows = BudgetPresentation.expenses(card, in: ledger).filter { calendar.isDate($0.occurredAt, inSameDayAs: selectedDay) }
            HStack {
                Text(selectedDay, format: .dateTime.month().day())
                Spacer()
                if !rows.isEmpty {
                    Text(MoneyFormat.string(BudgetPresentation.dailyAmount(selectedDay, card: card, ledger: ledger), currencyCode: card.currencyCode)).monospacedDigit()
                }
            }.font(.subheadline).padding(.top, 6)
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
    @Bindable var workspace: CheckLineWorkspace
    var expenseID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var attachments: [ExpenseAttachment] = []
    @State private var attachmentToDelete: UUID?
    @State private var errorText: String?
    @State private var retrospectivePreview: RetrospectivePreview?
    @State private var pendingTarget: UUID?
    @State private var showSettledMoveImpact = false
    private var expense: Expense? { workspace.ledger.expenses[expenseID] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let expense {
                        WalletSymbol(name: BudgetPresentation.symbol(for: expense))
                        Text(MoneyFormat.string(expense.kind == .refund ? expense.originalAmount : -expense.originalAmount, currencyCode: expense.originalCurrencyCode)).font(.largeTitle.weight(.medium)).monospacedDigit()
                        Text(expense.merchant ?? String(localized: "v1.card.record.untitled")).font(.title3)
                        Text(expense.occurredAt, format: .dateTime.year().month().day().hour().minute()).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        if let note = expense.note, !note.isEmpty {
                            Text(String(localized: "wallet.expense.noteAndPastedText")).font(.headline)
                            Text(note).font(.body).textSelection(.enabled)
                        }
                        if expense.attributionState == .pending { pendingActions(expense) }
                        attachmentSection
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "wallet.expense.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large]).presentationBackground(PaperTheme.canvas).presentationCornerRadius(30)
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
        .alert(String(localized: "wallet.expense.retrospectiveImpact"), isPresented: Binding(get: { retrospectivePreview != nil }, set: { if !$0 { retrospectivePreview = nil } })) {
            Button(String(localized: "wallet.expense.confirmAttribution")) {
                if let preview = retrospectivePreview {
                    do { try workspace.confirmPendingRetrospective(preview) }
                    catch { errorText = String(localized: "wallet.expense.actionFailed") }
                }
                retrospectivePreview = nil
            }
            Button(String(localized: "action.cancel"), role: .cancel) { retrospectivePreview = nil }
        } message: {
            if let preview = retrospectivePreview {
                Text(String(format: String(localized: "wallet.expense.retrospectiveMessage"), MoneyFormat.string(preview.amountDelta, currencyCode: preview.sourceCurrencyCode), MoneyFormat.string(preview.balanceAfter, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode)))
            }
        }
        .alert(String(localized: "wallet.expense.retrospectiveImpact"), isPresented: $showSettledMoveImpact) {
            Button(String(localized: "wallet.expense.changeAttribution")) {
                do { try workspace.changePendingExpense(expenseID, to: pendingTarget, confirmedSettledImpact: true) }
                catch { errorText = String(localized: "wallet.expense.actionFailed") }
            }
            Button(String(localized: "action.cancel"), role: .cancel) { pendingTarget = nil }
        } message: { Text(String(localized: "wallet.expense.moveSettledMessage")) }
    }

    private func pendingActions(_ expense: Expense) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "v1.card.pending"), systemImage: "clock")
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

    private func changeAttribution(to periodID: UUID?, expense: Expense) {
        if let oldID = expense.budgetPeriodID, workspace.ledger.periods[oldID]?.state == .settled {
            pendingTarget = periodID
            showSettledMoveImpact = true
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
                        Image(systemName: "trash").frame(width: 44, height: 44)
                    }.accessibilityLabel(String(localized: "wallet.expense.deleteAttachment"))
                }
            }
            if attachments.count < ExpenseAttachmentStore.maximumPerExpense {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: ExpenseAttachmentStore.maximumPerExpense - attachments.count, matching: .images) {
                    Label(String(localized: "wallet.expense.addAttachment"), systemImage: "photo.badge.plus")
                }
                Button {
                    if let data = UIPasteboard.general.image?.pngData() { saveAttachment(data) }
                    else { errorText = String(localized: "wallet.expense.noClipboardImage") }
                } label: { Label(String(localized: "wallet.expense.pasteImage"), systemImage: "doc.on.clipboard") }
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
