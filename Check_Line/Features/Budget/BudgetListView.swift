import SwiftUI

struct BudgetListView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome

    var body: some View {
        WalletRootPage(title: String(localized: "tab.budgets"), workspace: workspace, onAdd: { workspace.openComposer(.budget) }) {
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 20)], spacing: 24) {
                        ForEach(workspace.cards) { card in
                            VStack(alignment: .leading, spacing: 12) {
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink { HomeBudgetDetailView(workspace: workspace, budgetID: card.id) } label: {
                                        LiquidBudgetCard(card: card)
                                    }.buttonStyle(.plain)
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
                            }
                        }
                    }
                }
            }
        }
    }
}
