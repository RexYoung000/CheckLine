import SwiftUI

/// Presents a deterministic preview, then returns through the existing confirmation gate.
struct PendingExpenseImpactView: View {
    @Bindable var workspace: CheckLineWorkspace
    var preview: RetrospectivePreview
    var onClose: () -> Void
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label(String(localized: "wallet.expense.retrospectiveImpact"), systemImage: "clock.arrow.circlepath").font(.title2.weight(.semibold))
                    PaperFormItem(title: String(localized: "ui.impact.originalPeriod"), value: workspace.ledger.periods[preview.periodID]?.startDate.formatted(date: .abbreviated, time: .omitted) ?? "")
                    PaperFormItem(title: String(localized: "ui.impact.change"), value: MoneyFormat.string(preview.amountDelta, currencyCode: preview.sourceCurrencyCode))
                    PaperFormItem(title: String(localized: "wallet.settlement.walletAfter"), value: MoneyFormat.string(preview.balanceAfter, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode))
                    PaperFormItem(title: String(localized: "v1.wish.recovery"), value: MoneyFormat.string(preview.recoveryGapAfter, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode))
                    Text(String(localized: "ui.design.impact")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                    if let errorText { Text(errorText).font(.subheadline).foregroundStyle(.red) }
                }.padding(22).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }.background(PaperTheme.canvas)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button(String(localized: "wallet.expense.confirmAttribution")) {
                        do { try workspace.confirmPendingRetrospective(preview); onClose() }
                        catch { errorText = String(localized: "wallet.expense.actionFailed") }
                    }.buttonStyle(PaperSolidButtonStyle())
                    Button(String(localized: "action.cancel"), action: onClose).buttonStyle(PaperQuietButtonStyle())
                }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity).background(PaperTheme.canvas)
            }.navigationBarTitleDisplayMode(.inline)
        }
    }
}
