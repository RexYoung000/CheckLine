import SwiftUI

struct CheckLineHomeView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var detail: BudgetDetailSection?
    @State private var inlineDetails = false
    @State private var summaryPopup: BudgetDetailSection?
    @State private var selectedExpense: Expense?
    @Namespace private var summaryNamespace
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.3, dampingFraction: 0.8))) private var dragOffset: CGSize = .zero
    @State private var receiptOffset = 0
    @State private var deckHeight: CGFloat = 222
    @State private var flightOffset: CGSize = .zero
    @State private var isCardFlying = false

    private var card: HomeBudgetCardModel? { workspace.selectedCard }
    private var closure: CGFloat { reduceMotion ? 0 : chrome?.pocketClosure ?? 0 }

    var body: some View {
        WalletRootPage(tab: .home, title: String(localized: "tab.home"), workspace: workspace, lightHeader: true, fullPaperBackground: card == nil) {
            if let card {
                VStack(spacing: 0) {
                    deck(card)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .background { GeometryReader { proxy in Color.clear.preference(key: WalletDeckHeightKey.self, value: proxy.size.height) } }
                        .onPreferenceChange(WalletDeckHeightKey.self) { deckHeight = $0 }
                        .scaleEffect(1 - closure * 0.035, anchor: .bottom)
                        .rotation3DEffect(.degrees(-6 * Double(closure)), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.35)
                        .offset(y: -24 * closure)
                    VStack(spacing: 18) {
                    if inlineDetails {
                        BudgetInlineDetails(workspace: workspace, card: card)
                    } else {
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 12) { usedTile(card); dateTile(card) }
                    } else {
                        HStack(alignment: .top, spacing: 12) { usedTile(card); dateTile(card) }
                    }
                    receipts(card)
                    if BudgetPresentation.pendingCount(card, in: workspace.ledger) > 0 {
                        Button { detail = .pending } label: {
                            HStack {
                                Label(String(format: String(localized: "wallet.pending.count"), BudgetPresentation.pendingCount(card, in: workspace.ledger)), systemImage: "clock")
                                Spacer()
                                Text(MoneyFormat.string(card.snapshot.pendingAmount, currencyCode: card.currencyCode)).monospacedDigit()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            .font(.subheadline).padding(16).walletSurface(radius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                    if workspace.ledger.expenses.values.contains(where: { $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil }) {
                        NavigationLink { UnbudgetedRecordsView(workspace: workspace) } label: {
                            Label(String(localized: "v1.unbudgeted"), systemImage: "tray").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(16).walletSurface(radius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                    }
                    }
                    .opacity(max(0, 1 - Double(closure) * 2.2))
                    .rotation3DEffect(.degrees(7 * Double(closure)), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.3)
                    .padding(.horizontal, 16)
                    .padding(.top, 38)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, minHeight: 470, alignment: .top)
                    .background {
                        GeometryReader { proxy in
                            WalletCardholderSurface(opening: 1 - closure)
                                .frame(height: proxy.size.height + (deckHeight - 24) * closure)
                        }
                    }
                    .padding(.top, -24)
                    .offset(y: -(deckHeight - 24) * closure)
                }
                .background(PaperTheme.paper)
                .frame(maxWidth: 560)
            } else {
                VStack(spacing: 24) {
                    WalletSymbol(name: "wallet.pass", size: 80)
                    VStack(spacing: 10) {
                        Text(String(localized: "v1.home.empty.title"))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(PaperTheme.paperInk)
                            .accessibilityAddTraits(.isHeader)
                        Text(String(localized: "wallet.empty.budget"))
                            .font(.body)
                            .foregroundStyle(PaperTheme.paperInk.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .multilineTextAlignment(.center)
                    Button(String(localized: "v1.budget.create")) { workspace.openComposer(.budget) }
                        .buttonStyle(PaperSolidButtonStyle(foreground: PaperTheme.paper, background: PaperTheme.paperInk))
                        .accessibilityIdentifier("wallet.empty.createBudget")
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 48)
                .frame(maxWidth: 560)
            }
        }
        .sheet(item: $detail) { section in
            if let card { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: section) }
        }
        .sheet(item: $selectedExpense) { item in WalletExpenseDetail(workspace: workspace, expenseID: item.id) }
        .overlay {
            if let summaryPopup, let card {
                HomeSummaryOverlay(workspace: workspace, card: card, section: summaryPopup, namespace: summaryNamespace) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)) { self.summaryPopup = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .onChange(of: card?.id) { _, _ in receiptOffset = 0 }
        .onAppear {
            guard DesignPreviewData.isEnabled else { return }
            if DesignPreviewData.screen == "home-inline" { inlineDetails = true }
            if DesignPreviewData.screen == "home-used" { summaryPopup = .overview }
            if DesignPreviewData.screen == "home-calendar" { summaryPopup = .calendar }
        }
    }

    private func deck(_ card: HomeBudgetCardModel) -> some View {
        ZStack(alignment: .topTrailing) {
            if canChangeCard(1) {
                RoundedRectangle(cornerRadius: 27)
                    .fill(LinearGradient(colors: [Color(red: 0.78, green: 0.75, blue: 0.9), Color(red: 0.63, green: 0.60, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { RoundedRectangle(cornerRadius: 27).strokeBorder(.white.opacity(0.5), lineWidth: 0.7) }
                    .padding(.horizontal, 11).offset(y: -9)
                    .accessibilityHidden(true)
            }
            ZStack(alignment: .topTrailing) {
            Button { withAnimation(reduceMotion ? nil : .smooth(duration: 0.28)) { inlineDetails.toggle() } } label: { LiquidBudgetCard(card: card, flows: !workspace.showAgent && !workspace.showComposer && detail == nil && !inlineDetails && chrome?.isSettingsPresented != true && chrome?.isAttentionPresented != true) }
                .buttonStyle(.plain)
                .highPriorityGesture(LongPressGesture(minimumDuration: 0.16, maximumDistance: 12).sequenced(before: DragGesture(minimumDistance: 0))
                    .updating($dragOffset) { value, offset, _ in
                        guard !reduceMotion, canChangeCard(1), !isCardFlying else { return }
                        if case .second(true, let drag?) = value { offset = drag.translation }
                    }
                    .onEnded { value in
                        guard case .second(true, let drag?) = value, canChangeCard(1), !isCardFlying else { return }
                        let distance = hypot(drag.translation.width, drag.translation.height)
                        if distance >= min(deckHeight, 300) * 0.3 {
                            isCardFlying = true
                            withTransaction(Transaction(animation: nil)) {
                                flightOffset = CGSize(width: drag.translation.width * 0.7, height: drag.translation.height * 0.7)
                            }
                            withAnimation(.easeOut(duration: 0.15)) {
                                flightOffset = CGSize(width: drag.translation.width / distance * 360, height: drag.translation.height / distance * 360)
                            }
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(150))
                                withTransaction(Transaction(animation: nil)) {
                                    changeCard(1)
                                    flightOffset = .zero
                                    isCardFlying = false
                                }
                            }
                        }
                    })
                .accessibilityActions {
                    if canChangeCard(1) { Button(String(localized: "wallet.card.next")) { changeCard(1) } }
                    if canChangeCard(-1) { Button(String(localized: "wallet.card.previous")) { changeCard(-1) } }
                }
            Menu {
                ForEach(workspace.cards) { item in
                    Button { workspace.selectedBudgetID = item.id } label: {
                        if item.id == card.id { Label(item.name, systemImage: "checkmark") } else { Text(item.name) }
                    }
                }
                Divider()
                Button(String(localized: "wallet.card.details"), systemImage: "arrow.up.right") { inlineDetails = true }
                Button(String(localized: "wallet.budget.manage"), systemImage: "wallet.pass") { chrome?.selectedTab = .budgets }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.white).frame(width: 44, height: 44).padding(8)
            }
            .accessibilityLabel(String(localized: "wallet.card.more"))
            }
        .overlay(alignment: .bottomLeading) {
            Button { workspace.openComposer(.record) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .paperGlass(.circle, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "capture.title"))
            .padding(.leading, 18).padding(.bottom, 22)
        }
        .offset(x: dragOffset.width * 0.7 + flightOffset.width, y: dragOffset.height * 0.7 + flightOffset.height)
        .id(card.id)
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .offset(y: 18).combined(with: .opacity), removal: .offset(y: -80).combined(with: .opacity)))
        }
        .padding(.top, 8)
    }

    private func usedTile(_ card: HomeBudgetCardModel) -> some View {
        Button { withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)) { summaryPopup = .overview } } label: {
            VStack(alignment: .leading, spacing: 12) {
                tileLabel(String(localized: "v1.card.used"), icon: "arrow.up.right")
                Text(MoneyFormat.string(-BudgetPresentation.used(card), currencyCode: card.currencyCode))
                    .font(.title2.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                HStack(alignment: .bottom) {
                    BudgetMiniBars(card: card, ledger: workspace.ledger)
                    Text(String(localized: "wallet.last7days")).font(.caption2).foregroundStyle(PaperTheme.muted)
                }
            }.padding(16).frame(maxWidth: .infinity, minHeight: 137, alignment: .topLeading).walletSurface()
                .matchedGeometryEffect(id: BudgetDetailSection.overview.rawValue, in: summaryNamespace, isSource: summaryPopup != .overview)
        }.buttonStyle(.plain)
    }

    private func dateTile(_ card: HomeBudgetCardModel) -> some View {
        Button { withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)) { summaryPopup = .calendar } } label: {
            VStack(alignment: .leading, spacing: 16) {
                tileLabel(Date().formatted(.dateTime.month(.wide)), icon: "arrow.up.right")
                HStack(alignment: .bottom, spacing: 12) {
                    MiniBudgetCalendar(card: card, ledger: workspace.ledger)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if let end = card.periodEnd {
                            Text(max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: end).day ?? 0), format: .number)
                                .font(.title.weight(.medium)).monospacedDigit()
                            Text(String(localized: "wallet.daysLeft")).font(.caption2)
                        } else {
                            Image(systemName: "infinity").font(.title2)
                            Text(String(localized: "wallet.noDeadline")).font(.caption2)
                        }
                    }.foregroundStyle(PaperTheme.muted)
                }
            }.padding(16).frame(maxWidth: .infinity, minHeight: 137, alignment: .topLeading).walletSurface()
                .matchedGeometryEffect(id: BudgetDetailSection.calendar.rawValue, in: summaryNamespace, isSource: summaryPopup != .calendar)
        }.buttonStyle(.plain)
    }

    private func tileLabel(_ title: String, icon: String) -> some View {
        HStack { Text(title); Spacer(); Image(systemName: icon) }.font(.caption).foregroundStyle(PaperTheme.muted)
    }

    private func receipts(_ card: HomeBudgetCardModel) -> some View {
        let rows = BudgetPresentation.expenses(card, in: workspace.ledger).filter { $0.attributionState == .confirmed }
        return VStack(spacing: 12) {
            HStack {
                Text(String(localized: "expense.recent.title")).font(.headline)
                Spacer()
                Button { detail = .records } label: { Image(systemName: "arrow.up.right").frame(width: 44, height: 44) }
                    .accessibilityLabel(String(localized: "wallet.records.all"))
            }
            if rows.isEmpty {
                Text(String(localized: "v1.card.records.empty")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(.vertical, 20)
            } else {
                WalletReceiptStack(rows: rows, position: $receiptOffset) { selectedExpense = $0 }
                    .id(card.id)
            }
        }
    }

    private func changeCard(_ direction: Int) {
        guard let card, let index = workspace.cards.firstIndex(where: { $0.id == card.id }), workspace.cards.indices.contains(index + direction) else { return }
        workspace.selectedBudgetID = workspace.cards[index + direction].id
        PaperHaptics.selection()
    }

    private func canChangeCard(_ direction: Int) -> Bool {
        guard let card, let index = workspace.cards.firstIndex(where: { $0.id == card.id }) else { return false }
        return workspace.cards.indices.contains(index + direction)
    }
}

private struct HomeSummaryOverlay: View {
    @Bindable var workspace: CheckLineWorkspace
    var card: HomeBudgetCardModel
    var section: BudgetDetailSection
    var namespace: Namespace.ID
    var close: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.54).ignoresSafeArea().onTapGesture(perform: close)
                VStack(spacing: 0) {
                    HStack {
                        Text(section.title).font(.headline)
                        Spacer()
                        Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                            .accessibilityLabel(String(localized: "action.close"))
                    }.padding(.horizontal, 22).padding(.top, 14)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                        if section == .overview {
                            Text(MoneyFormat.string(-BudgetPresentation.used(card), currencyCode: card.currencyCode))
                                .font(.largeTitle.weight(.medium)).monospacedDigit()
                            BudgetDailyChart(card: card, ledger: workspace.ledger)
                            HStack {
                                Text(String(localized: "v1.card.pending"))
                                Spacer()
                                Text(MoneyFormat.string(card.snapshot.pendingAmount, currencyCode: card.currencyCode))
                            }.font(.subheadline)
                        } else {
                            BudgetCalendarView(card: card, ledger: workspace.ledger)
                        }
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 560)
                .frame(height: min(geometry.size.height - 64, 620))
                .walletSurface()
                .matchedGeometryEffect(id: section.rawValue, in: namespace, isSource: true)
                .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(PaperTheme.ink)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
    }
}

private struct WalletDeckHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 222 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct BudgetMiniBars: View {
    var card: HomeBudgetCardModel
    var ledger: Ledger
    var body: some View {
        let values = BudgetPresentation.days().map { BudgetPresentation.dailyAmount($0, card: card, ledger: ledger) }
        let maximum = max(values.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(values.indices, id: \.self) { index in
                Capsule().fill(PaperTheme.accent.opacity(index == 6 ? 1 : 0.55))
                    .frame(width: 7, height: max(2, 30 * NSDecimalNumber(decimal: max(0, values[index]) / maximum).doubleValue))
            }
        }.frame(height: 32).accessibilityHidden(true)
    }
}

struct MiniBudgetCalendar: View {
    var card: HomeBudgetCardModel
    var ledger: Ledger
    var body: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<29
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(6), spacing: 4), count: 7), spacing: 4) {
            ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(width: 6, height: 6) }
            ForEach(Array(range), id: \.self) { day in
                let date = calendar.date(byAdding: .day, value: day - 1, to: start) ?? start
                let hasRecords = BudgetPresentation.expenses(card, in: ledger).contains { calendar.isDate($0.occurredAt, inSameDayAs: date) }
                RoundedRectangle(cornerRadius: 1.5).fill(hasRecords ? PaperTheme.accent : .white.opacity(0.12)).frame(width: 6, height: 6)
                    .overlay { if calendar.isDateInToday(date) { RoundedRectangle(cornerRadius: 1.5).stroke(.white, lineWidth: 1) } }
            }
        }.frame(width: 66).accessibilityHidden(true)
    }
}
