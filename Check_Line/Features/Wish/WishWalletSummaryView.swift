import SwiftUI

struct WishWalletSummaryView: View {
    var projection: WalletProjection
    var currencyCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                LabeledContent(String(localized: "v1.wish.balance")) {
                    Text(MoneyFormat.string(projection.balance, currencyCode: currencyCode))
                }
                LabeledContent(String(localized: "v1.wish.recovery")) {
                    Text(MoneyFormat.string(projection.recoveryGap, currencyCode: currencyCode))
                }
                Text(String(localized: "v1.wish.notRealMoney"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(String(localized: "v1.wish.empty"))
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(String(localized: "v1.wish.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.close")) { dismiss() }
                }
            }
        }
    }
}
