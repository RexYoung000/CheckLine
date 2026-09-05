import SwiftUI

struct AgentTaskPanel: View {
    @Bindable var workspace: CheckLineWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if workspace.panelExpanded == false {
                collapsed
            } else {
                expanded
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private var collapsed: some View {
        Button {
            workspace.expandPanel()
        } label: {
            Label(String(localized: "v1.agent.collapsed"), systemImage: "text.bubble")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "v1.agent.collapsed"))
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "v1.agent.offline"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "action.close")) {
                    workspace.collapsePanel()
                }
                .font(.caption)
            }

            if let banner = workspace.banner {
                Text(bannerText(banner))
                    .font(.subheadline)
                    .accessibilityLabel(bannerText(banner))
            }

            if workspace.showsStructuredConfirm {
                structuredConfirm
            }

            HStack {
                TextField(String(localized: "v1.agent.placeholder"), text: $workspace.draftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                Button(String(localized: "v1.agent.send")) {
                    Task { await workspace.submitText() }
                }
                .disabled(workspace.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || workspace.isWorking)
            }

            if workspace.lastUndo != nil {
                Button(String(localized: "action.undo")) {
                    workspace.undoLast()
                }
            }
        }
    }

    private var structuredConfirm: some View {
        VStack(alignment: .leading, spacing: 8) {
            if workspace.banner == .needsAmount || MoneyFormat.parseAmount(workspace.confirmAmountText) == nil {
                TextField(String(localized: "v1.agent.amount"), text: $workspace.confirmAmountText)
                    .keyboardType(.decimalPad)
                Picker(String(localized: "v1.budget.currency"), selection: $workspace.confirmCurrencyCode) {
                    Text("CNY").tag("CNY")
                    Text("USD").tag("USD")
                    Text("JPY").tag("JPY")
                    Text("EUR").tag("EUR")
                }
            }
            Picker(String(localized: "v1.agent.attribution"), selection: $workspace.selectedAttributionID) {
                ForEach(workspace.attributionChoices) { choice in
                    Text(choice.periodID == nil ? String(localized: "v1.unbudgeted") : choice.title)
                        .tag(choice.id)
                }
            }
            Button(String(localized: "v1.agent.confirm")) {
                workspace.confirmStructured()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func bannerText(_ banner: WorkspaceBanner) -> String {
        switch banner {
        case .recorded:
            String(localized: "v1.banner.recorded")
        case .undone:
            String(localized: "v1.banner.undone")
        case .createdBudget:
            String(localized: "v1.banner.created")
        case .queryRemaining(let amount, let currency):
            String(format: String(localized: "v1.banner.query"), locale: .current, MoneyFormat.string(amount, currencyCode: currency))
        case .refusedRecommend:
            String(localized: "v1.banner.refuseRecommend")
        case .refusedOutOfScope:
            String(localized: "v1.banner.refuseScope")
        case .needsAmount:
            String(localized: "v1.banner.needsAmount")
        case .needsFullscreen:
            String(localized: "v1.banner.needsFullscreen")
        case .needsClarification:
            String(localized: "v1.banner.needsClarification")
        case .failed:
            String(localized: "v1.banner.failed")
        }
    }
}
