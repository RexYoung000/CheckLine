import SwiftUI

/// Presents a deterministic preview, then returns through the existing confirmation gate.
struct PendingExpenseImpactView: View {
    @Bindable var workspace: CheckLineWorkspace
    var preview: RetrospectivePreview
    var onClose: () -> Void
    @State private var errorText: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    CheckLineIconLabel(String(localized: "wallet.expense.retrospectiveImpact"), symbol: "clock.arrow.circlepath", size: 24).font(.title2.weight(.semibold))
                    Text(String(localized: "ui.impact.confirmPendingSummary")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                    VStack(alignment: .leading, spacing: 16) {
                        impactRow("ui.impact.originalPeriod", periodRange)
                        impactRow("ui.impact.change", MoneyFormat.string(preview.amountDelta, currencyCode: preview.sourceCurrencyCode))
                    }.padding(18).walletSurface(radius: 22)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "ui.impact.walletTitle")).font(.headline)
                        impactRow("v1.wish.balance", MoneyFormat.string(preview.balanceAfter, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode))
                        impactRow("v1.wish.recovery", MoneyFormat.string(preview.recoveryGapAfter, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode))
                    }.padding(18).walletSurface(radius: 22)
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

    private var periodRange: String {
        guard let period = workspace.ledger.periods[preview.periodID] else { return "" }
        let start = period.startDate.formatted(date: .abbreviated, time: .omitted)
        return period.endDate.map { start + " – " + $0.formatted(date: .abbreviated, time: .omitted) } ?? start
    }

    private func impactRow(_ key: String.LocalizationValue, _ value: String) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Text(String(localized: key)).font(.subheadline).foregroundStyle(PaperTheme.muted)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit()
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }.accessibilityElement(children: .combine)
    }
}
