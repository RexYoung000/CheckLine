import SwiftUI

struct PrototypeSettingsView: View {
    let store: PrototypeStore
    let onPlaceholder: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                statusCard
                settingsSection("settings.finance", rows: financeRows)
                settingsSection("settings.general", rows: generalRows)
                settingsSection("settings.about", rows: aboutRows)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(CheckLineColor.canvas)
        .navigationTitle(Text("tab.settings"))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("settings.status.title")
                .font(.title3.bold())
            Text(String(format: String(localized: "settings.status.subtitle"), store.activeBudgets.count))
                .font(.subheadline)
                .foregroundStyle(CheckLineColor.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .prototypeCard()
    }

    private func settingsSection(_ title: LocalizedStringKey, rows: [SettingRowData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PrototypeSectionHeader(title)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Button {
                        onPlaceholder(String(format: String(localized: "settings.prototype.unavailable"), row.title))
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: row.symbol)
                                .foregroundStyle(CheckLineColor.brand)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(CheckLineColor.text)
                                Text(row.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(CheckLineColor.secondary)
                            }
                            Spacer()
                            if row.isFuture {
                                Text("settings.future")
                                    .font(.caption2.bold())
                                    .foregroundStyle(CheckLineColor.quiet)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(CheckLineColor.quiet)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 66)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < rows.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .prototypeCard()
        }
    }

    private var financeRows: [SettingRowData] {
        [
            .init(title: String(localized: "settings.budgets"), subtitle: String(localized: "settings.budgets.subtitle"), symbol: "wallet.pass"),
            .init(title: String(localized: "settings.records"), subtitle: String(localized: "settings.records.subtitle"), symbol: "list.bullet.rectangle"),
            .init(title: String(localized: "settings.export"), subtitle: String(localized: "settings.export.subtitle"), symbol: "square.and.arrow.up", isFuture: true)
        ]
    }

    private var generalRows: [SettingRowData] {
        [
            .init(title: String(localized: "settings.notifications"), subtitle: String(localized: "settings.notifications.subtitle"), symbol: "bell", isFuture: true),
            .init(title: String(localized: "settings.appearance"), subtitle: String(localized: "settings.appearance.subtitle"), symbol: "circle.lefthalf.filled", isFuture: true),
            .init(title: String(localized: "settings.currency"), subtitle: String(localized: "settings.currency.subtitle"), symbol: "yensign.circle"),
            .init(title: String(localized: "settings.icloud"), subtitle: String(localized: "settings.icloud.subtitle"), symbol: "icloud", isFuture: true)
        ]
    }

    private var aboutRows: [SettingRowData] {
        [
            .init(title: String(localized: "settings.tutorial"), subtitle: String(localized: "settings.tutorial.subtitle"), symbol: "questionmark.circle"),
            .init(title: String(localized: "settings.privacy"), subtitle: String(localized: "settings.privacy.subtitle"), symbol: "hand.raised"),
            .init(title: String(localized: "settings.feedback"), subtitle: String(localized: "settings.feedback.subtitle"), symbol: "bubble.left.and.bubble.right"),
            .init(title: String(localized: "settings.version"), subtitle: String(localized: "settings.version.subtitle"), symbol: "info.circle")
        ]
    }
}

private struct SettingRowData: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    var isFuture = false
}
