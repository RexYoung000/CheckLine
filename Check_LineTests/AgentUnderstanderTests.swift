import Foundation
import Testing
@testable import CheckLine

struct AgentContextBuilderTests {
    @Test("上下文只含卡名、周期、货币、商家和标签，不含金额或钱包")
    func omitsAmountsAndWallet() throws {
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
        _ = try ledger.insertBudgetCard(
            name: "已归档旅行",
            amount: Decimal(string: "9999", locale: Locale(identifier: "en_US_POSIX"))!,
            currencyCode: "USD",
            cycleType: .oneShot,
            recurrence: nil,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 10),
            now: now
        )
        if var archived = ledger.budgets.values.first(where: { $0.name == "已归档旅行" }) {
            archived.state = .archived
            ledger.upsert(archived)
        }

        let expenseAmount = Decimal(string: "135.79", locale: Locale(identifier: "en_US_POSIX"))!
        _ = try ledger.record(
            amount: expenseAmount,
            currencyCode: "CNY",
            occurredAt: now,
            now: now,
            decision: .confirmed(periodID: dining.1.id),
            merchant: "HiddenCafe"
        )
        let tag = ExpenseTag(id: UUID(), name: "人情", createdAt: now)
        ledger.tags[tag.id] = tag

        let wallet = try WalletLedger.append(
            ledger: ledger,
            type: .surplus,
            sourceSignedAmount: Decimal(string: "77.77", locale: Locale(identifier: "en_US_POSIX"))!,
            sourceCurrencyCode: "CNY",
            quote: nil,
            at: now
        )
        ledger = wallet.0

        let context = AgentContextBuilder.build(ledger)
        #expect(context.budgetCards.map(\.name) == ["餐饮"])
        #expect(context.budgetCards.first?.cycleType == CycleType.repeating.rawValue)
        #expect(context.budgetCards.first?.currencyCode == "CNY")
        #expect(context.recentMerchants == ["HiddenCafe"])
        #expect(context.tagNames == ["人情"])

        let json = context.jsonUTF8
        #expect(json.contains("2468") == false)
        #expect(json.contains("135.79") == false)
        #expect(json.contains("77.77") == false)
        #expect(json.contains("9999") == false)
        #expect(json.lowercased().contains("wallet") == false)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        #expect(Set(object?.keys.map { $0 } ?? []) == ["budgetCards", "recentMerchants", "tagNames"])
        #expect(object?["recentMerchants"] as? [String] == ["HiddenCafe"])
        #expect(object?["tagNames"] as? [String] == ["人情"])
        let card = (object?["budgetCards"] as? [[String: Any]])?.first
        #expect(Set(card?.keys.map { $0 } ?? []) == ["name", "cycleType", "currencyCode"])
    }

    @Test("最近商家按时间去重且最多 10 条")
    func merchantsAreDedupedAndCapped() throws {
        let now = TestDates.day(2026, 1, 20)
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
        for index in 1...12 {
            _ = try ledger.record(
                amount: 10,
                currencyCode: "CNY",
                occurredAt: TestDates.day(2026, 1, index),
                now: now,
                decision: .confirmed(periodID: dining.1.id),
                merchant: "Shop\(index)"
            )
        }
        _ = try ledger.record(
            amount: 12,
            currencyCode: "CNY",
            occurredAt: TestDates.day(2026, 1, 20, hour: 18),
            now: now,
            decision: .confirmed(periodID: dining.1.id),
            merchant: "Shop12"
        )

        let context = AgentContextBuilder.build(ledger)
        #expect(context.recentMerchants.count == 10)
        #expect(context.recentMerchants.first == "Shop12")
        #expect(context.recentMerchants.contains("Shop1") == false)
        #expect(context.recentMerchants.contains("Shop2") == false)
    }
}

struct LocalRegexFallbackTests {
    @Test("本地回退提取金额、货币和商家")
    func extractsCaptureFields() {
        let candidate = LocalRegexFallback.candidate(from: "在星巴克花了 35 元")
        #expect(candidate.intentType == "capture")
        #expect(candidate.amount == "35")
        #expect(candidate.currencyCode == "CNY")
        #expect(candidate.merchant == "星巴克")
        #expect(candidate.periodID == nil)
        #expect(candidate.budgetID == nil)
    }

    @Test("离线创建预算卡与普通消费不会混淆")
    func recognizesBudgetCreation() {
        let budget = LocalRegexFallback.candidate(from: "创建每月餐饮预算 1,000 元")
        #expect(budget.intentType == "createBudget")
        #expect(budget.name == "餐饮")
        #expect(budget.amount == "1,000")
        #expect(budget.currencyCode == "CNY")
        #expect(budget.cycleType == CycleType.repeating.rawValue)

        let spending = LocalRegexFallback.candidate(from: "咖啡 35 元记到餐饮预算卡")
        #expect(spending.intentType == "capture")
        #expect(spending.amount == "35")

        let draftBridge = LocalRegexFallback.candidate(from: "创建预算卡 餐饮 1000元 每月")
        #expect(draftBridge.name == "餐饮")
        #expect(draftBridge.amount == "1000")
        #expect(draftBridge.cycleType == CycleType.repeating.rawValue)
    }
}

struct IntentValidatorTests {
    @Test("每月预算默认完整月周期和钱包货币")
    func monthlyBudgetHasPeriodBounds() {
        let now = TestDates.day(2026, 1, 5)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let result = IntentValidator.validate(
            AgentIntentCandidate(intentType: "createBudget", amount: "1,000", name: "餐饮", cycleType: CycleType.repeating.rawValue),
            ledger: ledger,
            now: now,
            sourceType: .agentText
        )
        guard case .intent(.createBudget(let draft)) = result else {
            Issue.record("expected monthly budget")
            return
        }
        #expect(draft.amount == 1_000)
        #expect(draft.currencyCode == "CNY")
        #expect(draft.recurrence == .monthly)
        #expect(draft.startDate <= now)
        #expect(draft.endDate != nil)
        if let end = draft.endDate {
            #expect(Calendar.current.component(.month, from: end) == 1)
            #expect(Calendar.current.component(.day, from: end) == 31)
        }
    }

    @Test("金额必须是正 Decimal 字符串，非法则追问")
    func invalidAmountNeedsClarification() {
        let now = TestDates.day(2026, 1, 5)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let result = IntentValidator.validate(
            .capture(amount: "abc", currencyCode: "CNY", merchant: "面馆"),
            ledger: ledger,
            now: now,
            sourceType: .agentText
        )
        #expect(result == .needsClarification(field: "amount", options: []))
    }

    @Test("不存在的周期 ID 不能变成正式意图")
    func unknownPeriodNeedsClarification() {
        let now = TestDates.day(2026, 1, 5)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        var candidate = AgentIntentCandidate.capture(amount: "35", currencyCode: "CNY")
        candidate.periodID = UUID().uuidString
        let result = IntentValidator.validate(candidate, ledger: ledger, now: now, sourceType: .agentText)
        guard case .needsClarification(let field, _) = result else {
            Issue.record("expected clarification")
            return
        }
        #expect(field == "periodID")
    }

    @Test("合法金额字符串才转成 Decimal")
    func parsesDecimalAmount() throws {
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
        var candidate = AgentIntentCandidate.capture(amount: "35.50", currencyCode: "CNY", merchant: "面馆")
        candidate.periodID = created.1.id.uuidString
        let result = IntentValidator.validate(candidate, ledger: ledger, now: now, sourceType: .agentText)
        guard case .intent(.capture(let draft)) = result else {
            Issue.record("expected capture intent")
            return
        }
        #expect(draft.amount == Decimal(string: "35.50", locale: Locale(identifier: "en_US_POSIX")))
        #expect(draft.periodID == created.1.id)
        #expect(draft.merchant == "面馆")
    }

    @Test("候选 JSON 里的金额保持字符串")
    func candidateKeepsAmountAsString() throws {
        let data = Data(#"{"intentType":"capture","amount":"35.50","currencyCode":"CNY"}"#.utf8)
        let candidate = try JSONDecoder().decode(AgentIntentCandidate.self, from: data)
        #expect(candidate.amount == "35.50")
    }
}

struct AgentUnderstanderTests {
    @Test("推荐购买在本地拒绝，不调用模型")
    func localRefuseRecommend() async {
        let now = TestDates.day(2026, 1, 5)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let understander = AgentUnderstander(
            provider: MockLLMProvider { _ in
                Issue.record("provider should not be called for recommend")
                throw LLMProviderError.unavailable
            }
        )
        let result = await understander.understand(
            input: .text("推荐买点什么"),
            ledger: ledger,
            now: now
        )
        #expect(result == .intent(.recommendPurchase))
    }

    @Test("范围外请求在本地拒绝，不调用模型")
    func localRefuseOutOfScope() async {
        let now = TestDates.day(2026, 1, 5)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let understander = AgentUnderstander(provider: MockLLMProvider.unavailable())
        let result = await understander.understand(
            input: .text("帮我看看这只股票"),
            ledger: ledger,
            now: now
        )
        #expect(result == .intent(.outOfScope))
    }

    @Test("模型不可用时回退本地提取，归属留空")
    func fallbackWhenProviderFails() async throws {
        let now = TestDates.day(2026, 1, 5)
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        _ = try ledger.insertBudgetCard(
            name: "餐饮",
            amount: 1_000,
            currencyCode: "CNY",
            cycleType: .repeating,
            recurrence: .monthly,
            startDate: TestDates.day(2026, 1, 1),
            endDate: TestDates.day(2026, 1, 31),
            now: now
        )
        let understander = AgentUnderstander(provider: MockLLMProvider.unavailable())
        let result = await understander.understand(
            input: .text("星巴克 35 元"),
            ledger: ledger,
            now: now
        )
        guard case .intent(.capture(let draft)) = result else {
            Issue.record("expected capture from fallback")
            return
        }
        #expect(draft.amount == 35)
        #expect(draft.currencyCode == "CNY")
        #expect(draft.merchant == "星巴克")
        #expect(draft.periodID == nil)
        #expect(draft.budgetID == nil)

        let evaluation = AgentActionCoordinator(calendar: TestDates.calendar)
            .evaluate(intent: .capture(draft), ledger: ledger, now: now)
        #expect(evaluation.gate == .confirmStructured)
    }

    @Test("模型成功返回后经校验变成正式意图")
    func providerCandidateIsValidated() async throws {
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
        var candidate = AgentIntentCandidate.capture(amount: "20", currencyCode: "CNY", merchant: "咖啡")
        candidate.budgetName = "餐饮"
        candidate.periodID = created.1.id.uuidString
        let understander = AgentUnderstander(provider: MockLLMProvider.stub(candidate))
        let result = await understander.understand(
            input: .text("咖啡 20"),
            ledger: ledger,
            now: now
        )
        guard case .intent(.capture(let draft)) = result else {
            Issue.record("expected validated capture")
            return
        }
        #expect(draft.amount == 20)
        #expect(draft.periodID == created.1.id)
        #expect(draft.budgetID == created.0.id)
    }

    @Test("按预算卡名称查询剩余")
    func queryByBudgetName() async throws {
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
        var candidate = AgentIntentCandidate(intentType: "queryBudgetStatus")
        candidate.budgetName = "餐饮"
        let understander = AgentUnderstander(provider: MockLLMProvider.stub(candidate))
        let result = await understander.understand(
            input: .text("餐饮还能花多少"),
            ledger: ledger,
            now: now
        )
        #expect(result == .intent(.queryBudgetStatus(budgetID: created.0.id)))
    }

    @Test("语音转写和 OCR 文字走同一管线，只区分来源")
    func multimodalInputsSharePipeline() async {
        let now = TestDates.day(2026, 1, 5)
        let ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let understander = AgentUnderstander(provider: MockLLMProvider.unavailable())

        let speech = await understander.understand(
            input: SpeechCaptureAdapter.input(fromTranscription: "面馆 18 元"),
            ledger: ledger,
            now: now
        )
        let ocr = await understander.understand(
            input: ImageOCRCaptureAdapter.input(fromOCRLines: ["面馆", "18 元"]),
            ledger: ledger,
            now: now
        )
        guard case .intent(.capture(let speechDraft)) = speech,
              case .intent(.capture(let ocrDraft)) = ocr
        else {
            Issue.record("expected capture from both inputs")
            return
        }
        #expect(speechDraft.amount == 18)
        #expect(ocrDraft.amount == 18)
        #expect(speechDraft.sourceType == .voice)
        #expect(ocrDraft.sourceType == .image)
        #expect(AgentPrompt.systemText.contains("No prose, no tools"))
    }
}
