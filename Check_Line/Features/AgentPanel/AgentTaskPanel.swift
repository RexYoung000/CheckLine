import SwiftUI

struct AgentTaskPanel: View {
    enum Part: Equatable { case complete, content, footer }
    @Bindable var workspace: CheckLineWorkspace
    @Bindable var voiceCapture: VoiceCaptureController
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
                if workspace.captureProposal != nil {
                    workspace.taskDraft.attributionID = id
                }
            }
            .onChange(of: workspace.panelExpanded) { _, expanded in
                if expanded == false {
                    inputFocused = false
                }
            }
            .alert(String(localized: "ui.voice.permission.title"), isPresented: $showingVoiceNotice) {
                Button(String(localized: "action.cancel"), role: .cancel) { }
                Button(String(localized: "ui.voice.permission.start")) { beginVoiceInput() }
            } message: {
                Text(String(localized: "ui.voice.permission.detail"))
            }
            .alert(String(localized: "cloud.agent.consentTitle"), isPresented: Binding(
                get: { workspace.needsCloudConsent && part != .content },
                set: { workspace.needsCloudConsent = $0 }
            )) {
                Button(String(localized: "cloud.agent.continueLocal"), role: .cancel) {
                    workspace.cloudSettings.consent = false
                    Task { await workspace.submitText() }
                }
                Button(String(localized: "cloud.agent.enableSend")) {
                    workspace.cloudSettings.consent = true
                    Task { await workspace.submitText() }
                }
            } message: { Text(String(localized: "cloud.agent.consentBody")) }
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
                VStack(alignment: .leading, spacing: 18) {
                    structuredFields.disabled(voiceCapture.isActive)
                    structuredActions.disabled(voiceCapture.isActive)
                }
                .padding(18)
                .walletSurface(radius: 24)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("wallet.agent.confirmation")
            }
            if workspace.taskDraft.agentUsesCloud == true && workspace.taskDraft.pendingAgentField == "budgetName"
                || (workspace.cloudPendingAction?.requestedIntent ?? workspace.cloudPendingAction?.intentType) == "queryBudgetStatus" {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(workspace.ledger.budgets.values.filter { $0.state != .archived }.sorted { $0.sortIndex < $1.sortIndex }, id: \.id) { budget in
                        Button { workspace.chooseCloudBudget(budget.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Text(budget.name); Spacer(); Text(MoneyFormat.string(budget.defaultAmount, currencyCode: budget.defaultCurrencyCode)).foregroundStyle(PaperTheme.muted) }
                                if let period = HomeProjector.displayPeriod(for: budget.id, ledger: workspace.ledger) {
                                    Text(BudgetPresentation.periodDates(start: period.startDate, end: period.endDate)).font(.caption).foregroundStyle(PaperTheme.muted)
                                }
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("cloud.agent.budget." + budget.id.uuidString)
                    }
                    if workspace.cloudPendingAction == nil {
                        Button(String(localized: "cloud.agent.unbudgeted")) { workspace.chooseCloudBudget(nil) }
                            .frame(minHeight: 44)
                    }
                }.padding(16).walletSurface()
            }
            if workspace.taskDraft.agentNeedsDate == true {
                DatePicker(String(localized: "cloud.agent.date"), selection: $workspace.taskDraft.occurredAt, displayedComponents: .date)
                Button(String(localized: "cloud.agent.continue")) {
                    workspace.taskDraft.agentNeedsDate = false
                    workspace.reviewRetainedTask()
                }.frame(minHeight: 44)
            }
            if case .cloudFailure = workspace.agentBanner {
                Button(String(localized: "cloud.agent.retry")) { Task { await workspace.submitText() } }
                    .frame(minHeight: 44).accessibilityIdentifier("cloud.agent.retry")
            }
            if let action = workspace.cloudPendingAction, (action.requestedIntent ?? action.intentType) != "queryBudgetStatus" {
                CloudAgentActionsView(workspace: workspace, candidate: action)
            }
            }

            if part != .content {
            VStack(alignment: .leading, spacing: 12) {
                TextField("", text: $workspace.draftText,
                          prompt: Text(inputPlaceholder).font(typeSize.isAccessibilitySize ? .caption : .body).foregroundStyle(PaperTheme.muted), axis: .vertical)
                    .font(.body).lineLimit(typeSize.isAccessibilitySize ? 1...2 : 2...4)
                    .focused($inputFocused)
                    .accessibilityLabel(String(localized: "ui.agent.inputLabel"))
                    .accessibilityIdentifier("wallet.agent.input")
                    .disabled(voiceCapture.isActive)
                if let statusKey = voiceCapture.statusKey {
                    Text(LocalizedStringKey(statusKey)).font(.caption).foregroundStyle(PaperTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("wallet.agent.voice.status")
                }
                if voiceCapture.canOpenSettings {
                    Button(String(localized: "ui.voice.settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }.font(.subheadline).frame(minHeight: 44)
                }
                HStack(spacing: 8) {
                    if voiceCapture.isActive {
                        Button(String(localized: "ui.voice.cancel")) { voiceCapture.cancel() }
                            .font(.subheadline).frame(minHeight: 44)
                            .accessibilityIdentifier("wallet.agent.voice.cancel")
                    }
                    Spacer()
                    Button {
                        if voiceCapture.isListening { voiceCapture.finish() }
                        else if voiceCapture.needsPermissionExplanation { showingVoiceNotice = true }
                        else { beginVoiceInput() }
                    } label: {
                        CheckLineIcon(symbol: voiceCapture.isListening ? "stop.fill" : "mic", size: 20)
                            .frame(width: 44, height: 44)
                            .background(voiceCapture.isListening ? PaperTheme.accent.opacity(0.15) : Color.clear, in: Circle())
                    }.accessibilityLabel(String(localized: voiceCapture.isListening ? "ui.voice.finish" : "ui.agent.voice"))
                        .accessibilityIdentifier("wallet.agent.voice")
                        .disabled(workspace.isWorking || (voiceCapture.isActive && !voiceCapture.isListening))
                    Button {
                        inputFocused = false
                        Task { await workspace.submitText() }
                    } label: {
                        CheckLineIcon(symbol: "arrow.up", size: 20)
                            .foregroundStyle(canSend ? Color.white : PaperTheme.muted)
                            .frame(width: 44, height: 44)
                            .background(canSend ? PaperTheme.accent : PaperTheme.stroke, in: Circle())
                    }.disabled(!canSend)
                        .accessibilityLabel(String(localized: "v1.agent.send"))
                        .accessibilityIdentifier("wallet.agent.send")
                }
            }.padding(16).walletSurface(radius: 24)

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

    private func beginVoiceInput() {
        inputFocused = false
        workspace.panelExpanded = true
        let taskID = workspace.taskDraft.entityID
        let initialText = workspace.draftText
        Task {
            await voiceCapture.start(initialText: initialText) { text in
                guard workspace.taskDraft.entityID == taskID else { return }
                workspace.draftText = text
            }
        }
    }

    private var canSend: Bool {
        workspace.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && workspace.isWorking == false && !voiceCapture.isActive && !workspace.attachmentImportBlocksSubmission
    }

    private var inputPlaceholder: String {
        if workspace.showsStructuredConfirm { return String(localized: "ui.agent.followupPlaceholder") }
        let budget = workspace.isEmpty || workspace.pendingBudgetText != nil || workspace.composerIntent == .budget
        return String(localized: typeSize.isAccessibilitySize
                      ? (budget ? "ui.agent.shortBudgetExample" : "ui.agent.shortRecordExample")
                      : (budget ? "v1.agent.placeholder.budget" : "v1.agent.placeholder"))
    }

    private var structuredFields: some View {
        Button {
            workspace.taskDraft.formTouched = true
            if workspace.captureProposal != nil {
                workspace.taskDraft.amount = workspace.confirmAmountText
                workspace.taskDraft.currency = workspace.confirmCurrencyCode
                workspace.taskDraft.attributionID = workspace.selectedAttributionID
                workspace.taskDraft.explicitAttribution = true
            }
            workspace.taskDraft.mode = "form"
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(MoneyFormat.parseAmount(workspace.taskDraft.amount).map {
                        MoneyFormat.string($0, currencyCode: workspace.taskDraft.currency)
                    } ?? String(localized: "v1.agent.amount"))
                        .font(.title.weight(.medium)).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    CheckLineIcon(symbol: "square.and.pencil", size: 20).foregroundStyle(PaperTheme.accent)
                }
                if workspace.captureProposal != nil {
                    if !workspace.taskDraft.merchant.isEmpty {
                        Text(workspace.taskDraft.merchant).font(.headline)
                    }
                    Text(workspace.taskDraft.occurredAt, format: .dateTime.year().month().day())
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                    Text(workspace.attributionChoices.first(where: { $0.id == workspace.selectedAttributionID })?.title
                         ?? String(localized: "ui.task.invalidAttribution"))
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                } else if let draft = workspace.budgetProposal {
                    Text(draft.name).font(.headline)
                    Text(draft.recurrence?.monthlySchedule.map { BudgetPresentation.monthlyRule($0) }
                         ?? String(localized: draft.cycleType == .repeating ? "wallet.cycle.monthly" : "v1.cycle.oneShot"))
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                    Text(BudgetPresentation.periodDates(start: draft.startDate, end: draft.endDate))
                        .font(.caption).foregroundStyle(PaperTheme.muted)
                }
            }.foregroundStyle(PaperTheme.ink).frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(String(localized: "ui.task.editFields"))
            .accessibilityValue([workspace.taskDraft.amount + " " + workspace.taskDraft.currency,
                                 workspace.captureProposal == nil ? workspace.taskDraft.name : workspace.taskDraft.merchant,
                                 workspace.budgetProposal.map { BudgetPresentation.periodDates(start: $0.startDate, end: $0.endDate) }
                                     ?? workspace.taskDraft.occurredAt.formatted(date: .abbreviated, time: .omitted),
                                 workspace.attributionChoices.first(where: { $0.id == workspace.selectedAttributionID })?.title ?? ""]
                .filter { !$0.isEmpty }.joined(separator: ", "))
            .accessibilityIdentifier("wallet.agent.editFields")
    }

    private var structuredActions: some View {
        VStack(alignment: .leading, spacing: PaperTheme.Space.s) {
            Button(String(localized: workspace.budgetProposal == nil ? "v1.agent.confirm" : "v1.agent.confirm.budget")) {
                inputFocused = false
                workspace.confirmStructured()
            }
            .buttonStyle(PaperSolidButtonStyle(enabled: workspace.canConfirmProposal))
            .disabled(!workspace.canConfirmProposal)
            Button(String(localized: "ui.task.keepEditing")) {
                workspace.leaveTaskReview()
                inputFocused = true
            }.buttonStyle(PaperQuietButtonStyle())
        }
    }
}
