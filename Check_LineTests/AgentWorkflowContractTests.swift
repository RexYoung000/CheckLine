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
        let fixtures = try cases()
        for item in fixtures {
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
        #expect(decoded == fixtures.filter { $0["expected"] != nil }.count)
    }

    @Test("追问候选保留原动作，旧候选仍可解码且不越过确认")
    func continuationIsOptionalAndNonExecuting() throws {
        let legacy = try JSONDecoder().decode(AgentIntentCandidate.self,
            from: Data(#"{"intentType":"needsClarification","clarificationField":"periodID"}"#.utf8))
        #expect(legacy.requestedIntent == nil)
        let candidate = try JSONDecoder().decode(AgentIntentCandidate.self,
            from: Data(#"{"intentType":"needsClarification","requestedIntent":"settlePeriod","budgetName":"餐饮","clarificationField":"periodID"}"#.utf8))
        #expect(candidate.requestedIntent == "settlePeriod")
        let now = TestDates.day(2026, 10, 14)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        guard case .needsClarification(let field, _) = IntentValidator.validate(candidate, ledger: ledger, now: now, sourceType: .agentText) else {
            Issue.record("Continuation hint cannot execute a settlement")
            return
        }
        #expect(field == "periodID")
    }

    @Test("修改对象不明确的服务端候选只能继续追问，不能进入消费执行")
    func amendmentRequiresTarget() throws {
        let item = try #require(cases().first { $0["id"] as? String == "correction" })
        let expected = try #require(item["expected"] as? [String: Any])
        let candidate = try JSONDecoder().decode(AgentIntentCandidate.self,
                                                from: JSONSerialization.data(withJSONObject: expected))
        #expect(candidate.amount == "38")
        #expect(candidate.currencyCode == "CNY")
        let now = TestDates.day(2026, 10, 14)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let result = IntentValidator.validate(candidate, ledger: ledger, now: now, sourceType: .agentText)
        guard case .needsClarification(let field, _) = result else {
            Issue.record("An unbound amendment must not create a capture intent")
            return
        }
        #expect(field == "action")
    }

    @Test("服务端相对日期进入原生核对与草稿时，保留设备当地日历日期")
    func relativeDatesSurviveNativeDraft() throws {
        let formatter = ISO8601DateFormatter()
        let now = try #require(formatter.date(from: "2026-10-14T00:30:00Z"))
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        for (id, zone, expectedDay) in [("relative-date", "Asia/Shanghai", 13),
                                       ("relative-la", "America/Los_Angeles", 12)] {
            let item = try #require(cases().first { $0["id"] as? String == id })
            let expected = try #require(item["expected"] as? [String: Any])
            let candidate = try JSONDecoder().decode(AgentIntentCandidate.self,
                                                    from: JSONSerialization.data(withJSONObject: expected))
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: zone))
            guard case .intent(.capture(let draft)) = IntentValidator.validate(candidate, ledger: ledger,
                                                                              now: now, sourceType: .agentText) else {
                Issue.record("Expected resolved consumption date")
                return
            }
            #expect(calendar.component(.day, from: draft.occurredAt) == expectedDay)
            #expect(calendar.component(.month, from: draft.occurredAt) == 10)
            var task = TaskDraft()
            task.apply(candidate)
            #expect(task.occurredAt == draft.occurredAt)
        }
    }

    @Test("每次请求刷新设备参考时间，旧上下文仍可解码且固定偏移时区规范化")
    func deviceTimeContextIsFresh() throws {
        let formatter = ISO8601DateFormatter()
        let first = try #require(formatter.date(from: "2026-10-13T15:59:59Z"))
        let second = first.addingTimeInterval(2)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: first)
        let zone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let earlier = AgentContextBuilder.build(ledger, now: first, timeZone: zone)
        let later = AgentContextBuilder.build(ledger, now: second, timeZone: zone)
        #expect(earlier.deviceTime?.timestamp == "2026-10-13T15:59:59Z")
        #expect(later.deviceTime?.timestamp == "2026-10-13T16:00:01Z")
        let fixedZone = try #require(TimeZone(secondsFromGMT: 20700))
        #expect(AgentDeviceTimeContext.capture(now: first, timeZone: fixedZone).timeZoneIdentifier == "+05:45")
        let legacy = try JSONDecoder().decode(AgentContext.self,
                                             from: Data(#"{"budgetCards":[],"recentMerchants":[],"tagNames":[]}"#.utf8))
        #expect(legacy.deviceTime == nil)
    }

    @Test("理解请求使用本次发送时间，不能用草稿或响应时的旧参考")
    func understanderUsesTurnClock() async throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-13T15:59:59Z"))
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let expected = AgentDeviceTimeContext.capture(now: now, timeZone: .current)
        let understander = AgentUnderstander(provider: MockLLMProvider { prompt in
            #expect(prompt.context.deviceTime == expected)
            return AgentIntentCandidate(intentType: "needsClarification", clarificationField: "amount")
        })
        let result = await understander.understand(input: .text("昨天午餐"), ledger: ledger, now: now)
        guard case .needsClarification(let field, _) = result else {
            Issue.record("The time context must not bypass required fields")
            return
        }
        #expect(field == "amount")
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
