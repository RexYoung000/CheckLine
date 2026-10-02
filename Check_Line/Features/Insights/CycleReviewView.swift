import SwiftUI

struct CycleReviewView: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var showsDetails = false
    var body: some View {
        WalletRootPage(tab: .insights, title: String(localized: "wallet.analysis.title"), workspace: workspace) {
            VStack(alignment: .leading, spacing: 24) {
                if let card = workspace.selectedCard {
                    Menu {
                        ForEach(workspace.cards) { item in Button(item.name) { workspace.selectedBudgetID = item.id } }
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(card.name).font(.headline); Image(systemName: "chevron.down").font(.caption); Spacer() }
                            Text(periodSummary(card))
                                .font(.subheadline).foregroundStyle(PaperTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(PaperTheme.ink).frame(minHeight: 44)
                    }
                    if BudgetPresentation.expenses(card, in: workspace.ledger).isEmpty {
                        PaperCard {
                            VStack(alignment: .leading, spacing: 18) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 38, weight: .ultraLight))
                                    .foregroundStyle(PaperTheme.accent)
                                Text(String(localized: "wallet.analysis.noRecords"))
                                    .font(.headline)
                                Button(String(localized: "capture.title"), systemImage: "plus") {
                                    workspace.openComposer(.record)
                                }.buttonStyle(PaperSolidButtonStyle())
                            }
                        }
                    } else {
                        Button { showsDetails = true } label: {
                            PaperCard {
                                VStack(alignment: .leading, spacing: 18) {
                                    HStack { Text(String(localized: "wallet.used.title")).font(.subheadline); Spacer(); Image(systemName: "arrow.up.right") }
                                    Text(MoneyFormat.string(-BudgetPresentation.used(card), currencyCode: card.currencyCode)).font(.largeTitle.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                                    BudgetDailyChart(card: card, ledger: workspace.ledger, height: 120)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    PaperCard { BudgetCalendarView(card: card, ledger: workspace.ledger).id(card.id) }
                } else {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 18) {
                            Image(systemName: "calendar")
                                .font(.system(size: 52, weight: .ultraLight))
                                .foregroundStyle(PaperTheme.muted)
                                .frame(maxWidth: .infinity, minHeight: 130)
                            Text(String(localized: "v1.insights.empty")).font(.headline)
                            Button(String(localized: "v1.budget.create"), systemImage: "plus") {
                                workspace.openComposer(.budget)
                            }.buttonStyle(PaperSolidButtonStyle())
                        }
                    }
                }
            }.frame(maxWidth: 650)
        }
        .sheet(isPresented: $showsDetails) {
            if let card = workspace.selectedCard { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: .overview) }
        }
    }

    private func periodSummary(_ card: HomeBudgetCardModel) -> String {
        let start = card.periodStart.formatted(date: .abbreviated, time: .omitted)
        if let end = card.periodEnd {
            return String(format: String(localized: "ui.analysis.periodRange"), start, end.formatted(date: .abbreviated, time: .omitted))
        }
        return String(format: String(localized: "ui.analysis.periodFrom"), start)
    }
}
