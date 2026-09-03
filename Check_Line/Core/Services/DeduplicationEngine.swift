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
        if let hash = candidate.externalReferenceHash, hash.isEmpty == false {
            if let evidence = ledger.evidences.values.first(where: { $0.externalReferenceHash == hash }) {
                return .merge(existingExpenseID: evidence.expenseID)
            }
        }

        let matches = ledger.expenses.values.filter { expense in
            expense.kind == .purchase
                && expense.originalAmount == candidate.originalAmount
                && expense.originalCurrencyCode == candidate.originalCurrencyCode
        }

        var highConfidence: UUID?
        var uncertain: UUID?

        for expense in matches {
            let delta = abs(expense.occurredAt.timeIntervalSince(candidate.occurredAt))
            let merchantMatch = normalized(expense.merchant) == normalized(candidate.merchant)
                && normalized(candidate.merchant) != nil

            if delta <= highConfidenceWindow, merchantMatch {
                highConfidence = expense.id
                break
            }
            if delta <= uncertainWindow {
                uncertain = expense.id
            }
        }

        if let highConfidence {
            return .merge(existingExpenseID: highConfidence)
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

    private static func normalized(_ merchant: String?) -> String? {
        guard let merchant else { return nil }
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
