import SwiftUI

struct AgentTaskPanel: View {
    enum Part: Equatable { case complete, content, footer }
    @Bindable var workspace: CheckLineWorkspace
    var embedded: Bool = false
    var part: Part = .complete
    var onCreateBudget: (() -> Void)?
    @FocusState private var inputFocused: Bool
    @State private var showingVoiceNotice = false
    @Environment(\.dynamicTypeSize) private var typeSize

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
            .padding(.horizontal, embedded ? 0 : 16)
            .onChange(of: inputFocused) { _, focused in
                if focused { workspace.panelExpanded = true }
            }
            .onChange(of: workspace.confirmAmountText) { _, amount in
                if workspace.captureProposal != nil { workspace.taskDraft.amount = amount }
            }
            .onChange(of: workspace.confirmCurrencyCode) { _, code in
                if workspace.captureProposal != nil { workspace.taskDraft.currency = code }
            }
            .onChange(of: workspace.selectedAttributionID) { _, id in
                if workspace.captureProposal != nil { workspace.taskDraft.attributionID = id }
            }
            .onChange(of: workspace.panelExpanded) { _, expanded in
                if expanded == false {
                    inputFocused = false
                }
            }
            .alert(String(localized: "ui.agent.voice"), isPresented: $showingVoiceNotice) {
                Button(String(localized: "action.close"), role: .cancel) { }
            } message: {
                Text(String(localized: "ui.agent.voiceUnavailable"))
            }
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: PaperTheme.Space.m) {
            if part != .footer {
            if embedded == false {
                HStack {
                    Spacer()
                    Button(String(localized: "v1.agent.collapse")) {
                        inputFocused = false
                        workspace.collapsePanel()
                    }
                    .font(PaperTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(PaperTheme.ink)
                    .frame(minHeight: 32)
                }
            }

            if workspace.isEmpty && !embedded {
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

            if !embedded, let banner = workspace.agentBanner {
                Text(banner.localizedText)
                    .font(PaperTheme.Typography.meta)
                    .foregroundStyle(PaperTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(banner.localizedText)
            }

            if workspace.showsStructuredConfirm {
                structuredFields
            }
            }

            if part != .content {
            if workspace.showsStructuredConfirm {
                structuredActions
            } else {
            VStack(alignment: .leading, spacing: 12) {
                TextField("", text: $workspace.draftText,
                          prompt: Text(inputPlaceholder).font(typeSize.isAccessibilitySize ? .caption : .body).foregroundStyle(PaperTheme.muted), axis: .vertical)
                    .font(.body).lineLimit(typeSize.isAccessibilitySize ? 1...2 : 2...4)
                    .focused($inputFocused)
                    .accessibilityLabel(String(localized: "ui.agent.inputLabel"))
                    .accessibilityIdentifier("wallet.agent.input")
                HStack(spacing: 8) {
                    Spacer()
                    Button { showingVoiceNotice = true } label: {
                        Image(systemName: "mic").font(.system(size: 20)).frame(width: 44, height: 44)
                    }.accessibilityLabel(String(localized: "ui.agent.voice"))
                        .accessibilityIdentifier("wallet.agent.voice")
                    Button {
                        inputFocused = false
                        Task { await workspace.submitText() }
                    } label: {
                        Image(systemName: "arrow.up").font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(canSend ? Color.white : PaperTheme.muted)
                            .frame(width: 44, height: 44)
                            .background(canSend ? PaperTheme.accent : PaperTheme.stroke, in: Circle())
                    }.disabled(!canSend)
                        .accessibilityLabel(String(localized: "v1.agent.send"))
                        .accessibilityIdentifier("wallet.agent.send")
                }
            }.padding(16).walletSurface(radius: 24)
            }

            if workspace.lastUndo != nil && !workspace.showsStructuredConfirm {
                Button(String(localized: "action.undo")) {
                    workspace.undoLast()
                }
                .buttonStyle(PaperQuietButtonStyle())
            }
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

    private var inputPlaceholder: String {
        let budget = workspace.isEmpty || workspace.pendingBudgetText != nil || workspace.composerIntent == .budget
        return String(localized: typeSize.isAccessibilitySize
                      ? (budget ? "ui.agent.shortBudgetExample" : "ui.agent.shortRecordExample")
                      : (budget ? "v1.agent.placeholder.budget" : "v1.agent.placeholder"))
    }

    private var structuredFields: some View {
        VStack(alignment: .leading, spacing: PaperTheme.Space.m) {
            if let draft = workspace.captureProposal {
                HStack(alignment: .center, spacing: 12) {
                PaperField(
                    title: String(localized: "v1.agent.amount"),
                    text: $workspace.confirmAmountText,
                    keyboard: AmountKeyboard.type
                )
                Picker(String(localized: "v1.budget.currency"), selection: $workspace.confirmCurrencyCode) {
                    ForEach(Array(Set(["CNY", "USD", "JPY", "EUR", workspace.confirmCurrencyCode])).sorted(), id: \.self) { code in
                        Text(code).tag(code)
                    }
                }.pickerStyle(.menu).labelsHidden().fixedSize().frame(minHeight: 44)
                    .accessibilityLabel(String(localized: "v1.budget.currency"))
                }
                if let merchant = draft.merchant {
                    PaperFormItem(title: String(localized: "v1.composer.merchant"), value: merchant)
                }
                PaperFormItem(title: String(localized: "v1.composer.date"), value: draft.occurredAt.formatted(date: .abbreviated, time: .omitted))

                VStack(alignment: .leading, spacing: PaperTheme.Space.s) {
                    Text(String(localized: "v1.agent.attribution"))
                        .font(PaperTheme.Typography.caption)
                        .foregroundStyle(PaperTheme.muted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PaperTheme.Space.s) {
                            ForEach(workspace.attributionChoices) { choice in
                                PaperChoiceChip(
                                    title: choice.periodID == nil ? String(localized: "v1.unbudgeted") : choice.title,
                                    value: choice.id,
                                    selection: $workspace.selectedAttributionID
                                )
                            }
                        }
                    }
                }
            } else if let draft = workspace.budgetProposal {
                Text(draft.name).font(.headline)
                PaperFormItem(title: String(localized: "v1.budget.amount"), value: MoneyFormat.string(draft.amount, currencyCode: draft.currencyCode))
                PaperFormItem(title: String(localized: "v1.budget.cycle"), value: String(localized: draft.cycleType == .repeating ? "wallet.cycle.monthly" : "v1.cycle.oneShot"))
                Text(draft.startDate, format: .dateTime.year().month().day()).font(.subheadline)
                if let end = draft.endDate { Text(end, format: .dateTime.year().month().day()).font(.subheadline) }
            }

        }
    }

    private var structuredActions: some View {
        VStack(alignment: .leading, spacing: PaperTheme.Space.s) {
            Button(String(localized: workspace.budgetProposal == nil ? "v1.agent.confirm" : "v1.agent.confirm.budget")) {
                inputFocused = false
                workspace.confirmStructured()
            }
            .buttonStyle(PaperSolidButtonStyle(enabled: workspace.canConfirmProposal))
            .disabled(!workspace.canConfirmProposal)
            Button(String(localized: "wallet.agent.cancelProposal")) {
                workspace.cancelAgentProposal()
                inputFocused = true
            }.buttonStyle(PaperQuietButtonStyle())
        }
    }
}
