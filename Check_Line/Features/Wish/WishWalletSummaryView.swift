import SwiftUI

struct WishWalletSummaryView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var rulesExpanded = false
    private var projection: WalletProjection { workspace.wallet }
    private var currencyCode: String { workspace.ledger.walletSettings.walletCurrencyCode }
    private var entries: [WalletLedgerEntry] {
        workspace.ledger.sortedWalletEntries.reversed()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    WalletSymbol(name: "sparkles", size: 72)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "v1.wish.balance")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        Text(MoneyFormat.string(projection.balance, currencyCode: currencyCode))
                            .font(.largeTitle.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    }
                    if projection.recoveryGap > 0 {
                        PaperFormItem(title: String(localized: "v1.wish.recovery"), value: MoneyFormat.string(projection.recoveryGap, currencyCode: currencyCode))
                    }
                    DisclosureGroup(String(localized: "ui.wish.walletRules"), isExpanded: $rulesExpanded) {
                        VStack(alignment: .leading, spacing: 16) {
                            CheckLineIconLabel(String(localized: "wallet.wishes.settlementIn"), symbol: "arrow.down.left")
                            CheckLineIconLabel(String(localized: "wallet.wishes.redemptionOut"), symbol: "arrow.up.right")
                            Text(String(localized: "wallet.wishes.recoveryOrder")).font(.caption).foregroundStyle(PaperTheme.muted)
                        }.font(.subheadline).padding(.top, 12)
                    }.font(.subheadline).tint(PaperTheme.accent)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(String(localized: "wallet.wishes.history")).font(.headline)
                        if entries.isEmpty {
                            Text(String(localized: "wallet.wishes.historyEmpty"))
                                .font(.subheadline).foregroundStyle(PaperTheme.muted)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(entries) { entry in
                                    entryRow(entry)
                                }
                            }.padding(4).walletSurface()
                        }
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "v1.wish.title")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), iconSymbol: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .presentationBackground(PaperTheme.canvas)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PaperTheme.Radius.sheet)
    }

    private func entryRow(_ entry: WalletLedgerEntry) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 5) {
                Text(entryTitle(entry)).font(.subheadline.weight(.medium))
                Text(entry.occurredAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption).foregroundStyle(PaperTheme.muted)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(MoneyFormat.string(entry.walletSignedAmount, currencyCode: currencyCode))
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func entryTitle(_ entry: WalletLedgerEntry) -> String {
        if let settlementID = entry.settlementID,
           let settlement = workspace.ledger.settlements[settlementID],
           let period = workspace.ledger.periods[settlement.periodID],
           let budget = workspace.ledger.budgets[period.budgetID] {
            return budget.name + " · " + String(localized: entry.walletSignedAmount >= 0 ? "wallet.settlement.surplus" : "wallet.settlement.overrun")
        }
        if let redemptionID = entry.wishRedemptionID,
           let redemption = workspace.ledger.redemptions[redemptionID],
           let wish = workspace.ledger.wishes[redemption.wishID] {
            return wish.name + " · " + String(localized: "wallet.wishes.redemption")
        }
        switch entry.type {
        case .surplus: return String(localized: "wallet.settlement.surplus")
        case .overrun: return String(localized: "wallet.settlement.overrun")
        case .wishRedemption: return String(localized: "wallet.wishes.redemption")
        case .refund: return String(localized: "wallet.wishes.refund")
        case .retrospectiveAdjustment: return String(localized: "wallet.wishes.adjustment")
        }
    }
}
