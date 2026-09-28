import SwiftUI

struct BudgetListView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.walletReduceMotion) private var reduceMotion
    @State private var selectedBudget: HomeBudgetCardModel?
    @Namespace private var budgetTransition

    var body: some View {
        WalletRootPage(tab: .budgets, title: String(localized: "tab.budgets"), workspace: workspace, onAdd: { workspace.openComposer(.budget) }) {
            VStack(alignment: .leading, spacing: 20) {
                if workspace.isEmpty {
                    WalletEmptyBudgetCard { workspace.openComposer(.budget) }
                        .frame(maxWidth: 560)
                    Text(String(localized: "wallet.empty.budget"))
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                    Button(String(localized: "v1.budget.create")) { workspace.openComposer(.budget) }
                        .buttonStyle(PaperSolidButtonStyle())
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
            }
        }
        .sheet(item: $selectedBudget) { card in
            if #available(iOS 18.0, *), !reduceMotion {
                BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: .overview)
                    .navigationTransition(.zoom(sourceID: card.id, in: budgetTransition))
            } else {
                BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: .overview)
            }
        }
        .onAppear {
            if DesignPreviewData.isEnabled && DesignPreviewData.screen == "budget-inline" {
                selectedBudget = workspace.cards.first
            }
        }
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
                    Button(String(localized: "wallet.card.showHome"), systemImage: "house") {
                        workspace.selectedBudgetID = card.id
                        chrome?.selectedTab = .home
                    }
                    Button(String(localized: "wallet.card.pin"), systemImage: "pin") { workspace.pinBudget(card.id) }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).padding(8).foregroundStyle(PaperTheme.ink) }
                    .accessibilityLabel(String(localized: "wallet.card.more"))
            }
        }.frame(maxWidth: .infinity)
    }
}
