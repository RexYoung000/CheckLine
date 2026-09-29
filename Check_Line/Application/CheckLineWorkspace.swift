import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CheckLineWorkspace {
    var ledger: Ledger
    let storageLoadFailed: Bool
    var draftText: String = ""
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
    var showAgent: Bool = false
    var composerAfterAgent: ComposerIntent?
    var composerPrefillFromAgent: Bool = false
    var showComposer: Bool = false
    var composerIntent: ComposerIntent = .budget
    let attachmentStore: ExpenseAttachmentStore

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
        attachmentStore: ExpenseAttachmentStore? = nil
    ) {
        self.context = context
        self.calendar = calendar
        self.session = session ?? AgentSession.make(calendar: calendar)
        self.saveLedger = saveLedger ?? { try LedgerStore.replaceAll($0, in: $1) }
        self.attachmentStore = attachmentStore ?? ExpenseAttachmentStore()
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
        try commitPresentationChange(AttributionEngine.confirmPending(ledger: ledger, expenseID: id, now: now))
    }

    func changePendingExpense(_ id: UUID, to periodID: UUID?, confirmedSettledImpact: Bool = false, now: Date = Date()) throws {
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

    func createWish(name: String, amountText: String, symbolName: String, now: Date = Date()) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw WorkspaceInputError.missingName }
        let amount: Decimal?
        if amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { amount = nil }
        else {
            guard let parsed = MoneyFormat.parseAmount(amountText) else { throw LedgerError.zeroOrNegativeAmount }
            amount = parsed
        }
        var changed = ledger
        changed.upsert(Wish(id: UUID(), name: name, targetAmount: amount,
                            currencyCode: ledger.walletSettings.walletCurrencyCode,
                            referenceURL: nil, state: .active, createdAt: now,
                            completedAt: nil, symbolName: WishSymbols.allowed.contains(symbolName) ? symbolName : "star"))
        try commitPresentationChange(changed)
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
    }

    func submitText(now: Date = Date()) async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false, isWorking == false else { return }
        if pendingBudgetText != nil && ["取消", "算了", "cancel"].contains(text.lowercased()) {
            cancelAgentProposal()
            draftText = ""
            return
        }
        let request: String
        if let pendingBudgetText, !LocalRegexFallback.isBudgetCreationRequest(text) {
            request = pendingBudgetText + " " + text
        } else {
            request = text
        }
        panelExpanded = true
        isWorking = true
        banner = nil
        agentBanner = nil
        confirmAmountText = ""
        if pendingBudgetText == nil, let budgetID = inferQueryBudget(from: text) {
            let turn = session.turn(intent: .queryBudgetStatus(budgetID: budgetID), ledger: ledger, now: now)
            lastTurn = turn
            isWorking = false
            applyTurn(turn, now: now)
            agentBanner = banner
            return
        }
        let turn = await session.turn(input: .text(request), ledger: ledger, now: now)
        lastTurn = turn
        isWorking = false
        if LocalRegexFallback.isBudgetCreationRequest(request) {
            switch turn.understand {
            case .needsClarification:
                pendingBudgetText = request
                draftText = ""
            case .intent(.createBudget):
                pendingBudgetText = nil
                draftText = request
            default:
                pendingBudgetText = nil
            }
        } else {
            pendingBudgetText = nil
        }
        applyTurn(turn, now: now)
        agentBanner = banner
    }

    func confirmStructured(now: Date = Date()) {
        guard showsStructuredConfirm, let turn = lastTurn, case .intent(let intent) = turn.understand else { return }
        defer { agentBanner = banner }
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
        now: Date = Date()
    ) {
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
            endDate: cycleType == .repeating ? bounds.end : nil
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
        now: Date = Date()
    ) -> UUID? {
        guard note.count <= 10_000 else { banner = .failed; return nil }
        guard let amount = MoneyFormat.parseAmount(amountText) else {
            banner = .needsAmount
            return nil
        }
        let choice = attributionChoices.first(where: { $0.id == attributionID })
        let currency = cards.first(where: { $0.periodID == choice?.periodID })?.currencyCode
            ?? ledger.walletSettings.walletCurrencyCode
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = CaptureDraft(
            amount: amount,
            currencyCode: currency,
            occurredAt: occurredAt,
            merchant: trimmedMerchant.isEmpty ? nil : trimmedMerchant,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            periodID: choice?.periodID,
            sourceType: .manual
        )
        let confirmation: AgentConfirmation
        if let periodID = choice?.periodID {
            confirmation = .attribution(.confirmed(periodID: periodID))
        } else {
            confirmation = .attribution(.unbudgeted)
        }
        let previousIDs = Set(ledger.expenses.keys)
        persist(intent: .capture(draft), confirmation: confirmation, now: now, recordedBanner: .recorded, keepComposerOpen: keepComposerOpen)
        return ledger.expenses.keys.first { !previousIDs.contains($0) }
    }

    func openComposer(_ intent: ComposerIntent) {
        composerIntent = intent
        banner = nil
        showComposer = true
        collapsePanel()
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
                    persist(intent: intent, confirmation: .none, now: now, recordedBanner: .recorded)
                }
            case .confirmStructured:
                if case .capture(let draft) = intent {
                    let card = cards.first { $0.periodID == draft.periodID || $0.id == draft.budgetID }
                        ?? cards.first { $0.id == agentBudgetID } ?? selectedCard
                    confirmAmountText = draft.amount.map { "\($0)" } ?? ""
                    confirmCurrencyCode = draft.currencyCode ?? card?.currencyCode ?? ledger.walletSettings.walletCurrencyCode
                    selectedAttributionID = "unbudgeted"
                    if let card, let choice = attributionChoices.first(where: { $0.periodID == card.periodID }) {
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
            let executed = try session.execute(
                intent: intent,
                ledger: ledger,
                now: now,
                confirmation: confirmation
            )
            let newBudgetID = executed.ledger.budgets.keys.first { ledger.budgets[$0] == nil }
            try commitPresentationChange(executed.ledger)
            lastUndo = executed.undo
            undoBanner = executed.undo == nil ? nil : recordedBanner
            if let newBudgetID { selectedBudgetID = newBudgetID }
            banner = recordedBanner
            draftText = ""
            pendingBudgetText = nil
            lastTurn = nil
            confirmAmountText = ""
            if !keepComposerOpen { showComposer = false }
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

nonisolated enum WorkspaceInputError: Error { case missingName }

nonisolated enum WishSymbols {
    static let allowed = ["star", "headphones", "tent", "airplane", "camera", "bicycle", "gift", "book", "gamecontroller", "sofa"]
}
