import Foundation
import Testing
@testable import CheckLine

struct LLMRequestPayloadTests {
    @Test("云端请求体字段受限，上下文不含金额或钱包数据")
    func payloadAllowlistOmitsAmounts() throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let dining = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: Decimal(string: "2468", locale: Locale(identifier: "en_US_POSIX"))!,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        _ = try ledger.record(
            amount: Decimal(string: "135.79", locale: Locale(identifier: "en_US_POSIX"))!,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: dining.1.id),
            merchant: "HiddenCafe"
        )
        let wallet = try WalletLedger.append(
            ledger: ledger,
            type: .surplus,
            sourceSignedAmount: Decimal(string: "77.77", locale: Locale(identifier: "en_US_POSIX"))!,
            sourceCurrencyCode: "CNY",
            quote: nil,
            at: now
        )
        ledger = wallet.0

        let prompt = AgentPrompt.make(
            userMessage: "记一笔咖啡",
            context: AgentContextBuilder.build(ledger)
        )
        let json = prompt.requestPayload.jsonUTF8
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        #expect(Set(object?.keys.map { $0 } ?? []) == ["system", "userMessage", "context"])
        #expect(json.contains("2468") == false)
        #expect(json.contains("135.79") == false)
        #expect(json.contains("77.77") == false)
        let context = object?["context"] as? [String: Any]
        let contextJSON = String(decoding: try JSONSerialization.data(withJSONObject: context ?? [:]), as: UTF8.self)
        #expect(contextJSON.lowercased().contains("wallet") == false)
        #expect(Set(context?.keys.map { $0 } ?? []) == ["budgetCards", "recentMerchants", "tagNames"])
    }
}

struct CloudLLMProviderTests {
    @Test("HTTP 200 且 JSON 合法时解码为候选意图")
    func decodesCandidate() async throws {
        let client = StubHTTPClient { request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
            #expect(Set(body?.keys.map { $0 } ?? []) == ["system", "userMessage", "context"])
            let data = Data(#"{"intentType":"capture","amount":"18","currencyCode":"CNY","merchant":"面馆"}"#.utf8)
            return (data, HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }
        let provider = CloudLLMProvider(
            endpoint: URL(string: "https://example.invalid/v1/complete")!,
            client: client
        )
        let candidate = try await provider.complete(
            prompt: AgentPrompt.make(userMessage: "面馆 18", context: AgentContext(budgetCards: [], recentMerchants: [], tagNames: []))
        )
        #expect(candidate.intentType == "capture")
        #expect(candidate.amount == "18")
        #expect(candidate.merchant == "面馆")
    }

    @Test("非法 JSON 视为无效响应")
    func invalidJSONIsInvalidResponse() async {
        let client = StubHTTPClient { request in
            (Data("not-json".utf8), HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }
        let provider = CloudLLMProvider(
            endpoint: URL(string: "https://example.invalid/v1/complete")!,
            client: client
        )
        do {
            _ = try await provider.complete(
                prompt: AgentPrompt.make(userMessage: "hi", context: AgentContext(budgetCards: [], recentMerchants: [], tagNames: []))
            )
            Issue.record("expected invalidResponse")
        } catch LLMProviderError.invalidResponse {
            // expected
        } catch {
            Issue.record("unexpected error")
        }
    }

    @Test("非 2xx 视为模型不可用")
    func httpErrorIsUnavailable() async {
        let client = StubHTTPClient { request in
            (Data(), HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!)
        }
        let provider = CloudLLMProvider(
            endpoint: URL(string: "https://example.invalid/v1/complete")!,
            client: client
        )
        do {
            _ = try await provider.complete(
                prompt: AgentPrompt.make(userMessage: "hi", context: AgentContext(budgetCards: [], recentMerchants: [], tagNames: []))
            )
            Issue.record("expected unavailable")
        } catch LLMProviderError.unavailable {
            // expected
        } catch {
            Issue.record("unexpected error")
        }
    }
}

struct LLMProviderSettingsTests {
    @Test("默认关闭时不发起 HTTP")
    func disabledNeverUsesHTTP() async {
        let client = StubHTTPClient { _ in
            Issue.record("disabled settings must not perform HTTP")
            throw LLMProviderError.unavailable
        }
        let provider = LLMProviderSettings.disabled.makeProvider(client: client)
        do {
            _ = try await provider.complete(
                prompt: AgentPrompt.make(userMessage: "hi", context: AgentContext(budgetCards: [], recentMerchants: [], tagNames: []))
            )
            Issue.record("expected unavailable")
        } catch LLMProviderError.unavailable {
            // expected
        } catch {
            Issue.record("unexpected error")
        }
    }
}

struct AgentSessionTests {
    @Test("离线回合提取记一笔并走结构化确认，确认后写入")
    func offlineCaptureThenConfirm() async throws {
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
        let session = AgentSession.make(calendar: TestDates.calendar)
        #expect(session.isOfflineMode)

        let turn = await session.turn(input: .text("星巴克 35 元"), ledger: ledger, now: now)
        #expect(turn.isOfflineMode)
        #expect(turn.evaluation?.gate == .confirmStructured)
        #expect(turn.presentation == .confirmStructured)
        guard case .intent(.capture(let draft)) = turn.understand else {
            Issue.record("expected capture intent")
            return
        }
        #expect(draft.amount == 35)
        #expect(draft.periodID == nil)

        let executed = try session.execute(
            intent: .capture(draft),
            ledger: ledger,
            now: now,
            confirmation: .attribution(.confirmed(periodID: created.1.id))
        )
        #expect(executed.ledger.expenses.count == 1)
        #expect(executed.undo != nil)
    }

    @Test("本地组装的查询不走模型，余额来自 Core")
    func localQuerySkipsModel() throws {
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
        let client = StubHTTPClient { _ in
            Issue.record("local intent must not call HTTP")
            throw LLMProviderError.unavailable
        }
        let session = AgentSession.make(
            settings: .disabled,
            calendar: TestDates.calendar,
            httpClient: client
        )
        let intent = AgentIntent.queryBudgetStatus(budgetID: created.0.id)
        let turn = session.turn(intent: intent, ledger: ledger, now: now)
        #expect(turn.evaluation?.gate == .executeDirectly)
        #expect(turn.evaluation?.query?.remaining == 1_000)

        let executed = try session.execute(
            intent: intent,
            ledger: ledger,
            now: now,
            confirmation: .none
        )
        #expect(executed.query?.remaining == 1_000)
        #expect(executed.undo == nil)
    }

    @Test("推荐购买在回合层拒绝")
    func recommendIsRefused() async {
        let now = TestDates.day(2026, 1, 5)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let session = AgentSession.make(calendar: TestDates.calendar)
        let turn = await session.turn(input: .text("推荐买点什么"), ledger: ledger, now: now)
        #expect(turn.understand == .intent(.recommendPurchase))
        #expect(turn.evaluation?.gate == .refuse(.cannotRecommendPurchases))
    }

    @Test("显式启用后才走 HTTP，仍不经过真实网络")
    func enabledSettingsUseInjectedClient() async {
        let client = StubHTTPClient { _ in
            let data = Data(#"{"intentType":"outOfScope"}"#.utf8)
            return (
                data,
                HTTPURLResponse(
                    url: URL(string: "https://example.invalid/v1/complete")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        }
        let settings = LLMProviderSettings(
            isEnabled: true,
            endpoint: URL(string: "https://example.invalid/v1/complete")!
        )
        let session = AgentSession.make(
            settings: settings,
            calendar: TestDates.calendar,
            httpClient: client
        )
        #expect(session.isOfflineMode == false)
        let now = TestDates.day(2026, 1, 5)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let turn = await session.turn(input: .text("随便记一下"), ledger: ledger, now: now)
        #expect(turn.understand == .intent(.outOfScope))
    }
}

private struct StubHTTPClient: HTTPPerforming {
    var handler: @Sendable (URLRequest) throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try handler(request)
    }
}
