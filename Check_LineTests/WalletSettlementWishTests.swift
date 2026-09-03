import Foundation
import Testing
@testable import CheckLine

struct CurrencyEngineTests {
    @Test("同币种进入钱包时汇率为 1")
    func identityRate() throws {
        let converted = try CurrencyEngine.convertToWallet(
            sourceSignedAmount: 100,
            sourceCurrencyCode: "CNY",
            walletCurrencyCode: "CNY",
            quote: nil,
            at: TestDates.day(2026, 1, 1)
        )
        #expect(converted.walletSignedAmount == 100)
        #expect(converted.snapshot.kind == .identity)
        #expect(converted.snapshot.rate == 1)
    }

    @Test("跨币种没有可展示汇率时拒绝写入")
    func missingRateIsRefused() {
        #expect(throws: LedgerError.missingExchangeRate(source: "JPY", target: "CNY")) {
            try CurrencyEngine.convertToWallet(
                sourceSignedAmount: 1_000,
                sourceCurrencyCode: "JPY",
                walletCurrencyCode: "CNY",
                quote: nil,
                at: TestDates.day(2026, 1, 1)
            )
        }
    }

    @Test("优先使用实际入账汇率")
    func postedRateIsUsed() throws {
        let converted = try CurrencyEngine.convertToWallet(
            sourceSignedAmount: 1_000,
            sourceCurrencyCode: "JPY",
            walletCurrencyCode: "CNY",
            quote: .posted(rate: DecimalMath.parse("0.05"), at: TestDates.day(2026, 1, 1), sourceName: "bank"),
            at: TestDates.day(2026, 1, 1)
        )
        #expect(converted.walletSignedAmount == 50)
        #expect(converted.snapshot.kind == .posted)
    }
}

struct WalletLedgerTests {
    @Test("结余先补待恢复差额再形成钱包余额")
    func surplusFillsRecoveryGap() throws {
        let now = TestDates.day(2026, 1, 1)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let overrun = try WalletLedger.append(
            ledger: ledger,
            type: .overrun,
            sourceSignedAmount: -80,
            sourceCurrencyCode: "CNY",
            quote: nil,
            at: now
        )
        ledger = overrun.0
        #expect(WalletLedger.projection(ledger: ledger).recoveryGap == 80)
        #expect(WalletLedger.projection(ledger: ledger).balance == 0)

        let surplus = try WalletLedger.append(
            ledger: ledger,
            type: .surplus,
            sourceSignedAmount: 100,
            sourceCurrencyCode: "CNY",
            quote: nil,
            at: now.addingTimeInterval(1)
        )
        ledger = surplus.0
        let projection = WalletLedger.projection(ledger: ledger)
        #expect(projection.balance == 20)
        #expect(projection.recoveryGap == 0)
        #expect(projection.net == 20)
    }

    @Test("已有钱包分录后不能更改基准币")
    func currencyLockedAfterEntry() throws {
        let now = TestDates.day(2026, 1, 1)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        ledger = try WalletLedger.append(
            ledger: ledger,
            type: .surplus,
            sourceSignedAmount: 10,
            sourceCurrencyCode: "CNY",
            quote: nil,
            at: now
        ).0

        #expect(throws: LedgerError.walletCurrencyLocked) {
            try WalletLedger.setWalletCurrency(ledger: ledger, currencyCode: "USD", now: now)
        }
    }
}

struct SettlementEngineTests {
    @Test("待确认金额不进入确认支出，接受不完整数据后才能结算")
    func pendingExcludedUntilAccepted() throws {
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
            amount: 80,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: created.1.id)
        )
        _ = try ledger.record(
            amount: 30,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .pending(periodID: created.1.id, confidence: DecimalMath.parse("0.4"))
        )
        ledger = try CycleEngine.markDueIfNeeded(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 2, 1),
            calendar: TestDates.calendar
        )

        let preview = try SettlementEngine.preview(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 2, 1),
            calendar: TestDates.calendar,
            quote: nil
        )
        #expect(preview.confirmedSpent == 80)
        #expect(preview.pendingAmount == 30)
        #expect(preview.baseSurplus == 920)
        #expect(preview.hasBlockingPending)

        #expect(throws: LedgerError.incompleteSettlementNotAccepted) {
            try SettlementEngine.commit(
                ledger: ledger,
                periodID: created.1.id,
                now: TestDates.day(2026, 2, 1),
                calendar: TestDates.calendar,
                quote: nil,
                acceptedIncompleteData: false
            )
        }

        ledger = try SettlementEngine.commit(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 2, 1),
            calendar: TestDates.calendar,
            quote: nil,
            acceptedIncompleteData: true
        )
        #expect(WalletLedger.projection(ledger: ledger).balance == 920)
        #expect(try ledger.requirePeriod(created.1.id).state == .settled)
        #expect(try ledger.requireBudget(created.0.id).state == .active)
        #expect(ledger.periods(forBudget: created.0.id).count == 2)
    }

    @Test("一次性预算结算后归档且不续期")
    func oneShotArchives() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let created = try ledger.insertBudgetCard(
            name: "旅行",
            amount: 2_000,
            currencyCode: "CNY",
            cycleType: .oneShot,
            recurrence: nil,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 10),
            now: now
        )
        _ = try ledger.record(
            amount: 500,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: created.1.id)
        )
        ledger = try CycleEngine.markDueIfNeeded(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 1, 11),
            calendar: TestDates.calendar
        )
        ledger = try SettlementEngine.commit(
            ledger: ledger,
            periodID: created.1.id,
            now: TestDates.day(2026, 1, 11),
            calendar: TestDates.calendar,
            quote: nil,
            acceptedIncompleteData: false
        )
        #expect(try ledger.requireBudget(created.0.id).state == .archived)
        #expect(ledger.periods(forBudget: created.0.id).count == 1)
        #expect(WalletLedger.projection(ledger: ledger).balance == 1_500)
    }
}

struct WishRedemptionEngineTests {
    @Test("目标价不扣款，实际成交金额不足时不能完整兑现")
    func targetPriceIsIgnoredAndInsufficientIsRefused() throws {
        let now = TestDates.day(2026, 1, 1)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        ledger = try WalletLedger.append(
            ledger: ledger,
            type: .surplus,
            sourceSignedAmount: 800,
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

        #expect(throws: LedgerError.insufficientWishWallet) {
            try WishRedemptionEngine.preview(
                ledger: ledger,
                wishID: wish.id,
                actualAmount: 3_000,
                currencyCode: "CNY",
                quote: nil,
                now: now
            )
        }

        ledger = try WishRedemptionEngine.confirm(
            ledger: ledger,
            wishID: wish.id,
            actualAmount: 500,
            currencyCode: "CNY",
            quote: nil,
            now: now
        )
        #expect(WalletLedger.projection(ledger: ledger).balance == 300)
        #expect(try ledger.requireWish(wish.id).state == .completed)
        let expense = ledger.expenses.values.first { $0.wishRedemptionID != nil }
        #expect(expense?.budgetPeriodID == nil)
    }
}

struct RetrospectiveAdjustmentEngineTests {
    @Test("迟到交易确认后修正原周期有效支出并调整钱包")
    func lateExpenseAdjustsSettledPeriod() throws {
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
            amount: 100,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: created.1.id)
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
        #expect(WalletLedger.projection(ledger: ledger).balance == 900)

        let late = ledger.insertExpense(
            amount: 50,
            currencyCode: "CNY",
            occurredAt: TestDates.day(2026, 1, 20),
            now: TestDates.day(2026, 2, 3)
        )
        let preview = try RetrospectiveAdjustmentEngine.previewLateExpense(
            ledger: ledger,
            periodID: created.1.id,
            expenseID: late.id,
            quote: nil,
            now: TestDates.day(2026, 2, 3)
        )
        #expect(preview.amountDelta == 50)
        #expect(preview.effectiveSpentAfter == 150)
        #expect(preview.effectiveSurplusAfter == 850)
        #expect(preview.balanceAfter == 850)

        ledger = try RetrospectiveAdjustmentEngine.confirm(
            ledger: ledger,
            preview: preview,
            quote: nil,
            now: TestDates.day(2026, 2, 3)
        )
        #expect(try ledger.requireExpense(late.id).budgetPeriodID == created.1.id)
        let settlement = ledger.settlement(forPeriod: created.1.id)
        #expect(settlement?.confirmedSpent == 100)
        let effective = RetrospectiveAdjustmentEngine.effectiveResult(
            settlement: settlement!,
            adjustments: Array(ledger.adjustments.values)
        )
        #expect(effective.spent == 150)
        #expect(effective.surplus == 850)
        #expect(WalletLedger.projection(ledger: ledger).balance == 850)
    }

    @Test("已结算周期的退款减少有效支出并退回钱包")
    func refundRestoresWallet() throws {
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
        let original = try ledger.record(
            amount: 80,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: created.1.id)
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

        let preview = try RetrospectiveAdjustmentEngine.previewRefund(
            ledger: ledger,
            originalExpenseID: original.id,
            refundAmount: 80,
            quote: nil,
            now: TestDates.day(2026, 2, 4)
        )
        ledger = try RetrospectiveAdjustmentEngine.confirm(
            ledger: ledger,
            preview: preview,
            quote: nil,
            now: TestDates.day(2026, 2, 4)
        )
        #expect(WalletLedger.projection(ledger: ledger).balance == 1_000)
    }
}
