import Foundation
import Testing
@testable import CheckLine

struct AgentWorkflowContractTests {
    private func cases() throws -> [[String: Any]] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("services/agent-api/review/cases.json"))
        return try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }

    @Test("服务端审阅候选均可被当前 Swift 解码，高影响操作只返回追问")
    func decodesReviewCandidates() throws {
        var decoded = 0
        for item in try cases() {
            guard let expected = item["expected"] as? [String: Any] else { continue }
            let data = try JSONSerialization.data(withJSONObject: expected)
            let candidate = try JSONDecoder().decode(AgentIntentCandidate.self, from: data)
            #expect(candidate.periodID == nil && candidate.budgetID == nil)
            #expect(candidate.expenseID == nil && candidate.wishID == nil)
            if item["id"] as? String == "settlement" {
                #expect(candidate.intentType == "needsClarification")
                #expect(candidate.clarificationField == "periodID")
            }
            if item["id"] as? String == "foreign-currency" {
                #expect(candidate.currencyCode == "USD")
                #expect(candidate.amount == "3.50")
            }
            decoded += 1
        }
        #expect(decoded == 13)
    }

    @Test("同一服务端样例经本地校验生成 Decimal 与月度规则，金额仍由本机处理")
    func nativeValidationOfReviewCandidates() throws {
        let now = TestDates.day(2026, 10, 13)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        _ = try ledger.insertBudgetCard(name: "餐饮", amount: 1000, currencyCode: "CNY", cycleType: .repeating,
                                        recurrence: .monthly, startDate: TestDates.day(2026, 10, 1),
                                        endDate: TestDates.day(2026, 10, 31), now: now)
        let reviewCases = try cases()
        let expense = try #require(reviewCases.first { $0["id"] as? String == "expense" }?["expected"] as? [String: Any])
        let expenseCandidate = try JSONDecoder().decode(AgentIntentCandidate.self,
                                                       from: JSONSerialization.data(withJSONObject: expense))
        guard case .intent(.capture(let draft)) = IntentValidator.validate(expenseCandidate, ledger: ledger,
                                                                          now: now, sourceType: .agentText) else {
            Issue.record("Expected native capture validation")
            return
        }
        #expect(draft.amount == Decimal(string: "35"))
        #expect(draft.currencyCode == "CNY")
        #expect(draft.budgetID != nil)
        #expect(ledger.expenses.isEmpty)

        let monthly = try #require(reviewCases.first { $0["id"] as? String == "monthly" }?["expected"] as? [String: Any])
        let monthlyCandidate = try JSONDecoder().decode(AgentIntentCandidate.self,
                                                       from: JSONSerialization.data(withJSONObject: monthly))
        guard case .intent(.createBudget(let budgetDraft)) = IntentValidator.validate(monthlyCandidate, ledger: ledger,
                                                                                     now: now, sourceType: .agentText) else {
            Issue.record("Expected native monthly draft validation")
            return
        }
        #expect(budgetDraft.amount == 1000)
        #expect(budgetDraft.recurrence == .monthlyWindow(startDay: 5, endDay: 20))
        #expect(ledger.budgets.count == 1)
    }
}
