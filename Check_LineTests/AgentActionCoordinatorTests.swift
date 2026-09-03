import Foundation
import Testing
@testable import CheckLine

struct ConfirmationGateTests {
    @Test("明确单笔直接执行，缺金额或多笔先确认结构")
    func captureRiskTable() {
        let complete = CaptureGateFacts(
            hasAmountAndCurrency: true,
            isMultiItem: false,
            attributionNeedsConfirm: false,
            dedupNeedsConfirm: false,
            bindsSettledPeriod: false
        )
        #expect(ConfirmationGate.decide(.capture(complete)) == .executeDirectly)

        var missing = complete
        missing.hasAmountAndCurrency = false
        #expect(ConfirmationGate.decide(.capture(missing)) == .confirmStructured)

        var multi = complete
        multi.isMultiItem = true
        #expect(ConfirmationGate.decide(.capture(multi)) == .confirmStructured)

        #expect(ConfirmationGate.decide(.query) == .executeDirectly)
        #expect(ConfirmationGate.decide(.createBudget) == .confirmStructured)
        #expect(ConfirmationGate.decide(.highImpactChange) == .confirmImpact)
        #expect(ConfirmationGate.decide(.settlementGrade) == .confirmImpact)
        #expect(ConfirmationGate.decide(.recommendPurchase) == .refuse(.cannotRecommendPurchases))
        #expect(ConfirmationGate.decide(.outOfScope) == .refuse(.outOfScope))
    }
}

struct AgentActionCoordinatorTests {
    private var coordinator: AgentActionCoordinator {
        AgentActionCoordinator(calendar: TestDates.calendar)
    }

    @Test("低风险记一笔直接写入并可用快照撤销")
    func lowRiskCaptureAndUndo() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        let intent = AgentIntent.capture(
            CaptureDraft(
                amount: 35,
                currencyCode: "CNY",
                occurredAt: now,
                merchant: "面馆",
                periodID: created.1.id
            )
        )
        let evaluation = coordinator.evaluate(intent: intent, ledger: ledger, now: now)
        #expect(evaluation.gate == .executeDirectly)
        #expect(evaluation.presentation == .panel)

        let executed = try coordinator.execute(
            intent: intent,
            ledger: ledger,
            now: now,
            confirmation: .none
        )
        #expect(executed.ledger.expenses.count == 1)
        #expect(
            BudgetEngine.periodSnapshot(
                period: created.1,
                expenses: Array(executed.ledger.expenses.values)
            ).confirmedSpent == 35
        )

        #expect(executed.undo != nil)
        if let token = executed.undo {
            let undone = UndoCoordinator.undo(ledger: executed.ledger, token: token)
            #expect(undone.expenses.isEmpty)
        }
    }

    @Test("归属不确定时不写账本，确认结构化结果后再写入")
    func uncertainAttributionWaitsForConfirm() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let dining = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        _ = try ledger.insertBudgetCard(
            name: "旅行",
            amount: 3_000,
            currencyCode: "CNY",
            cycleType: .oneShot,
            recurrence: nil,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 10),
            now: now
        )
        let intent = AgentIntent.capture(
            CaptureDraft(amount: 50, currencyCode: "CNY", occurredAt: now, merchant: "咖啡")
        )
        let evaluation = coordinator.evaluate(intent: intent, ledger: ledger, now: now)
        #expect(evaluation.gate == .confirmStructured)
        #expect(evaluation.presentation == .confirmStructured)
        #expect(evaluation.structuredProposal == .unbudgeted)

        #expect(throws: AgentRefusal.confirmationRequired) {
            try coordinator.execute(intent: intent, ledger: ledger, now: now, confirmation: .none)
        }

        let executed = try coordinator.execute(
            intent: intent,
            ledger: ledger,
            now: now,
            confirmation: .attribution(.confirmed(periodID: dining.1.id))
        )
        #expect(executed.ledger.expenses.count == 1)
        let expense = executed.ledger.expenses.values.first
        #expect(expense?.budgetPeriodID == dining.1.id)
        #expect(expense?.attributionState == .confirmed)
    }

    @Test("查询剩余必须来自 BudgetEngine，不接受意图里的余额")
    func queryUsesDomainEngine() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        _ = try ledger.record(
            amount: 80,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: created.1.id)
        )
        let evaluation = coordinator.evaluate(
            intent: .queryBudgetStatus(budgetID: created.0.id),
            ledger: ledger,
            now: now
        )
        #expect(evaluation.gate == .executeDirectly)
        #expect(evaluation.query?.confirmedSpent == 80)
        #expect(evaluation.query?.remaining == 920)
        #expect(evaluation.query == BudgetEngine.periodSnapshot(period: created.1, expenses: Array(ledger.expenses.values)))
    }

    @Test("结算必须先展示领域预览，未确认不能提交")
    func settlementRequiresImpactConfirm() throws {
        let now = TestDates.day(2026, 1, 10)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        _ = try ledger.record(
            amount: 100,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: created.1.id)
        )
        let intent = AgentIntent.settlePeriod(periodID: created.1.id, quote: nil)
        let evaluation = coordinator.evaluate(
            intent: intent,
            ledger: ledger,
            now: TestDates.day(2026, 2, 1)
        )
        #expect(evaluation.gate == .confirmImpact)
        #expect(evaluation.presentation == .fullscreenImpact)
        if case .settlement(let preview) = evaluation.impact {
            #expect(preview.confirmedSpent == 100)
            #expect(preview.baseSurplus == 900)
            #expect(preview.balanceAfter == 900)
        } else {
            Issue.record("expected settlement preview")
        }
        #expect(ledger.settlements.isEmpty)

        #expect(throws: AgentRefusal.confirmationRequired) {
            try coordinator.execute(
                intent: intent,
                ledger: ledger,
                now: TestDates.day(2026, 2, 1),
                confirmation: .none
            )
        }

        let executed = try coordinator.execute(
            intent: intent,
            ledger: ledger,
            now: TestDates.day(2026, 2, 1),
            confirmation: .impact(ImpactAcknowledgement(acceptedIncompleteData: false))
        )
        #expect(executed.ledger.settlements.count == 1)
        #expect(WalletLedger.projection(ledger: executed.ledger).balance == 900)
    }

    @Test("心愿兑现不足时拒绝，且不写钱包")
    func wishRedemptionInsufficientIsRefused() throws {
        let now = TestDates.day(2026, 1, 1)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        ledger = try WalletLedger.append(
            ledger: ledger,
            type: .surplus,
            sourceSignedAmount: 100,
            sourceCurrencyCode: "CNY",
            quote: nil,
            at: now
        ).0
        let wish = Wish(
            id: UUID(),
            name: "耳机",
            targetAmount: 3_000,
            currencyCode: "CNY",
            referenceURL: nil,
            state: .active,
            createdAt: now,
            completedAt: nil
        )
        ledger.upsert(wish)
        let evaluation = coordinator.evaluate(
            intent: .redeemWish(wishID: wish.id, actualAmount: 3_000, currencyCode: "CNY", quote: nil),
            ledger: ledger,
            now: now
        )
        #expect(evaluation.gate == .refuse(.domain(.insufficientWishWallet)))
        #expect(WalletLedger.projection(ledger: ledger).balance == 100)
    }

    @Test("创建预算卡必须先确认结构化结果")
    func createBudgetNeedsStructuredConfirm() throws {
        let now = TestDates.day(2026, 1, 1)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let intent = AgentIntent.createBudget(
            CreateBudgetDraft(
                name: "餐饮",
                amount: 1_000,
                currencyCode: "CNY",
                cycleType: .repeating,
                recurrence: .monthly,
                startDate: now,
                endDate: TestDates.day(2026, 1, 31)
            )
        )
        #expect(coordinator.evaluate(intent: intent, ledger: ledger, now: now).gate == .confirmStructured)
        let executed = try coordinator.execute(
            intent: intent,
            ledger: ledger,
            now: now,
            confirmation: .accepted
        )
        #expect(executed.ledger.budgets.count == 1)
        #expect(executed.ledger.periods.count == 1)
    }

    @Test("已结算周期不能当普通记一笔，必须走追溯")
    func settledPeriodCaptureIsRefused() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        ledger = try CycleEngine.markDueIfNeeded(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 2, 1),
            calendar: TestDates.calendar
        )
        ledger = try SettlementEngine.commit(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 2, 1),
            calendar: TestDates.calendar,
            quote: nil,
            acceptedIncompleteData: false
        )
        let intent = AgentIntent.capture(
            CaptureDraft(
                amount: 20,
                currencyCode: "CNY",
                occurredAt: TestDates.day(2026, 1, 20),
                periodID: created.1.id
            )
        )
        let evaluation = coordinator.evaluate(intent: intent, ledger: ledger, now: TestDates.day(2026, 2, 3))
        #expect(evaluation.gate == .refuse(.bindsSettledPeriod))
    }

    @Test("范围外与推荐购买被拒绝且不改账本")
    func outOfScopeIsRefused() {
        let now = TestDates.day(2026, 1, 1)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        #expect(BudgetLoopInterpreter.interpret(text: "帮我看看该买哪只股票") == .outOfScope)
        #expect(BudgetLoopInterpreter.interpret(text: "推荐买耳机") == .recommendPurchase)
        #expect(coordinator.evaluate(intent: .outOfScope, ledger: ledger, now: now).refusal == .outOfScope)
        #expect(
            coordinator.evaluate(intent: .recommendPurchase, ledger: ledger, now: now).refusal
                == .cannotRecommendPurchases
        )
        #expect(ledger.expenses.isEmpty)
        #expect(ledger.walletEntries.isEmpty)
    }
}
