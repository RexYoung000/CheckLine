import Foundation
import Testing
@testable import CheckLine

struct LibraryPeriodPresentationTests {
    @Test("The stored deadline is still active through the last local hour")
    func inclusiveDeadline() throws {
        let calendar = TestDates.calendar
        let start = TestDates.day(2026, 11, 11, hour: 0)
        let end = TestDates.day(2026, 11, 16, hour: 0)
        let lastHour = end.addingTimeInterval(23 * 3600 + 59 * 60)
        let nextMidnight = TestDates.day(2026, 11, 17, hour: 0)
        let card = try makeCard(start: start, end: end, now: lastHour)

        let lastDay = LibraryPeriodPresentation(card: card, now: lastHour, calendar: calendar)
        #expect(lastDay.status == .endsToday)
        #expect(lastDay.remainingFraction == 1.0 / 6)

        // Home may still hold the active card projection when midnight passes.
        #expect(card.periodState == .active)
        let afterDeadline = LibraryPeriodPresentation(card: card, now: nextMidnight, calendar: calendar)
        #expect(afterDeadline.status == .due)
        #expect(afterDeadline.remainingFraction == 0)
    }

    @Test("Calendar-day segments survive a daylight-saving transition")
    func daylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7)))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 18)))
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10)))
        let card = try makeCard(start: start, end: end, now: now)

        let period = LibraryPeriodPresentation(card: card, now: now, calendar: calendar)
        #expect(period.status == .remaining(days: 2))
        #expect(period.remainingFraction == 0.75)
    }

    @Test("Upcoming and open-ended cards have no progress; a manual close shows settlement")
    func openEnded() throws {
        let calendar = TestDates.calendar
        let now = TestDates.day(2026, 11, 11)
        let start = TestDates.day(2026, 11, 13)
        var card = try makeCard(start: start, end: nil, now: now)

        let upcoming = LibraryPeriodPresentation(card: card, now: now, calendar: calendar)
        #expect(upcoming.status == .upcoming(days: 2))
        #expect(upcoming.remainingFraction == nil)

        let open = LibraryPeriodPresentation(card: card, now: start, calendar: calendar)
        #expect(open.status == .noDeadline)
        #expect(open.remainingFraction == nil)

        card.periodState = .pendingSettlement
        let closed = LibraryPeriodPresentation(card: card, now: start, calendar: calendar)
        #expect(closed.status == .due)
        #expect(closed.remainingFraction == 0)
    }

    private func makeCard(start: Date, end: Date?, now: Date) throws -> HomeBudgetCardModel {
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        _ = try ledger.insertBudgetCard(name: "Trip", amount: 200, currencyCode: "CNY", cycleType: .oneShot,
                                        recurrence: nil, startDate: start, endDate: end, now: now)
        return try #require(HomeProjector.cards(in: ledger, now: now).first)
    }
}
