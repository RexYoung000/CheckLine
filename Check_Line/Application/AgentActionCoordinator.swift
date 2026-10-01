import Foundation

nonisolated struct AgentActionCoordinator {
    var calendar: Calendar

    func evaluate(intent: AgentIntent, ledger: Ledger, now: Date) -> AgentEvaluation {
        switch intent {
        case .queryBudgetStatus(let budgetID):
            return AgentEvaluation(
                presentation: .panel,
                gate: .executeDirectly,
                structuredProposal: nil,
                impact: nil,
                query: querySnapshot(budgetID: budgetID, ledger: ledger),
                refusal: nil
            )
        case .capture(let draft):
            return evaluateCapture(draft, ledger: ledger, now: now)
        case .createBudget:
            return AgentEvaluation(
                presentation: .confirmStructured,
                gate: ConfirmationGate.decide(.createBudget),
                structuredProposal: nil,
                impact: nil,
                query: nil,
                refusal: nil
            )
        case .adjustPeriodAmount(let periodID, let newAmount):
            return evaluateAdjust(periodID: periodID, newAmount: newAmount, ledger: ledger)
        case .deleteExpense(let expenseID):
            return evaluateDelete(expenseID: expenseID, ledger: ledger)
        case .settlePeriod(let periodID, let quote):
            return evaluateSettle(periodID: periodID, quote: quote, ledger: ledger, now: now)
        case .redeemWish(let wishID, let actualAmount, let currencyCode, let quote):
            return evaluateWish(
                wishID: wishID,
                actualAmount: actualAmount,
                currencyCode: currencyCode,
                quote: quote,
                ledger: ledger,
                now: now
            )
        case .lateExpense(let periodID, let expenseID, let quote):
            return evaluateLate(
                periodID: periodID,
                expenseID: expenseID,
                quote: quote,
                ledger: ledger,
                now: now
            )
        case .recommendPurchase:
            return refused(.cannotRecommendPurchases)
        case .outOfScope:
            return refused(.outOfScope)
        }
    }

    func execute(
        intent: AgentIntent,
        ledger: Ledger,
        now: Date,
        confirmation: AgentConfirmation
    ) throws -> AgentExecution {
        if case .capture(let draft) = intent, let id = draft.expenseID, ledger.expenses[id] != nil {
            return AgentExecution(ledger: ledger, undo: nil, query: nil, savedEntityID: id)
        }
        if case .createBudget(let draft) = intent, let id = draft.budgetID, ledger.budgets[id] != nil {
            return AgentExecution(ledger: ledger, undo: nil, query: nil, savedEntityID: id)
        }
        let evaluation = evaluate(intent: intent, ledger: ledger, now: now)
        try validate(confirmation: confirmation, against: evaluation.gate)

        switch evaluation.gate {
        case .refuse(let reason):
            throw reason
        case .executeDirectly, .confirmStructured, .confirmImpact:
            break
        }

        let snapshot = ledger
        let result = try perform(intent: intent, ledger: ledger, now: now, confirmation: confirmation)
        let undo: UndoToken?
        switch intent {
        case .queryBudgetStatus:
            undo = nil
        default:
            undo = UndoToken(snapshot: snapshot)
        }
        return AgentExecution(ledger: result.ledger, undo: undo, query: result.query, savedEntityID: result.savedEntityID)
    }

    private func validate(confirmation: AgentConfirmation, against gate: GateDecision) throws {
        switch gate {
        case .executeDirectly:
            return
        case .confirmStructured:
            switch confirmation {
            case .accepted, .attribution:
                return
            default:
                throw AgentRefusal.confirmationRequired
            }
        case .confirmImpact:
            if case .impact = confirmation { return }
            throw AgentRefusal.confirmationRequired
        case .refuse(let reason):
            throw reason
        }
    }

    private func refused(_ reason: AgentRefusal) -> AgentEvaluation {
        AgentEvaluation(
            presentation: .panel,
            gate: .refuse(reason),
            structuredProposal: nil,
            impact: nil,
            query: nil,
            refusal: reason
        )
    }

    private func evaluateCapture(_ draft: CaptureDraft, ledger: Ledger, now: Date) -> AgentEvaluation {
        let facts = captureFacts(draft, ledger: ledger, now: now)
        let gate = ConfirmationGate.decide(.capture(facts))
        let proposal: AttributionDecision?
        if let amount = draft.amount, let currency = draft.currencyCode {
            let probe = probeExpense(draft: draft, amount: amount, currency: currency, now: now)
            proposal = draft.periodID == nil && draft.budgetID == nil
                ? AttributionEngine.suggestPeriod(expense: probe, ledger: ledger, calendar: calendar)
                : nil
        } else {
            proposal = nil
        }
        let presentation: AgentPresentation = {
            switch gate {
            case .executeDirectly:
                return .panel
            case .confirmStructured:
                return .confirmStructured
            case .confirmImpact:
                return .fullscreenImpact
            case .refuse:
                return .panel
            }
        }()
        let refusal: AgentRefusal?
        if case .refuse(let reason) = gate {
            refusal = reason
        } else {
            refusal = nil
        }
        return AgentEvaluation(
            presentation: presentation,
            gate: gate,
            structuredProposal: proposal,
            impact: nil,
            query: nil,
            refusal: refusal
        )
    }

    private func captureFacts(_ draft: CaptureDraft, ledger: Ledger, now: Date) -> CaptureGateFacts {
        var bindsSettled = false
        if let periodID = draft.periodID, let period = ledger.periods[periodID], period.state == .settled {
            bindsSettled = true
        }
        var attributionNeedsConfirm = draft.periodID == nil && draft.budgetID == nil
        var dedupNeedsConfirm = false
        if let amount = draft.amount, let currency = draft.currencyCode {
            let candidate = NormalizedTransactionCandidate(
                originalAmount: amount,
                originalCurrencyCode: currency,
                occurredAt: draft.occurredAt,
                merchant: draft.merchant,
                sourceType: draft.sourceType,
                externalReferenceHash: nil
            )
            if case .pending = DeduplicationEngine.classify(candidate: candidate, ledger: ledger) {
                dedupNeedsConfirm = true
            }
            let probe = probeExpense(draft: draft, amount: amount, currency: currency, now: now)
            let suggestion = AttributionEngine.suggestPeriod(expense: probe, ledger: ledger, calendar: calendar)
            if draft.periodID == nil && draft.budgetID == nil {
                switch suggestion {
                case .confirmed, .queued:
                    attributionNeedsConfirm = false
                case .pending, .unbudgeted:
                    attributionNeedsConfirm = true
                }
            } else {
                attributionNeedsConfirm = false
            }
        }
        return CaptureGateFacts(
            hasAmountAndCurrency: draft.amount != nil && draft.currencyCode != nil,
            isMultiItem: draft.isMultiItem,
            attributionNeedsConfirm: attributionNeedsConfirm,
            dedupNeedsConfirm: dedupNeedsConfirm,
            bindsSettledPeriod: bindsSettled
        )
    }

    private func probeExpense(draft: CaptureDraft, amount: Decimal, currency: String, now: Date) -> Expense {
        Expense(
            id: UUID(),
            originalAmount: amount,
            originalCurrencyCode: currency,
            postedAmount: nil,
            postedCurrencyCode: nil,
            estimatedBudgetAmount: nil,
            estimateRateSource: nil,
            kind: .purchase,
            reversesExpenseID: nil,
            occurredAt: draft.occurredAt,
            merchant: draft.merchant,
            note: draft.note,
            budgetPeriodID: draft.periodID,
            queuedForBudgetID: nil,
            attributionState: .unbudgeted,
            attributionConfidence: nil,
            wishRedemptionID: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    private func evaluateAdjust(periodID: UUID, newAmount: Decimal, ledger: Ledger) -> AgentEvaluation {
        guard let period = ledger.periods[periodID], period.state != .settled else {
            return refused(.bindsSettledPeriod)
        }
        var previewPeriod = period
        previewPeriod.budgetAmount = newAmount
        let snapshot = BudgetEngine.periodSnapshot(period: previewPeriod, expenses: Array(ledger.expenses.values))
        return AgentEvaluation(
            presentation: .fullscreenImpact,
            gate: ConfirmationGate.decide(.highImpactChange),
            structuredProposal: nil,
            impact: .periodAmount(
                PeriodAmountImpact(
                    periodID: periodID,
                    previousAmount: period.budgetAmount,
                    newAmount: newAmount,
                    snapshotAfter: snapshot
                )
            ),
            query: nil,
            refusal: nil
        )
    }

    private func evaluateDelete(expenseID: UUID, ledger: Ledger) -> AgentEvaluation {
        guard let expense = ledger.expenses[expenseID] else {
            return refused(.domain(.expenseNotFound))
        }
        if let periodID = expense.budgetPeriodID, ledger.periods[periodID]?.state == .settled {
            return refused(.bindsSettledPeriod)
        }
        var preview = ledger
        preview.expenses[expenseID] = nil
        let snapshot: PeriodBudgetSnapshot?
        if let periodID = expense.budgetPeriodID, let period = preview.periods[periodID] {
            snapshot = BudgetEngine.periodSnapshot(period: period, expenses: Array(preview.expenses.values))
        } else {
            snapshot = nil
        }
        return AgentEvaluation(
            presentation: .fullscreenImpact,
            gate: ConfirmationGate.decide(.highImpactChange),
            structuredProposal: nil,
            impact: .deleteExpense(periodSnapshotAfter: snapshot),
            query: nil,
            refusal: nil
        )
    }

    private func evaluateSettle(periodID: UUID, quote: ExchangeQuote?, ledger: Ledger, now: Date) -> AgentEvaluation {
        do {
            var scratch = ledger
            scratch = try CycleEngine.markDueIfNeeded(
                ledger: scratch,
                periodID: periodID,
                now: now,
                calendar: calendar
            )
            if scratch.periods[periodID]?.state == .active {
                scratch = try CycleEngine.beginManualSettlement(ledger: scratch, periodID: periodID, now: now)
            }
            let preview = try SettlementEngine.preview(
                ledger: scratch,
                periodID: periodID,
                now: now,
                calendar: calendar,
                quote: quote
            )
            return AgentEvaluation(
                presentation: .fullscreenImpact,
                gate: ConfirmationGate.decide(.settlementGrade),
                structuredProposal: nil,
                impact: .settlement(preview),
                query: nil,
                refusal: nil
            )
        } catch let error as LedgerError {
            return refused(.domain(error))
        } catch {
            return refused(.outOfScope)
        }
    }

    private func evaluateWish(
        wishID: UUID,
        actualAmount: Decimal,
        currencyCode: String,
        quote: ExchangeQuote?,
        ledger: Ledger,
        now: Date
    ) -> AgentEvaluation {
        do {
            let preview = try WishRedemptionEngine.preview(
                ledger: ledger,
                wishID: wishID,
                actualAmount: actualAmount,
                currencyCode: currencyCode,
                quote: quote,
                now: now
            )
            return AgentEvaluation(
                presentation: .fullscreenImpact,
                gate: ConfirmationGate.decide(.settlementGrade),
                structuredProposal: nil,
                impact: .wish(preview),
                query: nil,
                refusal: nil
            )
        } catch let error as LedgerError {
            return refused(.domain(error))
        } catch {
            return refused(.outOfScope)
        }
    }

    private func evaluateLate(
        periodID: UUID,
        expenseID: UUID,
        quote: ExchangeQuote?,
        ledger: Ledger,
        now: Date
    ) -> AgentEvaluation {
        do {
            let preview = try RetrospectiveAdjustmentEngine.previewLateExpense(
                ledger: ledger,
                periodID: periodID,
                expenseID: expenseID,
                quote: quote,
                now: now
            )
            return AgentEvaluation(
                presentation: .fullscreenImpact,
                gate: ConfirmationGate.decide(.settlementGrade),
                structuredProposal: nil,
                impact: .retrospective(preview),
                query: nil,
                refusal: nil
            )
        } catch let error as LedgerError {
            return refused(.domain(error))
        } catch {
            return refused(.outOfScope)
        }
    }

    private func querySnapshot(budgetID: UUID, ledger: Ledger) -> PeriodBudgetSnapshot? {
        let period = ledger.periods(forBudget: budgetID).last { $0.state == .active }
            ?? ledger.periods(forBudget: budgetID).last { $0.state == .pendingSettlement }
        guard let period else { return nil }
        return BudgetEngine.periodSnapshot(period: period, expenses: Array(ledger.expenses.values))
    }

    private func perform(
        intent: AgentIntent,
        ledger: Ledger,
        now: Date,
        confirmation: AgentConfirmation
    ) throws -> AgentExecution {
        switch intent {
        case .queryBudgetStatus(let budgetID):
            return AgentExecution(
                ledger: ledger,
                undo: nil,
                query: querySnapshot(budgetID: budgetID, ledger: ledger)
            )
        case .capture(let draft):
            return try performCapture(draft, ledger: ledger, now: now, confirmation: confirmation)
        case .createBudget(let draft):
            var ledger = ledger
            let created = try ledger.insertBudgetCard(
                name: draft.name,
                amount: draft.amount,
                currencyCode: draft.currencyCode,
                cycleType: draft.cycleType,
                recurrence: draft.recurrence,
                startDate: draft.startDate,
                endDate: draft.endDate,
                now: now,
                id: draft.budgetID ?? UUID(),
                periodID: draft.periodID ?? UUID()
            )
            return AgentExecution(ledger: ledger, undo: nil, query: nil, savedEntityID: created.0.id)
        case .adjustPeriodAmount(let periodID, let newAmount):
            var ledger = ledger
            var period = try ledger.requirePeriod(periodID)
            guard period.state != .settled else { throw AgentRefusal.bindsSettledPeriod }
            period.budgetAmount = newAmount
            ledger.upsert(period)
            return AgentExecution(ledger: ledger, undo: nil, query: nil)
        case .deleteExpense(let expenseID):
            var ledger = ledger
            let expense = try ledger.requireExpense(expenseID)
            if let periodID = expense.budgetPeriodID, ledger.periods[periodID]?.state == .settled {
                throw AgentRefusal.bindsSettledPeriod
            }
            ledger.expenses[expenseID] = nil
            ledger.expenseTagIDs[expenseID] = nil
            for evidence in ledger.evidences.values where evidence.expenseID == expenseID {
                ledger.evidences[evidence.id] = nil
            }
            return AgentExecution(ledger: ledger, undo: nil, query: nil)
        case .settlePeriod(let periodID, let quote):
            guard case .impact(let acknowledgement) = confirmation else {
                throw AgentRefusal.confirmationRequired
            }
            var ledger = ledger
            ledger = try CycleEngine.markDueIfNeeded(
                ledger: ledger,
                periodID: periodID,
                now: now,
                calendar: calendar
            )
            if ledger.periods[periodID]?.state == .active {
                ledger = try CycleEngine.beginManualSettlement(ledger: ledger, periodID: periodID, now: now)
            }
            ledger = try SettlementEngine.commit(
                ledger: ledger,
                periodID: periodID,
                now: now,
                calendar: calendar,
                quote: acknowledgement.quote ?? quote,
                acceptedIncompleteData: acknowledgement.acceptedIncompleteData
            )
            return AgentExecution(ledger: ledger, undo: nil, query: nil)
        case .redeemWish(let wishID, let actualAmount, let currencyCode, let quote):
            guard case .impact(let acknowledgement) = confirmation, acknowledgement.realPurchaseConfirmed else {
                throw AgentRefusal.confirmationRequired
            }
            let ledger = try WishRedemptionEngine.confirm(
                ledger: ledger,
                wishID: wishID,
                actualAmount: actualAmount,
                currencyCode: currencyCode,
                quote: acknowledgement.quote ?? quote,
                now: now
            )
            return AgentExecution(ledger: ledger, undo: nil, query: nil)
        case .lateExpense(let periodID, let expenseID, let quote):
            guard case .impact(let acknowledgement) = confirmation else {
                throw AgentRefusal.confirmationRequired
            }
            let preview = try RetrospectiveAdjustmentEngine.previewLateExpense(
                ledger: ledger,
                periodID: periodID,
                expenseID: expenseID,
                quote: acknowledgement.quote ?? quote,
                now: now
            )
            let ledger = try RetrospectiveAdjustmentEngine.confirm(
                ledger: ledger,
                preview: preview,
                quote: acknowledgement.quote ?? quote,
                now: now
            )
            return AgentExecution(ledger: ledger, undo: nil, query: nil)
        case .recommendPurchase, .outOfScope:
            throw AgentRefusal.outOfScope
        }
    }

    private func performCapture(
        _ draft: CaptureDraft,
        ledger: Ledger,
        now: Date,
        confirmation: AgentConfirmation
    ) throws -> AgentExecution {
        guard let amount = draft.amount, let currency = draft.currencyCode else {
            throw AgentRefusal.missingAmount
        }
        var ledger = ledger
        let candidate = NormalizedTransactionCandidate(
            originalAmount: amount,
            originalCurrencyCode: currency,
            occurredAt: draft.occurredAt,
            merchant: draft.merchant,
            sourceType: draft.sourceType,
            externalReferenceHash: nil
        )
        let dedup = DeduplicationEngine.classify(candidate: candidate, ledger: ledger)
        if case .merge(let existingID) = dedup {
            ledger = try DeduplicationEngine.mergeEvidence(
                ledger: ledger,
                existingExpenseID: existingID,
                candidate: candidate,
                now: now
            )
            return AgentExecution(ledger: ledger, undo: nil, query: nil, savedEntityID: existingID)
        }

        var expense = ledger.insertExpense(
            amount: amount,
            currencyCode: currency,
            occurredAt: draft.occurredAt,
            now: now,
            merchant: draft.merchant,
            id: draft.expenseID ?? UUID()
        )
        expense.note = draft.note
        ledger.upsert(expense)

        for name in draft.tagNames {
            let tag = ExpenseTag(id: UUID(), name: name, createdAt: now)
            ledger.tags[tag.id] = tag
            ledger.attach(tagID: tag.id, toExpense: expense.id)
        }

        ledger.upsert(
            SourceEvidence(
                id: UUID(),
                expenseID: expense.id,
                sourceType: draft.sourceType,
                externalReferenceHash: nil,
                capturedAt: now,
                coverageTimestamp: draft.occurredAt
            )
        )

        var decision: AttributionDecision
        if case .attribution(let confirmed) = confirmation {
            decision = confirmed
        } else if let periodID = draft.periodID {
            decision = .confirmed(periodID: periodID)
        } else if let budgetID = draft.budgetID,
                  let period = ledger.periods.values.first(where: {
                      $0.budgetID == budgetID && $0.state == .pendingSettlement
                  }),
                  CycleEngine.shouldQueue(expenseOccurredAt: draft.occurredAt, period: period, calendar: calendar) {
            decision = .queued(budgetID: budgetID)
        } else {
            decision = AttributionEngine.suggestPeriod(expense: expense, ledger: ledger, calendar: calendar)
        }
        let targetID: UUID?
        switch decision {
        case .confirmed(let id), .pending(let id, _): targetID = id
        default: targetID = nil
        }
        if let targetID, let original = ledger.periods[targetID] {
            ledger = try CycleEngine.markDueIfNeeded(ledger: ledger, periodID: targetID, now: now, calendar: calendar)
            let period = try ledger.requirePeriod(targetID)
            guard calendar.startOfDay(for: expense.occurredAt) >= calendar.startOfDay(for: original.startDate) else { throw LedgerError.captureDateOutsidePeriod }
            if let end = CycleEngine.exclusiveEnd(of: period, calendar: calendar), expense.occurredAt >= end {
                if ledger.budgets[period.budgetID]?.cycleType == .repeating,
                   CycleEngine.shouldQueue(expenseOccurredAt: expense.occurredAt, period: period, calendar: calendar) {
                    decision = .queued(budgetID: period.budgetID)
                } else { throw LedgerError.captureDateOutsidePeriod }
            }
        }
        if case .queued(let id) = decision, let budget = ledger.budgets[id], currency != budget.defaultCurrencyCode {
            throw LedgerError.missingExchangeRate(source: currency, target: budget.defaultCurrencyCode)
        }
        if case .confirmed(let id) = decision, let period = ledger.periods[id],
           CurrencyEngine.budgetSettlementAmount(expense: expense, periodCurrencyCode: period.currencyCode) == nil {
            throw LedgerError.missingExchangeRate(source: currency, target: period.currencyCode)
        }
        if case .pending(let id, _) = decision, let period = ledger.periods[id],
           CurrencyEngine.budgetSettlementAmount(expense: expense, periodCurrencyCode: period.currencyCode) == nil {
            throw LedgerError.missingExchangeRate(source: currency, target: period.currencyCode)
        }
        ledger = try AttributionEngine.apply(
            ledger: ledger,
            expenseID: expense.id,
            decision: decision,
            now: now
        )
        return AgentExecution(ledger: ledger, undo: nil, query: nil, savedEntityID: expense.id)
    }
}
