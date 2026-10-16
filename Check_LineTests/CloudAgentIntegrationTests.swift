import Foundation
import SwiftData
import Testing
@testable import CheckLine

private actor ScriptedAgentHTTP: HTTPPerforming {
    var replies: [(Int, String)]
    var requests: [URLRequest] = []
    let delay: UInt64
    init(_ replies: [(Int, String)], delay: UInt64 = 0) { self.replies = replies; self.delay = delay }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
        let reply = replies.isEmpty ? (503, "{}") : replies.removeFirst()
        return (Data(reply.1.utf8), HTTPURLResponse(url: request.url!, statusCode: reply.0, httpVersion: nil, headerFields: nil)!)
    }
    func count() -> Int { requests.count }
    func last() -> URLRequest? { requests.last }
}

@MainActor struct CloudAgentIntegrationTests {
    let now = TestDates.day(2026, 10, 16)
    private func workspace(_ client: ScriptedAgentHTTP, consent: Bool? = true) throws -> CheckLineWorkspace {
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let credential = PrivateAgentCredential(endpoint: URL(string: "https://example.test/v1/agent/interpret")!,
            token: String(repeating: "t", count: 40), expiresAt: TestDates.day(2027, 1, 1))
        let settings = CloudAgentSettings(credential: credential, consent: consent, httpClient: client)
        return CheckLineWorkspace(context: ModelContext(container), now: now, calendar: TestDates.calendar, cloudSettings: settings)
    }
    private func addCard(_ workspace: CheckLineWorkspace, name: String) throws -> UUID {
        workspace.createBudget(name: name, amountText: "1000", currencyCode: "CNY", cycleType: .repeating, now: now)
        return try #require(workspace.ledger.budgets.values.first { $0.name == name }?.id)
    }
    private func send(_ text: String, to workspace: CheckLineWorkspace) async {
        workspace.draftText = text
        await workspace.submitText(now: now)
    }

    @Test("首次发送先询问，未许可不触网也不丢原文")
    func consentBeforeNetwork() async throws {
        let http = ScriptedAgentHTTP([])
        let workspace = try workspace(http, consent: nil)
        await send("午餐35元", to: workspace)
        #expect(workspace.needsCloudConsent)
        #expect(workspace.draftText == "午餐35元")
        #expect(await http.count() == 0)
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("追问保留商家与币种，金额回复在本机合并，单一卡仍须选归属")
    func partialCandidateAndAttribution() async throws {
        let http = ScriptedAgentHTTP([(200, #"{"intentType":"needsClarification","merchant":"午餐","currencyCode":"CNY","clarificationField":"amount"}"#)])
        let workspace = try workspace(http)
        let card = try addCard(workspace, name: "餐饮")
        workspace.beginTask(.record, mode: "agent", now: now)
        await send("午餐，帮我记录", to: workspace)
        #expect(workspace.taskDraft.merchant == "午餐")
        #expect(workspace.agentBanner == .needsAmount)
        await send("35元", to: workspace)
        #expect(await http.count() == 1)
        #expect(workspace.taskDraft.amount == "35")
        #expect(workspace.taskDraft.pendingAgentField == "budgetName")
        #expect(workspace.ledger.expenses.isEmpty)
        workspace.chooseCloudBudget(card, now: now)
        #expect(workspace.showsStructuredConfirm)
        workspace.confirmStructured(now: now)
        let expense = try #require(workspace.ledger.expenses.values.first)
        #expect(expense.originalAmount == 35 && expense.originalCurrencyCode == "CNY")
        #expect(expense.merchant == "午餐")
        #expect(workspace.ledger.periods[try #require(expense.budgetPeriodID)]?.budgetID == card)
        let request = try #require(await http.last())
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + String(repeating: "t", count: 40))
        let data = try #require(request.httpBody)
        let body = try JSONDecoder().decode(LLMRequestPayload.self, from: data)
        #expect(body.userMessage == "午餐，帮我记录")
        #expect(body.context.recentMerchants.isEmpty && body.context.tagNames.isEmpty)
        #expect(body.context.deviceTime != nil)
    }

    @Test("选定预算B不会被首页焦点A替代")
    func chosenBudgetWins() async throws {
        let http = ScriptedAgentHTTP([(200, #"{"intentType":"capture","merchant":"午餐","amount":"35","currencyCode":"CNY"}"#)])
        let workspace = try workspace(http)
        let a = try addCard(workspace, name: "A")
        let b = try addCard(workspace, name: "B")
        workspace.selectedBudgetID = a
        workspace.beginTask(.record, mode: "agent", now: now)
        let originalScope = workspace.taskDraft.key
        await send("午餐35元", to: workspace)
        #expect(workspace.ledger.expenses.isEmpty)
        workspace.chooseCloudBudget(b, now: now)
        #expect(workspace.taskDraft.key == originalScope)
        workspace.confirmStructured(now: now)
        let expense = try #require(workspace.ledger.expenses.values.first)
        #expect(workspace.ledger.periods[try #require(expense.budgetPeriodID)]?.budgetID == b)
    }

    @Test("显式未纳入不被单一卡片自动吸收")
    func explicitUnbudgeted() async throws {
        let http = ScriptedAgentHTTP([(200, #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"午餐"}"#)])
        let workspace = try workspace(http)
        _ = try addCard(workspace, name: "餐饮")
        workspace.beginTask(.record, mode: "agent", now: now)
        await send("午餐35元", to: workspace)
        workspace.chooseCloudBudget(nil, now: now)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.values.first?.budgetPeriodID == nil)
        #expect(workspace.ledger.expenses.count == 1)
    }

    @Test("云端失败保留输入与草稿，不静默采用本地猜测写入")
    func networkFailureRetainsInput() async throws {
        let http = ScriptedAgentHTTP([(401, "{}")])
        let workspace = try workspace(http)
        await send("午餐35元", to: workspace)
        #expect(workspace.draftText == "午餐35元")
        #expect(workspace.agentBanner == .cloudFailure(.unauthorized))
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("切手动后旧网络回调不能覆盖新输入或保存")
    func cancelledCallbackIsIgnored() async throws {
        let http = ScriptedAgentHTTP([(200, #"{"intentType":"capture","amount":"35","currencyCode":"CNY"}"#)], delay: 100_000_000)
        let workspace = try workspace(http)
        workspace.draftText = "午餐35元"
        let pending = Task { await workspace.submitText(now: now) }
        while await http.count() == 0 { await Task.yield() }
        workspace.taskDraft.mode = "form"
        workspace.taskDraft.amount = "99"
        await pending.value
        #expect(workspace.taskDraft.amount == "99")
        #expect(workspace.ledger.expenses.isEmpty)
        #expect(!workspace.isWorking)
    }

    @Test("修改对象不明只追问，不建消费")
    func ambiguousModificationDoesNotCapture() async throws {
        let http = ScriptedAgentHTTP([(200, #"{"intentType":"needsClarification","amount":"38","currencyCode":"CNY","clarificationField":"action"}"#)])
        let workspace = try workspace(http)
        await send("改成38元", to: workspace)
        #expect(workspace.cloudPendingAction?.amount == "38")
        #expect(workspace.ledger.expenses.isEmpty)
        #expect(!workspace.showsStructuredConfirm)
    }

    @Test("意图不明可明确选择记一笔，再补金额和预算；不会因选择动作直接保存")
    func explicitOperationContinuesSameFacts() async throws {
        let http = ScriptedAgentHTTP([(200, #"{"intentType":"needsClarification","merchant":"午餐","currencyCode":"CNY","clarificationField":"input"}"#)])
        let workspace = try workspace(http)
        let card = try addCard(workspace, name: "餐饮")
        await send("午餐", to: workspace)
        #expect(workspace.cloudPendingAction != nil)
        workspace.resolveCloudOperation(.record, now: now)
        #expect(workspace.cloudPendingAction == nil)
        #expect(workspace.taskDraft.merchant == "午餐")
        #expect(workspace.agentBanner == .needsAmount)
        #expect(workspace.ledger.expenses.isEmpty)
        await send("35元", to: workspace)
        #expect(await http.count() == 1)
        workspace.chooseCloudBudget(card, now: now)
        #expect(workspace.showsStructuredConfirm)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.values.first?.merchant == "午餐")
    }

    @Test("联调凭据到期边界拒绝请求，未授权时不可创建云端请求")
    func credentialExpiryAndConsent() throws {
        let credential = PrivateAgentCredential(endpoint: URL(string: "https://example.test/v1/agent/interpret")!,
            token: String(repeating: "t", count: 40), expiresAt: now)
        #expect(credential.isValid(at: now.addingTimeInterval(-1)))
        #expect(!credential.isValid(at: now))
        let expired = CloudAgentSettings(credential: credential, consent: true)
        #expect(throws: LLMProviderError.unauthorized) { try expired.provider(at: now) }
        let denied = CloudAgentSettings(credential: credential, consent: false)
        #expect(throws: LLMProviderError.unauthorized) { try denied.provider(at: now.addingTimeInterval(-1)) }
    }

    @Test("已选卡按消费日找周期，不使用其他卡或已结算旧期")
    func selectedCardPeriodResolution() throws {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let a = try ledger.insertBudgetCard(name: "A", amount: 1000, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil,
            startDate: TestDates.day(2026, 10, 1), endDate: TestDates.day(2026, 10, 20), now: now)
        let b = try ledger.insertBudgetCard(name: "B", amount: 1000, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil,
            startDate: TestDates.day(2026, 10, 1), endDate: TestDates.day(2026, 10, 20), now: now)
        let draft = CaptureDraft(amount: 35, currencyCode: "CNY", occurredAt: now, merchant: "午餐", periodID: nil, budgetID: b.0.id)
        let result = try AgentActionCoordinator(calendar: TestDates.calendar).execute(intent: .capture(draft), ledger: ledger, now: now, confirmation: .accepted)
        #expect(result.ledger.expenses.values.first?.budgetPeriodID == b.1.id)
        #expect(result.ledger.expenses.values.first?.budgetPeriodID != a.1.id)
        ledger.periods[b.1.id]?.state = .settled
        #expect(CaptureAttributionResolver.resolve(budgetID: b.0.id, occurredAt: now, ledger: ledger, calendar: TestDates.calendar) == .unavailable)
    }
    @Test("删除先选本机对象并核对影响，陈旧确认和已结算记录均拒绝")
    func deletionRequiresCurrentLocalReview() async throws {
        let http = ScriptedAgentHTTP([(200, #"{"intentType":"needsClarification","requestedIntent":"deleteExpense","merchant":"午餐","clarificationField":"expenseID"}"#)])
        let workspace = try workspace(http)
        _ = workspace.recordExpense(amountText: "35", merchant: "午餐", note: "", attributionID: "unbudgeted", occurredAt: now, now: now)
        let id = try #require(workspace.ledger.expenses.values.first?.id)
        await send("删除午餐", to: workspace)
        #expect(workspace.ledger.expenses[id] != nil)
        let reviewed = workspace.ledger
        #expect(workspace.cloudDeletePreview(id, in: reviewed, now: now) != nil)
        #expect(workspace.confirmCloudDelete(id, reviewed: reviewed, now: now))
        #expect(workspace.ledger.expenses[id] == nil)
        #expect(!workspace.confirmCloudDelete(id, reviewed: reviewed, now: now))
    }

    @Test("超时和限流保持不同恢复信息，拒绝HTTP地址")
    func errorsAndTransportPolicy() async throws {
        let context = AgentContext(budgetCards: [], recentMerchants: [], tagNames: [])
        let prompt = AgentPrompt.make(userMessage: "synthetic", context: context)
        for (status, expected) in [(401, LLMProviderError.unauthorized), (429, .rateLimited), (504, .timedOut), (502, .unavailable)] {
            let client = ScriptedAgentHTTP([(status, "{}")])
            let provider = CloudLLMProvider(endpoint: URL(string: "https://example.test/v1/agent/interpret")!, client: client)
            await #expect(throws: expected) { try await provider.complete(prompt: prompt) }
        }
        let client = ScriptedAgentHTTP([])
        let insecure = CloudLLMProvider(endpoint: URL(string: "http://example.test")!, client: client)
        await #expect(throws: LLMProviderError.unavailable) { try await insecure.complete(prompt: prompt) }
        #expect(await client.count() == 0)
    }

    @Test("无换算依据的异币种保存被阻止，原币和输入保持")
    func foreignCurrencyDoesNotBecomeZero() async throws {
        let http = ScriptedAgentHTTP([(200, #"{"intentType":"capture","merchant":"午餐","amount":"10","currencyCode":"USD"}"#)])
        let workspace = try workspace(http)
        let id = try addCard(workspace, name: "餐饮")
        workspace.beginTask(.record, mode: "agent", now: now)
        await send("午餐10美元", to: workspace)
        workspace.chooseCloudBudget(id, now: now)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
        #expect(workspace.taskDraft.currency == "USD" && workspace.taskDraft.amount == "10")
        #expect(workspace.agentBanner == .needsConversion)
    }

}
