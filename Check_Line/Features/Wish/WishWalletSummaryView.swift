import SwiftUI

struct WishWalletSummaryView: View {
    var projection: WalletProjection
    var currencyCode: String
    @Environment(\.dismiss) private var dismiss

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
                    PaperCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Label(String(localized: "wallet.wishes.settlementIn"), systemImage: "arrow.down.left")
                            Label(String(localized: "wallet.wishes.redemptionOut"), systemImage: "arrow.up.right")
                            Text(String(localized: "wallet.wishes.recoveryOrder")).font(.caption).foregroundStyle(PaperTheme.muted)
                        }.font(.subheadline)
                    }
                    Text(String(localized: "v1.wish.notRealMoney")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "v1.wish.title")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .presentationBackground(PaperTheme.canvas)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PaperTheme.Radius.sheet)
    }
}
