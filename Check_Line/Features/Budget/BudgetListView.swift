import SwiftUI

struct BudgetListView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.walletReduceMotion) private var reduceMotion
    @State private var expandedBudgetID: UUID?

    var body: some View {
        WalletRootPage(tab: .budgets, title: String(localized: "tab.budgets"), workspace: workspace, onAdd: { workspace.openComposer(.budget) }) {
            VStack(alignment: .leading, spacing: 20) {
                if workspace.isEmpty {
                    PaperEmptyHint(title: String(localized: "v1.home.empty.title"), message: String(localized: "wallet.empty.budget"))
                    Button(String(localized: "v1.budget.create")) { workspace.openComposer(.budget) }.buttonStyle(PaperSolidButtonStyle())
                } else {
                    HStack {
                        Text(String(localized: "wallet.budget.collection")).font(.subheadline)
                        Spacer()
                        Text(workspace.cards.count, format: .number).font(.subheadline.monospacedDigit()).foregroundStyle(PaperTheme.muted)
                    }
                    LazyVStack(spacing: 24) {
                        let columns = sizeClass == .regular ? 2 : 1
                        ForEach(0..<((workspace.cards.count + columns - 1) / columns), id: \.self) { row in
                            let start = row * columns
                            let end = min(start + columns, workspace.cards.count)
                            HStack(alignment: .top, spacing: 20) {
                                ForEach(Array(workspace.cards[start..<end])) { card in budgetCard(card) }
                                if end - start < columns { Color.clear.frame(maxWidth: .infinity) }
                            }
                            if let expanded = expandedBudgetID, workspace.cards[start..<end].contains(where: { $0.id == expanded }),
                               let card = workspace.cards.first(where: { $0.id == expanded }) {
                                BudgetInlineDetails(workspace: workspace, card: card)
                                    .frame(maxWidth: .infinity)
                                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if DesignPreviewData.isEnabled && DesignPreviewData.screen == "budget-inline" {
                expandedBudgetID = workspace.cards.first?.id
            }
        }
    }

    private func budgetCard(_ card: HomeBudgetCardModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86)) {
                        expandedBudgetID = expandedBudgetID == card.id ? nil : card.id
                    }
                } label: { LiquidBudgetCard(card: card) }
                    .buttonStyle(.plain)
                    .accessibilityHint(String(localized: "wallet.card.details"))
                Menu {
                    Button(String(localized: "wallet.card.showHome"), systemImage: "house") {
                        workspace.selectedBudgetID = card.id
                        chrome?.selectedTab = .home
                    }
                    Button(String(localized: "wallet.card.pin"), systemImage: "pin") { workspace.pinBudget(card.id) }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).padding(8).foregroundStyle(.white) }
                    .accessibilityLabel(String(localized: "wallet.card.more"))
            }
            HStack(spacing: 8) {
                Image(systemName: card.cycleType == .repeating ? "arrow.triangle.2.circlepath" : "flag")
                Text(card.cycleType == .repeating ? String(localized: "v1.cycle.repeating") : String(localized: "v1.cycle.oneShot"))
                Spacer()
                if let end = card.periodEnd { Text(end, format: .dateTime.month().day()) }
                else { Text(String(localized: "wallet.noDeadline")) }
            }.font(.caption).foregroundStyle(PaperTheme.muted).padding(.horizontal, 6)
        }.frame(maxWidth: .infinity)
    }
}
