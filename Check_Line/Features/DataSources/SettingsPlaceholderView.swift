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
                        CheckLineIcon(symbol: "iphone.gen3")
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
                    if let workspace, workspace.cloudSettings.isConfigured {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(String(localized: "cloud.agent.setting"), isOn: Binding(
                                get: { workspace.cloudSettings.isEnabled },
                                set: { workspace.cloudSettings.consent = $0; workspace.cancelCloudRequest() }
                            ))
                            .tint(PaperTheme.accent)
                            .disabled(!workspace.cloudSettings.isAvailable && !workspace.cloudSettings.isEnabled)
                            .accessibilityIdentifier("cloud.agent.enabled")
                            Text(String(localized: workspace.cloudSettings.isAvailable ? "cloud.agent.settingBody" : "cloud.agent.unauthorized"))
                                .font(.caption).foregroundStyle(PaperTheme.muted).fixedSize(horizontal: false, vertical: true)
                        }.padding(16).walletSurface()
                    }
                    VStack(spacing: 0) {
                        inlineSetting("wallet.settings.language", value: String(localized: "wallet.settings.followsSystem"), detail: "wallet.settings.languageBody")
                        if let workspace {
                            inlineSetting("wallet.settings.walletCurrency", value: workspace.ledger.walletSettings.walletCurrencyCode, detail: "ui.settings.currencySummary")
                        }
                        inlineSetting("wallet.settings.motionTitle", value: String(localized: reduceMotion ? "wallet.settings.motionOff" : "wallet.settings.followsSystem"), detail: "wallet.settings.motionBody")
                    }.walletSurface()
                    VStack(spacing: 0) {
                        settingsRow(title: String(localized: "wallet.settings.sourcesTitle"), symbol: "tray.and.arrow.down", summary: String(localized: "wallet.settings.manual")) {
                            SourceReviewView()
                        }
                        Divider().padding(.leading, 54)
                        settingsRow(title: String(localized: "wallet.settings.privacyTitle"), symbol: "lock.shield") {
                            SettingsInformationView(isPrivacy: true)
                        }
                        Divider().padding(.leading, 54)
                        settingsRow(title: String(localized: "settings.about"), symbol: "info.circle", summary: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1") {
                            SettingsInformationView(isPrivacy: false)
                        }
                    }
                    .walletSurface()
                }.padding(22).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "v1.settings.title")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), iconSymbol: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .presentationBackground(PaperTheme.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PaperTheme.Radius.sheet)
    }

    private func settingsRow<Destination: View>(title: String, symbol: String, summary: String? = nil, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                CheckLineIcon(symbol: symbol).font(.body).foregroundStyle(PaperTheme.accent).frame(width: 34)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Text(title).font(.body).foregroundStyle(PaperTheme.ink)
                            .fixedSize(horizontal: true, vertical: true)
                        Spacer(minLength: 0)
                        if let summary {
                            Text(summary).font(.subheadline).foregroundStyle(PaperTheme.muted)
                                .fixedSize(horizontal: true, vertical: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.body).foregroundStyle(PaperTheme.ink)
                        if let summary {
                            Text(summary).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                CheckLineIcon(symbol: "chevron.right", size: 20).font(.caption.weight(.semibold)).foregroundStyle(PaperTheme.muted)
            }.padding(.vertical, 12).contentShape(Rectangle())
        }.buttonStyle(.plain).padding(.horizontal, 16).frame(minHeight: 56)
    }

    private func inlineSetting(_ key: String.LocalizationValue, value: String, detail: String.LocalizationValue) -> some View {
        DisclosureGroup {
            Text(String(localized: detail)).font(.caption).foregroundStyle(PaperTheme.muted)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(String(localized: key)); Spacer(minLength: 12)
                    Text(value).foregroundStyle(PaperTheme.muted)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: key)); Text(value).font(.subheadline).foregroundStyle(PaperTheme.muted)
                }
            }
        }.font(.body).tint(PaperTheme.accent).padding(16)
    }
}

struct SettingsInformationView: View {
    let isPrivacy: Bool
    private var facts: [(String.LocalizationValue, String.LocalizationValue)] {
        isPrivacy ? [("ui.privacy.ledger", "ui.privacy.ledgerBody"), ("cloud.agent.setting", "cloud.agent.privacyBody"), ("wallet.expense.attachments", "ui.privacy.attachmentsBody"), ("ui.source.voice", "ui.privacy.voiceBody"), ("native.cover.title", "native.cover.privacy")]
                  : [("ui.about.purpose", "ui.about.purposeBody"), ("ui.about.local", "ui.about.localBody")]
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !isPrivacy {
                    Text("CheckLine").font(.largeTitle.weight(.medium))
                    Text((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1") + ")")
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                }
                ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: fact.0)).font(.headline)
                        Text(String(localized: fact.1)).font(.subheadline).foregroundStyle(PaperTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).walletSurface()
                }
            }.padding(22).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: isPrivacy ? "wallet.settings.privacyTitle" : "settings.about"))
            .navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
    }
}
