import SwiftUI

struct WalletConversionDetails: View {
    let entry: WalletLedgerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaperValueRow(title: String(localized: "wallet.exchange.rate"), value: entry.conversion.rate.formatted())
            Text(String(localized: entry.conversion.kind == .posted ? "ui.exchange.posted" : "wallet.exchange.userEstimate"))
                .font(.caption).foregroundStyle(PaperTheme.muted)
            Text(entry.conversion.quotedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.caption).foregroundStyle(PaperTheme.muted)
        }
    }
}

struct WalletEntryDetailView: View {
    @Bindable var workspace: CheckLineWorkspace
    let entryID: UUID
    @Environment(\.dismiss) private var dismiss
    private var entry: WalletLedgerEntry? { workspace.ledger.walletEntries[entryID] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let entry {
                    Text(MoneyFormat.string(entry.walletSignedAmount, currencyCode: entry.walletCurrencyCode))
                        .font(.largeTitle.weight(.medium)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(String(localized: "wallet.exchange.walletChange"))
                        .accessibilityValue(MoneyFormat.string(entry.walletSignedAmount, currencyCode: entry.walletCurrencyCode))
                        .accessibilityIdentifier("wallet.wishes.entry.amount")
                    Text(entry.occurredAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                    VStack(alignment: .leading, spacing: 16) {
                        PaperValueRow(title: String(localized: "ui.wallet.originalAmount"), value: MoneyFormat.string(entry.sourceSignedAmount, currencyCode: entry.sourceCurrencyCode))
                        if entry.conversion.kind != .identity { WalletConversionDetails(entry: entry) }
                        if let note = entry.note, !note.isEmpty { Text(note).font(.subheadline).textSelection(.enabled) }
                    }.padding(18).walletSurface()
                    if let settlement = associatedSettlement(entry), let period = workspace.ledger.periods[settlement.periodID], workspace.ledger.budgets[period.budgetID] != nil {
                        NavigationLink {
                            BudgetDetailContent(workspace: workspace, budgetID: period.budgetID, section: .overview, periodID: period.id)
                                .environment(\.shellChrome, nil)
                                .navigationDestination(for: BudgetWorkspaceRoute.self) { BudgetWorkspaceDestination(workspace: workspace, route: $0) }
                        } label: { CheckLineIconLabel(String(localized: "ui.wallet.viewPeriod"), symbol: "arrow.up.right") }
                        .buttonStyle(PaperQuietButtonStyle())
                    }
                    if let redemptionID = entry.wishRedemptionID,
                       let redemption = workspace.ledger.redemptions[redemptionID], workspace.ledger.wishes[redemption.wishID] != nil {
                        NavigationLink { WishDetailView(workspace: workspace, wishID: redemption.wishID) }
                        label: { CheckLineIconLabel(String(localized: "ui.wallet.viewPurchase"), symbol: "arrow.up.right") }
                            .buttonStyle(PaperQuietButtonStyle())
                    }
                } else {
                    ContentUnavailableView(String(localized: "ui.wallet.entryUnavailable"), systemImage: "receipt")
                    Button(String(localized: "action.back")) { dismiss() }.buttonStyle(PaperQuietButtonStyle())
                }
            }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "ui.wallet.entryTitle")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .accessibilityIdentifier("wallet.wishes.entry.detail")
    }

    private func associatedSettlement(_ entry: WalletLedgerEntry) -> Settlement? {
        let id = entry.settlementID ?? entry.adjustmentID.flatMap { workspace.ledger.adjustments[$0]?.settlementID }
        return id.flatMap { workspace.ledger.settlements[$0] }
    }
}
