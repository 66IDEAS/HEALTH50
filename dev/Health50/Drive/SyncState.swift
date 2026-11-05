import Foundation

/// What the app remembers about one month file in Google Drive.
struct MonthRecord: Codable, Sendable, Equatable {
    var updatedAt: Date
    var records: Int
    var bytes: Int64
    var fileID: String?
    var types: [String: TypeStat]
}

/// Technical bookkeeping of the automatic export. Holds no health data.
struct SyncState: Codable, Sendable, Equatable {
    /// How far the app has read in Health, per data type (Health's own change markers).
    var anchors: [String: Data] = [:]
    /// Month files that exist in Drive, by month name ("2026-11").
    var months: [String: MonthRecord] = [:]
    /// Months that changed and still have to be written. Kept so an interrupted run continues.
    var dirty: Set<String> = []
    /// Set when records were deleted in Health. Health reports deletions without a date, so the next
    /// manual upload rewrites every month.
    var pendingFullRebuild = false

    var folderID: String?
    var folderName: String?
    var email: String?
    var indexFileID: String?
    var lastSuccess: Date?

    /// Overview per data type across all months, for the index file.
    var typeOverview: [String: TypeStat] {
        var overview: [String: TypeStat] = [:]
        for month in months.values {
            for (type, stat) in month.types {
                if overview[type] == nil { overview[type] = stat } else { overview[type]!.merge(stat) }
            }
        }
        return overview
    }
}

enum SyncStateStore {
    private static var url: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Health50", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("sync-state.json")
    }

    static func load() -> SyncState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SyncState.self, from: data) else { return SyncState() }
        return state
    }

    static func save(_ state: SyncState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        // Background runs must be able to write this after the first unlock.
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func reset() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Export files are created here and deleted as soon as they are delivered. Nothing is kept.
enum TempFiles {
    private static var folder: URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Health50Exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func url(named name: String) -> URL {
        let url = folder.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        return url
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Removes leftovers of failed or interrupted runs.
    static func removeAll() {
        try? FileManager.default.removeItem(at: folder)
    }
}
