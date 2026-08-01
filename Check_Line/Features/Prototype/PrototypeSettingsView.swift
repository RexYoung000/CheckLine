import SwiftUI

struct PrototypeSettingsView: View {
    let store: PrototypeStore
    let onDeleteSingleExpense: (PrototypeExpense, UUID, Bool) -> Void
    let onDeleteBatchExpenses: (Set<UUID>, UUID, Set<UUID>) -> Void
    let onPlaceholder: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                statusCard
                financeSection
                settingsSection("settings.general", rows: generalRows)
                settingsSection("settings.about", rows: aboutRows)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(CheckLineColor.canvas.ignoresSafeArea())
        .navigationTitle(Text("tab.settings"))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.status.title")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CheckLineColor.secondary)
            Text(String(format: String(localized: "settings.status.subtitle"), store.activeBudgets.count))
                .font(.title3.weight(.semibold))
                .foregroundStyle(CheckLineColor.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var financeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CheckLineSectionHeader("settings.finance")

            CheckLineSurface {
                VStack(spacing: 0) {
                    Button {
                        showUnavailable(String(localized: "settings.budgets"))
                    } label: {
                        settingLabel(financeRows[0])
                    }
                    .buttonStyle(.plain)

                    Divider()

                    NavigationLink {
                        PrototypeRecordBudgetPickerView(
                            store: store,
                            onDeleteSingle: onDeleteSingleExpense,
                            onDeleteBatch: onDeleteBatchExpenses
                        )
                    } label: {
                        settingLabel(financeRows[1])
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Button {
                        showUnavailable(String(localized: "settings.export"))
                    } label: {
                        settingLabel(financeRows[2])
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func settingsSection(_ title: LocalizedStringKey, rows: [SettingRowData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CheckLineSectionHeader(title)

            CheckLineSurface {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        Button {
                            showUnavailable(row.title)
                        } label: {
                            settingLabel(row)
                        }
                        .buttonStyle(.plain)

                        if index < rows.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func settingLabel(_ row: SettingRowData, showsChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.title)
                        .font(.subheadline.bold())
                    Text(row.subtitle)
                        .font(.caption)
                        .foregroundStyle(CheckLineColor.secondary)
                }
            } icon: {
                Image(systemName: row.symbol)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CheckLineColor.text)
                    .frame(width: 34, height: 34)
                    .background(CheckLineColor.muted, in: Circle())
            }
            Spacer()
            if row.isFuture {
                Text("settings.future")
                    .font(.caption2.bold())
                    .foregroundStyle(CheckLineColor.quiet)
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                .foregroundStyle(CheckLineColor.quiet)
            }
        }
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    private func showUnavailable(_ title: String) {
        onPlaceholder(String(format: String(localized: "settings.prototype.unavailable"), title))
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
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    var isFuture = false

    init(title: String, subtitle: String, symbol: String, isFuture: Bool = false) {
        self.id = title
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.isFuture = isFuture
    }
}
