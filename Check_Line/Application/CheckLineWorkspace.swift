import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CheckLineWorkspace {
    var ledger: Ledger
    var draftText: String = ""
    var panelExpanded: Bool = false
    var lastTurn: AgentTurn?
    var confirmAmountText: String = ""
    var confirmCurrencyCode: String = "CNY"
    var selectedAttributionID: String = "unbudgeted"
    var lastUndo: UndoToken?
    var banner: WorkspaceBanner?
    var isWorking: Bool = false
    var selectedBudgetID: UUID?
    var agentBudgetID: UUID?
    var showAgent: Bool = false
    var composerAfterAgent: ComposerIntent?
    var showComposer: Bool = false
    var composerIntent: ComposerIntent = .budget

    private let context: ModelContext
    private let session: AgentSession
    private let calendar: Calendar

    init(
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        session: AgentSession? = nil
    ) {
        self.context = context
        self.calendar = calendar
        self.session = session ?? AgentSession.make(calendar: calendar)
        if let loaded = try? LedgerStore.load(from: context, now: now) {
            ledger = loaded
        } else {
            ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
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

    func redeemWish(_ id: UUID, actualAmount: Decimal, currencyCode: String, realPurchaseConfirmed: Bool, now: Date = Date()) throws {
        let result = try session.execute(intent: .redeemWish(wishID: id, actualAmount: actualAmount, currencyCode: currencyCode, quote: nil), ledger: ledger, now: now, confirmation: .impact(ImpactAcknowledgement(realPurchaseConfirmed: realPurchaseConfirmed)))
        try commitPresentationChange(result.ledger)
        lastUndo = nil
    }

    private func commitPresentationChange(_ changed: Ledger) throws {
        do {
            try LedgerStore.replaceAll(changed, in: context)
            ledger = changed
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

    var showsStructuredConfirm: Bool {
        guard let turn = lastTurn else { return false }
        if case .needsClarification = turn.understand { return true }
        return turn.evaluation?.gate == .confirmStructured
    }

    func submitText(now: Date = Date()) async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false, isWorking == false else { return }
        panelExpanded = true
        isWorking = true
        banner = nil
        if let budgetID = inferQueryBudget(from: text) {
            let turn = session.turn(intent: .queryBudgetStatus(budgetID: budgetID), ledger: ledger, now: now)
            lastTurn = turn
            isWorking = false
            applyTurn(turn, now: now)
            return
        }
        let turn = await session.turn(input: .text(text), ledger: ledger, now: now)
        lastTurn = turn
        isWorking = false
        applyTurn(turn, now: now)
    }

    func confirmStructured(now: Date = Date()) {
        guard let turn = lastTurn, case .intent(var intent) = turn.understand else { return }
        if case .capture(var draft) = intent {
            if draft.amount == nil {
                guard let amount = MoneyFormat.parseAmount(confirmAmountText) else {
                    banner = .needsAmount
                    return
                }
                draft.amount = amount
                draft.currencyCode = confirmCurrencyCode
            }
            let confirmation: AgentConfirmation
            if let periodID = attributionChoices.first(where: { $0.id == selectedAttributionID })?.periodID {
                confirmation = .attribution(.confirmed(periodID: periodID))
            } else {
                confirmation = .attribution(.unbudgeted)
            }
            persist(intent: .capture(draft), confirmation: confirmation, now: now, recordedBanner: .recorded)
            return
        }
        persist(intent: intent, confirmation: .accepted, now: now, recordedBanner: .createdBudget)
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

    func recordExpense(
        amountText: String,
        merchant: String,
        note: String,
        attributionID: String,
        occurredAt: Date,
        now: Date = Date()
    ) {
        guard let amount = MoneyFormat.parseAmount(amountText) else {
            banner = .needsAmount
            return
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
        persist(intent: .capture(draft), confirmation: confirmation, now: now, recordedBanner: .recorded)
    }

    func openComposer(_ intent: ComposerIntent) {
        composerIntent = intent
        showComposer = true
        collapsePanel()
    }

    func undoLast(now: Date = Date()) {
        guard let token = lastUndo else { return }
        ledger = UndoCoordinator.undo(ledger: ledger, token: token)
        lastUndo = nil
        lastTurn = nil
        persistLedger()
        banner = .undone
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
                    if let amount = draft.amount {
                        confirmAmountText = "\(amount)"
                    }
                    if let currency = draft.currencyCode {
                        confirmCurrencyCode = currency
                    }
                    if let card = cards.first(where: { $0.id == agentBudgetID }) ?? selectedCard, let choice = attributionChoices.first(where: { $0.periodID == card.periodID }) {
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
        recordedBanner: WorkspaceBanner
    ) {
        do {
            let executed = try session.execute(
                intent: intent,
                ledger: ledger,
                now: now,
                confirmation: confirmation
            )
            try commitPresentationChange(executed.ledger)
            lastUndo = executed.undo
            banner = recordedBanner
            draftText = ""
            lastTurn = nil
            confirmAmountText = ""
            showComposer = false
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

    private func persistLedger() {
        do {
            try LedgerStore.replaceAll(ledger, in: context)
        } catch {
            banner = .failed
        }
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
