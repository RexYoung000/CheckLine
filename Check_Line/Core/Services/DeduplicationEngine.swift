import Foundation

nonisolated enum DeduplicationDecision: Equatable, Sendable {
    case newExpense
    case merge(existingExpenseID: UUID)
    case pending(existingExpenseID: UUID)
}

nonisolated enum DeduplicationEngine {
    static let highConfidenceWindow: TimeInterval = 2 * 60 * 60
    static let uncertainWindow: TimeInterval = 48 * 60 * 60

    static func classify(
        candidate: NormalizedTransactionCandidate,
        ledger: Ledger
    ) -> DeduplicationDecision {
        let purchases = ledger.expenses.values.filter { $0.kind == .purchase }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        // A stable transaction identity can be replayed by the same source. It must
        // still refer to an existing purchase with the same original money facts.
        if let hash = candidate.externalReferenceHash, hash.isEmpty == false {
            let identified = purchases.filter { expense in
                ledger.evidences(forExpense: expense.id).contains { $0.externalReferenceHash == hash }
            }
            if identified.count == 1, let expense = identified.first,
               expense.originalAmount == candidate.originalAmount,
               expense.originalCurrencyCode == candidate.originalCurrencyCode {
                return .merge(existingExpenseID: expense.id)
            }
            if let expense = identified.first {
                return .pending(existingExpenseID: expense.id)
            }
        }

        // Each manual/text/voice/image task expresses a new user record. Task
        // retries are handled by the coordinator's stable expense ID, not similarity.
        guard isTransactionSource(candidate.sourceType) else { return .newExpense }

        let matches = purchases.filter {
            $0.originalAmount == candidate.originalAmount
                && $0.originalCurrencyCode == candidate.originalCurrencyCode
        }

        var highConfidence: [UUID] = []
        var uncertain: UUID?

        for expense in matches {
            let delta = abs(expense.occurredAt.timeIntervalSince(candidate.occurredAt))
            let merchantMatch = normalized(expense.merchant) == normalized(candidate.merchant)
                && normalized(candidate.merchant) != nil

            let hasDifferentTransactionSource = ledger.evidences(forExpense: expense.id).contains {
                isTransactionSource($0.sourceType) && $0.sourceType != candidate.sourceType
            }
            if delta <= highConfidenceWindow, merchantMatch, hasDifferentTransactionSource {
                highConfidence.append(expense.id)
            }
            if delta <= uncertainWindow, uncertain == nil {
                uncertain = expense.id
            }
        }

        if highConfidence.count == 1, let highConfidence = highConfidence.first {
            return .merge(existingExpenseID: highConfidence)
        }
        if let ambiguous = highConfidence.first {
            return .pending(existingExpenseID: ambiguous)
        }
        if let uncertain {
            return .pending(existingExpenseID: uncertain)
        }
        return .newExpense
    }

    static func mergeEvidence(
        ledger: Ledger,
        existingExpenseID: UUID,
        candidate: NormalizedTransactionCandidate,
        now: Date,
        evidenceID: UUID = UUID()
    ) throws -> Ledger {
        var ledger = ledger
        _ = try ledger.requireExpense(existingExpenseID)
        let evidence = SourceEvidence(
            id: evidenceID,
            expenseID: existingExpenseID,
            sourceType: candidate.sourceType,
            externalReferenceHash: candidate.externalReferenceHash,
            capturedAt: now,
            coverageTimestamp: candidate.occurredAt
        )
        ledger.upsert(evidence)
        return ledger
    }

    private static func isTransactionSource(_ source: SourceType) -> Bool {
        switch source {
        case .applePay, .sms, .email, .statement: true
        case .manual, .agentText, .voice, .image: false
        }
    }

    private static func normalized(_ merchant: String?) -> String? {
        guard let merchant else { return nil }
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
