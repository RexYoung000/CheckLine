import SwiftUI

struct CheckLineHomeView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var detail: BudgetDetailSection?
    @State private var dragOffset: CGFloat = 0
    @State private var receiptOffset = 0

    private var card: HomeBudgetCardModel? { workspace.selectedCard }

    var body: some View {
        WalletRootPage(title: String(localized: "tab.home"), workspace: workspace, lightHeader: true) {
            if let card {
                VStack(spacing: 18) {
                    deck(card)
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
                }.frame(maxWidth: 560)
            } else {
                VStack(spacing: 24) {
                    WalletSymbol(name: "wallet.pass", size: 80)
                    PaperEmptyHint(title: String(localized: "v1.home.empty.title"), message: String(localized: "wallet.empty.budget"))
                    Button(String(localized: "v1.budget.create")) { workspace.openComposer(.budget) }.buttonStyle(PaperSolidButtonStyle())
                }.padding(.vertical, 36)
            }
        }
        .sheet(item: $detail) { section in
            if let card { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: section) }
        }
        .onChange(of: workspace.selectedBudgetID) { _, _ in receiptOffset = 0 }
    }

    private func deck(_ card: HomeBudgetCardModel) -> some View {
        ZStack(alignment: .topTrailing) {
            if workspace.cards.count > 1 {
                RoundedRectangle(cornerRadius: 28).fill(PaperTheme.accent.opacity(0.45))
                    .padding(.horizontal, 9).rotationEffect(.degrees(-2)).offset(y: -6)
                    .accessibilityHidden(true)
            }
            Button { detail = .overview } label: { LiquidBudgetCard(card: card, flows: !workspace.showAgent && !workspace.showComposer && detail == nil && chrome?.isSettingsPresented != true) }
                .buttonStyle(.plain)
                .offset(y: dragOffset)
                .simultaneousGesture(DragGesture(minimumDistance: 18).onChanged { value in
                    dragOffset = reduceMotion ? 0 : max(-70, min(70, value.translation.height * 0.55))
                }.onEnded { value in
                    let delta = value.translation.height
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                        if abs(delta) > 45 { changeCard(delta < 0 ? 1 : -1) }
                        dragOffset = 0
                    }
                })
                .accessibilityAction(named: Text("wallet.card.next")) { changeCard(1) }
                .accessibilityAction(named: Text("wallet.card.previous")) { changeCard(-1) }
            Menu {
                ForEach(workspace.cards) { item in
                    Button { workspace.selectedBudgetID = item.id } label: {
                        if item.id == card.id { Label(item.name, systemImage: "checkmark") } else { Text(item.name) }
                    }
                }
                Divider()
                Button(String(localized: "wallet.card.details"), systemImage: "arrow.up.right") { detail = .overview }
                Button(String(localized: "wallet.budget.manage"), systemImage: "wallet.pass") { chrome?.selectedTab = .budgets }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.white).frame(width: 44, height: 44).padding(8)
            }
            .accessibilityLabel(String(localized: "wallet.card.more"))
        }
        .padding(.top, 8)
    }

    private func usedTile(_ card: HomeBudgetCardModel) -> some View {
        Button { detail = .overview } label: {
            VStack(alignment: .leading, spacing: 12) {
                tileLabel(String(localized: "v1.card.used"), icon: "arrow.up.right")
                Text(MoneyFormat.string(-BudgetPresentation.used(card), currencyCode: card.currencyCode))
                    .font(.title2.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                HStack(alignment: .bottom) {
                    BudgetMiniBars(card: card, ledger: workspace.ledger)
                    Text(String(localized: "wallet.last7days")).font(.caption2).foregroundStyle(PaperTheme.muted)
                }
            }.padding(16).frame(maxWidth: .infinity, minHeight: 137, alignment: .topLeading).walletSurface()
        }.buttonStyle(.plain)
    }

    private func dateTile(_ card: HomeBudgetCardModel) -> some View {
        Button { detail = .calendar } label: {
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
        }.buttonStyle(.plain)
    }

    private func tileLabel(_ title: String, icon: String) -> some View {
        HStack { Text(title); Spacer(); Image(systemName: icon) }.font(.caption).foregroundStyle(PaperTheme.muted)
    }

    private func receipts(_ card: HomeBudgetCardModel) -> some View {
        let rows = BudgetPresentation.expenses(card, in: workspace.ledger).filter { $0.attributionState == .confirmed }
        let start = min(receiptOffset, max(0, rows.count - 1))
        let shown = Array(rows.dropFirst(start).prefix(3))
        return VStack(spacing: 12) {
            HStack {
                Text(String(localized: "expense.recent.title")).font(.headline)
                Spacer()
                Button { detail = .records } label: { Image(systemName: "arrow.up.right").frame(width: 44, height: 44) }
                    .accessibilityLabel(String(localized: "wallet.records.all"))
            }
            if shown.isEmpty {
                Text(String(localized: "v1.card.records.empty")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(.vertical, 20)
            } else {
                VStack(spacing: -7) {
                    ForEach(Array(shown.reversed().enumerated()), id: \.element.id) { index, expense in
                        Button { detail = .records } label: {
                            HStack(spacing: 12) {
                                Image(systemName: BudgetPresentation.symbol(for: expense))
                                Text(expense.merchant ?? String(localized: "v1.card.record.untitled")).lineLimit(1)
                                Spacer(minLength: 4)
                                Text(MoneyFormat.string(expense.kind == .refund ? expense.originalAmount : -expense.originalAmount, currencyCode: expense.originalCurrencyCode)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .font(.subheadline).padding(.horizontal, 16).frame(minHeight: 55)
                            .foregroundStyle(PaperTheme.paperInk)
                            .background(LinearGradient(colors: [PaperTheme.accent.opacity(0.85), Color(red: 0.91, green: 0.87, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, CGFloat(shown.count - index - 1) * 7)
                        }.buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 20).onEnded { value in
                    guard abs(value.translation.height) > 25 else { return }
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
                        receiptOffset = max(0, min(rows.count - 1, start + (value.translation.height > 0 ? 1 : -1)))
                    }
                })
                .accessibilityAction(named: Text("wallet.records.older")) { receiptOffset = min(rows.count - 1, start + 1) }
                .accessibilityAction(named: Text("wallet.records.newer")) { receiptOffset = max(0, start - 1) }
            }
        }
    }

    private func changeCard(_ direction: Int) {
        guard let card, let index = workspace.cards.firstIndex(where: { $0.id == card.id }), workspace.cards.indices.contains(index + direction) else { return }
        workspace.selectedBudgetID = workspace.cards[index + direction].id
        PaperHaptics.selection()
    }
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
