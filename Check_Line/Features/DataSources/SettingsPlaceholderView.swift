import SwiftUI

struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.walletReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        WalletSymbol(name: "person.crop.circle", size: 64)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CheckLine").font(.title2.weight(.medium))
                            Text(String(localized: "wallet.settings.device")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        }
                    }.padding(.vertical, 12)
                    settingsGroup(title: String(localized: "wallet.settings.privacyTitle"), symbol: "lock.shield", summary: String(localized: "wallet.settings.device")) {
                        Text(String(localized: "v1.settings.privacy"))
                    }
                    settingsGroup(title: String(localized: "wallet.settings.sourcesTitle"), symbol: "tray.and.arrow.down", summary: String(localized: "wallet.settings.manual")) {
                        Text(String(localized: "v1.settings.sources"))
                    }
                    settingsGroup(title: String(localized: "wallet.settings.motionTitle"), symbol: "water.waves", summary: reduceMotion ? String(localized: "wallet.settings.motionOff") : String(localized: "wallet.settings.motionOn")) {
                        Text(String(localized: "wallet.settings.motionBody"))
                    }
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

    private func settingsGroup<Content: View>(title: String, symbol: String, summary: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup {
            content().font(.subheadline).foregroundStyle(PaperTheme.muted)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 16)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(PaperTheme.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline).foregroundStyle(PaperTheme.ink)
                    Text(summary).font(.caption).foregroundStyle(PaperTheme.muted)
                }
            }.padding(.vertical, 6)
        }.padding(18).walletSurface()
    }
}
