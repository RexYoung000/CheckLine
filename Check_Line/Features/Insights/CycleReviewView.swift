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
                            HStack { Text(card.name).font(.headline); CheckLineIcon(symbol: "chevron.down", size: 20).font(.caption); Spacer() }
                            Text(periodSummary(card))
                                .font(.subheadline).foregroundStyle(PaperTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(PaperTheme.ink).frame(minHeight: 44)
                    }
                    let hasRecords = !BudgetPresentation.expenses(card, in: workspace.ledger).isEmpty
                    if hasRecords {
                        Button { showsDetails = true } label: {
                            PaperCard {
                                VStack(alignment: .leading, spacing: 18) {
                                    HStack { Text(String(localized: "wallet.used.title")).font(.subheadline); Spacer(); CheckLineIcon(symbol: "arrow.up.right") }
                                    Text(MoneyFormat.string(-BudgetPresentation.used(card), currencyCode: card.currencyCode)).font(.largeTitle.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                                    BudgetDailyChart(card: card, ledger: workspace.ledger, height: 120)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    PaperCard {
                        VStack(alignment: .leading, spacing: 20) {
                            if !hasRecords {
                                Text(String(localized: "wallet.analysis.noRecords"))
                                    .font(.headline)
                                Button(String(localized: "capture.title"), iconSymbol: "plus") {
                                    workspace.openComposer(.record)
                                }
                                .buttonStyle(PaperSolidButtonStyle())
                                .accessibilityIdentifier("wallet.analysis.empty.record")
                            }
                            BudgetCalendarView(card: card, ledger: workspace.ledger, showsEmptyDayMessage: hasRecords).id(card.id)
                        }
                    }
                } else {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 18) {
                            CheckLineIcon(symbol: "calendar", size: 48)
                                .font(.system(size: 52, weight: .ultraLight))
                                .foregroundStyle(PaperTheme.muted)
                                .frame(maxWidth: .infinity, minHeight: 130)
                            Text(String(localized: "v1.insights.empty")).font(.headline)
                            Button(String(localized: "v1.budget.create"), iconSymbol: "plus") {
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
