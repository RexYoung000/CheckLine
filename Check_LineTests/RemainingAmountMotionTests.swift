import Foundation
import Testing
@testable import CheckLine

struct RemainingAmountMotionTests {
    @Test("加载、切卡、无成功事件的更新不伪装扣减")
    func loadingSwitchAndUnrelatedUpdates() throws {
        let old = card(remaining: 100)
        let new = card(remaining: 90, from: old)
        let event = try #require(BudgetRemainingChange(before: old, after: new))
        var initial = RemainingAmountDisplayState(card: new, change: event)
        #expect(!update(&initial, new, event))
        var state = RemainingAmountDisplayState(card: old)
        #expect(!update(&state, new, nil))
        #expect(state.displayed == 90)
        let switched = card(remaining: 30)
        #expect(!update(&state, switched, event))
        #expect(state.displayed == 30)
        var differentPeriod = new
        differentPeriod.periodID = UUID()
        #expect(!RemainingAmountMotion.shouldAnimate(change: event, card: differentPeriod, displayed: 100, isVisible: true, reduceMotion: false, voiceOver: false))
    }

    @Test("成功事件仅当前首页、前台且普通模式滚动", arguments: [0, 1, 2, 3])
    func accessibilityAndVisibility(_ mode: Int) throws {
        let old = card(remaining: DecimalMath.parse("10.01"))
        let new = card(remaining: DecimalMath.parse("-5.05"), from: old)
        let event = try #require(BudgetRemainingChange(before: old, after: new))
        var state = RemainingAmountDisplayState(card: old)
        let animate = state.update(card: new, change: event, context: RemainingMotionContext(isHomeCurrent: mode != 3, isExposed: true), isActive: true, reduceMotion: mode == 1, voiceOver: mode == 2)
        #expect(animate == (mode == 0))
        #expect(state.displayed == DecimalMath.parse("-5.05"))
    }

    @Test("输入预览遮盖时保留旧数，成功关闭后才滚到新数；连续成功取最后值")
    func deferredAndContinuousChanges() throws {
        let old = card(remaining: 100)
        let first = card(remaining: DecimalMath.parse("90.10"), from: old)
        let second = card(remaining: DecimalMath.parse("-0.01"), from: old)
        let firstEvent = try #require(BudgetRemainingChange(before: old, after: first))
        let secondEvent = try #require(BudgetRemainingChange(before: first, after: second))
        var state = RemainingAmountDisplayState(card: old)
        let covered = RemainingMotionContext(isHomeCurrent: true, isExposed: false)
        let firstCovered = state.update(card: first, change: firstEvent, context: covered, isActive: true, reduceMotion: false, voiceOver: false)
        #expect(!firstCovered)
        #expect(state.displayed == 100)
        let secondCovered = state.update(card: second, change: secondEvent, context: covered, isActive: true, reduceMotion: false, voiceOver: false)
        #expect(!secondCovered)
        #expect(update(&state, second, secondEvent))
        #expect(state.displayed == DecimalMath.parse("-0.01"))
        #expect(!update(&state, second, secondEvent))
        let third = card(remaining: 25, from: old)
        let thirdEvent = try #require(BudgetRemainingChange(before: second, after: third))
        #expect(update(&state, third, thirdEvent))
        #expect(state.displayed == 25)
    }

    @Test("后台及撤销静态更新，恢复不会重放旧成功事件")
    func interruptionDoesNotReplay() throws {
        let old = card(remaining: 100)
        let new = card(remaining: 50, from: old)
        let event = try #require(BudgetRemainingChange(before: old, after: new))
        var state = RemainingAmountDisplayState(card: old)
        let background = state.update(card: new, change: event, context: RemainingMotionContext(isHomeCurrent: true, isExposed: true), isActive: false, reduceMotion: false, voiceOver: false)
        #expect(!background)
        #expect(!update(&state, new, event))
        #expect(!update(&state, old, event))
        #expect(state.displayed == 100)
    }

    @Test("币种切换不滚；不同币种和小数保持系统格式")
    func currencyAndDecimal() throws {
        let old = card(remaining: DecimalMath.parse("1234.56"))
        var changed = card(remaining: 1000, from: old)
        changed.currencyCode = "USD"
        #expect(BudgetRemainingChange(before: old, after: changed) == nil)
        #expect(MoneyFormat.string(DecimalMath.parse("-5.05"), currencyCode: "USD") != MoneyFormat.string(DecimalMath.parse("-5.05"), currencyCode: "CNY"))
    }

    private func update(_ state: inout RemainingAmountDisplayState, _ card: HomeBudgetCardModel, _ event: BudgetRemainingChange?) -> Bool {
        state.update(card: card, change: event, context: RemainingMotionContext(isHomeCurrent: true, isExposed: true), isActive: true, reduceMotion: false, voiceOver: false)
    }

    private func card(remaining: Decimal, from source: HomeBudgetCardModel? = nil) -> HomeBudgetCardModel {
        HomeBudgetCardModel(id: source?.id ?? UUID(), periodID: source?.periodID ?? UUID(), name: "饭费", cycleType: .repeating, currencyCode: "CNY", snapshot: BudgetEngine.periodSnapshot(budgetAmount: 1000, confirmedAmounts: [1000 - remaining], pendingAmounts: []), periodState: .active, periodStart: TestDates.day(2026, 9, 1), periodEnd: TestDates.day(2026, 9, 30), cycleProgress: nil)
    }
}
