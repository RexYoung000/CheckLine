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
    @State private var voiceCapture = VoiceCaptureController()
    @Environment(\.scenePhase) private var scenePhase
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
    private var monthlySchedule: MonthlySchedule {
        get { workspace.taskDraft.monthlySchedule ?? MonthlySchedule() }
        nonmutating set { workspace.taskDraft.monthlySchedule = newValue; workspace.taskDraft.fieldsTouched = true }
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
    @State private var discardRequested = false
    @State private var detent: PresentationDetent = .large
    private enum FormField: Hashable { case name, amount, merchant, note, source }
    @FocusState private var focusedFormField: FormField?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.shellChrome) private var chrome
    @State private var attachmentImport = TaskAttachmentImportController()
    @State private var imageSelection: AttachmentImageSelection?
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
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if workspace.conversation.isEmpty && !workspace.retainedTaskAvailable {
                                    agentGreeting
                                }
                                ForEach(workspace.conversation) { entry in
                                    conversationBubble(entry)
                                }
                                if workspace.retainedTaskAvailable && workspace.taskDraft.committedEntityID == nil {
                                    retainedTaskSummary
                                }
                                if workspace.isWorking {
                                    HStack(spacing: 12) {
                                        CloudMascotView(state: .thinking).frame(width: 42, height: 42).accessibilityHidden(true)
                                        Text(String(localized: "ui.agent.working")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                                    }.accessibilityIdentifier("wallet.agent.working")
                                }
                                if attachmentImport.blocksSubmission {
                                    VStack(alignment: .leading, spacing: 10) {
                                        if attachmentImport.isReading {
                                            ProgressView(String(format: String(localized: "ui.attachment.reading"), attachmentImport.addedCount, attachmentImport.items.count))
                                        } else {
                                            Text(String(format: String(localized: "ui.attachment.readFailed"), attachmentImport.failedCount))
                                            Button(String(localized: "ui.attachment.retry")) { attachmentImport.retry(workspace: workspace) }
                                            Button(String(localized: "ui.attachment.removeFailed")) { attachmentImport.removeFailures(workspace: workspace) }
                                        }
                                    }.font(.subheadline).foregroundStyle(PaperTheme.muted).padding(16).walletSurface()
                                }
                                AgentTaskPanel(workspace: workspace, voiceCapture: voiceCapture, embedded: true, part: .content) {
                                    workspace.composerIntent = .budget
                                    workspace.beginTask(.budget, mode: "form")
                                    mode = .form
                                }
                                Color.clear.frame(height: 1).id("agent.latest")
                            }.padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 12)
                        }
                        .scrollDismissesKeyboard(.interactively).clipped()
                        .onChange(of: workspace.conversation.count) { _, _ in
                            withAnimation(reduceMotion ? nil : PaperTheme.Motion.panel) {
                                proxy.scrollTo("agent.latest", anchor: .bottom)
                            }
                        }
                    }
                }
            }

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if workspace.taskDraft.committedEntityID != nil {
                VStack(spacing: 8) {
                Text(String(localized: workspace.taskDraft.kind == "budget" ? "ui.task.savedBudget" : workspace.taskDraft.attachments.isEmpty ? "ui.task.savedRecord" : "ui.task.savedAttachmentsPending")).font(.caption).foregroundStyle(PaperTheme.muted)
                    .padding(.horizontal, 22).background(PaperTheme.canvas)
                PaperSubmitBar(title: String(localized: workspace.taskDraft.attachments.isEmpty ? "ui.task.finishSaved" : "ui.task.finishAttachments"), enabled: !workspace.draftStorageFailed, action: finishCommittedTask)
                    .accessibilityIdentifier("wallet.task.resume").padding(.top, 12).background(PaperTheme.canvas)
                }.background(PaperTheme.canvas)
            } else if mode == .form {
                VStack(spacing: 8) {
                if let hint = budgetValidationHint {
                    Text(hint).font(.caption).foregroundStyle(PaperTheme.muted)
                        .accessibilityIdentifier("wallet.composer.validation")
                        .padding(.horizontal, 22)
                }
                PaperSubmitBar(
                    title: workspace.composerIntent == .budget ? String(localized: "v1.budget.create") : String(localized: "wallet.record.save"),
                    enabled: canSubmit,
                    action: submitForm
                ).accessibilityIdentifier("wallet.composer.save").padding(.top, 12).background(PaperTheme.canvas)
                }.background(PaperTheme.canvas)
            } else {
                AgentTaskPanel(workspace: workspace, voiceCapture: voiceCapture, embedded: true, part: .footer)
                    .padding(.horizontal, 22).padding(.bottom, 8).background(PaperTheme.canvas)
            }
        }
        .frame(maxWidth: .infinity)
        .presentationBackground(PaperTheme.canvas)
        .tint(PaperTheme.focus)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedFormField != nil {
                    Spacer()
                    Button(String(localized: "ui.keyboard.done")) { focusedFormField = nil }
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
            extrasExpanded = !note.isEmpty || !workspace.taskDraft.attachments.isEmpty
            detent = mode == .form || typeSize.isAccessibilitySize || !workspace.conversation.isEmpty || workspace.showsStructuredConfirm || workspace.retainedTaskAvailable ? .large : .height(360)
        }
        .onChange(of: workspace.panelExpanded) { _, expanded in if expanded { detent = .large } }
        .onChange(of: workspace.showsStructuredConfirm) { _, confirming in if confirming { detent = .large } }
        .onChange(of: typeSize) { _, size in if size.isAccessibilitySize { detent = .large } }
        .alert(String(localized: "ui.draft.discard.title"), isPresented: $discardRequested) {
            Button(String(localized: "ui.draft.keep"), role: .cancel) { }
            Button(String(localized: "ui.draft.discard.action"), role: .destructive) {
                voiceCapture.stopForInterruption()
                workspace.discardTask()
            }
        }
        .onChange(of: workspace.showComposer) { _, presented in
            if presented == false && !workspace.showAgent { dismiss() }
        }
        .onDisappear { workspace.cancelCloudRequest(); voiceCapture.stopForInterruption(); attachmentImport.cancel(workspace: workspace) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { workspace.cancelCloudRequest(); voiceCapture.stopForInterruption(); attachmentImport.cancel(workspace: workspace) }
        }
        .onChange(of: workspace.taskDraft.entityID) { _, _ in
            voiceCapture.stopForInterruption(); attachmentImport.cancel(workspace: workspace)
        }
        .onChange(of: mode) { _, mode in
            voiceCapture.stopForInterruption()
            if mode == .form { workspace.banner = nil; detent = .large }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            attachmentImport.start(items.map { item in
                TaskAttachmentImportItem(id: UUID()) {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw ExpenseAttachmentError.unreadableImage }
                    return data
                }
            }, workspace: workspace)
            pickerItems = []
        }
        .fullScreenCover(item: $imageSelection) { AttachmentImagePreview(selection: $0) }
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
                Button {
                    workspace.closeTaskPanel()
                    dismiss()
                } label: { CheckLineIcon(symbol: "xmark", size: 17).frame(width: 44, height: 44) }
                    .accessibilityLabel(String(localized: "action.close"))
                    .accessibilityIdentifier(mode == .agent ? "wallet.agent.close" : "wallet.composer.close")
                Spacer()
                if mode == .form {
                    Text(String(localized: workspace.composerIntent == .budget ? "v1.budget.create" : "capture.title")).font(.headline)
                    Spacer()
                }
                if mode == .agent { modeToggle }
                Menu {
                    Button(String(localized: "ui.draft.discard"), role: .destructive) { discardRequested = true }
                } label: { CheckLineIcon(symbol: "ellipsis", size: 17).frame(width: 44, height: 44) }
                .accessibilityLabel(String(localized: "ui.task.options"))
                .accessibilityIdentifier("wallet.task.options")
            }
            if mode == .form {
                modeToggle.frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 6)
            }
            if workspace.draftStorageFailed {
                Text(String(localized: "ui.draft.failed")).font(.caption).foregroundStyle(.red)
                Button(String(localized: "ui.draft.retry")) { workspace.retryTaskStorage() }.frame(minHeight: 44)
            }
        }.padding(.horizontal, 16).padding(.top, 12)
    }

    private func conversationBubble(_ entry: AgentConversationEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if entry.isUser { Spacer(minLength: 32) }
            if !entry.isUser {
                CloudMascotView(state: entry.id == workspace.conversation.last?.id ? workspace.mascotState : .idle)
                    .frame(width: 36, height: 36).accessibilityHidden(true)
            }
            Text(entry.text)
                .font(.body).foregroundStyle(PaperTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(14)
                .background(entry.isUser ? PaperTheme.accent.opacity(0.12) : PaperTheme.card,
                            in: RoundedRectangle(cornerRadius: 20))
                .accessibilityLabel(String(localized: entry.isUser ? "ui.agent.you" : "wallet.mascot.name") + "，" + entry.text)
            if !entry.isUser { Spacer(minLength: 12) }
        }.id(entry.id)
    }

    private var cyclePicker: some View {
        Picker(String(localized: "v1.budget.cycle"), selection: field(\.repeating)) {
            Text(String(localized: "wallet.cycle.monthly")).tag(true)
            Text(String(localized: "v1.cycle.oneShot")).tag(false)
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("wallet.composer.cycle")
    }

    private func scheduleField<Value>(_ keyPath: WritableKeyPath<MonthlySchedule, Value>) -> Binding<Value> {
        Binding(get: { monthlySchedule[keyPath: keyPath] }, set: { value in
            var schedule = monthlySchedule
            schedule[keyPath: keyPath] = value
            monthlySchedule = schedule
        })
    }

    private var monthlySettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            let kind = Picker(String(localized: "ui.schedule.kind"), selection: scheduleField(\.kind)) {
                Text(String(localized: "ui.schedule.cycle")).tag(MonthlySchedule.Kind.cycle)
                Text(String(localized: "ui.schedule.window")).tag(MonthlySchedule.Kind.window)
            }.accessibilityIdentifier("wallet.composer.monthlyKind")
            if typeSize.isAccessibilitySize { kind.pickerStyle(.menu) }
            else { kind.pickerStyle(.segmented) }
            monthlyDayPicker("ui.schedule.start", selection: scheduleField(\.startDay), id: "wallet.composer.monthlyStart")
            if monthlySchedule.kind == .window {
                monthlyDayPicker(monthlySchedule.endDay < monthlySchedule.startDay ? "ui.schedule.nextEnd" : "ui.schedule.end",
                                 selection: scheduleField(\.endDay), id: "wallet.composer.monthlyEnd")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(BudgetPresentation.monthlyRule(monthlySchedule)).font(.subheadline)
                if let plan = workspace.monthlyBudgetPlan(for: monthlySchedule) {
                    Text(BudgetPresentation.periodDates(start: plan.startDate, end: plan.endDate))
                        .font(.caption).foregroundStyle(PaperTheme.muted)
                        .accessibilityIdentifier("wallet.composer.periodDates")
                    if plan.startDate > Date() {
                        Text(String(localized: "ui.schedule.notStarted")).font(.caption).foregroundStyle(PaperTheme.muted)
                    }
                }
                if monthlySchedule.kind == .window {
                    Text(String(localized: "ui.schedule.gapHint")).font(.caption).foregroundStyle(PaperTheme.muted)
                }
                if monthlySchedule.startDay > 28 || (monthlySchedule.kind == .window && monthlySchedule.endDay > 28) {
                    Text(String(localized: "ui.schedule.shortMonth")).font(.caption).foregroundStyle(PaperTheme.muted)
                }
            }.fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(PaperTheme.ink)
    }

    private func monthlyDayPicker(_ title: String.LocalizationValue, selection: Binding<Int>, id: String) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(String(localized: title)).foregroundStyle(PaperTheme.muted)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Picker(String(localized: title), selection: selection) {
                ForEach(1...31, id: \.self) { day in
                    Text(String(format: String(localized: "ui.schedule.day"), day)).tag(day)
                }
            }.pickerStyle(.menu).labelsHidden().frame(minHeight: 44)
                .accessibilityIdentifier(id)
                .accessibilityLabel(String(localized: title))
                .accessibilityValue(String(format: String(localized: "ui.schedule.day"), selection.wrappedValue))
        }.font(.body)
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

    private var retainedTaskSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "ui.task.retained.title")).font(.headline)
            Text([workspace.taskDraft.kind == "budget" ? name : merchant, amount.isEmpty ? nil : amount + " " + currency]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            if workspace.taskDraft.kind == "record" {
                Text(currentAttributionTitle).font(.caption).foregroundStyle(PaperTheme.muted)
            }
            if let message = workspace.agentBanner {
                Text(message.localizedText).font(.subheadline).foregroundStyle(PaperTheme.muted)
            }
            Button(String(localized: "ui.task.retained.continue")) { workspace.reviewRetainedTask() }
                .buttonStyle(PaperSolidButtonStyle(enabled: !workspace.attachmentImportBlocksSubmission))
                .disabled(workspace.attachmentImportBlocksSubmission)
                .accessibilityIdentifier("wallet.task.continue")
        }.padding(18).walletSurface().accessibilityElement(children: .contain).accessibilityIdentifier("wallet.task.retained")
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "v1.budget.name")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        TextField("", text: field(\.name), prompt: Text(String(localized: "v1.composer.name.placeholder")))
                            .font(.title3).frame(minHeight: 44).focused($focusedFormField, equals: .name)
                            .accessibilityLabel(String(localized: "v1.composer.name.placeholder"))
                            .accessibilityIdentifier("wallet.composer.name")
                    }
                    .padding(18)
                    .walletSurface()
                    .paperFocusRing(focusedFormField == .name)
                    VStack(alignment: .leading, spacing: 16) {
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                        layout {
                            Text(String(localized: "v1.budget.amount")).foregroundStyle(PaperTheme.muted)
                            HStack(spacing: 12) {
                                TextField("0", text: field(\.amount))
                                    .focused($focusedFormField, equals: .amount)
                                    .accessibilityIdentifier("wallet.composer.amount")
                                    .accessibilityLabel(String(localized: "v1.budget.amount"))
                                    .keyboardType(AmountKeyboard.type).multilineTextAlignment(.trailing)
                                    .font(.title2.weight(.medium)).frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                currencyButton
                            }
                        }
                    }
                    .padding(18)
                    .walletSurface()
                    .paperFocusRing(focusedFormField == .amount)
                    VStack(alignment: .leading, spacing: 14) {
                        if typeSize.isAccessibilitySize {
                            cyclePicker.pickerStyle(.menu)
                        } else {
                            cyclePicker.pickerStyle(.segmented).controlSize(.large)
                        }
                        if repeating { monthlySettings }
                        else {
                            let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
                            Text(String(format: String(localized: "ui.create.onceDates"), start.formatted(date: .abbreviated, time: .omitted)))
                                .font(.caption).foregroundStyle(PaperTheme.muted).fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(18).walletSurface()
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        currencyButton
                        PaperHeroField(
                            placeholder: String(localized: "v1.composer.amount.placeholder"),
                            text: field(\.amount), keyboard: AmountKeyboard.type,
                            isFocused: focusedFormField == .amount
                        ).focused($focusedFormField, equals: .amount)
                            .accessibilityIdentifier("wallet.composer.amount")
                    }.padding(.vertical, 16)
                    VStack(spacing: 16) {
                        VStack(spacing: 0) {
                            merchantRow
                            selectionRow("v1.agent.attribution", value: currentAttributionTitle) { showingCardPicker = true }
                            selectionRow("v1.composer.date", value: occurredAt.formatted(date: .abbreviated, time: .omitted)) { showingDatePicker = true }
                        }
                        .padding(4)
                        .walletSurface()
                        DisclosureGroup(isExpanded: $extrasExpanded) {
                            noteCard
                            PaperField(
                                title: String(localized: "ui.record.rawText"),
                                text: Binding(get: { workspace.taskSourceText }, set: { workspace.taskSourceText = $0 }),
                                axis: .vertical,
                                isFocused: focusedFormField == .source
                            ).focused($focusedFormField, equals: .source)
                            attachmentInput
                        } label: {
                            CheckLineIconLabel(note.isEmpty && workspace.taskSourceText.isEmpty && workspace.taskDraft.attachments.isEmpty ? String(localized: "ui.record.extras") : String(format: String(localized: "ui.record.extrasCount"), note.count + workspace.taskSourceText.count, workspace.taskDraft.attachments.count), symbol: "text.badge.plus")
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
        CurrencyMenuButton(currency: field(\.currency), preferred: workspace.ledger.walletSettings.walletCurrencyCode)
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
                .focused($focusedFormField, equals: .merchant)
                .accessibilityLabel(String(localized: "v1.composer.merchant"))
                .font(.body)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(PaperTheme.ink)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .paperFocusRing(focusedFormField == .merchant, radius: 16)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: field(\.note))
                    .focused($focusedFormField, equals: .note)
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
        .paperFocusRing(focusedFormField == .note)
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
                        Button { imageSelection = AttachmentImageSelection(id: attachment.id, image: image) } label: {
                            Image(uiImage: image).resizable().scaledToFit().frame(width: 64, height: 64)
                        }.buttonStyle(.plain).accessibilityLabel(String(localized: "ui.attachment.view"))
                    }
                    Text(String(localized: "wallet.expense.attachments")).font(.caption)
                    Spacer()
                    Button(role: .destructive) { workspace.taskDraft.attachments.removeAll { $0.id == attachment.id } } label: {
                        CheckLineIcon(symbol: "trash").frame(width: 44, height: 44)
                    }.accessibilityLabel(String(localized: "wallet.expense.deleteAttachment"))
                }
            }
            if attachmentImport.isReading {
                ProgressView(String(format: String(localized: "ui.attachment.reading"), attachmentImport.addedCount, attachmentImport.items.count))
                    .font(.caption).accessibilityIdentifier("wallet.attachment.reading")
            }
            if attachmentImport.failedCount > 0 {
                Text(String(format: String(localized: "ui.attachment.readFailed"), attachmentImport.failedCount))
                    .font(.caption).foregroundStyle(PaperTheme.accent)
                HStack {
                    Button(String(localized: "ui.attachment.retry")) { attachmentImport.retry(workspace: workspace) }
                    Button(String(localized: "ui.attachment.removeFailed")) { attachmentImport.removeFailures(workspace: workspace) }
                }.font(.subheadline).disabled(attachmentImport.isReading).frame(minHeight: 44)
            }
            if totalCount < ExpenseAttachmentStore.maximumPerExpense && !attachmentImport.blocksSubmission {
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

    private var budgetValidationHint: String? {
        guard workspace.composerIntent == .budget, !workspace.draftStorageFailed, !workspace.draftLoadFailed,
              !workspace.attachmentImportBlocksSubmission else { return nil }
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAmountText = !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasName && hasAmountText { return String(localized: "ui.create.nameRequired") }
        if (hasName || hasAmountText) && MoneyFormat.parseAmount(amount) == nil { return String(localized: "ui.create.amountRequired") }
        if repeating && workspace.monthlyBudgetPlan(for: monthlySchedule) == nil { return String(localized: "ui.schedule.invalid") }
        return nil
    }

    private var canSubmit: Bool {
        guard !workspace.draftStorageFailed && !workspace.draftLoadFailed && !workspace.attachmentImportBlocksSubmission else { return false }
        return switch workspace.composerIntent {
        case .budget:
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && MoneyFormat.parseAmount(amount) != nil
                && (!repeating || workspace.monthlyBudgetPlan(for: monthlySchedule) != nil)
        case .record:
            MoneyFormat.parseAmount(amount) != nil && note.count <= 10_000
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
        focusedFormField = nil
        if mode == .form {
            workspace.taskDraft.formTouched = true
            if workspace.composerIntent == .budget {
                // The user's fields are the source of truth; a generated sentence must not re-parse them.
                workspace.reviewRetainedTask()
            } else {
                workspace.taskDraft.explicitAttribution = true
                if workspace.showsStructuredConfirm {
                    workspace.leaveTaskReview()
                    workspace.reviewRetainedTask()
                }
                if workspace.draftText.isEmpty { workspace.draftText = [merchant, amount].filter { !$0.isEmpty }.joined(separator: " ") }
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
                workspace.absorbUnsentAgentInputForManual()
            }
            mode = .form
            extrasExpanded = !note.isEmpty || !workspace.taskDraft.attachments.isEmpty
        }
        withAnimation(reduceMotion ? nil : PaperTheme.Motion.panel) { detent = .large }
    }

    private func submitForm() {
        switch workspace.composerIntent {
        case .budget:
            workspace.createBudget(name: name, amountText: amount, currencyCode: currency,
                                   cycleType: repeating ? .repeating : .oneShot,
                                   monthlySchedule: repeating ? monthlySchedule : nil,
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
            let wasBudget = workspace.taskDraft.kind == "budget"
            try workspace.completeTaskAttachments(id)
            workspace.banner = wasBudget ? .createdBudget : .recorded
            workspace.showComposer = false; workspace.showAgent = false
            dismiss(); PaperHaptics.light()
        } catch {
            attachmentError = String(localized: "wallet.expense.retrySave")
            workspace.banner = .failed
        }
    }
}
