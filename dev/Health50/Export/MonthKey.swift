import Foundation

/// A calendar month in UTC. Records belong to the month in which they start.
struct MonthKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(_ date: Date) {
        let parts = Self.calendar.dateComponents([.year, .month], from: date)
        year = parts.year!
        month = parts.month!
    }

    /// "2026-11"
    init?(name: String) {
        let parts = name.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
        year = y
        month = m
    }

    var name: String { month < 10 ? "\(year)-0\(month)" : "\(year)-\(month)" }
    var description: String { name }
    var fileName: String { "health50-\(name).json" }

    var start: Date { Self.calendar.date(from: DateComponents(year: year, month: month, day: 1))! }
    var end: Date { next.start }
    var next: MonthKey { month == 12 ? MonthKey(year: year + 1, month: 1) : MonthKey(year: year, month: month + 1) }
    var previous: MonthKey { month == 1 ? MonthKey(year: year - 1, month: 12) : MonthKey(year: year, month: month - 1) }

    /// True once the month is over.
    func isClosed(at now: Date = .now) -> Bool { end <= now }

    static func < (a: MonthKey, b: MonthKey) -> Bool { (a.year, a.month) < (b.year, b.month) }

    /// Every month from `first` to `last`, inclusive.
    static func range(_ first: MonthKey, _ last: MonthKey) -> [MonthKey] {
        var result: [MonthKey] = []
        var current = first
        while current <= last {
            result.append(current)
            current = current.next
        }
        return result
    }
}
