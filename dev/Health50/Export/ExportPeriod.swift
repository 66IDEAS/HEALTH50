import Foundation

/// The period the user picks for "Save to Files…".
enum ExportPeriod: String, CaseIterable, Sendable {
    case last30Days
    case last12Months
    case fullHistory

    /// Records that start at or after this moment are exported. Nil means no limit.
    func start(now: Date = .now, calendar: Calendar = .current) -> Date? {
        switch self {
        case .last30Days: calendar.date(byAdding: .day, value: -30, to: now)
        case .last12Months: calendar.date(byAdding: .month, value: -12, to: now)
        case .fullHistory: nil
        }
    }

    /// Each period has its own file name, so saving one period never replaces the file of another.
    var fileName: String {
        switch self {
        case .last30Days: "health50-export-30-days.json"
        case .last12Months: "health50-export-12-months.json"
        case .fullHistory: "health50-export.json"
        }
    }

    /// Key of the menu entry in the String Catalog.
    var titleKey: String { "period.\(rawValue)" }

    func scope(now: Date = .now) -> ExportScope {
        if let start = start(now: now) { .range(name: rawValue, from: start) } else { .full }
    }
}
