import SwiftUI

struct CycleReviewView: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var showsDetails = false
    var body: some View {
        WalletRootPage(title: String(localized: "wallet.analysis.title"), workspace: workspace) {
            VStack(alignment: .leading, spacing: 24) {
                if let card = workspace.selectedCard {
                    Menu {
                        ForEach(workspace.cards) { item in Button(item.name) { workspace.selectedBudgetID = item.id } }
                    } label: {
                        HStack { Text(card.name).font(.headline); Image(systemName: "chevron.down").font(.caption); Spacer() }
                            .foregroundStyle(PaperTheme.ink).frame(minHeight: 44)
                    }
                    Button { showsDetails = true } label: {
                        PaperCard {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack { Text(String(localized: "wallet.used.title")).font(.subheadline); Spacer(); Image(systemName: "arrow.up.right") }
                                Text(MoneyFormat.string(-BudgetPresentation.used(card), currencyCode: card.currencyCode)).font(.largeTitle.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                                BudgetDailyChart(card: card, ledger: workspace.ledger, height: 120)
                            }
                        }
                    }.buttonStyle(.plain)
                    PaperCard { BudgetCalendarView(card: card, ledger: workspace.ledger) }
                } else {
                    PaperEmptyHint(title: String(localized: "v1.insights.empty"), message: String(localized: "wallet.empty.analysis"))
                }
            }.frame(maxWidth: 650)
        }
        .sheet(isPresented: $showsDetails) {
            if let card = workspace.selectedCard { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: .overview) }
        }
    }
}
