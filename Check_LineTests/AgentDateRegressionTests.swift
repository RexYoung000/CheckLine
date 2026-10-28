import Foundation
import SwiftData
import Testing
@testable import CheckLine

private actor DateCandidateHTTP: HTTPPerforming {
    let candidate: AgentIntentCandidate
    init(_ candidate: AgentIntentCandidate) { self.candidate = candidate }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (try JSONEncoder().encode(candidate),
         HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor
struct AgentDateRegressionTests {
    private let now = TestDates.day(2026, 10, 28)

    @Test("草稿和正式意图保留同一ISO日期，不因毫秒或偏移丢失", arguments: [
        "2026-10-27T02:00:00.000Z", "2026-10-27T02:00:00.123456Z",
        "2026-10-27T02:00:00Z", "2026-10-27T07:45:00.125+05:45", "2026-10-27"
    ])
    func draftAndValidatorShareDates(_ raw: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let expected = try #require(AgentDateParser.parse(raw, calendar: calendar))
        let candidate = AgentIntentCandidate(intentType: "capture", amount: "35", currencyCode: "CNY", occurredAt: raw)
        var task = TaskDraft(occurredAt: now)
        task.agentNeedsDate = true
        task.apply(candidate, calendar: calendar)
        guard case .intent(.capture(let intent)) = IntentValidator.validate(candidate, ledger: .blank(walletCurrencyCode: "CNY", now: now),
                                                                          now: now, sourceType: .agentText, calendar: calendar) else {
            Issue.record("A valid date must survive validation")
            return
        }
        #expect(task.occurredAt == expected && intent.occurredAt == expected)
        #expect(task.agentNeedsDate == false)
        #expect(calendar.component(.day, from: task.occurredAt) == 27)
    }

    @Test("无效显式日期进入核对，不静默使用旧日期", arguments: [
        "2026-02-30", "2026-13-01", "2026-10-27T25:00:00Z", "2026-10-27T02:00:00+24:00",
        "2026-10-27T02:00:00", "yesterday", ""
    ])
    func invalidExplicitDatesRemainUnresolved(_ raw: String) {
        let candidate = AgentIntentCandidate(intentType: "capture", amount: "35", currencyCode: "CNY", occurredAt: raw)
        var task = TaskDraft(occurredAt: now)
        task.apply(candidate, calendar: TestDates.calendar)
        #expect(AgentDateParser.parse(raw, calendar: TestDates.calendar) == nil)
        #expect(task.occurredAt == now && task.agentNeedsDate == true)
        #expect(IntentValidator.validate(candidate, ledger: .blank(walletCurrencyCode: "CNY", now: now), now: now,
                                         sourceType: .agentText) == .needsClarification(field: "occurredAt", options: []))
    }

    @Test("无日期的字段补充保留用户已核对日期和待核对状态")
    func absentDateDoesNotOverwriteState() {
        var task = TaskDraft(occurredAt: now)
        task.agentNeedsDate = true
        task.apply(.capture(amount: "40"))
        #expect(task.occurredAt == now && task.agentNeedsDate == true)
        task.agentNeedsDate = false
        task.apply(.capture(merchant: "Sample"))
        #expect(task.occurredAt == now && task.agentNeedsDate == false)
    }

    @Test("纯日期按设备日历日解析，兼容非UTC与夏令时", arguments: ["Asia/Shanghai", "America/Los_Angeles", "Asia/Kathmandu"])
    func calendarOnlyDateUsesDeviceZone(_ zone: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        let day = try #require(AgentDateParser.parse("2026-03-08", calendar: calendar))
        #expect(calendar.component(.day, from: day) == 8)
        #expect(calendar.component(.hour, from: day) == 0)
        #expect(AgentDateParser.parse("2024-02-29", calendar: calendar) != nil)
        #expect(AgentDateParser.parse("2026-02-29", calendar: calendar) == nil)
    }

    @Test("未来消费按设备日历日判断，同一天稍晚的时间不误判")
    func futureDayUsesLocalCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let localToday = try #require(AgentDateParser.parse("2026-10-27T16:30:00Z"))
        let sameDay = try #require(AgentDateParser.parse("2026-10-28T15:00:00Z"))
        let tomorrow = try #require(AgentDateParser.parse("2026-10-28T16:00:00Z"))
        #expect(!AgentDateParser.isFutureDay(sameDay, relativeTo: localToday, calendar: calendar))
        #expect(AgentDateParser.isFutureDay(tomorrow, relativeTo: localToday, calendar: calendar))
    }

    @Test("云端无效或未来日期在恢复核对时仍被拦，明确选日期后可继续", arguments: ["2026-02-30", "2026-10-29T02:00:00.000Z"])
    func unresolvedDateCannotBypassReview(_ raw: String) async throws {
        let workspace = try workspace(candidate: AgentIntentCandidate(intentType: "capture", amount: "35", currencyCode: "CNY",
                                                                      merchant: "Sample", occurredAt: raw))
        workspace.draftText = "午餐35元"
        await workspace.submitText(now: now)
        #expect(workspace.taskDraft.agentNeedsDate == true)
        #expect(workspace.taskDraft.pendingAgentField == "occurredAt")
        workspace.reviewRetainedTask(now: now)
        #expect(!workspace.showsStructuredConfirm && !workspace.canConfirmProposal)
        workspace.confirmStructured(now: now)
        #expect(workspace.ledger.expenses.isEmpty)

        let reviewedDate = now.addingTimeInterval(-86_400)
        workspace.taskDraft.occurredAt = reviewedDate
        workspace.taskDraft.agentNeedsDate = false
        workspace.chooseCloudBudget(nil, now: now)
        #expect(workspace.showsStructuredConfirm)
        workspace.confirmStructured(now: now)
        let expense = try #require(workspace.ledger.expenses.values.first)
        #expect(expense.occurredAt == reviewedDate && expense.originalAmount == 35)
    }

    @Test("补金额时仍保留此前候选的小数秒日期")
    func dateSurvivesAmountClarification() async throws {
        let raw = "2026-10-27T02:00:00.123Z"
        let candidate = AgentIntentCandidate(intentType: "needsClarification", currencyCode: "CNY", merchant: "Sample",
                                            occurredAt: raw, clarificationField: "amount", requestedIntent: "capture")
        let workspace = try workspace(candidate: candidate)
        workspace.draftText = "昨天午餐"
        await workspace.submitText(now: now)
        workspace.draftText = "35元"
        await workspace.submitText(now: now)
        workspace.chooseCloudBudget(nil, now: now)
        workspace.confirmStructured(now: now)
        let saved = try #require(workspace.ledger.expenses.values.first)
        #expect(saved.occurredAt == AgentDateParser.parse(raw))
    }

    private func workspace(candidate: AgentIntentCandidate) throws -> CheckLineWorkspace {
        let credential = PrivateAgentCredential(endpoint: URL(string: "https://example.test/v1/agent/interpret")!,
            token: String(repeating: "t", count: 40), expiresAt: now.addingTimeInterval(86_400))
        let settings = CloudAgentSettings(credential: credential, consent: true, httpClient: DateCandidateHTTP(candidate))
        return CheckLineWorkspace(context: ModelContext(try CheckLinePersistence.makeContainer(inMemory: true)),
                                  now: now, calendar: TestDates.calendar, cloudSettings: settings)
    }
}
