import Foundation
import HealthKit
import Network

enum WaitReason: String, Codable, Sendable { case wifi, locked, system }
enum FailReason: String, Codable, Sendable { case storage, upload, save, generic }

/// Result of one automatic export run. Stored so the app can show it the next time it opens.
enum SyncOutcome: Codable, Sendable, Equatable {
    case upToDate(Date)
    case noData
    case needsReconnect
    /// Failed for a reason that fixes itself; the app retries on its own.
    case waiting(WaitReason)
    case failed(FailReason)
}

/// Decides which months have to be rewritten. Pure logic, no Health or network access.
enum SyncPlanner {
    static func plan(
        state: SyncState,
        changedMonths: Set<MonthKey>,
        deletions: Int,
        foreground: Bool,
        now: Date
    ) -> (dirty: Set<String>, pendingFullRebuild: Bool) {
        var dirty = state.dirty.union(changedMonths.map(\.name))
        var pending = state.pendingFullRebuild
        if deletions > 0 {
            // Health reports a deletion without its date. Most deletions concern recent data, so the
            // current and the previous month are rewritten now and the rest at the next manual upload.
            let current = MonthKey(now)
            for month in [current, current.previous] where state.months[month.name] != nil {
                dirty.insert(month.name)
            }
            pending = true
        }
        if foreground, pending {
            dirty.formUnion(state.months.keys)
            pending = false
        }
        return (dirty, pending)
    }
}

/// Where month files and the index go. Google Drive in the app; a local folder in debug runs and tests.
protocol ExportDestination: Sendable {
    func findFile(named name: String) async throws -> String?
    /// Stores the file, replacing the one with `existingID` if given. Returns the stored file's ID.
    func upload(file: URL, name: String, existingID: String?) async throws -> String
}

struct DriveDestination: ExportDestination {
    let drive: DriveClient
    let folderID: String

    func findFile(named name: String) async throws -> String? { try await drive.findFile(named: name, in: folderID) }
    func upload(file: URL, name: String, existingID: String?) async throws -> String {
        try await drive.upload(file: file, name: name, folderID: folderID, existingID: existingID)
    }
}

/// Writes into a folder on disk. Used to check the monthly export without a Google account.
struct FolderDestination: ExportDestination {
    let folder: URL

    func findFile(named name: String) async throws -> String? {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path) ? name : nil
    }

    func upload(file: URL, name: String, existingID: String?) async throws -> String {
        let target = folder.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: file, to: target)
        return name
    }
}

/// Keeps the Google Drive folder current: one JSON file per month plus an index file.
actor DriveSync {
    static let shared = DriveSync()

    private let store = HKHealthStore()
    private var running = false

    var isRunning: Bool { running }

    func run(foreground: Bool, allowsCellular: Bool, progress: @Sendable (Double) -> Void = { _ in }) async -> SyncOutcome {
        guard !running else { return .waiting(.system) }
        running = true
        defer { running = false }
        do {
            return try await perform(foreground: foreground, allowsCellular: allowsCellular, progress: progress)
        } catch {
            return Self.outcome(for: error, foreground: foreground)
        }
    }

    private func perform(foreground: Bool, allowsCellular: Bool, progress: @Sendable (Double) -> Void) async throws -> SyncOutcome {
        var state = SyncStateStore.load()
        guard GoogleAuth.shared.isConnected, let folderID = state.folderID else { return .needsReconnect }

        switch await Self.connection() {
        case .none: return foreground ? .failed(.upload) : .waiting(.wifi)
        case .cellular where !allowsCellular: return .waiting(.wifi)
        default: break
        }

        TempFiles.removeAll()
        let destination = DriveDestination(drive: DriveClient(allowsCellular: allowsCellular), folderID: folderID)
        return try await synchronize(state: &state, destination: destination, foreground: foreground, progress: progress) {
            SyncStateStore.save($0)
        }
    }

    #if DEBUG
    /// Runs the same monthly export into a local folder, with its own bookkeeping file next to it.
    func debugLocalRun(into folder: URL) async -> SyncOutcome {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stateFile = folder.appendingPathComponent("debug-sync-state.json")
        var state = (try? JSONDecoder().decode(SyncState.self, from: Data(contentsOf: stateFile))) ?? SyncState()
        do {
            return try await synchronize(state: &state, destination: FolderDestination(folder: folder), foreground: true, progress: { _ in }) {
                try? JSONEncoder().encode($0).write(to: stateFile)
            }
        } catch {
            return Self.outcome(for: error, foreground: true)
        }
    }
    #endif

    /// The run itself, independent of where the files end up.
    func synchronize(
        state: inout SyncState,
        destination: some ExportDestination,
        foreground: Bool,
        progress: @Sendable (Double) -> Void,
        persist: (SyncState) -> Void
    ) async throws -> SyncOutcome {
        let now = Date.now
        let exporter = HealthExporter(store: store)

        // 1. What changed in Health since the last run?
        let changes = try await detectChanges(anchors: state.anchors)
        let plan = SyncPlanner.plan(state: state, changedMonths: changes.months, deletions: changes.deletions, foreground: foreground, now: now)
        state.anchors = changes.anchors
        state.dirty = plan.dirty
        state.pendingFullRebuild = plan.pendingFullRebuild
        persist(state)
        progress(0.05)

        if state.dirty.isEmpty, state.months.isEmpty { return .noData }

        // 2. Rewrite and upload every month that changed, oldest first.
        let months = state.dirty.compactMap(MonthKey.init(name:)).sorted()
        for (index, month) in months.enumerated() {
            try Task.checkCancellation()
            let file = TempFiles.url(named: month.fileName)
            defer { TempFiles.remove(file) }
            let summary = try await exporter.export(.month(month), to: file, now: now)
            let known = state.months[month.name]
            if summary.records > 0 || known != nil {
                var fileID = known?.fileID
                if fileID == nil { fileID = try await destination.findFile(named: month.fileName) }
                let uploaded = try await destination.upload(file: file, name: month.fileName, existingID: fileID)
                state.months[month.name] = MonthRecord(updatedAt: now, records: summary.records, bytes: summary.bytes, fileID: uploaded, types: summary.types)
            }
            state.dirty.remove(month.name)
            persist(state)
            progress(0.05 + 0.9 * Double(index + 1) / Double(months.count))
        }

        if state.months.isEmpty { return .noData }

        // 3. The index file lists what exists.
        let indexFile = TempFiles.url(named: "health50-index.json")
        defer { TempFiles.remove(indexFile) }
        try IndexWriter.write(to: indexFile, state: state, exporter: exporter, now: now)
        var indexID = state.indexFileID
        if indexID == nil { indexID = try await destination.findFile(named: "health50-index.json") }
        state.indexFileID = try await destination.upload(file: indexFile, name: "health50-index.json", existingID: indexID)
        state.lastSuccess = now
        persist(state)
        progress(1)
        return .upToDate(now)
    }

    // MARK: Change detection

    private struct Changes {
        var anchors: [String: Data]
        var months: Set<MonthKey> = []
        var deletions = 0
    }

    /// Asks Health, per data type, for what was added or deleted since the stored marker.
    /// Reads in pages so memory stays bounded even on the very first run.
    private func detectChanges(anchors: [String: Data]) async throws -> Changes {
        var changes = Changes(anchors: anchors)
        let pageSize = 20_000
        for type in HealthCatalog.sampleTypes {
            try Task.checkCancellation()
            var anchor = anchors[type.identifier].flatMap {
                try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
            }
            while true {
                let descriptor = HKAnchoredObjectQueryDescriptor(
                    predicates: [HKSamplePredicate<HKSample>.sample(type: type)],
                    anchor: anchor,
                    limit: pageSize
                )
                let result: HKAnchoredObjectQueryDescriptor<HKSample>.Result
                do {
                    result = try await descriptor.result(for: store)
                } catch let error as HKError where error.code == .errorAuthorizationNotDetermined || error.code == .errorAuthorizationDenied {
                    break
                } catch {
                    throw HealthExporter.mapped(error)
                }
                for sample in result.addedSamples { changes.months.insert(MonthKey(sample.startDate)) }
                changes.deletions += result.deletedObjects.count
                anchor = result.newAnchor
                if result.addedSamples.count + result.deletedObjects.count < pageSize { break }
            }
            if let anchor, let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
                changes.anchors[type.identifier] = data
            }
        }
        return changes
    }

    // MARK: Helpers

    private enum Connection { case none, wifi, cellular }

    private static func connection() async -> Connection {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                if path.status != .satisfied {
                    continuation.resume(returning: .none)
                } else {
                    continuation.resume(returning: path.isExpensive ? .cellular : .wifi)
                }
            }
            monitor.start(queue: DispatchQueue(label: "com.66ideas.health50.network"))
        }
    }

    static func outcome(for error: Error, foreground: Bool) -> SyncOutcome {
        switch error {
        case DriveError.needsReconnect: return .needsReconnect
        case DriveError.network: return foreground ? .failed(.upload) : .waiting(.wifi)
        case DriveError.http: return foreground ? .failed(.upload) : .waiting(.system)
        case ExportError.locked: return .waiting(.locked)
        case ExportError.noSpace: return .failed(.storage)
        case is CancellationError: return .waiting(.system)
        default: return foreground ? .failed(.generic) : .waiting(.system)
        }
    }
}

/// Writes health50-index.json: the list of month files, the profile and an overview per data type.
enum IndexWriter {
    static func write(to url: URL, state: SyncState, exporter: HealthExporter, now: Date) throws {
        let w = try JSONStreamWriter(url: url)
        w.beginObject()
        w.field("format", "health50")
        w.field("formatVersion", HealthExporter.formatVersion)
        w.field("kind", "index")
        w.field("generatedAt", now)
        HealthExporter.writeGenerator(w)
        w.field("access", HealthExporter.accessNote)
        exporter.writeProfile(w)

        w.newline(); w.key("files"); w.beginArray()
        for name in state.months.keys.sorted() {
            guard let month = MonthKey(name: name), let record = state.months[name] else { continue }
            w.newline(); w.beginObject()
            w.field("month", name)
            w.field("name", month.fileName)
            w.field("updatedAt", record.updatedAt)
            w.field("monthClosed", month.isClosed(at: now))
            w.field("records", record.records)
            w.field("bytes", Int(record.bytes))
            w.endObject()
        }
        w.newline(); w.endArray()

        let overview = state.typeOverview
        w.newline(); w.key("types"); w.beginObject()
        for type in overview.keys.sorted() {
            guard let stat = overview[type] else { continue }
            w.newline(); w.key(type); w.beginObject()
            w.field("first", stat.first); w.field("last", stat.last); w.field("records", stat.records)
            w.endObject()
        }
        w.newline(); w.endObject()
        w.newline(); w.endObject()
        try w.close()
    }
}
