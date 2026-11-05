import CoreLocation
import HealthKit

/// What one export file covers.
enum ExportScope: Sendable {
    /// The full accessible history in one file (manual "Save to Files…").
    case full
    /// All records that start at or after a moment (manual "Save to Files…" with a limited period).
    case range(name: String, from: Date)
    /// All records that start in one UTC month.
    case month(MonthKey)

    var from: Date? {
        switch self {
        case .full: nil
        case .range(_, let from): from
        case .month(let month): month.start
        }
    }

    var to: Date? { if case .month(let m) = self { m.end } else { nil } }

    /// Manual saves carry the profile; month files do not, because the index has it.
    var isManual: Bool { if case .month = self { false } else { true } }
}

struct TypeStat: Codable, Sendable, Equatable {
    var first: Date
    var last: Date
    var records: Int

    mutating func merge(_ other: TypeStat) {
        first = min(first, other.first)
        last = max(last, other.last)
        records += other.records
    }
}

struct ExportSummary: Sendable {
    var records = 0
    var bytes: Int64 = 0
    var types: [String: TypeStat] = [:]
}

enum ExportError: Error, Equatable {
    /// Health data cannot be read while the iPhone is locked.
    case locked
    /// Not enough free space to write the export.
    case noSpace
}

/// Reads health records and writes them in the Health50 export format (see specs/export-format.md).
struct HealthExporter: Sendable {
    static let formatVersion = 1
    static let accessNote = "Contains only the data the user allowed Health50 to read. "
        + "A missing data type can mean that access was not given or that no data exists."
    static let pageSize = 20_000
    /// Apple introduced Health in 2014. Nothing in Health's activity history can be older.
    static let firstHealthYear = 2014

    let store: HKHealthStore

    // MARK: Authorization

    /// Asks for read access to every supported type. Never asks for write access.
    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: HealthCatalog.readTypes)
    }

    /// True when there are data types iOS has not asked the user about yet.
    func hasTypesToReview() async -> Bool {
        (try? await store.statusForAuthorizationRequest(toShare: [], read: HealthCatalog.readTypes)) == .shouldRequest
    }

    // MARK: Export

    /// Writes one export file. Returns how many records it contains.
    func export(
        _ scope: ExportScope,
        to url: URL,
        now: Date = .now,
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws -> ExportSummary {
        let session = try Session(url: url)
        do {
            try await write(scope, session: session, now: now, progress: progress)
            try session.writer.close()
        } catch {
            try? session.writer.close()
            try? FileManager.default.removeItem(at: url)
            throw Self.mapped(error)
        }
        var summary = session.summary
        summary.bytes = session.writer.bytesWritten
        return summary
    }

    private func write(_ scope: ExportScope, session: Session, now: Date, progress: @Sendable (Double) -> Void) async throws {
        let w = session.writer
        let range = (from: scope.from, to: scope.to)
        let steps = Double(HealthCatalog.quantities.count + HealthCatalog.categories.count + 8)
        var done = 0.0
        func tick() { done += 1; progress(min(done / steps, 1)) }

        w.beginObject()
        w.field("format", "health50")
        w.field("formatVersion", Self.formatVersion)
        switch scope {
        case .full:
            w.field("kind", "full")
        case .range(let name, let from):
            w.field("kind", "range")
            w.key("period"); w.beginObject()
            w.field("name", name); w.field("from", from); w.field("to", now)
            w.endObject()
        case .month(let month):
            w.field("kind", "month")
            w.key("period"); w.beginObject()
            w.field("month", month.name); w.field("from", month.start); w.field("to", month.end)
            w.endObject()
            w.field("monthClosed", month.isClosed(at: now))
        }
        w.field("generatedAt", now)
        Self.writeGenerator(w)
        w.field("access", Self.accessNote)
        if scope.isManual { writeProfile(w) }

        // quantities
        var sectionOpen = false
        for kind in HealthCatalog.quantities {
            var typeOpen = false
            try await pages({ .quantitySample(type: kind.type, predicate: $0) }, range) { page in
                if !sectionOpen { w.newline(); w.key("quantities"); w.beginObject(); sectionOpen = true }
                if !typeOpen {
                    w.newline(); w.key(kind.identifier); w.beginObject()
                    w.field("unit", kind.unit.unitString); w.key("samples"); w.beginArray()
                    typeOpen = true
                }
                for sample in page {
                    w.newline(); w.beginObject()
                    session.head(sample, type: kind.identifier)
                    w.field("value", sample.quantity.doubleValue(for: kind.unit))
                    session.tail(sample)
                    w.endObject()
                }
            }
            if typeOpen { w.newline(); w.endArray(); w.endObject() }
            tick()
        }
        if sectionOpen { w.newline(); w.endObject() }

        // categories
        sectionOpen = false
        for kind in HealthCatalog.categories {
            var typeOpen = false
            try await pages({ .categorySample(type: kind.type, predicate: $0) }, range) { page in
                if !sectionOpen { w.newline(); w.key("categories"); w.beginObject(); sectionOpen = true }
                if !typeOpen {
                    w.newline(); w.key(kind.identifier); w.beginObject(); w.key("samples"); w.beginArray()
                    typeOpen = true
                }
                for sample in page {
                    w.newline(); w.beginObject()
                    session.head(sample, type: kind.identifier)
                    if let name = kind.valueNames[sample.value] { w.field("value", name) }
                    w.field("code", sample.value)
                    session.tail(sample)
                    w.endObject()
                }
            }
            if typeOpen { w.newline(); w.endArray(); w.endObject() }
            tick()
        }
        if sectionOpen { w.newline(); w.endObject() }

        try await list("workouts", session, { .workout($0) }, range) { workout in
            try await self.encode(workout, session)
        }
        tick()

        sectionOpen = false
        for type in HealthCatalog.correlationTypes {
            try await pages({ .correlation(type: type, predicate: $0) }, range) { page in
                if !sectionOpen { w.newline(); w.key("correlations"); w.beginArray(); sectionOpen = true }
                for correlation in page { w.newline(); self.encode(correlation, type, session) }
            }
        }
        if sectionOpen { w.newline(); w.endArray() }
        tick()

        try await list("electrocardiograms", session, { .electrocardiogram($0) }, range) { ecg in
            try await self.encode(ecg, session)
        }
        tick()

        try await list("heartbeatSeries", session, { .heartbeatSeries($0) }, range) { series in
            try await self.encode(series, session)
        }
        tick()

        try await list("audiograms", session, { .audiogram($0) }, range) { audiogram in
            self.encode(audiogram, session)
        }
        tick()

        try await list("statesOfMind", session, { .stateOfMind($0) }, range) { state in
            self.encode(state, session)
        }
        tick()

        sectionOpen = false
        try await pages({ .gad7Assessment($0) }, range) { page in
            if !sectionOpen { w.newline(); w.key("scoredAssessments"); w.beginArray(); sectionOpen = true }
            for item in page {
                w.newline()
                self.encodeAssessment(item, type: "HKScoredAssessmentTypeIdentifierGAD7", answers: item.answers.map(\.rawValue),
                                      risk: HealthCatalog.name("HKGAD7AssessmentRisk", item.risk.rawValue), session)
            }
        }
        try await pages({ .phq9Assessment($0) }, range) { page in
            if !sectionOpen { w.newline(); w.key("scoredAssessments"); w.beginArray(); sectionOpen = true }
            for item in page {
                w.newline()
                self.encodeAssessment(item, type: "HKScoredAssessmentTypeIdentifierPHQ9", answers: item.answers.map(\.rawValue),
                                      risk: HealthCatalog.name("HKPHQ9AssessmentRisk", item.risk.rawValue), session)
            }
        }
        if sectionOpen { w.newline(); w.endArray() }
        tick()

        try await writeActivitySummaries(scope, session)
        tick()

        if case .full = scope, let first = session.firstRecord, let last = session.lastRecord {
            w.newline(); w.key("period"); w.beginObject()
            w.field("from", first); w.field("to", last)
            w.endObject()
        }
        session.writeSources()
        w.newline()
        w.endObject()
        progress(1)
    }

    // MARK: Paging

    /// Reads all samples of one type in pages, oldest first, so memory stays bounded.
    /// A type the user has not allowed simply yields nothing.
    private func pages<S: HKSample>(
        _ make: (NSPredicate?) -> HKSamplePredicate<S>,
        _ range: (from: Date?, to: Date?),
        _ body: ([S]) async throws -> Void
    ) async throws {
        var cursor = range.from
        var seenAtCursor = Set<UUID>()
        while true {
            try Task.checkCancellation()
            let descriptor = HKSampleQueryDescriptor(
                predicates: [make(Self.predicate(from: cursor, to: range.to))],
                sortDescriptors: [SortDescriptor(\S.startDate, order: .forward)],
                limit: Self.pageSize
            )
            let page: [S]
            do {
                page = try await descriptor.result(for: store)
            } catch let error as HKError where error.code == .errorAuthorizationNotDetermined || error.code == .errorAuthorizationDenied {
                return
            }
            let fresh = seenAtCursor.isEmpty ? page : page.filter { !seenAtCursor.contains($0.uuid) }
            if !fresh.isEmpty { try await body(fresh) }
            guard page.count == Self.pageSize, let last = page.last else { return }
            if last.startDate == cursor, fresh.isEmpty { return }
            if last.startDate != cursor { seenAtCursor.removeAll() }
            cursor = last.startDate
            for sample in page.reversed() {
                guard sample.startDate == last.startDate else { break }
                seenAtCursor.insert(sample.uuid)
            }
        }
    }

    /// Writes one array section, leaving it out when there is nothing to write.
    private func list<S: HKSample>(
        _ name: String,
        _ session: Session,
        _ make: (NSPredicate?) -> HKSamplePredicate<S>,
        _ range: (from: Date?, to: Date?),
        _ encode: (S) async throws -> Void
    ) async throws {
        var open = false
        try await pages(make, range) { page in
            if !open { session.writer.newline(); session.writer.key(name); session.writer.beginArray(); open = true }
            for sample in page { session.writer.newline(); try await encode(sample) }
        }
        if open { session.writer.newline(); session.writer.endArray() }
    }

    static func predicate(from: Date?, to: Date?) -> NSPredicate? {
        var parts: [NSPredicate] = []
        if let from { parts.append(NSPredicate(format: "%K >= %@", HKPredicateKeyPathStartDate, from as NSDate)) }
        if let to { parts.append(NSPredicate(format: "%K < %@", HKPredicateKeyPathStartDate, to as NSDate)) }
        return parts.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }

    static func mapped(_ error: Error) -> Error {
        if let error = error as? HKError, error.code == .errorDatabaseInaccessible { return ExportError.locked }
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSFileWriteOutOfSpaceError { return ExportError.noSpace }
        if ns.domain == NSPOSIXErrorDomain, ns.code == Int(ENOSPC) { return ExportError.noSpace }
        return error
    }

    // MARK: Record encoding

    private func encode(_ workout: HKWorkout, _ session: Session) async throws {
        let w = session.writer
        w.beginObject()
        w.field("id", workout.uuid.uuidString)
        w.field("activity", HealthCatalog.activityName(workout.workoutActivityType))
        w.field("activityCode", Int(workout.workoutActivityType.rawValue))
        session.times(workout, type: "HKWorkoutTypeIdentifier")
        w.field("duration", workout.duration)
        w.field("source", session.sourceKey(workout))

        let statistics = workout.allStatistics
            .compactMap { type, stats in HealthCatalog.quantityByIdentifier[type.identifier].map { ($0, stats) } }
            .sorted { $0.0.identifier < $1.0.identifier }
        if !statistics.isEmpty {
            w.key("statistics"); w.beginObject()
            for (kind, stats) in statistics {
                w.key(kind.identifier); w.beginObject()
                if let q = stats.sumQuantity() { w.field("sum", q.doubleValue(for: kind.unit)) }
                if let q = stats.averageQuantity() { w.field("average", q.doubleValue(for: kind.unit)) }
                if let q = stats.minimumQuantity() { w.field("minimum", q.doubleValue(for: kind.unit)) }
                if let q = stats.maximumQuantity() { w.field("maximum", q.doubleValue(for: kind.unit)) }
                w.field("unit", kind.unit.unitString)
                w.endObject()
            }
            w.endObject()
        }

        if let events = workout.workoutEvents, !events.isEmpty {
            w.key("events"); w.beginArray()
            for event in events {
                w.beginObject()
                w.field("type", HealthCatalog.name("HKWorkoutEventType", event.type.rawValue) ?? "other")
                w.field("start", event.dateInterval.start)
                if event.dateInterval.duration > 0 { w.field("end", event.dateInterval.end) }
                w.endObject()
            }
            w.endArray()
        }

        // GPS route, when the workout has one and the user allowed reading routes.
        let routes = (try? await HKSampleQueryDescriptor(
            predicates: [.workoutRoute(HKQuery.predicateForObjects(from: workout))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        ).result(for: store)) ?? []
        var routeOpen = false
        for route in routes {
            do {
                for try await location in HKWorkoutRouteQueryDescriptor(route).results(for: store) {
                    if !routeOpen { w.key("route"); w.beginArray(); routeOpen = true }
                    w.beginObject()
                    w.field("time", location.timestamp)
                    w.field("latitude", location.coordinate.latitude)
                    w.field("longitude", location.coordinate.longitude)
                    w.field("altitude", location.altitude)
                    if location.speed >= 0 { w.field("speed", location.speed) }
                    if location.horizontalAccuracy >= 0 { w.field("horizontalAccuracy", location.horizontalAccuracy) }
                    w.endObject()
                }
            } catch let error as HKError where error.code == .errorDatabaseInaccessible {
                throw error
            } catch {
                // A route that cannot be read is left out; the workout itself is still exported.
            }
        }
        if routeOpen { w.endArray() }

        session.metadata(workout)
        w.endObject()
    }

    private func encode(_ correlation: HKCorrelation, _ type: HKCorrelationType, _ session: Session) {
        let w = session.writer
        w.beginObject()
        w.field("type", type.identifier)
        session.head(correlation, type: type.identifier)
        w.field("source", session.sourceKey(correlation))
        w.key("samples"); w.beginArray()
        let members = correlation.objects.compactMap { $0 as? HKQuantitySample }
            .sorted { $0.quantityType.identifier < $1.quantityType.identifier }
        for member in members {
            guard let kind = HealthCatalog.quantityByIdentifier[member.quantityType.identifier] else { continue }
            w.beginObject()
            w.field("id", member.uuid.uuidString)
            w.field("type", kind.identifier)
            w.field("value", member.quantity.doubleValue(for: kind.unit))
            w.field("unit", kind.unit.unitString)
            w.endObject()
        }
        w.endArray()
        session.metadata(correlation)
        w.endObject()
    }

    private func encode(_ ecg: HKElectrocardiogram, _ session: Session) async throws {
        let w = session.writer
        let microvolt = HKUnit.voltUnit(with: .micro)
        w.beginObject()
        session.head(ecg, type: "HKDataTypeIdentifierElectrocardiogram")
        w.field("source", session.sourceKey(ecg))
        w.field("classification", HealthCatalog.name("HKElectrocardiogramClassification", ecg.classification.rawValue) ?? "unrecognized")
        w.field("symptomsStatus", HealthCatalog.name("HKElectrocardiogramSymptomsStatus", ecg.symptomsStatus.rawValue) ?? "notSet")
        if let rate = ecg.averageHeartRate {
            let unit = HKUnit.count().unitDivided(by: .minute())
            w.key("averageHeartRate"); w.beginObject()
            w.field("value", rate.doubleValue(for: unit)); w.field("unit", unit.unitString)
            w.endObject()
        }
        if let frequency = ecg.samplingFrequency {
            w.key("samplingFrequency"); w.beginObject()
            w.field("value", frequency.doubleValue(for: .hertz())); w.field("unit", HKUnit.hertz().unitString)
            w.endObject()
        }
        w.key("voltages"); w.beginObject()
        w.field("unit", microvolt.unitString)
        w.key("values"); w.beginArray()
        do {
            for try await measurement in HKElectrocardiogramQueryDescriptor(ecg).results(for: store) {
                if let quantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                    w.number(quantity.doubleValue(for: microvolt))
                }
            }
        } catch let error as HKError where error.code == .errorDatabaseInaccessible {
            throw error
        } catch {
            // The recording itself could not be read; classification and rates are still exported.
        }
        w.endArray()
        w.endObject()
        session.metadata(ecg)
        w.endObject()
    }

    private func encode(_ series: HKHeartbeatSeriesSample, _ session: Session) async throws {
        let w = session.writer
        w.beginObject()
        session.head(series, type: "HKDataTypeIdentifierHeartbeatSeries")
        w.field("source", session.sourceKey(series))
        w.key("beats"); w.beginArray()
        do {
            for try await beat in HKHeartbeatSeriesQueryDescriptor(series).results(for: store) {
                w.beginObject()
                w.field("time", beat.timeIntervalSinceStart)
                if beat.precededByGap { w.field("precededByGap", true) }
                w.endObject()
            }
        } catch let error as HKError where error.code == .errorDatabaseInaccessible {
            throw error
        } catch {}
        w.endArray()
        session.metadata(series)
        w.endObject()
    }

    private func encode(_ audiogram: HKAudiogramSample, _ session: Session) {
        let w = session.writer
        w.beginObject()
        session.head(audiogram, type: "HKDataTypeIdentifierAudiogram")
        w.field("source", session.sourceKey(audiogram))
        w.key("points"); w.beginArray()
        for point in audiogram.sensitivityPoints {
            w.beginObject()
            w.key("frequency"); w.beginObject()
            w.field("value", point.frequency.doubleValue(for: .hertz())); w.field("unit", HKUnit.hertz().unitString)
            w.endObject()
            for test in point.tests {
                w.key(test.side == .left ? "left" : "right"); w.beginObject()
                w.field("value", test.sensitivity.doubleValue(for: .decibelHearingLevel()))
                w.field("unit", HKUnit.decibelHearingLevel().unitString)
                w.endObject()
            }
            w.endObject()
        }
        w.endArray()
        session.metadata(audiogram)
        w.endObject()
    }

    private func encode(_ state: HKStateOfMind, _ session: Session) {
        let w = session.writer
        w.beginObject()
        session.head(state, type: "HKDataTypeIdentifierStateOfMind")
        w.field("source", session.sourceKey(state))
        w.field("kind", HealthCatalog.name("HKStateOfMindKind", state.kind.rawValue) ?? "other")
        w.field("valence", state.valence)
        if let name = HealthCatalog.name("HKStateOfMindValenceClassification", state.valenceClassification.rawValue) {
            w.field("valenceClassification", name)
        }
        w.key("labels"); w.beginArray()
        for label in state.labels { w.string(HealthCatalog.name("HKStateOfMindLabel", label.rawValue) ?? String(label.rawValue)) }
        w.endArray()
        w.key("associations"); w.beginArray()
        for item in state.associations { w.string(HealthCatalog.name("HKStateOfMindAssociation", item.rawValue) ?? String(item.rawValue)) }
        w.endArray()
        session.metadata(state)
        w.endObject()
    }

    private func encodeAssessment(_ sample: HKScoredAssessment, type: String, answers: [Int], risk: String?, _ session: Session) {
        let w = session.writer
        w.beginObject()
        w.field("type", type)
        session.head(sample, type: type)
        w.field("source", session.sourceKey(sample))
        w.field("score", sample.score)
        if let risk { w.field("risk", risk) }
        w.key("answers"); w.beginArray()
        for answer in answers { w.int(answer) }
        w.endArray()
        session.metadata(sample)
        w.endObject()
    }

    private func writeActivitySummaries(_ scope: ExportScope, _ session: Session) async throws {
        let w = session.writer
        var predicate: NSPredicate?
        if let from = scope.from {
            // Month files end with the month; a manual range runs up to today.
            let calendar = MonthKey.calendar
            let last = scope.to?.addingTimeInterval(-1) ?? Date.now
            var start = calendar.dateComponents([.year, .month, .day], from: from)
            var end = calendar.dateComponents([.year, .month, .day], from: last)
            start.calendar = calendar
            end.calendar = calendar
            predicate = HKQuery.predicate(forActivitySummariesBetweenStart: start, end: end)
        }
        let summaries: [HKActivitySummary]
        do {
            summaries = try await HKActivitySummaryQueryDescriptor(predicate: predicate).result(for: store)
        } catch let error as HKError where error.code == .errorDatabaseInaccessible {
            throw error
        } catch {
            return
        }
        guard !summaries.isEmpty else { return }
        let calendar = Calendar(identifier: .gregorian)
        w.newline(); w.key("activitySummaries"); w.beginArray()
        for summary in summaries {
            let day = summary.dateComponents(for: calendar)
            guard let y = day.year, let m = day.month, let d = day.day else { continue }
            // Health returns empty placeholder summaries dated around 1970. They are not the user's data.
            guard y >= Self.firstHealthYear else { continue }
            func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
            w.newline(); w.beginObject()
            w.field("date", "\(y)-\(two(m))-\(two(d))")
            ring(w, "activeEnergy", summary.activeEnergyBurned, summary.activeEnergyBurnedGoal, .kilocalorie())
            ring(w, "exerciseTime", summary.appleExerciseTime, summary.exerciseTimeGoal, .minute())
            ring(w, "standHours", summary.appleStandHours, summary.standHoursGoal, .count())
            w.endObject()
            session.count(type: "HKActivitySummaryTypeIdentifier", date: calendar.date(from: day) ?? .now)
        }
        w.newline(); w.endArray()
    }

    private func ring(_ w: JSONStreamWriter, _ name: String, _ value: HKQuantity, _ goal: HKQuantity?, _ unit: HKUnit) {
        w.key(name); w.beginObject()
        w.field("value", value.doubleValue(for: unit))
        if let goal { w.field("goal", goal.doubleValue(for: unit)) }
        w.field("unit", unit.unitString)
        w.endObject()
    }

    // MARK: Profile and header

    /// Values that are not tied to a date. Fields the user did not allow or fill in are left out.
    func writeProfile(_ w: JSONStreamWriter) {
        var fields: [(String, String)] = []
        if let birth = try? store.dateOfBirthComponents(), let y = birth.year, let m = birth.month, let d = birth.day {
            func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
            fields.append(("dateOfBirth", "\(y)-\(two(m))-\(two(d))"))
        }
        if let value = try? store.biologicalSex().biologicalSex, value != .notSet,
           let name = HealthCatalog.name("HKBiologicalSex", value.rawValue) { fields.append(("biologicalSex", name)) }
        if let value = try? store.bloodType().bloodType, value != .notSet,
           let name = HealthCatalog.name("HKBloodType", value.rawValue) { fields.append(("bloodType", name)) }
        if let value = try? store.fitzpatrickSkinType().skinType, value != .notSet,
           let name = HealthCatalog.name("HKFitzpatrickSkinType", value.rawValue) { fields.append(("fitzpatrickSkinType", name)) }
        if let value = try? store.wheelchairUse().wheelchairUse, value != .notSet,
           let name = HealthCatalog.name("HKWheelchairUse", value.rawValue) { fields.append(("wheelchairUse", name)) }
        guard !fields.isEmpty else { return }
        w.newline(); w.key("profile"); w.beginObject()
        for (name, value) in fields { w.field(name, value) }
        w.endObject()
    }

    static func writeGenerator(_ w: JSONStreamWriter) {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        w.key("generator"); w.beginObject()
        w.field("app", "Health50")
        w.field("version", "\(version) (\(build))")
        w.field("device", deviceModel)
        w.field("os", "iOS \(os.majorVersion).\(os.minorVersion)" + (os.patchVersion > 0 ? ".\(os.patchVersion)" : ""))
        w.endObject()
    }

    static let deviceModel: String = {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }()
}

/// State of one export file while it is being written.
private final class Session {
    let writer: JSONStreamWriter
    var summary = ExportSummary()
    var firstRecord: Date?
    var lastRecord: Date?
    private var sourceKeys: [String: String] = [:]
    private var sources: [(key: String, revision: HKSourceRevision)] = []

    init(url: URL) throws {
        writer = try JSONStreamWriter(url: url)
    }

    /// id, start and end of a record, and bookkeeping for the index.
    func head(_ sample: HKSample, type: String) {
        writer.field("id", sample.uuid.uuidString)
        times(sample, type: type)
    }

    func times(_ sample: HKSample, type: String) {
        writer.field("start", sample.startDate)
        if sample.endDate != sample.startDate { writer.field("end", sample.endDate) }
        count(type: type, date: sample.startDate)
    }

    /// source and metadata of a simple record.
    func tail(_ sample: HKSample) {
        writer.field("source", sourceKey(sample))
        metadata(sample)
    }

    func metadata(_ object: HKObject) {
        guard let metadata = object.metadata, !metadata.isEmpty else { return }
        writer.key("metadata"); writer.beginObject()
        for key in metadata.keys.sorted() {
            writer.key(key)
            writer.any(metadata[key]!)
        }
        writer.endObject()
    }

    func count(type: String, date: Date) {
        summary.records += 1
        if var stat = summary.types[type] {
            stat.first = min(stat.first, date); stat.last = max(stat.last, date); stat.records += 1
            summary.types[type] = stat
        } else {
            summary.types[type] = TypeStat(first: date, last: date, records: 1)
        }
        firstRecord = min(firstRecord ?? date, date)
        lastRecord = max(lastRecord ?? date, date)
    }

    func sourceKey(_ sample: HKSample) -> String {
        let revision = sample.sourceRevision
        let os = revision.operatingSystemVersion
        let identity = [
            revision.source.bundleIdentifier, revision.source.name, revision.productType ?? "", revision.version ?? "",
            "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
        ].joined(separator: "|")
        if let key = sourceKeys[identity] { return key }
        let key = "s\(sources.count + 1)"
        sourceKeys[identity] = key
        sources.append((key, revision))
        return key
    }

    func writeSources() {
        guard !sources.isEmpty else { return }
        writer.newline(); writer.key("sources"); writer.beginObject()
        for (key, revision) in sources {
            writer.newline(); writer.key(key); writer.beginObject()
            writer.field("name", revision.source.name)
            writer.field("bundleId", revision.source.bundleIdentifier)
            if let version = revision.version { writer.field("version", version) }
            if let device = revision.productType { writer.field("device", device) }
            let os = revision.operatingSystemVersion
            if os.majorVersion > 0 {
                writer.field("osVersion", "\(os.majorVersion).\(os.minorVersion)" + (os.patchVersion > 0 ? ".\(os.patchVersion)" : ""))
            }
            writer.endObject()
        }
        writer.newline(); writer.endObject()
    }
}
