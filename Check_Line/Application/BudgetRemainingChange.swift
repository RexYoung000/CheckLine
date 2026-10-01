import Foundation

// A persisted success event, never inferred from a view loading or a different card.
nonisolated struct BudgetRemainingChange: Equatable, Sendable {
    let id: UUID
    let budgetID: UUID
    let periodID: UUID
    let currencyCode: String
    let before: Decimal
    let after: Decimal

    init?(before old: HomeBudgetCardModel, after new: HomeBudgetCardModel) {
        guard old.id == new.id, old.periodID == new.periodID, old.currencyCode == new.currencyCode,
              BudgetPresentation.remaining(old) != BudgetPresentation.remaining(new) else { return nil }
        id = UUID()
        budgetID = new.id
        periodID = new.periodID
        currencyCode = new.currencyCode
        before = BudgetPresentation.remaining(old)
        after = BudgetPresentation.remaining(new)
    }

    func matches(_ card: HomeBudgetCardModel) -> Bool {
        budgetID == card.id && periodID == card.periodID && currencyCode == card.currencyCode && after == BudgetPresentation.remaining(card)
    }
}

nonisolated enum RemainingAmountMotion {
    static func shouldAnimate(change: BudgetRemainingChange?, card: HomeBudgetCardModel, displayed: Decimal, isVisible: Bool, reduceMotion: Bool, voiceOver: Bool) -> Bool {
        guard isVisible, !reduceMotion, !voiceOver, let change, change.matches(card) else { return false }
        return change.before == displayed && change.after != displayed
    }
}


nonisolated struct RemainingMotionContext: Equatable {
    var isHomeCurrent = false
    var isExposed = false
}

nonisolated struct RemainingAmountDisplayState {
    private(set) var displayed: Decimal
    private var seenEventID: UUID?
    private var pending: BudgetRemainingChange?

    init(card: HomeBudgetCardModel, change: BudgetRemainingChange? = nil) {
        displayed = BudgetPresentation.remaining(card)
        seenEventID = change?.id
    }

    mutating func update(card: HomeBudgetCardModel, change: BudgetRemainingChange?, context: RemainingMotionContext, isActive: Bool, reduceMotion: Bool, voiceOver: Bool) -> Bool {
        let actual = BudgetPresentation.remaining(card)
        defer { seenEventID = change?.id }
        guard context.isHomeCurrent, isActive, !reduceMotion, !voiceOver else {
            displayed = actual
            pending = nil
            return false
        }
        if let change, change.id != seenEventID, change.matches(card),
           change.before == displayed || pending?.after == change.before {
            pending = change.rebased(from: displayed)
        } else if pending?.matches(card) != true {
            pending = nil
            displayed = actual
            return false
        }
        guard context.isExposed else { return false }
        let animate = RemainingAmountMotion.shouldAnimate(change: pending, card: card, displayed: displayed, isVisible: true, reduceMotion: reduceMotion, voiceOver: voiceOver)
        displayed = actual
        pending = nil
        return animate
    }
}

private extension BudgetRemainingChange {
    nonisolated init(id: UUID, budgetID: UUID, periodID: UUID, currencyCode: String, before: Decimal, after: Decimal) {
        self.id = id; self.budgetID = budgetID; self.periodID = periodID
        self.currencyCode = currencyCode; self.before = before; self.after = after
    }

    nonisolated func rebased(from displayed: Decimal) -> Self {
        Self(id: id, budgetID: budgetID, periodID: periodID, currencyCode: currencyCode, before: displayed, after: after)
    }
}
