import Foundation
import SwiftData
import Testing
@testable import CheckLine

/// Synthetic candidates only: no request leaves this injected transport.
private actor ContinuationAgentHTTP: HTTPPerforming {
    private var replies: [String]
    private var requestCount = 0
    private let holdsResponse: Bool
    private var releaseResponse: CheckedContinuation<Void, Never>?

    init(_ replies: [String], holdsResponse: Bool = false) {
        self.replies = replies
        self.holdsResponse = holdsResponse
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        let body = replies.isEmpty ? "{}" : replies.removeFirst()
        if holdsResponse { await withCheckedContinuation { releaseResponse = $0 } }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    func count() -> Int { requestCount }
    func release() { releaseResponse?.resume(); releaseResponse = nil }
}

@MainActor
struct AgentContinuationRegressionTests {
    private let now = TestDates.day(2026, 10, 28)

    private func settings(_ client: ContinuationAgentHTTP) -> CloudAgentSettings {
        let credential = PrivateAgentCredential(endpoint: URL(string: "https://example.test/v1/agent/interpret")!,
            token: String(repeating: "c", count: 40), expiresAt: TestDates.day(2027, 1, 1))
        return CloudAgentSettings(credential: credential, consent: true, httpClient: client)
    }

    private func workspace(_ replies: [String]) throws -> CheckLineWorkspace {
        CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)),
            now: now, calendar: TestDates.calendar, cloudSettings: settings(ContinuationAgentHTTP(replies)))
    }

    private func addBudget(_ name: String, to workspace: CheckLineWorkspace, start: Date? = nil) throws -> UUID {
        let ids = Set(workspace.ledger.budgets.keys)
        workspace.createBudget(name: name, amountText: "1000", currencyCode: "CNY", cycleType: .oneShot,
                               now: start ?? TestDates.day(2026, 10, 1))
        return try #require(workspace.ledger.budgets.keys.first { !ids.contains($0) })
    }

    private func send(_ text: String, to workspace: CheckLineWorkspace) async {
        workspace.draftText = text
        await workspace.submitText(now: now)
    }

    private func offlineExplicitWorkspace() throws -> CheckLineWorkspace {
        let workspace = CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)),
            now: now, calendar: TestDates.calendar, cloudSettings: CloudAgentSettings())
        let budget = try addBudget("餐饮", to: workspace)
        workspace.beginTask(.record, mode: "form", now: now, budgetID: budget)
        workspace.taskDraft.formTouched = true
        workspace.taskDraft.explicitAttribution = true
        workspace.taskDraft.mode = "agent"
        return workspace
    }

    @Test("离线否定、未来和不支持的日期不能按旧日期保存，年份不充当金额", arguments: [
        "午餐35元，不是今天的", "2026-10-29午餐35元", "2026-10-29午餐35", "上周三午餐35元", "今天或昨天午餐35元"
    ])
    func offlineUnreliableDateRequiresReviewWithoutYearAmount(_ text: String) async throws {
        let workspace = try offlineExplicitWorkspace()
        let identity = workspace.taskIdentity
        workspace.taskDraft.occurredAt = TestDates.day(2026, 10, 20)
        workspace.taskDraft.note = "已有备注"
        let attachment = TaskAttachment(data: Data([1, 2, 3]))
        workspace.taskDraft.attachments = [attachment]
        await send(text, to: workspace)
        #expect(workspace.taskIdentity == identity)
        #expect(workspace.taskDraft.amount == "35")
        #expect(workspace.taskDraft.note == "已有备注" && workspace.taskDraft.attachments == [attachment])
        #expect(workspace.taskDraft.occurredAt == TestDates.day(2026, 10, 20))
        #expect(workspace.taskDraft.agentNeedsDate == true && workspace.taskDraft.pendingAgentField == "occurredAt")
        #expect(!workspace.showsStructuredConfirm && !workspace.canConfirmProposal)
        workspace.reviewRetainedTask(now: now)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("离线单独否定日期保留已知消费，明确昨天续答仍可完成")
    func offlineDateCorrectionPreservesFactsAndAcceptsExplicitAnswer() async throws {
        let workspace = try offlineExplicitWorkspace()
        workspace.taskDraft.amount = "35"
        workspace.taskDraft.merchant = "午餐"
        workspace.taskDraft.note = "已有备注"
        let identity = workspace.taskIdentity
        await send("不是今天的", to: workspace)
        #expect(workspace.taskIdentity == identity)
        #expect(workspace.taskDraft.amount == "35" && workspace.taskDraft.merchant == "午餐")
        #expect(workspace.taskDraft.agentNeedsDate == true && workspace.ledger.expenses.isEmpty)
        await send("昨天", to: workspace)
        let saved = try #require(workspace.ledger.expenses[identity.entityID])
        #expect(saved.originalAmount == 35 && saved.merchant == "午餐" && saved.note == "已有备注")
        #expect(TestDates.calendar.isDate(saved.occurredAt, inSameDayAs: TestDates.day(2026, 10, 27)))
    }

    @Test("离线明确今天和昨天的消费保留低风险记录路径", arguments: [0, -1])
    func offlineSimpleDaysStillRecordAtExplicitDay(_ offset: Int) async throws {
        let workspace = try offlineExplicitWorkspace()
        let identity = workspace.taskIdentity
        await send(offset == 0 ? "今天午餐35元" : "昨天午餐35元", to: workspace)
        let saved = try #require(workspace.ledger.expenses[identity.entityID])
        let expected = try #require(TestDates.calendar.date(byAdding: .day, value: offset, to: now))
        #expect(saved.originalAmount == 35 && saved.merchant == "午餐")
        #expect(TestDates.calendar.isDate(saved.occurredAt, inSameDayAs: expected))
        #expect(workspace.agentBanner == .recorded && workspace.lastUndo != nil)
    }

    @Test("离线单独日期不变成年份金额，无关日期提问不复用已知消费")
    func offlineDateOnlyAndUnrelatedMessageCannotReuseExpense() async throws {
        let workspace = try offlineExplicitWorkspace()
        await send("2026-10-29", to: workspace)
        #expect(workspace.taskDraft.amount.isEmpty && workspace.ledger.expenses.isEmpty)
        workspace.taskDraft.agentNeedsDate = false
        workspace.taskDraft.amount = "35"
        workspace.taskDraft.merchant = "午餐"
        await send("今天天气26度", to: workspace)
        #expect(workspace.taskDraft.amount == "35")
        #expect(!workspace.showsStructuredConfirm && workspace.ledger.expenses.isEmpty)
    }

    @Test("明确新预算替换旧归属，并按消费日解析新预算的实际周期")
    func explicitNewBudgetReplacesOldAttributionAtExpenseDate() async throws {
        let workspace = try workspace([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"午餐","occurredAt":"2026-10-10T12:00:00.000Z"}"#,
            #"{"intentType":"needsClarification","requestedIntent":"capture","budgetName":"交通","clarificationField":"amount"}"#
        ])
        let a = try addBudget("餐饮", to: workspace)
        let b = try addBudget("交通", to: workspace)
        let firstB = try #require(workspace.ledger.periods.values.first { $0.budgetID == b })
        workspace.ledger.periods[firstB.id]?.endDate = TestDates.day(2026, 10, 15)
        var next = firstB
        next.id = UUID(); next.sequence = 2
        next.startDate = TestDates.day(2026, 10, 16); next.endDate = nil
        workspace.ledger.upsert(next)
        workspace.beginTask(.record, mode: "agent", now: now)
        await send("午餐35元，10月10日的", to: workspace)
        workspace.chooseCloudBudget(a, now: now)
        let identity = workspace.taskIdentity
        await send("这笔记到交通预算", to: workspace)
        #expect(workspace.taskIdentity == identity)
        #expect(workspace.captureProposal?.periodID == firstB.id)
        #expect(workspace.captureProposal?.periodID != next.id)
        #expect(workspace.ledger.expenses.isEmpty)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses[identity.entityID]?.budgetPeriodID == firstB.id)
    }

    @Test("否定旧归属的空候选清掉旧选卡，续答前不能核对或提交")
    func deniedAttributionClearsOldSelectionUntilExplicitAnswer() async throws {
        let workspace = try workspace([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"午餐"}"#,
            #"{"intentType":"needsClarification","clarificationField":"budgetName"}"#
        ])
        let a = try addBudget("餐饮", to: workspace)
        workspace.beginTask(.record, mode: "agent", now: now, budgetID: a)
        await send("午餐35元", to: workspace)
        workspace.chooseCloudBudget(a, now: now)
        let identity = workspace.taskIdentity
        await send("这笔不计入餐饮预算", to: workspace)
        #expect(workspace.taskIdentity == identity)
        #expect(!workspace.taskDraft.explicitAttribution)
        #expect(workspace.taskDraft.agentEntryExplicitBudget == false)
        #expect(workspace.taskDraft.agentBudgetName == nil)
        #expect(workspace.taskDraft.pendingAgentField == "budgetName")
        #expect(!workspace.showsStructuredConfirm && !workspace.canConfirmProposal)
        workspace.reviewRetainedTask(now: now)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
        workspace.chooseCloudBudget(nil, now: now)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses[identity.entityID]?.budgetPeriodID == nil)
        #expect(workspace.ledger.expenses.count == 1)
    }

    @Test("重名、未知和无有效周期的新预算都不会退回旧归属", arguments: ["duplicate", "unknown", "unavailable"])
    func unresolvedNewBudgetDoesNotFallBackToPreviousBudget(_ reason: String) async throws {
        let workspace = try workspace([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"午餐"}"#,
            #"{"intentType":"capture","budgetName":"交通"}"#
        ])
        let a = try addBudget("餐饮", to: workspace)
        if reason != "unknown" {
            let b = try addBudget("交通", to: workspace)
            if reason == "duplicate" { _ = try addBudget("交通", to: workspace) }
            else {
                let period = try #require(workspace.ledger.periods.values.first { $0.budgetID == b })
                workspace.ledger.periods[period.id]?.endDate = TestDates.day(2026, 10, 20)
            }
        }
        workspace.beginTask(.record, mode: "agent", now: now)
        await send("午餐35元", to: workspace)
        workspace.chooseCloudBudget(a, now: now)
        let identity = workspace.taskIdentity
        await send("这笔改到交通预算", to: workspace)
        #expect(workspace.taskIdentity == identity)
        #expect(workspace.taskDraft.attributionID == "unbudgeted")
        #expect(!workspace.taskDraft.explicitAttribution)
        #expect(!workspace.showsStructuredConfirm)
        #expect(workspace.agentBanner == (reason == "unavailable" ? .needsPeriod : .needsClarification("budgetName")))
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("金额先补全后仍须核对缺失日期，短日期回答保持同一任务")
    func amountAnswerDoesNotErasePendingDateReview() async throws {
        let http = ContinuationAgentHTTP([
            #"{"intentType":"needsClarification","requestedIntent":"capture","merchant":"午餐","currencyCode":"CNY","clarificationField":"occurredAt"}"#
        ])
        let workspace = CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)),
            now: now, calendar: TestDates.calendar, cloudSettings: settings(http))
        await send("记一笔午餐，日期还没核对", to: workspace)
        let identity = workspace.taskIdentity
        #expect(workspace.taskDraft.pendingAgentField == "amount")
        await send("35元", to: workspace)
        #expect(workspace.taskDraft.agentNeedsDate == true)
        #expect(workspace.taskDraft.pendingAgentField == "occurredAt")
        #expect(!workspace.canConfirmProposal)
        workspace.reviewRetainedTask(now: now)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
        await send("2026-10-27", to: workspace)
        #expect(await http.count() == 1)
        #expect(workspace.taskIdentity == identity)
        #expect(workspace.taskDraft.agentNeedsDate == false)
        #expect(TestDates.calendar.isDate(workspace.taskDraft.occurredAt, inSameDayAs: TestDates.day(2026, 10, 27)))
        workspace.chooseCloudBudget(nil, now: now)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses[identity.entityID]?.originalAmount == 35)
    }

    @Test("归属和日期同时待核对时选卡与取消都不能抹掉日期门禁")
    func combinedAttributionAndDateReviewSurvivesBudgetSelectionAndCancel() async throws {
        let workspace = try workspace([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"午餐"}"#,
            #"{"intentType":"needsClarification","requestedIntent":"capture","clarificationField":"budgetName","requiresDateReview":true}"#
        ])
        let a = try addBudget("餐饮", to: workspace)
        let b = try addBudget("交通", to: workspace)
        workspace.beginTask(.record, mode: "agent", now: now)
        await send("午餐35元", to: workspace)
        workspace.chooseCloudBudget(a, now: now)
        let identity = workspace.taskIdentity
        await send("这笔不计入餐饮预算，日期不是今天", to: workspace)
        #expect(!workspace.taskDraft.explicitAttribution)
        #expect(workspace.taskDraft.agentNeedsDate == true)
        workspace.chooseCloudBudget(b, now: now)
        #expect(workspace.taskDraft.pendingAgentField == "occurredAt")
        #expect(workspace.taskDraft.agentNeedsDate == true && !workspace.canConfirmProposal)
        workspace.leaveTaskReview()
        workspace.reviewRetainedTask(now: now)
        workspace.confirmStructured(now: now)
        #expect(workspace.taskIdentity == identity)
        #expect(workspace.taskDraft.agentNeedsDate == true)
        #expect(workspace.ledger.expenses.isEmpty)
        workspace.taskDraft.occurredAt = TestDates.day(2026, 10, 27)
        workspace.taskDraft.agentNeedsDate = false // The existing date picker explicitly validates the chosen day.
        workspace.reviewRetainedTask(now: now)
        #expect(workspace.showsStructuredConfirm)
        workspace.confirmStructured(now: now)
        let saved = try #require(workspace.ledger.expenses[identity.entityID])
        #expect(workspace.ledger.periods[try #require(saved.budgetPeriodID)]?.budgetID == b)
    }

    @Test("动作追问保留归属与日期双重门禁，日期核对后仍须重新选卡", arguments: ["budgetB", "unbudgeted"])
    func actionClarificationPreservesBothRequiredReviews(_ destination: String) async throws {
        let workspace = try workspace([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"午餐","note":"保留备注"}"#,
            #"{"intentType":"needsClarification","budgetName":"餐饮","clarificationField":"action","requiresBudgetReview":true,"requiresDateReview":true}"#
        ])
        let a = try addBudget("餐饮", to: workspace)
        let b = try addBudget("交通", to: workspace)
        workspace.beginTask(.record, mode: "agent", now: now)
        await send("午餐35元，保留备注", to: workspace)
        workspace.chooseCloudBudget(a, now: now)
        let identity = workspace.taskIdentity
        await send("这笔需要重新核对操作、日期和预算", to: workspace)
        #expect(workspace.cloudPendingAction != nil && !workspace.canConfirmProposal)
        workspace.resolveCloudOperation(.record, now: now)
        #expect(workspace.taskIdentity == identity)
        #expect(workspace.taskDraft.amount == "35" && workspace.taskDraft.merchant == "午餐" && workspace.taskDraft.note == "保留备注")
        #expect(!workspace.taskDraft.explicitAttribution && workspace.taskDraft.agentEntryExplicitBudget == false)
        #expect(workspace.taskDraft.attributionID == "unbudgeted" && workspace.taskDraft.agentBudgetName == nil)
        #expect(workspace.taskDraft.agentNeedsDate == true)
        #expect(workspace.taskDraft.pendingAgentField == "occurredAt" && !workspace.canConfirmProposal)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
        workspace.taskDraft.occurredAt = TestDates.day(2026, 10, 27)
        workspace.taskDraft.agentNeedsDate = false // Explicit date picker review.
        workspace.reviewRetainedTask(now: now)
        #expect(workspace.taskDraft.pendingAgentField == "budgetName")
        #expect(!workspace.showsStructuredConfirm && !workspace.canConfirmProposal)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)
        workspace.chooseCloudBudget(destination == "budgetB" ? b : nil, now: now)
        #expect(workspace.showsStructuredConfirm && workspace.canConfirmProposal)
        workspace.confirmStructured(now: now)
        let saved = try #require(workspace.ledger.expenses[identity.entityID])
        #expect(saved.originalAmount == 35)
        if destination == "budgetB" {
            #expect(workspace.ledger.periods[try #require(saved.budgetPeriodID)]?.budgetID == b)
        } else {
            #expect(saved.budgetPeriodID == nil)
        }
        #expect(workspace.ledger.expenses.count == 1)
    }

    @Test("动作追问选择同一操作后合并修正，保留任务身份原文和附件")
    func sameOperationClarificationPreservesKnownFactsAndAttachments() async throws {
        let workspace = try workspace([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"午餐","note":"原备注","occurredAt":"2026-10-27T12:00:00.000Z"}"#,
            #"{"intentType":"needsClarification","currencyCode":"USD","clarificationField":"action"}"#
        ])
        await send("午餐35元，昨天的，原备注", to: workspace)
        let identity = workspace.taskIdentity
        let date = workspace.taskDraft.occurredAt
        let attachment = TaskAttachment(data: Data([1, 2, 3]))
        workspace.taskDraft.attachments = [attachment]
        await send("币种改为美元，不是人民币", to: workspace)
        #expect(workspace.cloudPendingAction != nil)
        workspace.resolveCloudOperation(.record, now: now)
        #expect(workspace.taskIdentity == identity)
        #expect(workspace.taskDraft.amount == "35" && workspace.taskDraft.merchant == "午餐")
        #expect(workspace.taskDraft.currency == "USD" && workspace.taskDraft.note == "原备注")
        #expect(workspace.taskDraft.occurredAt == date && workspace.taskDraft.attachments == [attachment])
        #expect(workspace.taskSourceText == "午餐35元，昨天的，原备注\n币种改为美元，不是人民币")
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("明确更正当前商家保留金额，裸新商家不继承旧金额")
    func merchantCorrectionAndBareNewDescriptionRemainDistinct() async throws {
        for text in ["这笔商家改为午餐", "午餐"] {
            let workspace = try workspace([
                #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"咖啡"}"#,
                #"{"intentType":"capture","merchant":"午餐"}"#
            ])
            await send("咖啡35元", to: workspace)
            let identity = workspace.taskIdentity
            await send(text, to: workspace)
            #expect(workspace.taskDraft.merchant == "午餐")
            if text == "午餐" {
                #expect(workspace.taskIdentity != identity)
                #expect(workspace.taskDraft.amount.isEmpty)
                #expect(workspace.agentBanner == .needsAmount)
            } else {
                #expect(workspace.taskIdentity == identity)
                #expect(workspace.taskDraft.amount == "35")
            }
            #expect(workspace.ledger.expenses.isEmpty)
        }
    }

    @Test("明确另记后的动作追问只带新候选，旧金额备注附件不跨任务")
    func explicitNewTaskDoesNotReuseOldFactsAfterActionClarification() async throws {
        let workspace = try workspace([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"咖啡","note":"旧备注"}"#,
            #"{"intentType":"needsClarification","merchant":"午餐","clarificationField":"action"}"#
        ])
        await send("咖啡35元", to: workspace)
        workspace.taskDraft.attachments = [TaskAttachment(data: Data([1]))]
        let identity = workspace.taskIdentity
        await send("另记一笔午餐", to: workspace)
        workspace.resolveCloudOperation(.record, now: now)
        #expect(workspace.taskIdentity != identity)
        #expect(workspace.taskDraft.amount.isEmpty && workspace.taskDraft.note.isEmpty)
        #expect(workspace.taskDraft.attachments.isEmpty)
        #expect(workspace.taskDraft.merchant == "午餐")
        #expect(workspace.taskSourceText == "另记一笔午餐")
        #expect(workspace.agentBanner == .needsAmount)
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("动作追问改选其他操作创建独立草稿，不搬运旧消费事实")
    func differentOperationStartsIndependentDraft() async throws {
        let workspace = try workspace([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"咖啡","note":"旧备注"}"#,
            #"{"intentType":"needsClarification","amount":"1200","currencyCode":"CNY","name":"旅行","cycleType":"oneShot","clarificationField":"action"}"#
        ])
        await send("咖啡35元", to: workspace)
        workspace.taskDraft.attachments = [TaskAttachment(data: Data([1]))]
        let identity = workspace.taskIdentity
        await send("改成一次性旅行1200元", to: workspace)
        workspace.resolveCloudOperation(.budget, now: now)
        #expect(workspace.taskIdentity != identity)
        #expect(workspace.taskDraft.kind == "budget" && workspace.taskDraft.amount == "1200")
        #expect(workspace.taskDraft.name == "旅行")
        #expect(workspace.taskDraft.merchant.isEmpty && workspace.taskDraft.note.isEmpty && workspace.taskDraft.attachments.isEmpty)
        #expect(workspace.taskSourceText == "改成一次性旅行1200元")
        #expect(workspace.showsStructuredConfirm)
        #expect(workspace.ledger.expenses.isEmpty && workspace.ledger.budgets.isEmpty)
    }

    @Test("取消歧义动作使旧选择失效，保留已有消费事实")
    func cancellingPendingOperationInvalidatesOldSelection() async throws {
        let workspace = try workspace([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"咖啡"}"#,
            #"{"intentType":"needsClarification","currencyCode":"USD","clarificationField":"action"}"#
        ])
        await send("咖啡35元", to: workspace)
        await send("币种改为美元，不是人民币", to: workspace)
        workspace.leaveTaskReview()
        let retained = workspace.taskDraft
        workspace.resolveCloudOperation(.record, now: now)
        #expect(workspace.cloudPendingAction == nil)
        #expect(workspace.taskDraft == retained)
        #expect(workspace.taskDraft.currency == "CNY" && workspace.taskDraft.amount == "35")
        #expect(!workspace.showsStructuredConfirm)
        #expect(workspace.ledger.expenses.isEmpty)
    }

    @Test("切任务并取消网络后迟到候选不能修改或执行新任务")
    func cancelledCallbackCannotPolluteNewTask() async throws {
        let http = ContinuationAgentHTTP([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"咖啡"}"#
        ], holdsResponse: true)
        let workspace = CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)),
            now: now, calendar: TestDates.calendar, cloudSettings: settings(http))
        workspace.draftText = "咖啡35元"
        let pending = Task { await workspace.submitText(now: now) }
        while await http.count() == 0 { await Task.yield() }
        workspace.closeTaskPanel()
        workspace.beginTask(.budget, mode: "form", now: now)
        workspace.taskDraft.name = "新任务"
        let retained = workspace.taskDraft
        await http.release()
        await pending.value
        #expect(workspace.taskDraft == retained)
        #expect(!workspace.isWorking && workspace.cloudPendingAction == nil)
        #expect(workspace.ledger.expenses.isEmpty && workspace.ledger.budgets.isEmpty)
    }

    @Test("同任务修正跨重启保留，保存失败重试仍仅写入一次")
    func restoredCorrectionRetainsIdentityThroughSaveFailureRetry() async throws {
        final class SaveSwitch { var fails = true }
        let toggle = SaveSwitch()
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let drafts = TaskDraftStore(inMemory: true)
        let http = ContinuationAgentHTTP([
            #"{"intentType":"capture","amount":"35","currencyCode":"CNY","merchant":"咖啡","note":"保留备注"}"#,
            #"{"intentType":"needsClarification","amount":"40","clarificationField":"action"}"#
        ])
        let first = CheckLineWorkspace(context: ModelContext(container), now: now, calendar: TestDates.calendar,
            draftStore: drafts, cloudSettings: settings(http))
        await send("咖啡35元", to: first)
        let identity = first.taskIdentity
        await send("金额需要改为40块钱", to: first)
        first.resolveCloudOperation(.record, now: now)
        first.chooseCloudBudget(nil, now: now)
        first.leaveTaskReview()
        let restored = CheckLineWorkspace(context: ModelContext(container), now: now, calendar: TestDates.calendar,
            saveLedger: { ledger, context in
                if toggle.fails { throw CocoaError(.fileWriteUnknown) }
                try LedgerStore.replaceAll(ledger, in: context)
            }, draftStore: drafts, cloudSettings: settings(ContinuationAgentHTTP([])))
        restored.resumeAgentTask()
        #expect(restored.taskIdentity == identity)
        #expect(restored.taskDraft.amount == "40" && restored.taskDraft.merchant == "咖啡" && restored.taskDraft.note == "保留备注")
        restored.reviewRetainedTask(now: now)
        #expect(restored.showsStructuredConfirm)
        restored.confirmStructured(now: now)
        #expect(restored.agentBanner == .failed && restored.ledger.expenses.isEmpty)
        #expect(restored.taskIdentity == identity && restored.canConfirmProposal)
        toggle.fails = false
        restored.confirmStructured(now: now)
        restored.confirmStructured(now: now)
        #expect(restored.ledger.expenses.count == 1)
        #expect(restored.ledger.expenses[identity.entityID]?.originalAmount == 40)
        #expect(try LedgerStore.load(from: ModelContext(container), now: now).expenses.count == 1)
    }
}
