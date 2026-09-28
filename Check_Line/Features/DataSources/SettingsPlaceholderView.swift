import SwiftUI

struct SettingsPlaceholderView: View {
    var workspace: CheckLineWorkspace? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.walletReduceMotion) private var reduceMotion
    @AppStorage("checkline.appearance") private var appearance = CheckLineAppearance.system.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: "iphone.gen3")
                            .font(.title3)
                            .foregroundStyle(PaperTheme.accent)
                            .frame(width: 48, height: 48)
                            .walletSurface(radius: 16)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CheckLine").font(.title2.weight(.medium))
                            Text(String(localized: "wallet.settings.device")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        }
                    }.padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "wallet.appearance.title"))
                            .font(.subheadline.weight(.semibold))
                        Picker(String(localized: "wallet.appearance.title"), selection: $appearance) {
                            ForEach(CheckLineAppearance.allCases) { choice in
                                Text(choice.title).tag(choice.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    .walletSurface()
                    VStack(spacing: 0) {
                        settingsRow(title: String(localized: "wallet.settings.language"), symbol: "globe", summary: String(localized: "wallet.settings.followsSystem")) {
                            settingsDetail(title: String(localized: "wallet.settings.language"), body: String(localized: "wallet.settings.languageBody"))
                        }
                        Divider().padding(.leading, 54)
                        if let workspace {
                            settingsRow(title: String(localized: "wallet.settings.walletCurrency"), symbol: "banknote", summary: workspace.ledger.walletSettings.walletCurrencyCode) {
                                settingsDetail(title: String(localized: "wallet.settings.walletCurrency"), body: String(localized: "wallet.settings.currencyBody"))
                            }
                            Divider().padding(.leading, 54)
                        }
                        settingsRow(title: String(localized: "wallet.settings.motionTitle"), symbol: "water.waves", summary: reduceMotion ? String(localized: "wallet.settings.motionOff") : String(localized: "wallet.settings.followsSystem")) {
                            settingsDetail(title: String(localized: "wallet.settings.motionTitle"), body: String(localized: "wallet.settings.motionBody"))
                        }
                    }.walletSurface()
                    VStack(spacing: 0) {
                        settingsRow(title: String(localized: "wallet.settings.sourcesTitle"), symbol: "tray.and.arrow.down", summary: String(localized: "wallet.settings.manual")) {
                            settingsDetail(title: String(localized: "wallet.settings.sourcesTitle"), body: String(localized: "v1.settings.sources"))
                        }
                        Divider().padding(.leading, 54)
                        settingsRow(title: String(localized: "wallet.settings.privacyTitle"), symbol: "lock.shield", summary: String(localized: "wallet.settings.device")) {
                            settingsDetail(title: String(localized: "wallet.settings.privacyTitle"), body: String(localized: "v1.settings.privacy"))
                        }
                        Divider().padding(.leading, 54)
                        settingsRow(title: String(localized: "settings.about"), symbol: "info.circle", summary: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1") {
                            settingsDetail(title: String(localized: "settings.about"), body: String(localized: "wallet.settings.aboutBody"))
                        }
                    }
                    .walletSurface()
                }.padding(22).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "v1.settings.title")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .presentationBackground(PaperTheme.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PaperTheme.Radius.sheet)
    }

    private func settingsRow<Destination: View>(title: String, symbol: String, summary: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.body).foregroundStyle(PaperTheme.accent).frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body).foregroundStyle(PaperTheme.ink)
                    Text(summary).font(.caption).foregroundStyle(PaperTheme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(PaperTheme.muted)
            }.padding(.vertical, 6)
        }.buttonStyle(.plain).padding(.horizontal, 16).frame(minHeight: 64)
    }

    private func settingsDetail(title: String, body: String) -> some View {
        ScrollView {
            Text(body)
                .font(.body)
                .foregroundStyle(PaperTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .walletSurface()
                .padding(20)
        }
        .background(PaperTheme.canvas.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
