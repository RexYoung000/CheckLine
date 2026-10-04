import SwiftUI

struct CycleReviewView: View {
    @Bindable var workspace: CheckLineWorkspace
    var body: some View {
        WalletRootPage(tab: .insights, title: String(localized: "wallet.analysis.title"), workspace: workspace) {
            VStack(alignment: .leading, spacing: 24) {
                if let card = workspace.selectedCard {
                    Menu {
                        ForEach(workspace.cards) { item in Button(item.name) { workspace.selectedBudgetID = item.id } }
                    } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.name).font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(periodSummary(card))
                                    .font(.caption).foregroundStyle(PaperTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            CheckLineIcon(symbol: "chevron.down", size: 18).foregroundStyle(PaperTheme.muted)
                        }
                        .foregroundStyle(PaperTheme.ink).frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(18).walletSurface()
                    }
                    .accessibilityIdentifier("wallet.analysis.cardPicker")
                    let hasRecords = !BudgetPresentation.expenses(card, in: workspace.ledger).isEmpty
                    if hasRecords {
                        NavigationLink(value: BudgetWorkspaceRoute.budget(card.id, card.periodID, .records)) {
                            PaperCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(alignment: .top, spacing: 16) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(String(localized: "wallet.used.title")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                                            Text(MoneyFormat.string(BudgetPresentation.used(card), currencyCode: card.currencyCode))
                                                .font(.largeTitle.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                                        }
                                        Spacer(minLength: 0)
                                        CheckLineIcon(symbol: "arrow.up.right", size: 20).foregroundStyle(PaperTheme.muted)
                                    }
                                    BudgetDailyChart(card: card, ledger: workspace.ledger, height: 104)
                                    if BudgetPresentation.pendingCount(card, in: workspace.ledger) > 0 {
                                        CheckLineIconLabel(String(format: String(localized: "wallet.pending.count"), BudgetPresentation.pendingCount(card, in: workspace.ledger)) + " · " + MoneyFormat.string(card.snapshot.pendingAmount, currencyCode: card.currencyCode), symbol: "clock", size: 16)
                                            .font(.caption).foregroundStyle(PaperTheme.accent)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    let missing = BudgetPresentation.expenses(card, in: workspace.ledger).filter { CurrencyEngine.budgetSettlementAmount(expense: $0, periodCurrencyCode: card.currencyCode) == nil }.count
                                    if missing > 0 {
                                        CheckLineIconLabel(String(format: String(localized: "ui.coverage.unconverted"), missing), symbol: "exclamationmark.circle", size: 16)
                                            .font(.caption).foregroundStyle(PaperTheme.accent)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("wallet.analysis.records")
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
                            Text(String(localized: "v1.insights.empty")).font(.title3.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(String(localized: "ui.analysis.empty.explanation"))
                                .font(.subheadline).foregroundStyle(PaperTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            Button(String(localized: "v1.budget.create"), iconSymbol: "plus") {
                                workspace.openComposer(.budget)
                            }.buttonStyle(PaperSolidButtonStyle())
                                .accessibilityIdentifier("wallet.analysis.empty.createBudget")
                        }
                    }
                }
            }.frame(maxWidth: 650)
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
