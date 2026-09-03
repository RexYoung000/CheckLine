import Foundation

nonisolated enum TextCaptureAdapter {
    static func intent(from facts: CaptureDraft) -> AgentIntent {
        .capture(facts)
    }
}

nonisolated enum BudgetLoopInterpreter {
    static func interpret(text: String) -> AgentIntent {
        let lowered = text.lowercased()
        if containsRecommend(lowered) {
            return .recommendPurchase
        }
        if containsOutOfScope(lowered) {
            return .outOfScope
        }
        return .capture(
            CaptureDraft(
                amount: nil,
                currencyCode: nil,
                occurredAt: Date(),
                isMultiItem: false
            )
        )
    }

    private static func containsRecommend(_ text: String) -> Bool {
        text.contains("推荐买") || text.contains("recommend buying") || text.contains("你该买")
    }

    private static func containsOutOfScope(_ text: String) -> Bool {
        let markers = ["股票", "基金", "贷款", "保险", "税务", "理财规划", "stock", "loan", "insurance", "tax advice"]
        return markers.contains { text.contains($0) }
    }
}
