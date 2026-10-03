import SwiftUI

struct CheckLineHomeView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editingCard: HomeBudgetCardModel?
    @State private var detail: BudgetDetailSection?
    @State private var presentedBudgetID: UUID?
    @State private var summaryPopup: BudgetDetailSection?
    @State private var selectedExpense: Expense?
    @State private var previewApplied = false
    @Namespace private var summaryNamespace
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.3, dampingFraction: 0.8))) private var dragOffset: CGSize = .zero
    @State private var receiptOffset = 0
    @State private var deckHeight: CGFloat = 222
    @State private var deckWidth: CGFloat = 350
    @State private var flightOffset: CGSize = .zero
    @State private var isCardFlying = false
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.38, dampingFraction: 0.76))) private var touchPoint: CGPoint?
    @Namespace private var budgetTransition

    private var card: HomeBudgetCardModel? { workspace.selectedCard }
    private var closure: CGFloat { reduceMotion ? 0 : chrome?.pocketClosure ?? 0 }

    var body: some View {
        WalletRootPage(tab: .home, title: String(localized: "tab.home"), workspace: workspace, lightHeader: true, fullPaperBackground: card == nil,
                       detailPresented: Binding(get: { detail != nil }, set: { if !$0 { detail = nil } }),
                       detail: {
            AnyView(HomeBudgetDetailView(workspace: workspace, budgetID: presentedBudgetID ?? card?.id ?? UUID(), initialSection: detail ?? .overview))
        }) {
            if let card {
                VStack(spacing: 0) {
                    deck(card)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .background { GeometryReader { proxy in
                            Color.clear
                                .preference(key: WalletDeckHeightKey.self, value: proxy.size.height)
                                .preference(key: WalletDeckWidthKey.self, value: proxy.size.width)
                        } }
                        .onPreferenceChange(WalletDeckHeightKey.self) { deckHeight = $0 }
                        .onPreferenceChange(WalletDeckWidthKey.self) { deckWidth = $0 }
                        .scaleEffect(1 - closure * 0.035, anchor: .bottom)
                        .rotation3DEffect(.degrees(-6 * Double(closure)), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.35)
                        .offset(y: -24 * closure)
                    VStack(spacing: 18) {
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 12) { usedTile(card); dateTile(card) }
                    } else {
                        HStack(alignment: .top, spacing: 0) {
                            usedTile(card)
                            Rectangle().fill(PaperTheme.stroke).frame(width: 1).padding(.vertical, 7)
                            dateTile(card)
                        }
                    }
                    if BudgetPresentation.pendingCount(card, in: workspace.ledger) > 0 {
                        Button { openDetail(.pending, card: card) } label: {
                            HStack {
                                Label(String(format: String(localized: "wallet.pending.count"), BudgetPresentation.pendingCount(card, in: workspace.ledger)), systemImage: "clock")
                                Spacer()
                                Text(MoneyFormat.string(card.snapshot.pendingAmount, currencyCode: card.currencyCode)).monospacedDigit()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            .font(.subheadline).foregroundStyle(PaperTheme.gold)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }
                    if workspace.ledger.expenses.values.contains(where: { $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil }) {
                        NavigationLink { UnbudgetedRecordsView(workspace: workspace) } label: {
                            Label(String(localized: "v1.unbudgeted"), systemImage: "tray")
                                .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }
                    receipts(card)
                    }
                    .opacity(max(0, 1 - Double(closure) * 2.2))
                    .rotation3DEffect(.degrees(7 * Double(closure)), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.3)
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, minHeight: 440, alignment: .top)
                    .background {
                        GeometryReader { proxy in
                            WalletCardholderSurface(opening: 1 - closure)
                                .frame(height: proxy.size.height + (deckHeight - 24) * closure)
                        }
                    }
                    .padding(.top, -24)
                    .offset(y: -(deckHeight - 24) * closure)
                }
                .frame(maxWidth: 560)
            } else {
                VStack(spacing: 0) {
                    WalletEmptyBudgetCard { workspace.showAgent = true }
                        .padding(.horizontal, 18)
                        .padding(.top, 24)
                    VStack(spacing: 0) {
                        Button(String(localized: "wallet.empty.manual")) { workspace.openComposer(.budget) }
                            .buttonStyle(PaperQuietButtonStyle())
                            .accessibilityIdentifier("wallet.empty.createBudget")
                    }
                    .padding(.horizontal, 28).padding(.top, 36).padding(.bottom, 100)
                    .frame(maxWidth: .infinity, minHeight: 430, alignment: .top)
                    .background { WalletCardholderSurface() }
                    .padding(.top, -24)
                }
                .frame(maxWidth: 560)
            }
        }
        .fullScreenCover(item: $editingCard) { card in
            BudgetAmountEditorView(workspace: workspace, card: card)
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
            guard DesignPreviewData.isEnabled && !previewApplied else { return }
            previewApplied = true
            if DesignPreviewData.screen == "home-inline", let card { openDetail(.overview, card: card) }
            if DesignPreviewData.screen == "home-used" { summaryPopup = .overview }
            if DesignPreviewData.screen == "home-calendar" { summaryPopup = .calendar }
        }
    }

    private func openDetail(_ section: BudgetDetailSection, card: HomeBudgetCardModel) {
        presentedBudgetID = card.id
        detail = section
    }

    private func deck(_ card: HomeBudgetCardModel) -> some View {
        ZStack(alignment: .topTrailing) {
            if let nextCard = adjacentCard(1) {
                LiquidBudgetCard(card: nextCard)
                    .padding(.horizontal, 11)
                    .rotationEffect(.degrees(-2), anchor: .top)
                    .offset(y: -9)
                    .opacity(min(0.85, 0.45 + hypot(dragOffset.width, dragOffset.height) / 300))
                    .accessibilityHidden(true)
            }
            ZStack(alignment: .topTrailing) {
            Button { openDetail(.overview, card: card) } label: {
                LiquidBudgetCard(card: card, flows: !workspace.showAgent && !workspace.showComposer && detail == nil && chrome?.isSettingsPresented != true && chrome?.isAttentionPresented != true, reflectionPoint: touchPoint,
                    remainingChange: workspace.remainingAmountChange,
                    remainingMotionContext: RemainingMotionContext(
                        isHomeCurrent: chrome?.selectedTab == .home,
                        isExposed: !workspace.showComposer && !workspace.showAgent && editingCard == nil && detail == nil && summaryPopup == nil && selectedExpense == nil && chrome?.isSettingsPresented != true && chrome?.isAttentionPresented != true))
                    .modifier(WalletTransitionSource(id: card.id, namespace: budgetTransition))
            }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wallet.home.card")
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.16, maximumDistance: 12).sequenced(before: DragGesture(minimumDistance: 0))
                    .updating($dragOffset) { value, offset, _ in
                        guard !reduceMotion, canChangeCard(1), !isCardFlying else { return }
                        if case .second(true, let drag?) = value { offset = drag.translation }
                    }
                    .updating($touchPoint) { value, point, _ in
                        if case .second(true, let drag?) = value { point = drag.location }
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
                if BudgetAmountEditEngine.isEditable(budgetID: card.id, periodID: card.periodID, ledger: workspace.ledger) {
                    Button(String(localized: "wallet.budget.edit.title"), systemImage: "pencil") { editingCard = card }
                }
                Button(String(localized: "wallet.card.details"), systemImage: "arrow.up.right") { openDetail(.overview, card: card) }
                Button(String(localized: "wallet.budget.manage"), systemImage: "wallet.pass") { chrome?.selectedTab = .budgets }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(PaperTheme.ink).frame(width: 44, height: 44).padding(8)
            }
            .accessibilityLabel(String(localized: "wallet.card.more"))
            .accessibilityIdentifier("wallet.home.card.more")
            }
        .overlay(alignment: .bottomLeading) {
            Button { workspace.openComposer(.record) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(PaperTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(PaperTheme.card.opacity(0.15), in: Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1) }
            }
            .buttonStyle(PaperCirclePressStyle())
            .accessibilityLabel(String(localized: "capture.title"))
            .padding(.leading, 18).padding(.bottom, 22)
        }
        .rotation3DEffect(.degrees(reduceMotion ? 0 : Double((0.5 - (touchPoint?.y ?? deckHeight * 0.5) / max(deckHeight, 1)) * 8)), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
        .rotation3DEffect(.degrees(reduceMotion ? 0 : Double((((touchPoint?.x ?? deckWidth * 0.5) / max(deckWidth, 1)) - 0.5) * 8)), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
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
                    Text(card.periodState == .pendingSettlement ? String(localized: "wallet.periodLast7days") : String(localized: "wallet.last7days"))
                        .font(.caption2).foregroundStyle(PaperTheme.muted)
                }
            }.padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
                .matchedGeometryEffect(id: BudgetDetailSection.overview.rawValue, in: summaryNamespace, isSource: summaryPopup != .overview)
        }.buttonStyle(.plain)
    }

    private func dateTile(_ card: HomeBudgetCardModel) -> some View {
        Button { withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)) { summaryPopup = .calendar } } label: {
            VStack(alignment: .leading, spacing: 16) {
                tileLabel(card.periodStart.formatted(.dateTime.month(.wide)), icon: "arrow.up.right")
                HStack(alignment: .bottom, spacing: 12) {
                    MiniBudgetCalendar(card: card, ledger: workspace.ledger)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if card.periodState == .pendingSettlement {
                            Text(String(localized: "budget.settling.section"))
                                .font(.subheadline.weight(.medium))
                        } else if let end = card.periodEnd {
                            Text(max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: end).day ?? 0), format: .number)
                                .font(.title.weight(.medium)).monospacedDigit()
                            Text(String(localized: "wallet.daysLeft")).font(.caption2)
                        } else {
                            Image(systemName: "infinity").font(.title2)
                            Text(String(localized: "wallet.noDeadline")).font(.caption2)
                        }
                    }.foregroundStyle(PaperTheme.muted)
                }
            }.padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
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
                Button { openDetail(.records, card: card) } label: { Image(systemName: "arrow.up.right").frame(width: 44, height: 44) }
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
        guard let next = adjacentCard(direction) else { return }
        workspace.selectedBudgetID = next.id
        PaperHaptics.selection()
    }

    private func canChangeCard(_ direction: Int) -> Bool {
        adjacentCard(direction) != nil
    }

    private func adjacentCard(_ direction: Int) -> HomeBudgetCardModel? {
        guard workspace.cards.count > 1, let card,
              let index = workspace.cards.firstIndex(where: { $0.id == card.id }) else { return nil }
        let count = workspace.cards.count
        return workspace.cards[(index + direction % count + count) % count]
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

private struct WalletDeckWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 350 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct BudgetMiniBars: View {
    var card: HomeBudgetCardModel
    var ledger: Ledger
    var body: some View {
        let values = BudgetPresentation.days(endingAt: BudgetPresentation.referenceDate(card, in: ledger))
            .map { BudgetPresentation.dailyAmount($0, card: card, ledger: ledger) }
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
        let reference = BudgetPresentation.referenceDate(card, in: ledger)
        let start = calendar.dateInterval(of: .month, for: reference)?.start ?? reference
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<29
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(6), spacing: 4), count: 7), spacing: 4) {
            ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(width: 6, height: 6) }
            ForEach(Array(range), id: \.self) { day in
                let date = calendar.date(byAdding: .day, value: day - 1, to: start) ?? start
                let hasRecords = BudgetPresentation.expenses(card, in: ledger).contains { calendar.isDate($0.occurredAt, inSameDayAs: date) }
                RoundedRectangle(cornerRadius: 1.5).fill(hasRecords ? PaperTheme.accent : .white.opacity(0.12)).frame(width: 6, height: 6)
                    .overlay { if calendar.isDate(date, inSameDayAs: reference) { RoundedRectangle(cornerRadius: 1.5).stroke(PaperTheme.accent, lineWidth: 1) } }
            }
        }.frame(width: 66).accessibilityHidden(true)
    }
}
