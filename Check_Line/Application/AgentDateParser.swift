import Foundation

/// Dates extracted from text use one parser before entering a draft or an intent.
nonisolated enum AgentDateParser {
    static func parse(_ raw: String?, calendar: Calendar = .current) -> Date? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.range(of: #"^\d{4}-\d{2}-\d{2}(?:T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d))?$"#,
                          options: .regularExpression) != nil else { return nil }
        let parts = value.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, parts[0] >= 100 else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        // A date without a clock denotes the user's local day, not midnight UTC.
        gregorian.timeZone = value.count == 10 ? calendar.timeZone : TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let day = gregorian.date(from: components),
              gregorian.dateComponents([.year, .month, .day], from: day) == components else { return nil }
        if value.count == 10 { return gregorian.startOfDay(for: day) }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = value.contains(".")
            ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func isFutureDay(_ date: Date, relativeTo now: Date, calendar: Calendar) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
    }
}
