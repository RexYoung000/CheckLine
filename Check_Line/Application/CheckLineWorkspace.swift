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
    var showCreateBudget: Bool = false

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
        showCreateBudget = false
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
        if draftText.isEmpty {
            panelExpanded = false
        }
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
                if case .queryBudgetStatus = intent, let query = turn.evaluation?.query {
                    let currency = cards.first?.currencyCode ?? ledger.walletSettings.walletCurrencyCode
                    banner = .queryRemaining(amount: query.availableToSpend, currencyCode: currency)
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
                    if let firstCard = attributionChoices.first(where: { $0.periodID != nil }) {
                        selectedAttributionID = firstCard.id
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
            ledger = executed.ledger
            lastUndo = executed.undo
            persistLedger()
            banner = recordedBanner
            draftText = ""
            lastTurn = nil
            confirmAmountText = ""
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
        return cards.first?.id
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
