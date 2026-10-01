import SwiftUI

/// Only the front home card opts in. Currency glyphs transition; money never uses floating-point interpolation.
struct BudgetRemainingAmountText: View {
    let card: HomeBudgetCardModel
    let change: BudgetRemainingChange?
    let context: RemainingMotionContext
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasAppeared = false
    @State private var countsDown = false
    @State private var display: RemainingAmountDisplayState

    init(card: HomeBudgetCardModel, change: BudgetRemainingChange?, context: RemainingMotionContext) {
        self.card = card; self.change = change; self.context = context
        _display = State(initialValue: RemainingAmountDisplayState(card: card, change: change))
    }

    var body: some View {
        Text(MoneyFormat.string(abs(display.displayed), currencyCode: card.currencyCode))
            .contentTransition(.numericText(countsDown: countsDown))
            .accessibilityHidden(true) // The enclosing card exposes one final, signed currency value.
            .onAppear {
                if hasAppeared { refresh() } else { reset(); hasAppeared = true }
            }
            .onDisappear {
                if !context.isHomeCurrent || context.isExposed { reset() }
            }
            .onChange(of: card.snapshot) { _, _ in refresh() }
            .onChange(of: change?.id) { _, _ in refresh() }
            .onChange(of: context) { _, _ in refresh() }
            .onChange(of: scenePhase) { _, _ in refresh() }
            .onChange(of: reduceMotion) { _, _ in refresh() }
            .onChange(of: voiceOver) { _, _ in refresh() }
    }

    private func reset() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { display = RemainingAmountDisplayState(card: card, change: change) }
    }

    private func refresh() {
        var updated = display
        let animate = updated.update(card: card, change: change, context: context, isActive: scenePhase == .active, reduceMotion: reduceMotion, voiceOver: voiceOver)
        var transaction = Transaction(animation: animate ? .easeOut(duration: 0.55) : nil)
        transaction.disablesAnimations = !animate
        withTransaction(transaction) {
            countsDown = abs(updated.displayed) < abs(display.displayed)
            display = updated
        }
    }
}
