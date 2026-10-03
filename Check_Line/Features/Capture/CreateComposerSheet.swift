import SwiftUI
import PhotosUI

enum ComposerMode: String, CaseIterable, Identifiable {
    case form
    case agent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .form: String(localized: "v1.composer.form")
        case .agent: String(localized: "v1.composer.agent")
        }
    }
}

struct CreateComposerSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    private var mode: ComposerMode {
        get { ComposerMode(rawValue: workspace.taskDraft.mode) ?? .form }
        nonmutating set { workspace.taskDraft.mode = newValue.rawValue }
    }
    private var name: String {
        get { workspace.taskDraft.name }
        nonmutating set { workspace.taskDraft.name = newValue; workspace.taskDraft.fieldsTouched = true }
    }
    private var amount: String {
        get { workspace.taskDraft.amount }
        nonmutating set { workspace.taskDraft.amount = newValue; workspace.taskDraft.fieldsTouched = true }
    }
    private var currency: String {
        get { workspace.taskDraft.currency }
        nonmutating set { workspace.taskDraft.currency = newValue; workspace.taskDraft.fieldsTouched = true }
    }
    private var repeating: Bool {
        get { workspace.taskDraft.repeating }
        nonmutating set { workspace.taskDraft.repeating = newValue; workspace.taskDraft.fieldsTouched = true }
    }
    private var merchant: String {
        get { workspace.taskDraft.merchant }
        nonmutating set { workspace.taskDraft.merchant = newValue; workspace.taskDraft.fieldsTouched = true }
    }
    private var note: String {
        get { workspace.taskDraft.note }
        nonmutating set { workspace.taskDraft.note = newValue; workspace.taskDraft.fieldsTouched = true }
    }
    private var occurredAt: Date {
        get { workspace.taskDraft.occurredAt }
        nonmutating set { workspace.taskDraft.occurredAt = newValue; workspace.taskDraft.fieldsTouched = true }
    }
    private var attributionID: String {
        get { workspace.taskDraft.attributionID }
        nonmutating set { workspace.taskDraft.attributionID = newValue; workspace.taskDraft.fieldsTouched = true }
    }
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var extrasExpanded = false
    @State private var conversationExpanded = false
    @State private var discardRequested = false
    @State private var detent: PresentationDetent = .large
    @FocusState private var formFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.shellChrome) private var chrome
    @State private var isImportingImages = false
    @State private var attachmentError: String?
    @State private var showingCurrencyPicker = false
    @State private var showingCardPicker = false
    @State private var showingDatePicker = false
    @Environment(\.dismiss) private var dismiss

    private let currencies = ["CNY", "USD", "JPY", "EUR"]

    var body: some View {
        ZStack {
            PaperTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if mode == .form {
                    formBody
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            agentGreeting
                            if conversationExpanded && !workspace.conversation.isEmpty {
                                DisclosureGroup(String(localized: "ui.agent.conversation"), isExpanded: $conversationExpanded) {
                                    ForEach(workspace.conversation) { entry in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(String(localized: entry.isUser ? "ui.agent.you" : "wallet.mascot.name")).font(.caption).foregroundStyle(PaperTheme.muted)
                                            Text(entry.text).font(.subheadline).textSelection(.enabled)
                                        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).walletSurface(radius: 16)
                                    }
                                }
                            }
                            AgentTaskPanel(workspace: workspace, embedded: true, part: .content) {
                                workspace.composerIntent = .budget
                                workspace.beginTask(.budget, mode: "form")
                                mode = .form
                            }
                        }.padding(.horizontal, 22).padding(.top, 8)
                    }.scrollDismissesKeyboard(.interactively).clipped()
                }
            }

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if workspace.taskDraft.committedEntityID != nil {
                PaperSubmitBar(title: String(localized: "ui.task.finishAttachments"), enabled: !workspace.draftStorageFailed, action: finishCommittedTask)
                    .accessibilityIdentifier("wallet.task.resume").padding(.top, 12).background(PaperTheme.canvas)
            } else if mode == .form {
                PaperSubmitBar(
                    title: workspace.composerIntent == .budget ? String(localized: "v1.budget.create") : String(localized: "wallet.record.save"),
                    enabled: canSubmit,
                    action: submitForm
                ).accessibilityIdentifier("wallet.composer.save").padding(.top, 12).background(PaperTheme.canvas)
            } else {
                AgentTaskPanel(workspace: workspace, embedded: true, part: .footer)
                    .padding(.horizontal, 22).padding(.bottom, 8).background(PaperTheme.canvas)
            }
        }
        .frame(maxWidth: .infinity)
        .presentationBackground(PaperTheme.canvas)
        .tint(PaperTheme.accent)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if formFocused {
                    Spacer()
                    Button(String(localized: "ui.keyboard.done")) { formFocused = false }
                        .accessibilityIdentifier("wallet.keyboard.done")
                }
            }
        }
        .presentationDetents([.height(360), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PaperTheme.Radius.sheet)
        .onAppear {
            if workspace.showAgent {
                workspace.resumeAgentTask()
            }
            extrasExpanded = !note.isEmpty || !workspace.draftText.isEmpty || !workspace.taskDraft.attachments.isEmpty
            detent = mode == .form || typeSize.isAccessibilitySize ? .large : .height(360)
        }
        .onChange(of: workspace.panelExpanded) { _, expanded in if expanded { detent = .large } }
        .onChange(of: workspace.showsStructuredConfirm) { _, confirming in if confirming { detent = .large } }
        .onChange(of: typeSize) { _, size in if size.isAccessibilitySize { detent = .large } }
        .confirmationDialog(String(localized: "ui.draft.discard"), isPresented: $discardRequested, titleVisibility: .visible) {
            Button(String(localized: "ui.draft.discard"), role: .destructive) { workspace.discardTask() }
        }
        .onChange(of: workspace.showComposer) { _, presented in
            if presented == false && !workspace.showAgent { dismiss() }
        }
        .onChange(of: mode) { _, mode in
            if mode == .form { workspace.banner = nil; detent = .large }
        }
        .onChange(of: pickerItems) { _, items in Task { await importImages(items) } }
        .confirmationDialog(
            String(localized: "v1.composer.choose.currency"),
            isPresented: $showingCurrencyPicker,
            titleVisibility: .visible
        ) {
            ForEach(currencies, id: \.self) { code in
                Button(code) { currency = code }
            }
        }
        .confirmationDialog(
            String(localized: "v1.composer.choose.card"),
            isPresented: $showingCardPicker,
            titleVisibility: .visible
        ) {
            ForEach(workspace.attributionChoices) { choice in
                Button(choiceTitle(choice)) { attributionID = choice.id; workspace.taskDraft.explicitAttribution = true }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                DatePicker(
                    String(localized: "v1.composer.date"),
                    selection: field(\.occurredAt),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle(String(localized: "v1.composer.choose.date"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "action.close")) { showingDatePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationBackground(PaperTheme.canvas)
        }
    }

    private func field<Value>(_ path: WritableKeyPath<TaskDraft, Value>) -> Binding<Value> {
        Binding(get: { workspace.taskDraft[keyPath: path] }, set: {
            workspace.taskDraft[keyPath: path] = $0
            workspace.taskDraft.fieldsTouched = true
        })
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: { CheckLineIcon(symbol: "xmark", size: 17).frame(width: 44, height: 44) }
                    .accessibilityLabel(String(localized: "action.close"))
                    .accessibilityIdentifier(mode == .agent ? "wallet.agent.close" : "wallet.composer.close")
                Spacer()
                if mode == .form {
                    Text(String(localized: workspace.composerIntent == .budget ? "v1.budget.create" : "capture.title")).font(.headline)
                    Spacer()
                }
                if mode == .agent { modeToggle }
                Menu {
                    if mode == .agent && !workspace.conversation.isEmpty {
                        Button(String(localized: "ui.agent.conversation"), iconSymbol: "bubble.left.and.bubble.right") {
                            conversationExpanded.toggle(); detent = .large
                        }
                    }
                    Button(String(localized: "ui.draft.discard"), role: .destructive) { discardRequested = true }
                } label: { CheckLineIcon(symbol: "ellipsis", size: 17).frame(width: 44, height: 44) }
                .accessibilityLabel(String(localized: "ui.task.options"))
            }
            if mode == .form { modeToggle }
            if workspace.draftStorageFailed {
                Text(String(localized: "ui.draft.failed")).font(.caption).foregroundStyle(.red)
                if !workspace.draftLoadFailed {
                    Button(String(localized: "ui.draft.retry")) { workspace.retryTaskStorage() }.frame(minHeight: 44)
                }
            }
        }.padding(.horizontal, 16).padding(.top, 12)
    }

    private var agentGreeting: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            CloudMascotView(state: workspace.mascotState).frame(width: 82, height: 80).accessibilityHidden(true)
            Text(agentPrompt).font(.subheadline).foregroundStyle(PaperTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(PaperTheme.card, in: RoundedRectangle(cornerRadius: 22))
                .accessibilityIdentifier("wallet.agent.prompt")
        }
    }

    private var agentPrompt: String {
        if workspace.isWorking { return String(localized: "ui.agent.working") }
        if let banner = workspace.agentBanner { return banner.localizedText }
        if workspace.composerIntent == .budget || workspace.isEmpty { return String(localized: "ui.agent.createPrompt") }
        if let card = workspace.cards.first(where: { $0.id == workspace.taskDraft.contextBudgetID }) {
            let remaining = BudgetPresentation.remaining(card)
            if remaining < 0 { return String(localized: card.snapshot.certainOverrunAmount > 0 ? "v1.card.status.certain" : "v1.card.status.possible") }
            let value = MoneyFormat.string(remaining, currencyCode: card.currencyCode)
            if workspace.selectedCard?.id != card.id || chrome?.selectedTab == .wishes || chrome?.selectedTab == .insights {
                return String(format: String(localized: "ui.agent.cardRemaining"), card.name, value)
            }
            return String(format: String(localized: "ui.agent.remainingPrompt"), value)
        }
        return String(localized: "ui.agent.recordPrompt")
    }

    private var modeToggle: some View {
        Button { switchMode() } label: {
            if typeSize.isAccessibilitySize {
                CheckLineIcon(symbol: mode == .form ? "sparkles" : "square.and.pencil", size: 20).frame(width: 44, height: 44)
            } else {
                CheckLineIconLabel(String(localized: mode == .form ? "ui.agent.helpFill" : "ui.task.manual"), symbol: mode == .form ? "sparkles" : "square.and.pencil")
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
        }.accessibilityIdentifier("wallet.task.switchMode")
            .accessibilityLabel(String(localized: mode == .form ? "ui.agent.helpFill" : "ui.task.manual"))
    }

    private var formBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                if workspace.composerIntent == .budget {
                    PaperHeroField(
                        placeholder: String(localized: "v1.composer.name.placeholder"),
                        text: field(\.name)
                    ).focused($formFocused)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Text(String(localized: "v1.budget.amount")).foregroundStyle(PaperTheme.muted)
                            TextField("0", text: field(\.amount))
                                .focused($formFocused)
                                .accessibilityLabel(String(localized: "v1.budget.amount"))
                                .keyboardType(AmountKeyboard.type).multilineTextAlignment(.trailing)
                                .font(.title2.weight(.medium))
                            currencyButton
                        }
                    }.padding(18).walletSurface()
                    VStack(alignment: .leading, spacing: 14) {
                        PaperCapsuleSegment(
                            items: [(true, String(localized: "wallet.cycle.monthly")), (false, String(localized: "v1.cycle.oneShot"))],
                            selection: field(\.repeating)
                        )
                    let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
                        Text(String(format: String(localized: repeating ? "ui.create.monthDates" : "ui.create.onceDates"), start.formatted(date: .abbreviated, time: .omitted)))
                            .font(.caption).foregroundStyle(PaperTheme.muted).fixedSize(horizontal: false, vertical: true)
                    }.padding(18).walletSurface()
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        currencyButton
                        PaperHeroField(
                            placeholder: String(localized: "v1.composer.amount.placeholder"),
                            text: field(\.amount), keyboard: AmountKeyboard.type
                        ).focused($formFocused)
                    }.padding(.vertical, 16)
                    VStack(spacing: 16) {
                        VStack(spacing: 0) {
                            merchantRow
                            selectionRow("v1.agent.attribution", value: currentAttributionTitle) { showingCardPicker = true }
                            selectionRow("v1.composer.date", value: occurredAt.formatted(date: .abbreviated, time: .omitted)) { showingDatePicker = true }
                        }.padding(4).walletSurface()
                        DisclosureGroup(isExpanded: $extrasExpanded) {
                            noteCard
                            PaperField(title: String(localized: "ui.record.rawText"), text: field(\.text), axis: .vertical).focused($formFocused)
                            attachmentInput
                        } label: {
                            CheckLineIconLabel(note.isEmpty && workspace.draftText.isEmpty && workspace.taskDraft.attachments.isEmpty ? String(localized: "ui.record.extras") : String(format: String(localized: "ui.record.extrasCount"), note.count + workspace.draftText.count, workspace.taskDraft.attachments.count), symbol: "text.badge.plus")
                        }.padding(16).walletSurface()
                        if hasCurrencyMismatch {
                            Text(String(localized: "ui.currency.unconverted")).font(.caption).foregroundStyle(PaperTheme.muted)
                        }

                    }
                }

                if let banner = workspace.banner {
                    Text(banner.localizedText)
                        .font(PaperTheme.Typography.meta)
                        .foregroundStyle(PaperTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let attachmentError { Text(attachmentError).font(.caption).foregroundStyle(.red) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 650).frame(maxWidth: .infinity)
        .scrollDismissesKeyboard(.interactively)
        .clipped()
        .disabled(workspace.taskDraft.committedEntityID != nil)
    }

    private var currencyButton: some View {
        Button { showingCurrencyPicker = true } label: {
            HStack(spacing: 4) { Text(currency); CheckLineIcon(symbol: "chevron.down", size: 14) }
                .font(.subheadline.weight(.medium)).frame(minHeight: 44)
        }.accessibilityLabel(String(localized: "v1.budget.currency"))
            .accessibilityValue(currency)
    }

    private func selectionRow(_ key: String.LocalizationValue, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Text(String(localized: key)).foregroundStyle(PaperTheme.muted)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                HStack {
                    Text(value).multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                    CheckLineIcon(symbol: "chevron.down", size: 14).foregroundStyle(PaperTheme.muted)
                }
            }.font(.body).padding(16).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 52).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var merchantRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "v1.composer.merchant"))
                .font(.body)
                .foregroundStyle(PaperTheme.muted)
            TextField("", text: field(\.merchant), prompt: Text(String(localized: "v1.composer.merchant.placeholder")).foregroundStyle(PaperTheme.muted))
                .focused($formFocused)
                .accessibilityLabel(String(localized: "v1.composer.merchant"))
                .font(.body)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(PaperTheme.ink)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: field(\.note))
                    .focused($formFocused)
                    .font(.subheadline)
                    .foregroundStyle(PaperTheme.ink)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel(String(localized: "v1.composer.note.placeholder"))
                    .frame(height: 120)
                if note.isEmpty {
                    Text(String(localized: "v1.composer.note.placeholder"))
                        .font(.subheadline)
                        .foregroundStyle(PaperTheme.muted)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            HStack {
                Spacer()
                Text("\(note.count)/10000")
                    .font(.caption2)
                    .foregroundStyle(note.count > 10_000 ? .red : PaperTheme.muted)
            }
            if note.count > 10_000 {
                Text(String(localized: "wallet.expense.noteTooLong"))
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .padding(12)
        .walletSurface()
    }

    private var attachmentInput: some View {
        let totalCount = workspace.taskDraft.attachments.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "wallet.expense.attachments"))
                Spacer()
                Text("\(totalCount)/\(ExpenseAttachmentStore.maximumPerExpense)").foregroundStyle(PaperTheme.muted)
            }.font(.subheadline)
            ForEach(workspace.taskDraft.attachments) { attachment in
                HStack(spacing: 12) {
                    if let image = UIImage(data: attachment.data) {
                        Image(uiImage: image).resizable().scaledToFit().frame(width: 64, height: 64).accessibilityHidden(true)
                    }
                    Text(String(localized: "wallet.expense.attachments")).font(.caption)
                    Spacer()
                    Button(role: .destructive) { workspace.taskDraft.attachments.removeAll { $0.id == attachment.id } } label: {
                        CheckLineIcon(symbol: "trash").frame(width: 44, height: 44)
                    }.accessibilityLabel(String(localized: "wallet.expense.deleteAttachment"))
                }
            }
            if totalCount < ExpenseAttachmentStore.maximumPerExpense {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: ExpenseAttachmentStore.maximumPerExpense - totalCount, matching: .images) {
                    CheckLineIconLabel(String(localized: "wallet.expense.addAttachment"), symbol: "photo.badge.plus")
                }
                Button {
                    if let data = UIPasteboard.general.image?.pngData() { addAttachmentData(data) }
                    else { attachmentError = String(localized: "wallet.expense.noClipboardImage") }
                } label: { CheckLineIconLabel(String(localized: "wallet.expense.pasteImage"), symbol: "doc.on.clipboard") }
            }
        }
        .padding(16)
        .walletSurface()
    }

    private func addAttachmentData(_ data: Data) {
        do { try workspace.addTaskAttachment(data); attachmentError = nil }
        catch { attachmentError = String(localized: "wallet.expense.retrySave") }
    }

    private func importImages(_ items: [PhotosPickerItem]) async {
        isImportingImages = true
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw ExpenseAttachmentError.unreadableImage }
                addAttachmentData(data)
            } catch { attachmentError = String(localized: "wallet.expense.retrySave") }
        }
        pickerItems = []
        isImportingImages = false
    }

    private var canSubmit: Bool {
        guard !workspace.draftStorageFailed && !workspace.draftLoadFailed else { return false }
        return switch workspace.composerIntent {
        case .budget:
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && MoneyFormat.parseAmount(amount) != nil
        case .record:
            MoneyFormat.parseAmount(amount) != nil && note.count <= 10_000 && !isImportingImages
                && workspace.attributionChoices.contains { $0.id == attributionID }
        }
    }

    private var currentAttributionTitle: String {
        if let choice = workspace.attributionChoices.first(where: { $0.id == attributionID }) {
            return choiceTitle(choice)
        }
        return String(localized: "ui.task.invalidAttribution")
    }

    private var hasCurrencyMismatch: Bool {
        guard let periodID = workspace.attributionChoices.first(where: { $0.id == attributionID })?.periodID,
              let period = workspace.ledger.periods[periodID] else { return false }
        return period.currencyCode != currency
    }

    private func choiceTitle(_ choice: AttributionChoice) -> String {
        choice.periodID == nil ? String(localized: "v1.unbudgeted") : choice.title
    }

    private func switchMode() {
        formFocused = false
        if mode == .form {
            workspace.taskDraft.formTouched = true
            if workspace.composerIntent == .record { workspace.taskDraft.explicitAttribution = true }
            if workspace.draftText.isEmpty {
                workspace.draftText = workspace.composerIntent == .budget
                    ? String(format: String(localized: "v1.agent.budgetBridge"), name, amount, currency, String(localized: repeating ? "wallet.cycle.monthly" : "v1.cycle.oneShot"))
                    : [merchant, amount].filter { !$0.isEmpty }.joined(separator: " ")
            }
            mode = .agent
        } else {
            if let proposal = workspace.captureProposal {
                amount = workspace.confirmAmountText
                currency = workspace.confirmCurrencyCode
                merchant = proposal.merchant ?? merchant
                note = proposal.note ?? note
                attributionID = workspace.selectedAttributionID
                workspace.taskDraft.explicitAttribution = true
            } else if workspace.budgetProposal == nil && workspace.taskDraft.committedEntityID == nil {
                let request = [workspace.pendingBudgetText, workspace.draftText].compactMap { $0 }.joined(separator: " ")
                workspace.taskDraft.apply(LocalRegexFallback.candidate(from: request))
            }
            mode = .form
            extrasExpanded = !note.isEmpty || !workspace.draftText.isEmpty || !workspace.taskDraft.attachments.isEmpty
        }
        withAnimation(reduceMotion ? nil : PaperTheme.Motion.panel) { detent = .large }
    }

    private func submitForm() {
        switch workspace.composerIntent {
        case .budget:
            workspace.createBudget(name: name, amountText: amount, currencyCode: currency,
                                   cycleType: repeating ? .repeating : .oneShot,
                                   budgetID: workspace.taskDraft.entityID, periodID: workspace.taskDraft.newPeriodID)
        case .record:
            let id = workspace.taskDraft.committedEntityID ?? workspace.recordExpense(
                amountText: amount, merchant: merchant, note: note,
                attributionID: attributionID, occurredAt: occurredAt, keepComposerOpen: true,
                currencyCode: currency, expenseID: workspace.taskDraft.entityID)
            guard let id else { return }
            finishCommittedTask(id)
        }
    }

    private func finishCommittedTask() {
        guard let id = workspace.taskDraft.committedEntityID else { return }
        finishCommittedTask(id)
    }

    private func finishCommittedTask(_ id: UUID) {
        do {
            try workspace.completeTaskAttachments(id)
            workspace.banner = .recorded
            workspace.showComposer = false; workspace.showAgent = false
            dismiss(); PaperHaptics.light()
        } catch {
            attachmentError = String(localized: "wallet.expense.retrySave")
            workspace.banner = .failed
        }
    }
}
