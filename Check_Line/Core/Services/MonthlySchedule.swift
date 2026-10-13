import Foundation

/// The chosen days remain stable when a short month temporarily clamps a date.
nonisolated struct MonthlySchedule: Codable, Equatable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable { case cycle, window }

    var kind: Kind = .cycle
    var startDay: Int = 1
    var endDay: Int = 31

    var isValid: Bool { (1...31).contains(startDay) && (kind == .cycle || (1...31).contains(endDay)) }
    var recurrence: RecurrenceRule {
        kind == .cycle ? .monthlyCycle(startDay) : .monthlyWindow(startDay: startDay, endDay: endDay)
    }

    func period(inMonthContaining date: Date, calendar: Calendar) throws -> NextPeriodPlan {
        guard isValid,
              let month = calendar.dateInterval(of: .month, for: date)?.start,
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: month),
              let start = day(startDay, in: month, calendar: calendar),
              let nextStart = day(startDay, in: nextMonth, calendar: calendar),
              let latestEnd = calendar.date(byAdding: .day, value: -1, to: nextStart) else {
            throw LedgerError.repeatingBudgetNeedsRecurrence
        }
        let end: Date
        if kind == .cycle {
            end = latestEnd
        } else {
            let endMonth = endDay < startDay ? nextMonth : month
            guard let requestedEnd = day(endDay, in: endMonth, calendar: calendar) else {
                throw LedgerError.repeatingBudgetNeedsRecurrence
            }
            // A clamped end can meet the following start. That day belongs only to the new period.
            end = min(requestedEnd, latestEnd)
        }
        guard end >= start else { throw LedgerError.repeatingBudgetNeedsRecurrence }
        return NextPeriodPlan(startDate: start, endDate: end)
    }

    func period(containingOrFollowing date: Date, calendar: Calendar) throws -> NextPeriodPlan {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: date),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else {
            throw LedgerError.repeatingBudgetNeedsRecurrence
        }
        let previous = try period(inMonthContaining: previousMonth, calendar: calendar)
        if previous.contains(date, calendar: calendar) { return previous }
        let current = try period(inMonthContaining: date, calendar: calendar)
        if current.contains(date, calendar: calendar) || date < current.startDate { return current }
        return try period(inMonthContaining: nextMonth, calendar: calendar)
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        (try? period(containingOrFollowing: date, calendar: calendar).contains(date, calendar: calendar)) ?? false
    }

    func next(after period: BudgetPeriod, calendar: Calendar) throws -> NextPeriodPlan {
        guard let month = calendar.dateInterval(of: .month, for: period.startDate)?.start,
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else {
            throw LedgerError.repeatingBudgetNeedsRecurrence
        }
        return try self.period(inMonthContaining: nextMonth, calendar: calendar)
    }

    private func day(_ number: Int, in month: Date, calendar: Calendar) -> Date? {
        guard let count = calendar.range(of: .day, in: .month, for: month)?.count else { return nil }
        return calendar.date(byAdding: .day, value: min(number, count) - 1, to: month)
    }
}

extension NextPeriodPlan {
    func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard date >= calendar.startOfDay(for: startDate) else { return false }
        guard let endDate else { return true }
        guard let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) else { return false }
        return date < exclusiveEnd
    }
}
