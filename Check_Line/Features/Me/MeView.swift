import SwiftUI

struct MeView: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(String(localized: "v1.me.wish.section"))
                        .font(PaperTheme.Typography.caption)
                        .foregroundStyle(PaperTheme.muted)
                    VStack(spacing: 12) {
                        PaperFormItem(
                            title: String(localized: "v1.wish.balance"),
                            value: MoneyFormat.string(
                                workspace.wallet.balance,
                                currencyCode: workspace.ledger.walletSettings.walletCurrencyCode
                            )
                        )
                        PaperFormItem(
                            title: String(localized: "v1.wish.recovery"),
                            value: MoneyFormat.string(
                                workspace.wallet.recoveryGap,
                                currencyCode: workspace.ledger.walletSettings.walletCurrencyCode
                            )
                        )
                        Text(String(localized: "v1.wish.notRealMoney"))
                            .font(PaperTheme.Typography.caption)
                            .foregroundStyle(PaperTheme.muted)
                            .padding(.horizontal, 4)
                        PaperFormItem(
                            title: String(localized: "v1.wish.empty"),
                            value: ""
                        )
                    }

                    Text(String(localized: "v1.me.settings.section"))
                        .font(PaperTheme.Typography.caption)
                        .foregroundStyle(PaperTheme.muted)
                    PaperFormItem(
                        title: String(localized: "v1.settings.entry"),
                        value: "",
                        showArrow: true
                    ) {
                        showingSettings = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
                .frame(maxWidth: PaperTheme.Layout.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .tint(PaperTheme.ink)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                PaperPageTitle(title: String(localized: "tab.settings"))
            }
            .sheet(isPresented: $showingSettings) {
                SettingsPlaceholderView()
            }
        }
    }
}
