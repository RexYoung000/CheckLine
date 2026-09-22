import SwiftUI

struct AgentTaskPanel: View {
    @Bindable var workspace: CheckLineWorkspace
    var embedded: Bool = false
    var onCreateBudget: (() -> Void)?
    @FocusState private var inputFocused: Bool

    var body: some View {
        expanded
            .frame(maxWidth: PaperTheme.Layout.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .background {
                if embedded == false {
                    RoundedRectangle(cornerRadius: PaperTheme.Radius.card, style: .continuous)
                        .fill(PaperTheme.card)
                        .shadow(color: PaperTheme.shadow, radius: 16, x: 0, y: -4)
                }
            }
            .padding(.horizontal, embedded ? 20 : 16)
            .onChange(of: workspace.panelExpanded) { _, expanded in
                if expanded == false {
                    inputFocused = false
                }
            }
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: PaperTheme.Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "v1.agent.offline"))
                    .font(PaperTheme.Typography.caption)
                    .foregroundStyle(PaperTheme.muted)
                Spacer()
                if embedded == false {
                    Button(String(localized: "v1.agent.collapse")) {
                        inputFocused = false
                        workspace.collapsePanel()
                    }
                    .font(PaperTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(PaperTheme.ink)
                    .frame(minHeight: 32)
                }
            }

            if workspace.isEmpty {
                VStack(alignment: .leading, spacing: PaperTheme.Space.s) {
                    Text(String(localized: "v1.agent.needCard"))
                        .font(PaperTheme.Typography.meta)
                        .foregroundStyle(PaperTheme.ink)
                    Button(String(localized: "v1.budget.create")) {
                        if let onCreateBudget {
                            onCreateBudget()
                        } else {
                            workspace.openComposer(.budget)
                        }
                    }
                    .buttonStyle(PaperSolidButtonStyle())
                }
            }

            if let banner = workspace.banner {
                Text(banner.localizedText)
                    .font(PaperTheme.Typography.meta)
                    .foregroundStyle(PaperTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(banner.localizedText)
            }

            if workspace.showsStructuredConfirm {
                structuredConfirm
            }

            HStack(alignment: .bottom, spacing: PaperTheme.Space.s) {
                PaperField(
                    title: String(localized: "v1.agent.placeholder"),
                    text: $workspace.draftText,
                    axis: .vertical
                )
                .focused($inputFocused)

                Button(String(localized: "v1.agent.send")) {
                    Task { await workspace.submitText() }
                }
                .buttonStyle(
                    PaperSolidButtonStyle(
                        enabled: canSend
                    )
                )
                .disabled(canSend == false)
            }

            if workspace.lastUndo != nil {
                Button(String(localized: "action.undo")) {
                    workspace.undoLast()
                }
                .buttonStyle(PaperQuietButtonStyle())
            }
        }
        .padding(.horizontal, embedded ? 0 : PaperTheme.Space.m)
        .padding(.top, PaperTheme.Space.m)
        .padding(.bottom, PaperTheme.Space.s)
    }

    private var canSend: Bool {
        workspace.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && workspace.isWorking == false
    }

    private var structuredConfirm: some View {
        VStack(alignment: .leading, spacing: PaperTheme.Space.m) {
            if workspace.banner == .needsAmount || MoneyFormat.parseAmount(workspace.confirmAmountText) == nil {
                PaperField(
                    title: String(localized: "v1.agent.amount"),
                    text: $workspace.confirmAmountText,
                    keyboard: .decimalPad
                )
                HStack(spacing: PaperTheme.Space.s) {
                    ForEach(["CNY", "USD", "JPY", "EUR"], id: \.self) { code in
                        PaperChoiceChip(
                            title: code,
                            value: code,
                            selection: $workspace.confirmCurrencyCode
                        )
                    }
                }
                .accessibilityLabel(String(localized: "v1.budget.currency"))
            }

            VStack(alignment: .leading, spacing: PaperTheme.Space.s) {
                Text(String(localized: "v1.agent.attribution"))
                    .font(PaperTheme.Typography.caption)
                    .foregroundStyle(PaperTheme.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PaperTheme.Space.s) {
                        ForEach(workspace.attributionChoices) { choice in
                            PaperChoiceChip(
                                title: choice.periodID == nil
                                    ? String(localized: "v1.unbudgeted")
                                    : choice.title,
                                value: choice.id,
                                selection: $workspace.selectedAttributionID
                            )
                        }
                    }
                }
            }

            Button(String(localized: "v1.agent.confirm")) {
                workspace.confirmStructured()
            }
            .buttonStyle(PaperSolidButtonStyle())
        }
    }
}
