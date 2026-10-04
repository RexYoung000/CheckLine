import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CheckLineWorkspace {
    var conversation: [AgentConversationEntry] = []
    var remainingAmountChange: BudgetRemainingChange?
    var ledger: Ledger
    let storageLoadFailed: Bool
    var draftStorageFailed = false
    var draftLoadFailed = false
    var budgetDraftStorageFailed = false
    var budgetDraftLoadFailed = false
    var taskDraft = TaskDraft() {
        didSet {
            guard !isInitializing && !draftLoadFailed else { return }
            do { try draftStore.save(taskDraft); draftStorageFailed = false }
            catch { draftStorageFailed = true }
        }
    }
    var draftText: String {
        get { taskDraft.text }
        set { taskDraft.text = newValue }
    }
    var taskSourceText: String {
        get {
            [taskDraft.agentRequestText, taskDraft.text.isEmpty ? nil : taskDraft.text]
                .compactMap { $0 }.joined(separator: "\n")
        }
        set {
            taskDraft.agentRequestText = nil
            taskDraft.pendingAgentField = nil
            taskDraft.text = newValue
            taskDraft.fieldsTouched = true
        }
    }
    let draftStore: TaskDraftStore
    var lastSavedEntityID: UUID?
    var pendingBudgetText: String?
    var panelExpanded: Bool = false
    var lastTurn: AgentTurn?
    var confirmAmountText: String = ""
    var confirmCurrencyCode: String = "CNY"
    var selectedAttributionID: String = "unbudgeted"
    var lastUndo: UndoToken?
    var undoBanner: WorkspaceBanner?
    var banner: WorkspaceBanner?
    var agentBanner: WorkspaceBanner?
    var isWorking: Bool = false
    var selectedBudgetID: UUID?
    var agentBudgetID: UUID?
    private var requestedAgentContext = false
    var showAgent: Bool = false
    var showComposer: Bool = false
    var composerIntent: ComposerIntent = .budget
    let attachmentStore: ExpenseAttachmentStore

    @ObservationIgnored private var isInitializing = true
    private var budgetAmountDrafts: [UUID: (periodID: UUID, amountText: String)] = [:]
    private var budgetAmountDraftFailures: [String: Bool] = [:] // true: unreadable, false: write failed
    private let context: ModelContext
    private let session: AgentSession
    private let calendar: Calendar
    private let saveLedger: @MainActor (Ledger, ModelContext) throws -> Void

    init(
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        session: AgentSession? = nil,
        saveLedger: (@MainActor (Ledger, ModelContext) throws -> Void)? = nil,
        attachmentStore: ExpenseAttachmentStore? = nil,
        draftStore: TaskDraftStore? = nil
    ) {
        self.context = context
        self.calendar = calendar
        self.session = session ?? AgentSession.make(calendar: calendar)
        self.saveLedger = saveLedger ?? { try LedgerStore.replaceAll($0, in: $1) }
        let isolated = DesignPreviewData.isEnabled || context.container.configurations.allSatisfy { $0.isStoredInMemoryOnly }
        self.draftStore = draftStore ?? TaskDraftStore(inMemory: isolated)
        self.attachmentStore = attachmentStore ?? ExpenseAttachmentStore(root: isolated ? FileManager.default.temporaryDirectory.appendingPathComponent("CheckLineDemoAttachments-" + UUID().uuidString) : nil)
        if let loaded = try? LedgerStore.load(from: context, now: now) {
            ledger = loaded
            storageLoadFailed = false
            if !DesignPreviewData.isEnabled {
                try? self.attachmentStore.removeOrphans(keeping: Set(loaded.expenses.keys))
            }
        } else {
            ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
            storageLoadFailed = true
        }
        confirmCurrencyCode = ledger.walletSettings.walletCurrencyCode
        taskDraft = TaskDraft(currency: confirmCurrencyCode)
        isInitializing = false
    }

    var cards: [HomeBudgetCardModel] {
        HomeProjector.cards(in: ledger)
    }

    var selectedCard: HomeBudgetCardModel? {
        cards.first { $0.id == selectedBudgetID } ?? cards.first
    }

    func pinBudget(_ id: UUID) {
        var changed = ledger
        guard cards.contains(where: { $0.id == id }) else { return }
        let ordered = cards.filter { $0.id == id } + cards.filter { $0.id != id }
        for (index, card) in ordered.enumerated() {
            changed.budgets[card.id]?.sortIndex = index
        }
        do { try commitPresentationChange(changed) } catch { banner = .failed }
    }

    func confirmPendingExpense(_ id: UUID, now: Date = Date()) throws {
        let expense = try ledger.requireExpense(id)
        if let periodID = expense.budgetPeriodID, let period = ledger.periods[periodID],
           CurrencyEngine.budgetSettlementAmount(expense: expense, periodCurrencyCode: period.currencyCode) == nil {
            throw LedgerError.missingExchangeRate(source: expense.originalCurrencyCode, target: period.currencyCode)
        }
        try commitPresentationChange(AttributionEngine.confirmPending(ledger: ledger, expenseID: id, now: now))
    }

    func changePendingExpense(_ id: UUID, to periodID: UUID?, confirmedSettledImpact: Bool = false, now: Date = Date()) throws {
        let expense = try ledger.requireExpense(id)
        if let periodID, let period = ledger.periods[periodID],
           CurrencyEngine.budgetSettlementAmount(expense: expense, periodCurrencyCode: period.currencyCode) == nil {
            throw LedgerError.missingExchangeRate(source: expense.originalCurrencyCode, target: period.currencyCode)
        }
        let decision: AttributionDecision = periodID.map { .confirmed(periodID: $0) } ?? .unbudgeted
        try commitPresentationChange(AttributionEngine.resolvePending(ledger: ledger, expenseID: id, decision: decision, now: now, confirmedSettledImpact: confirmedSettledImpact))
    }

    func previewPendingRetrospective(_ id: UUID, now: Date = Date()) throws -> RetrospectivePreview {
        let expense = try ledger.requireExpense(id)
        guard let periodID = expense.budgetPeriodID else { throw LedgerError.periodNotFound }
        return try RetrospectiveAdjustmentEngine.previewLateExpense(ledger: ledger, periodID: periodID, expenseID: id, quote: nil, now: now)
    }

    func confirmPendingRetrospective(_ preview: RetrospectivePreview, now: Date = Date()) throws {
        guard let expenseID = preview.sourceExpenseID,
              ledger.expenses[expenseID]?.attributionState == .pending,
              try previewPendingRetrospective(expenseID, now: preview.conversion.quotedAt) == preview else {
            throw LedgerError.staleRetrospectivePreview
        }
        try commitPresentationChange(RetrospectiveAdjustmentEngine.confirm(ledger: ledger, preview: preview, quote: nil, now: now))
    }

    func createWish(name: String, amountText: String, currencyCode: String? = nil, symbolName: String = "star", now: Date = Date()) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw WorkspaceInputError.missingName }
        let currency = (currencyCode ?? ledger.walletSettings.walletCurrencyCode)
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard Locale.commonISOCurrencyCodes.contains(currency) else { throw WorkspaceInputError.invalidCurrency }
        let amount: Decimal?
        if amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { amount = nil }
        else {
            guard let parsed = MoneyFormat.parseAmount(amountText) else { throw LedgerError.zeroOrNegativeAmount }
            amount = parsed
        }
        var changed = ledger
        changed.upsert(Wish(id: UUID(), name: name, targetAmount: amount,
                            currencyCode: currency,
                            referenceURL: nil, state: .active, createdAt: now,
                            completedAt: nil, symbolName: WishSymbols.allowed.contains(symbolName) ? symbolName : "star"))
        try commitPresentationChange(changed)
    }

    func budgetAmountDraft(for card: HomeBudgetCardModel) -> String {
        let key = budgetAmountDraftKey(card.id, card.periodID)
        budgetDraftLoadFailed = budgetAmountDraftFailures[key] == true
        budgetDraftStorageFailed = budgetAmountDraftFailures[key] != nil
        if let draft = budgetAmountDrafts[card.id], draft.periodID == card.periodID { return draft.amountText }
        do {
            let draft = try draftStore.load(budgetAmountDraftKey(card.id, card.periodID))
            budgetDraftLoadFailed = false; budgetDraftStorageFailed = false
            if let draft {
                budgetAmountDrafts[card.id] = (card.periodID, draft.amount)
                return draft.amount
            }
        } catch { budgetAmountDraftFailures[key] = true; budgetDraftLoadFailed = true; budgetDraftStorageFailed = true; return "" }
        return card.snapshot.budgetAmount.description
    }

    func retainBudgetAmountDraft(_ text: String, for card: HomeBudgetCardModel) {
        budgetAmountDrafts[card.id] = (card.periodID, text)
        let key = budgetAmountDraftKey(card.id, card.periodID)
        guard budgetAmountDraftFailures[key] != true else { return }
        var draft = TaskDraft(kind: "budgetAmount", contextBudgetID: card.id, contextPeriodID: card.periodID)
        draft.amount = text; draft.currency = card.currencyCode; draft.fieldsTouched = true
        do { try draftStore.save(draft); budgetAmountDraftFailures[key] = nil; budgetDraftStorageFailed = false }
        catch { budgetAmountDraftFailures[key] = false; budgetDraftStorageFailed = true }
    }

    func discardBudgetAmountDraft(for card: HomeBudgetCardModel) {
        do {
            try draftStore.remove(budgetAmountDraftKey(card.id, card.periodID))
            budgetAmountDrafts[card.id] = nil
            budgetAmountDraftFailures[budgetAmountDraftKey(card.id, card.periodID)] = nil
            budgetDraftLoadFailed = false; budgetDraftStorageFailed = false
        } catch { budgetDraftStorageFailed = true }
    }

    private func budgetAmountDraftKey(_ budgetID: UUID, _ periodID: UUID) -> String {
        TaskDraft(kind: "budgetAmount", contextBudgetID: budgetID, contextPeriodID: periodID).key
    }

    func previewBudgetAmount(budgetID: UUID, periodID: UUID, amountText: String) throws -> BudgetAmountEditPreview {
        guard budgetAmountDraftFailures[budgetAmountDraftKey(budgetID, periodID)] == nil else { throw WorkspaceInputError.draftUnavailable }
        guard ConfirmationGate.decide(.highImpactChange) == .confirmImpact,
              let amount = MoneyFormat.parseBudgetAmount(amountText) else { throw LedgerError.invalidBudgetAmount }
        return try BudgetAmountEditEngine.preview(ledger: ledger, budgetID: budgetID, periodID: periodID, newAmount: amount)
    }

    func saveBudgetAmount(_ preview: BudgetAmountEditPreview, now: Date = Date()) throws {
        guard budgetAmountDraftFailures[budgetAmountDraftKey(preview.budgetID, preview.periodID)] == nil else { throw WorkspaceInputError.draftUnavailable }
        let before = ledger
        let changed = try BudgetAmountEditEngine.confirm(ledger: ledger, preview: preview, now: now)
        // A second window can have committed after this window produced its preview.
        let stored = try LedgerStore.load(from: ModelContext(context.container), now: now)
        var storedComparable = stored
        var memoryComparable = ledger
        storedComparable.expenseTagIDs = storedComparable.expenseTagIDs.filter { !$0.value.isEmpty }
        memoryComparable.expenseTagIDs = memoryComparable.expenseTagIDs.filter { !$0.value.isEmpty }
        // Existing ISO8601 JSON snapshots omit subsecond timestamps on disk.
        for (id, entry) in memoryComparable.walletEntries {
            memoryComparable.walletEntries[id]?.conversion = try PersistenceCoding.decodeConversion(PersistenceCoding.encodeConversion(entry.conversion))
        }
        for (id, settlement) in memoryComparable.settlements {
            memoryComparable.settlements[id]?.coverage = try PersistenceCoding.decodeCoverage(PersistenceCoding.encodeCoverage(settlement.coverage))
        }
        guard storedComparable == memoryComparable else {
            context.rollback()
            ledger = stored
            lastUndo = nil
            undoBanner = nil
            throw LedgerError.staleBudgetAmountPreview
        }
        try commitPresentationChange(changed)
        budgetAmountDrafts[preview.budgetID] = nil
        try? draftStore.remove(budgetAmountDraftKey(preview.budgetID, preview.periodID))
        publishRemainingChange(before: before, after: changed, budgetID: preview.budgetID)
    }

    private func publishRemainingChange(before: Ledger, after: Ledger, budgetID: UUID) {
        guard let old = HomeProjector.cards(in: before).first(where: { $0.id == budgetID }),
              let new = HomeProjector.cards(in: after).first(where: { $0.id == budgetID }),
              let change = BudgetRemainingChange(before: old, after: new) else { return }
        remainingAmountChange = change
    }

    func previewSettlement(_ periodID: UUID, quote: ExchangeQuote? = nil, now: Date = Date()) throws -> SettlementPreview {
        let turn = session.turn(intent: .settlePeriod(periodID: periodID, quote: quote), ledger: ledger, now: now)
        if let refusal = turn.evaluation?.refusal { throw refusal }
        guard case .settlement(let preview) = turn.evaluation?.impact else { throw AgentRefusal.outOfScope }
        return preview
    }

    func settlePeriod(
        _ periodID: UUID,
        quote: ExchangeQuote?,
        reviewedLedger: Ledger,
        acceptedIncompleteData: Bool,
        now: Date = Date()
    ) throws {
        guard ledger == reviewedLedger else { throw LedgerError.staleSettlementPreview }
        _ = try previewSettlement(periodID, quote: quote, now: now)
        let result = try session.execute(
            intent: .settlePeriod(periodID: periodID, quote: quote),
            ledger: ledger,
            now: now,
            confirmation: .impact(ImpactAcknowledgement(acceptedIncompleteData: acceptedIncompleteData, quote: quote))
        )
        try commitPresentationChange(result.ledger)
        if selectedBudgetID != nil && !cards.contains(where: { $0.id == selectedBudgetID }) {
            selectedBudgetID = cards.first?.id
        }
    }

    func redeemWish(_ id: UUID, actualAmount: Decimal, currencyCode: String, realPurchaseConfirmed: Bool, quote: ExchangeQuote? = nil, now: Date = Date()) throws {
        let result = try session.execute(intent: .redeemWish(wishID: id, actualAmount: actualAmount, currencyCode: currencyCode, quote: quote), ledger: ledger, now: now, confirmation: .impact(ImpactAcknowledgement(quote: quote, realPurchaseConfirmed: realPurchaseConfirmed)))
        try commitPresentationChange(result.ledger)
        lastUndo = nil
    }

    private func commitPresentationChange(_ changed: Ledger) throws {
        let removedExpenseIDs = Set(ledger.expenses.keys).subtracting(changed.expenses.keys)
        do {
            try saveLedger(changed, context)
            ledger = changed
            for id in removedExpenseIDs { try? attachmentStore.removeAll(for: id) }
            lastUndo = nil
            undoBanner = nil
        } catch {
            context.rollback()
            throw error
        }
    }

    var processingItems: [HomeProcessingItem] {
        HomeProjector.processingItems(in: ledger)
    }

    var wallet: WalletProjection {
        WalletLedger.projection(ledger: ledger)
    }

    var attributionChoices: [AttributionChoice] {
        HomeProjector.attributionChoices(in: ledger)
    }

    var isEmpty: Bool {
        cards.isEmpty
    }

    var actionFeedback: WorkspaceBanner? {
        if banner == .failed || banner == .undone { return banner }
        return lastUndo == nil ? nil : undoBanner
    }

    func dismissActionFeedback() {
        banner = nil
        undoBanner = nil
    }

    var showsStructuredConfirm: Bool {
        lastTurn?.evaluation?.gate == .confirmStructured
    }

    var mascotState: CloudMascotState {
        if isWorking { return .thinking }
        // Failed persistence can leave a confirmable proposal in place for retry.
        if agentBanner == .failed { return .error }
        if showsStructuredConfirm { return .waiting }
        switch agentBanner {
        case .recorded, .createdBudget, .queryRemaining: return .success
        case .needsAmount, .needsClarification, .needsFullscreen: return .waiting
        default: return .idle
        }
    }

    var captureProposal: CaptureDraft? {
        guard showsStructuredConfirm, case .intent(.capture(let draft)) = lastTurn?.understand else { return nil }
        return draft
    }

    var budgetProposal: CreateBudgetDraft? {
        guard showsStructuredConfirm, case .intent(.createBudget(let draft)) = lastTurn?.understand else { return nil }
        return draft
    }

    var canConfirmProposal: Bool {
        guard !draftStorageFailed && !draftLoadFailed && taskDraft.committedEntityID == nil else { return false }
        if captureProposal != nil {
            return MoneyFormat.parseAmount(confirmAmountText) != nil && !confirmCurrencyCode.isEmpty
                && attributionChoices.contains { $0.id == selectedAttributionID }
        }
        return budgetProposal != nil
    }

    func cancelAgentProposal() {
        lastTurn = nil
        confirmAmountText = ""
        pendingBudgetText = nil
        agentBanner = nil
    }

    func discussBudget(_ id: UUID) {
        guard cards.contains(where: { $0.id == id }) else { return }
        agentBudgetID = id
        cancelAgentProposal()
        beginTask(.record, mode: "agent", budgetID: id)
        requestedAgentContext = true
    }

    func submitText(now: Date = Date()) async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWorking, taskDraft.committedEntityID == nil else { return }
        conversation.append(AgentConversationEntry(isUser: true, text: text))
        if conversation.count > 24 { conversation.removeFirst(conversation.count - 24) }
        if ["取消", "算了", "cancel"].contains(text.lowercased()) {
            discardTask()
            agentBanner = .needsClarification("input")
            rememberAgentReply()
            return
        }
        panelExpanded = true
        isWorking = true
        defer { isWorking = false }
        banner = nil
        agentBanner = nil

        switch BudgetLoopInterpreter.interpret(text: text) {
        case .recommendPurchase, .outOfScope:
            let turn = await session.turn(input: .text(text), ledger: ledger, now: now)
            draftText = ""
            lastTurn = turn
            applyTurn(turn, now: now)
            agentBanner = banner
            rememberAgentReply()
            return
        default: break
        }

        if let budgetID = inferQueryBudget(from: text) {
            let turn = session.turn(intent: .queryBudgetStatus(budgetID: budgetID), ledger: ledger, now: now)
            draftText = ""
            lastTurn = turn
            applyTurn(turn, now: now)
            agentBanner = banner
            rememberAgentReply()
            return
        }

        var candidate = LocalRegexFallback.candidate(from: text)
        let hasActiveTask = taskDraft.agentRequestText != nil || taskDraft.pendingAgentField != nil
        let explicitStart = LocalRegexFallback.isBudgetCreationRequest(text) || LocalRegexFallback.isExplicitRecordRequest(text)
        if hasActiveTask && !explicitStart {
            if LocalRegexFallback.isAmountReply(text) {
                candidate = AgentIntentCandidate(intentType: taskDraft.kind == "budget" ? "createBudget" : "capture",
                                                 amount: LocalRegexFallback.extractAmount(from: text),
                                                 currencyCode: LocalRegexFallback.extractCurrency(from: text))
            } else if LocalRegexFallback.isCurrencyReply(text) {
                candidate = AgentIntentCandidate(intentType: taskDraft.kind == "budget" ? "createBudget" : "capture",
                                                 currencyCode: LocalRegexFallback.extractCurrency(from: text))
            } else if taskDraft.kind == "budget", let cycle = LocalRegexFallback.extractBudgetCycle(from: text) {
                let onlyCycle = text.range(of: #"(?i)^\s*(?:每月(?:循环)?|每个月|月度|按月|一次性(?:预算)?|单次|monthly|one-time|one time)(?:就好|吧|即可)?\s*[。.!！]?\s*$"#, options: .regularExpression) != nil
                candidate = AgentIntentCandidate(intentType: "createBudget",
                                                 amount: LocalRegexFallback.extractAmount(from: text),
                                                 currencyCode: LocalRegexFallback.extractCurrency(from: text),
                                                 name: onlyCycle ? nil : LocalRegexFallback.extractBudgetName(from: text),
                                                 cycleType: cycle)
            } else if taskDraft.kind == "budget", taskDraft.pendingAgentField == "name",
                      candidate.intentType == "needsClarification", text.count <= 40 {
                candidate = AgentIntentCandidate(intentType: "createBudget", name: text)
            }
        }

        let turn: AgentTurn
        if candidate.intentType == "createBudget" || candidate.intentType == "capture" {
            let kind: ComposerIntent = candidate.intentType == "createBudget" ? .budget : .record
            // A bare new expense description is not an amount correction. Never
            // reuse the previous number just because both messages are captures.
            let startsAnotherExpense = kind == .record && hasActiveTask && !taskDraft.amount.isEmpty
                && candidate.amount == nil && candidate.merchant != nil
            let continuesTask = hasActiveTask && taskDraft.kind == kind.rawValue && !explicitStart && !startsAnotherExpense
            let hasExplicitFields = taskDraft.formTouched || taskDraft.fieldsTouched
                || taskDraft.explicitAttribution || !taskDraft.attachments.isEmpty
            let keepsManualFields = hasExplicitFields && taskDraft.kind == kind.rawValue && !hasActiveTask
            if !continuesTask && !keepsManualFields {
                startAgentTask(kind, now: now)
            }
            composerIntent = kind
            taskDraft.apply(candidate)
            let previousText = taskDraft.agentRequestText
            taskDraft.agentRequestText = [previousText, text].compactMap { $0 }.joined(separator: "\n")
            draftText = ""

            var merged = candidate
            merged.amount = taskDraft.amount.isEmpty ? nil : taskDraft.amount
            merged.currencyCode = taskDraft.currency
            if kind == .budget {
                merged.name = taskDraft.name.isEmpty ? nil : taskDraft.name
                merged.cycleType = candidate.cycleType
                    ?? ((taskDraft.formTouched || LocalRegexFallback.extractBudgetCycle(from: taskDraft.agentRequestText ?? "") != nil)
                        ? (taskDraft.repeating ? "repeating" : "oneShot") : nil)
            } else {
                merged.merchant = taskDraft.merchant.isEmpty ? nil : taskDraft.merchant
                merged.note = taskDraft.note.isEmpty ? nil : taskDraft.note
                merged.occurredAt = ISO8601DateFormatter().string(from: taskDraft.occurredAt)
                if taskDraft.explicitAttribution, taskDraft.attributionID != "unbudgeted" {
                    merged.periodID = taskDraft.attributionID
                }
            }
            let result = IntentValidator.validate(merged, ledger: ledger, now: now, sourceType: .agentText)
            if case .intent(let intent) = result {
                turn = session.turn(intent: intent, ledger: ledger, now: now)
                taskDraft.pendingAgentField = nil
                pendingBudgetText = nil
            } else {
                turn = AgentTurn(understand: result, evaluation: nil, isOfflineMode: session.isOfflineMode)
                if case .needsClarification(let field, _) = result { taskDraft.pendingAgentField = field }
                pendingBudgetText = kind == .budget ? taskDraft.agentRequestText : nil
            }
        } else {
            // Unknown requests and domain refusals retain the text path; they cannot become an empty record.
            turn = await session.turn(input: .text(text), ledger: ledger, now: now)
            draftText = ""
        }
        lastTurn = turn
        applyTurn(turn, now: now)
        agentBanner = banner
        rememberAgentReply()
    }

    private func startAgentTask(_ kind: ComposerIntent, now: Date) {
        let card = cards.first { $0.id == (taskDraft.contextBudgetID ?? agentBudgetID) } ?? selectedCard
        var fresh = TaskDraft(kind: kind.rawValue,
                              contextBudgetID: kind == .record ? card?.id : nil,
                              contextPeriodID: kind == .record ? card?.periodID : nil)
        fresh.mode = "agent"
        fresh.occurredAt = now
        fresh.currency = kind == .record ? card?.currencyCode ?? ledger.walletSettings.walletCurrencyCode : ledger.walletSettings.walletCurrencyCode
        fresh.attributionID = kind == .record ? card?.periodID.uuidString ?? "unbudgeted" : "unbudgeted"
        taskDraft = fresh
        lastTurn = nil
        pendingBudgetText = nil
        confirmAmountText = ""
    }

    /// Switching to the form may incorporate text the user has not sent yet.
    /// Previously parsed source text is evidence only, never a second source of field values.
    func absorbUnsentAgentInputForManual() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, taskDraft.committedEntityID == nil else { return }
        var candidate: AgentIntentCandidate
        if LocalRegexFallback.isAmountReply(text) {
            candidate = .capture(amount: LocalRegexFallback.extractAmount(from: text),
                                 currencyCode: LocalRegexFallback.extractCurrency(from: text))
        } else if LocalRegexFallback.isCurrencyReply(text) {
            candidate = .capture(currencyCode: LocalRegexFallback.extractCurrency(from: text))
        } else if taskDraft.kind == "budget" {
            candidate = LocalRegexFallback.candidate(from: LocalRegexFallback.isBudgetCreationRequest(text) ? text : "创建预算卡 " + text)
            if !taskDraft.name.isEmpty, candidate.amount == nil, candidate.cycleType != nil {
                candidate.name = nil
            }
        } else {
            candidate = LocalRegexFallback.candidate(from: text)
        }
        taskDraft.apply(candidate)
    }

    private func rememberAgentReply() {
        if let agentBanner { conversation.append(AgentConversationEntry(isUser: false, text: agentBanner.localizedText)) }
    }

    func confirmStructured(now: Date = Date()) {
        guard showsStructuredConfirm, let turn = lastTurn, case .intent(let intent) = turn.understand else { return }
        defer { agentBanner = banner; rememberAgentReply() }
        if case .capture(var draft) = intent {
            guard let amount = MoneyFormat.parseAmount(confirmAmountText) else {
                banner = .needsAmount
                return
            }
            guard canConfirmProposal else { return }
            draft.amount = amount
            draft.currencyCode = confirmCurrencyCode
            let confirmation: AgentConfirmation
            if let periodID = attributionChoices.first(where: { $0.id == selectedAttributionID })?.periodID {
                confirmation = .attribution(.confirmed(periodID: periodID))
            } else {
                confirmation = .attribution(.unbudgeted)
            }
            persist(intent: .capture(draft), confirmation: confirmation, now: now, recordedBanner: .recorded)
            return
        }
        let isFirstCard = isEmpty
        persist(intent: intent, confirmation: .accepted, now: now, recordedBanner: .createdBudget)
        if isFirstCard && banner == .createdBudget {
            showAgent = false
        }
    }

    func createBudget(
        name: String,
        amountText: String,
        currencyCode: String,
        cycleType: CycleType,
        now: Date = Date(),
        budgetID: UUID? = nil,
        periodID: UUID? = nil
    ) {
        if taskDraft.kind != "budget" { beginTask(.budget, mode: "form", now: now) }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            banner = .failed
            return
        }
        guard let amount = MoneyFormat.parseAmount(amountText) else {
            banner = .needsAmount
            return
        }
        let bounds = monthBounds(now: now)
        let draft = CreateBudgetDraft(
            name: trimmedName,
            amount: amount,
            currencyCode: currencyCode,
            cycleType: cycleType,
            recurrence: cycleType == .repeating ? .monthly : nil,
            startDate: bounds.start,
            endDate: cycleType == .repeating ? bounds.end : nil,
            budgetID: budgetID, periodID: periodID
        )
        persist(
            intent: .createBudget(draft),
            confirmation: .accepted,
            now: now,
            recordedBanner: .createdBudget
        )
    }

    @discardableResult func recordExpense(
        amountText: String,
        merchant: String,
        note: String,
        attributionID: String,
        occurredAt: Date,
        keepComposerOpen: Bool = false,
        now: Date = Date(),
        currencyCode: String? = nil,
        expenseID: UUID? = nil
    ) -> UUID? {
        if taskDraft.kind != "record" { beginTask(.record, mode: "form", now: now) }
        guard note.count <= 10_000 else { banner = .failed; return nil }
        guard let amount = MoneyFormat.parseAmount(amountText) else {
            banner = .needsAmount
            return nil
        }
        guard let choice = attributionChoices.first(where: { $0.id == attributionID }) else { banner = .failed; return nil }
        let currency = currencyCode ?? cards.first(where: { $0.periodID == choice.periodID })?.currencyCode
            ?? ledger.walletSettings.walletCurrencyCode
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = CaptureDraft(
            amount: amount,
            currencyCode: currency,
            occurredAt: occurredAt,
            merchant: trimmedMerchant.isEmpty ? nil : trimmedMerchant,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            periodID: choice.periodID,
            sourceType: .manual,
            expenseID: expenseID
        )
        let confirmation: AgentConfirmation
        if let periodID = choice.periodID {
            confirmation = .attribution(.confirmed(periodID: periodID))
        } else {
            confirmation = .attribution(.unbudgeted)
        }
        lastSavedEntityID = nil
        persist(intent: .capture(draft), confirmation: confirmation, now: now, recordedBanner: .recorded, keepComposerOpen: keepComposerOpen)
        return lastSavedEntityID
    }

    func openComposer(_ intent: ComposerIntent, budgetID: UUID? = nil) {
        composerIntent = intent
        banner = nil
        beginTask(intent, mode: "form", budgetID: budgetID)
        showComposer = true
        collapsePanel()
    }

    func beginTask(_ intent: ComposerIntent, mode: String, now: Date = Date(), budgetID: UUID? = nil) {
        composerIntent = intent
        let card = cards.first { $0.id == (budgetID ?? (mode == "agent" ? agentBudgetID : selectedBudgetID)) } ?? selectedCard
        var fresh = TaskDraft(kind: intent.rawValue, contextBudgetID: intent == .record ? card?.id : nil,
                              contextPeriodID: intent == .record ? card?.periodID : nil)
        fresh.mode = mode; fresh.occurredAt = now
        fresh.currency = intent == .record ? card?.currencyCode ?? ledger.walletSettings.walletCurrencyCode : ledger.walletSettings.walletCurrencyCode
        fresh.attributionID = intent == .record ? card?.periodID.uuidString ?? "unbudgeted" : "unbudgeted"
        if taskDraft.key == fresh.key && taskDraft.hasInput { taskDraft.mode = mode; return }
        do {
            let restored = try draftStore.load(fresh.key)
            draftLoadFailed = false
            taskDraft = restored ?? fresh
            taskDraft.mode = mode
        } catch {
            draftLoadFailed = true; draftStorageFailed = true
            taskDraft = fresh
        }
        lastTurn = nil
        pendingBudgetText = taskDraft.kind == "budget" && taskDraft.pendingAgentField != nil ? taskDraft.agentRequestText : nil
        validateRestoredTask()
    }

    func resumeAgentTask() {
        if requestedAgentContext {
            requestedAgentContext = false
            composerIntent = .record; taskDraft.mode = "agent"
            return
        }
        if taskDraft.hasInput {
            composerIntent = ComposerIntent(rawValue: taskDraft.kind) ?? .record
            taskDraft.mode = "agent"
            return
        }
        var scope: TaskDraft?
        do {
            scope = try draftStore.recentScope()
            if let scope, let restored = try draftStore.load(scope.key) {
                draftLoadFailed = false
                taskDraft = restored; taskDraft.mode = "agent"
                composerIntent = ComposerIntent(rawValue: restored.kind) ?? .record
                agentBudgetID = restored.contextBudgetID
                lastTurn = nil
                validateRestoredTask()
            } else { beginTask(isEmpty ? .budget : .record, mode: "agent") }
        } catch {
            draftLoadFailed = true; draftStorageFailed = true
            if let scope { taskDraft = scope; composerIntent = ComposerIntent(rawValue: scope.kind) ?? .record }
            taskDraft.mode = "agent"
        }
    }

    private func validateRestoredTask() {
        pendingBudgetText = taskDraft.kind == "budget" && taskDraft.pendingAgentField != nil ? taskDraft.agentRequestText : nil
        if let field = taskDraft.pendingAgentField {
            agentBanner = field == "amount" ? .needsAmount : .needsClarification(field)
        }
        if taskDraft.kind == "record" && !attributionChoices.contains(where: { $0.id == taskDraft.attributionID }) {
            banner = .needsPeriod
        }
    }

    func discardTask() {
        do {
            try draftStore.remove(taskDraft.key)
            if draftLoadFailed { try draftStore.clearRecentScope() }
            draftLoadFailed = false; draftStorageFailed = false
            var fresh = TaskDraft(kind: taskDraft.kind, contextBudgetID: taskDraft.contextBudgetID, contextPeriodID: taskDraft.contextPeriodID)
            fresh.currency = taskDraft.currency; fresh.mode = taskDraft.mode
            fresh.attributionID = fresh.contextPeriodID?.uuidString ?? "unbudgeted"
            taskDraft = fresh; cancelAgentProposal()
        } catch { draftStorageFailed = true }
    }

    func retryTaskStorage() {
        guard !draftLoadFailed else { return }
        do { try draftStore.save(taskDraft); draftStorageFailed = false }
        catch { draftStorageFailed = true }
    }

    func addTaskAttachment(_ data: Data) throws {
        guard taskDraft.attachments.count < ExpenseAttachmentStore.maximumPerExpense else { throw ExpenseAttachmentError.limitReached }
        taskDraft.attachments.append(TaskAttachment(data: try ExpenseAttachmentStore.sanitize(data)))
    }

    func completeTaskAttachments(_ id: UUID) throws {
        if taskDraft.kind == "record", ledger.expenses[id] == nil { throw LedgerError.expenseNotFound }
        for attachment in taskDraft.attachments {
            try attachmentStore.add(imageData: attachment.data, to: id, id: attachment.id)
        }
        try draftStore.remove(taskDraft.key)
        var fresh = TaskDraft(kind: taskDraft.kind, contextBudgetID: taskDraft.contextBudgetID, contextPeriodID: taskDraft.contextPeriodID)
        fresh.mode = taskDraft.mode
        taskDraft = fresh
    }

    func undoLast(now: Date = Date()) {
        guard let token = lastUndo else { return }
        do {
            try commitPresentationChange(UndoCoordinator.undo(ledger: ledger, token: token))
            lastTurn = nil
            banner = .undone
            agentBanner = .undone
        } catch {
            banner = .failed
            agentBanner = .failed
        }
        if showAgent || (showComposer && taskDraft.mode == "agent") { rememberAgentReply() }
    }

    func expandPanel() {
        panelExpanded = true
    }

    func collapsePanel() {
        panelExpanded = false
    }

    private func applyTurn(_ turn: AgentTurn, now: Date) {
        switch turn.understand {
        case .needsClarification(let field, _):
            banner = .needsClarification(field)
            if field == "amount" {
                banner = .needsAmount
            }
        case .intent(let intent):
            switch turn.evaluation?.gate {
            case .executeDirectly:
                if case .queryBudgetStatus(let budgetID) = intent, let card = cards.first(where: { $0.id == budgetID }) {
                    agentBudgetID = budgetID
                    banner = .queryRemaining(amount: BudgetPresentation.remaining(card), currencyCode: card.currencyCode)
                    draftText = ""
                } else if case .capture = intent {
                    if taskDraft.explicitAttribution {
                        guard let choice = attributionChoices.first(where: { $0.id == taskDraft.attributionID }) else { banner = .needsPeriod; return }
                        persist(intent: intent, confirmation: .attribution(choice.periodID.map { .confirmed(periodID: $0) } ?? .unbudgeted), now: now, recordedBanner: .recorded)
                    } else {
                        persist(intent: intent, confirmation: .none, now: now, recordedBanner: .recorded)
                    }
                }
            case .confirmStructured:
                banner = .readyToConfirm
                if case .capture(let draft) = intent {
                    let card = cards.first { $0.periodID == draft.periodID || $0.id == draft.budgetID }
                        ?? cards.first { $0.id == agentBudgetID } ?? selectedCard
                    confirmAmountText = draft.amount.map { "\($0)" } ?? ""
                    confirmCurrencyCode = draft.currencyCode ?? card?.currencyCode ?? ledger.walletSettings.walletCurrencyCode
                    selectedAttributionID = "unbudgeted"
                    if taskDraft.explicitAttribution {
                        selectedAttributionID = taskDraft.attributionID
                    } else if let card, let choice = attributionChoices.first(where: { $0.periodID == card.periodID }) {
                        selectedAttributionID = choice.id
                    }
                    if draft.amount == nil {
                        banner = .needsAmount
                    }
                }
            case .confirmImpact:
                banner = .needsFullscreen
            case .refuse(.cannotRecommendPurchases):
                banner = .refusedRecommend
                draftText = ""
            case .refuse:
                banner = .refusedOutOfScope
                draftText = ""
            case .none:
                banner = .failed
            }
        }
    }

    private func persist(
        intent: AgentIntent,
        confirmation: AgentConfirmation,
        now: Date,
        recordedBanner: WorkspaceBanner,
        keepComposerOpen: Bool = false
    ) {
        do {
            guard !draftLoadFailed && !draftStorageFailed else { banner = .failed; return }
            var command = intent
            switch command {
            case .capture(var draft):
                draft.expenseID = draft.expenseID ?? taskDraft.entityID
                command = .capture(draft)
            case .createBudget(var draft):
                draft.budgetID = draft.budgetID ?? taskDraft.entityID
                draft.periodID = draft.periodID ?? taskDraft.newPeriodID
                command = .createBudget(draft)
            default: break
            }
            let executed = try session.execute(
                intent: command,
                ledger: ledger,
                now: now,
                confirmation: confirmation
            )
            let before = ledger
            let newBudgetID = executed.ledger.budgets.keys.first { ledger.budgets[$0] == nil }
            try commitPresentationChange(executed.ledger)
            if case .capture = intent {
                let newExpenses = executed.ledger.expenses.values.filter { before.expenses[$0.id] == nil }
                if let periodID = newExpenses.first?.budgetPeriodID, let budgetID = ledger.periods[periodID]?.budgetID {
                    publishRemainingChange(before: before, after: ledger, budgetID: budgetID)
                }
            }
            lastSavedEntityID = executed.savedEntityID
            if let id = executed.savedEntityID {
                taskDraft.committedEntityID = id
                guard !draftStorageFailed else { banner = .failed; return }
                if !keepComposerOpen { try completeTaskAttachments(id) }
            }
            lastUndo = executed.undo
            undoBanner = executed.undo == nil ? nil : recordedBanner
            if let newBudgetID { selectedBudgetID = newBudgetID }
            banner = recordedBanner
            if !keepComposerOpen { draftText = "" }
            pendingBudgetText = nil
            lastTurn = nil
            confirmAmountText = ""
            if !keepComposerOpen { showComposer = false }
        } catch LedgerError.captureDateOutsidePeriod {
            banner = .needsPeriod
        } catch LedgerError.missingExchangeRate {
            banner = .needsConversion
        } catch AgentRefusal.missingAmount {
            banner = .needsAmount
        } catch {
            banner = .failed
        }
    }

    private func inferQueryBudget(from text: String) -> UUID? {
        let lowered = text.lowercased()
        let markers = ["还能花", "还剩", "还能用", "remaining", "how much left"]
        guard markers.contains(where: { lowered.contains($0) }) else { return nil }
        if let match = cards.first(where: { text.contains($0.name) }) {
            return match.id
        }
        return agentBudgetID ?? selectedCard?.id
    }

    private func monthBounds(now: Date) -> (start: Date, end: Date) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let end = calendar.date(byAdding: .day, value: -1, to: next) ?? start
        return (start, end)
    }
}

nonisolated enum WorkspaceInputError: Error, Equatable { case missingName, draftUnavailable, invalidCurrency }

nonisolated enum WishSymbols {
    static let allowed = ["star", "headphones", "tent", "airplane", "camera", "bicycle", "gift", "book", "gamecontroller", "sofa"]
}

nonisolated struct AgentConversationEntry: Identifiable, Equatable {
    let id = UUID()
    var isUser: Bool
    var text: String
}
