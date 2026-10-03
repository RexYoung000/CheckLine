import SwiftUI

struct BudgetListView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.walletReduceMotion) private var reduceMotion
    @State private var editingCard: HomeBudgetCardModel?
    @State private var selectedBudget: HomeBudgetCardModel?
    @State private var presentedBudgetID: UUID?
    @State private var previewApplied = false
    @Namespace private var budgetTransition

    private var archived: [Budget] { workspace.ledger.budgets.values.filter { $0.state == .archived }.sorted { $0.sortIndex < $1.sortIndex } }
    var body: some View {
        WalletRootPage(tab: .budgets, title: String(localized: "tab.budgets"), workspace: workspace, onAdd: { workspace.openComposer(.budget) },
                       detailPresented: Binding(get: { selectedBudget != nil }, set: { if !$0 { selectedBudget = nil } }),
                       detail: { AnyView(HomeBudgetDetailView(workspace: workspace, budgetID: presentedBudgetID ?? selectedBudget?.id ?? UUID())) }) {
            VStack(alignment: .leading, spacing: 20) {
                if workspace.isEmpty {
                    WalletEmptyBudgetCard { workspace.openComposer(.budget) }
                        .frame(maxWidth: 560)
                } else {
                    HStack {
                        Text(String(localized: "wallet.budget.collection")).font(.subheadline)
                        Spacer()
                        Text(workspace.cards.count, format: .number).font(.subheadline.monospacedDigit()).foregroundStyle(PaperTheme.muted)
                    }
                    LazyVStack(spacing: 22) {
                        let columns = sizeClass == .regular ? 2 : 1
                        ForEach(0..<((workspace.cards.count + columns - 1) / columns), id: \.self) { row in
                            let start = row * columns
                            let end = min(start + columns, workspace.cards.count)
                            HStack(alignment: .top, spacing: 20) {
                                ForEach(Array(workspace.cards[start..<end])) { card in budgetCard(card) }
                                if end - start < columns { Color.clear.frame(maxWidth: .infinity) }
                            }
                        }
                    }
                }
                if !archived.isEmpty {
                    Text(String(localized: "ui.directory.archived")).font(.headline)
                    ForEach(archived) { budget in
                        Button {
                            selectedBudget = HomeProjector.card(budgetID: budget.id, periodID: workspace.ledger.periods(forBudget: budget.id).last?.id, in: workspace.ledger)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    CheckLineIconLabel(budget.name, symbol: "archivebox")
                                    if let period = workspace.ledger.periods(forBudget: budget.id).last {
                                        Text(period.startDate, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(PaperTheme.muted)
                                    }
                                }
                                Spacer(); CheckLineIcon(symbol: "chevron.right")
                            }.padding(18).walletSurface()
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .fullScreenCover(item: $editingCard) { card in
            BudgetAmountEditorView(workspace: workspace, card: card)
        }
        .onAppear {
            if !previewApplied && DesignPreviewData.isEnabled && DesignPreviewData.screen == "budget-inline" {
                previewApplied = true
                selectedBudget = workspace.cards.first
            }
        }
        .onChange(of: selectedBudget?.id) { _, id in if let id { presentedBudgetID = id } }
    }

    private func budgetCard(_ card: HomeBudgetCardModel) -> some View {
        let motionEnabled = !reduceMotion
        return VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Button {
                    selectedBudget = card
                } label: {
                    LiquidBudgetCard(card: card)
                        .modifier(WalletTransitionSource(id: card.id, namespace: budgetTransition))
                }
                    .buttonStyle(.plain)
                    .accessibilityHint(String(localized: "wallet.card.details"))
                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                        content
                            .scaleEffect(motionEnabled ? 1 - abs(phase.value) * 0.055 : 1)
                            .rotation3DEffect(.degrees(motionEnabled ? phase.value * 5 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.34)
                            .opacity(motionEnabled ? 1 - abs(phase.value) * 0.23 : 1)
                    }
                Menu {
                    if BudgetAmountEditEngine.isEditable(budgetID: card.id, periodID: card.periodID, ledger: workspace.ledger) {
                        Button(String(localized: "wallet.budget.edit.title"), iconSymbol: "pencil") { editingCard = card }
                    }
                    Button(String(localized: "wallet.card.showHome"), iconSymbol: "house") {
                        workspace.selectedBudgetID = card.id
                        chrome?.selectedTab = .home
                    }
                    Button(String(localized: "wallet.card.pin"), iconSymbol: "pin") { workspace.pinBudget(card.id) }
                } label: { CheckLineIcon(symbol: "ellipsis").frame(width: 44, height: 44).padding(8).foregroundStyle(PaperTheme.ink) }
                    .accessibilityLabel(String(localized: "wallet.card.more"))
                    .accessibilityIdentifier("wallet.budget.card.more")
            }
            CheckLineIconLabel(String(localized: card.periodState == .pendingSettlement ? "ui.period.due" : (card.cycleType == .repeating ? "wallet.cycle.monthly" : "v1.cycle.oneShot")), symbol: "calendar", size: 16)
                .font(.caption).foregroundStyle(PaperTheme.muted)
            HStack(spacing: 4) {
                Text(card.periodStart, format: .dateTime.year().month().day())
                if let end = card.periodEnd { Text("–"); Text(end, format: .dateTime.month().day()) }
            }.font(.caption).foregroundStyle(PaperTheme.muted)
            if BudgetPresentation.pendingCount(card, in: workspace.ledger) > 0 {
                CheckLineIconLabel(String(format: String(localized: "wallet.pending.count"), BudgetPresentation.pendingCount(card, in: workspace.ledger)), symbol: "clock", size: 16)
                    .font(.caption).foregroundStyle(PaperTheme.gold)
            }
        }.frame(maxWidth: .infinity)
    }
}
