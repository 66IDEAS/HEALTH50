import Foundation
import HealthKit
import Testing
@testable import Health50

private func temporaryFile(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(name + ".json")
}

/// Apple's parser accepts trailing commas, other parsers do not. Check for them explicitly.
private func hasTrailingComma(_ url: URL) throws -> Bool {
    let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
    return text.range(of: #",\s*[\]}]"#, options: .regularExpression) != nil
        || text.range(of: #"[\[{]\s*,"#, options: .regularExpression) != nil
}

private func parse(_ url: URL) throws -> [String: Any] {
    #expect(try !hasTrailingComma(url), "the file contains a trailing or leading comma")
    return try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
}

@Suite struct JSONStreamWriterTests {
    @Test func writesNestedStructureThatParses() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let w = try JSONStreamWriter(url: url)
        w.beginObject()
        w.field("text", "quote \" backslash \\ newline \n tab \t bell \u{07} umlaut ä 日本")
        w.field("whole", 42.0)
        w.field("fraction", 81.4)
        w.field("small", 0.00001)
        w.field("flag", true)
        w.key("nothing"); w.null()
        w.key("notANumber"); w.number(.nan)
        w.newline(); w.key("list"); w.beginArray()
        for i in 0..<3 { w.newline(); w.beginObject(); w.field("i", i); w.endObject() }
        w.newline(); w.endArray()
        w.key("empty"); w.beginArray(); w.endArray()
        w.newline(); w.endObject()
        try w.close()

        let json = try parse(url)
        #expect(json["text"] as? String == "quote \" backslash \\ newline \n tab \t bell \u{07} umlaut ä 日本")
        #expect(json["whole"] as? Int == 42)
        #expect(json["fraction"] as? Double == 81.4)
        #expect(json["small"] as? Double == 0.00001)
        #expect(json["flag"] as? Bool == true)
        #expect(json["nothing"] is NSNull)
        #expect(json["notANumber"] is NSNull)
        #expect((json["list"] as? [[String: Int]])?.map { $0["i"] } == [0, 1, 2])
        #expect((json["empty"] as? [Any])?.isEmpty == true)
    }

    @Test func writesMoreThanOneBuffer() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let w = try JSONStreamWriter(url: url)
        w.beginArray()
        for i in 0..<60_000 { w.newline(); w.beginObject(); w.field("value", Double(i) + 0.5); w.endObject() }
        w.newline(); w.endArray()
        try w.close()
        #expect(try !hasTrailingComma(url))
        let list = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Double]])
        #expect(list.count == 60_000)
        #expect(list.last?["value"] == 59_999.5)
        #expect(w.bytesWritten == Int64(try Data(contentsOf: url).count))
    }

    @Test func formatsDatesAsUTC() {
        let formatter = ISO8601DateFormatter()
        for seconds in [0.0, 951_782_400, 1_793_858_292.9, 4_102_444_799] {
            let date = Date(timeIntervalSince1970: seconds)
            #expect(JSONStreamWriter.iso(date) == formatter.string(from: date))
        }
    }

    @Test func encodesMetadataValues() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let w = try JSONStreamWriter(url: url)
        w.beginObject()
        w.key("metadata")
        w.any(["flag": NSNumber(value: true), "count": NSNumber(value: 3), "name": "x", "when": Date(timeIntervalSince1970: 0)] as [String: Any])
        w.endObject()
        try w.close()
        let metadata = try #require(try parse(url)["metadata"] as? [String: Any])
        #expect(metadata["flag"] as? Bool == true)
        #expect(metadata["count"] as? Int == 3)
        #expect(metadata["name"] as? String == "x")
        #expect(metadata["when"] as? String == "1970-01-01T00:00:00Z")
    }
}

@Suite struct MonthKeyTests {
    private func utc(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    @Test func assignsRecordsByUTCStart() {
        #expect(MonthKey(utc("2026-10-31T23:59:59Z")).name == "2026-10")
        #expect(MonthKey(utc("2026-11-01T00:00:00Z")).name == "2026-11")
        #expect(MonthKey(utc("2026-12-31T23:10:00Z")).next.name == "2027-01")
        #expect(MonthKey(year: 2026, month: 1).previous.name == "2025-12")
    }

    @Test func hasBoundariesAndFileName() {
        let month = MonthKey(year: 2026, month: 11)
        #expect(month.start == utc("2026-11-01T00:00:00Z"))
        #expect(month.end == utc("2026-12-01T00:00:00Z"))
        #expect(month.fileName == "health50-2026-11.json")
        #expect(!month.isClosed(at: utc("2026-11-05T06:00:00Z")))
        #expect(month.isClosed(at: utc("2026-12-01T00:00:00Z")))
    }

    @Test func parsesNamesAndBuildsRanges() {
        #expect(MonthKey(name: "2026-03") == MonthKey(year: 2026, month: 3))
        #expect(MonthKey(name: "2026-13") == nil)
        #expect(MonthKey(name: "nonsense") == nil)
        let range = MonthKey.range(MonthKey(year: 2025, month: 11), MonthKey(year: 2026, month: 2))
        #expect(range.map(\.name) == ["2025-11", "2025-12", "2026-01", "2026-02"])
    }
}

@Suite struct SyncPlannerTests {
    private let now = ISO8601DateFormatter().date(from: "2026-11-05T06:00:00Z")!

    private func state(months: [String], dirty: Set<String> = [], pending: Bool = false) -> SyncState {
        var state = SyncState()
        for name in months {
            state.months[name] = MonthRecord(updatedAt: now, records: 1, bytes: 10, fileID: "id-\(name)", types: [:])
        }
        state.dirty = dirty
        state.pendingFullRebuild = pending
        return state
    }

    @Test func rewritesOnlyChangedMonths() {
        let plan = SyncPlanner.plan(state: state(months: ["2026-09", "2026-10", "2026-11"]),
                                    changedMonths: [MonthKey(year: 2026, month: 11)], deletions: 0, foreground: false, now: now)
        #expect(plan.dirty == ["2026-11"])
        #expect(!plan.pendingFullRebuild)
    }

    @Test func keepsMonthsOfAnInterruptedRun() {
        let plan = SyncPlanner.plan(state: state(months: ["2026-10"], dirty: ["2026-08"]),
                                    changedMonths: [MonthKey(year: 2026, month: 11)], deletions: 0, foreground: false, now: now)
        #expect(plan.dirty == ["2026-08", "2026-11"])
    }

    @Test func deletionsRewriteRecentMonthsAndRememberTheRest() {
        let plan = SyncPlanner.plan(state: state(months: ["2026-01", "2026-10", "2026-11"]),
                                    changedMonths: [], deletions: 2, foreground: false, now: now)
        #expect(plan.dirty == ["2026-10", "2026-11"])
        #expect(plan.pendingFullRebuild)
    }

    @Test func manualUploadRewritesEverythingAfterDeletions() {
        let plan = SyncPlanner.plan(state: state(months: ["2026-01", "2026-10", "2026-11"], pending: true),
                                    changedMonths: [], deletions: 0, foreground: true, now: now)
        #expect(plan.dirty == ["2026-01", "2026-10", "2026-11"])
        #expect(!plan.pendingFullRebuild)
    }

    @Test func nothingChangedMeansNothingToDo() {
        let plan = SyncPlanner.plan(state: state(months: ["2026-11"]), changedMonths: [], deletions: 0, foreground: true, now: now)
        #expect(plan.dirty.isEmpty)
    }
}

@Suite struct HealthCatalogTests {
    @Test func everyQuantityTypeHasAUnit() {
        #expect(HealthCatalog.quantities.count == GeneratedHealthCatalog.quantityIdentifiers.count)
        #expect(HealthCatalog.quantities.count > 100)
        for kind in HealthCatalog.quantities {
            #expect(kind.type.is(compatibleWith: kind.unit), "\(kind.identifier) cannot be expressed in \(kind.unit.unitString)")
        }
    }

    @Test func usesReadableUnits() {
        func unit(_ id: HKQuantityTypeIdentifier) -> String? { HealthCatalog.quantityByIdentifier[id.rawValue]?.unit.unitString }
        #expect(unit(.heartRate) == "count/min")
        #expect(unit(.respiratoryRate) == "count/min")
        #expect(unit(.distanceWalkingRunning) == "km")
        #expect(unit(.distanceSwimming) == "m")
        #expect(unit(.bodyMass) == "kg")
        #expect(unit(.stepCount) == "count")
        #expect(unit(.oxygenSaturation) == "%")
        #expect(unit(.bodyTemperature) == "degC")
        #expect(unit(.bloodPressureSystolic) == "mmHg")
        #expect(unit(.activeEnergyBurned) == "kcal")
    }

    @Test func everyCategoryTypeResolves() {
        let resolved = Set(HealthCatalog.categories.map(\.identifier))
        let missing = GeneratedHealthCatalog.categoryIdentifiers.map(\.identifier).filter { !resolved.contains($0) }
        #expect(missing.isEmpty, "category types the SDK lists but HealthKit does not offer: \(missing)")
        let sleep = HealthCatalog.categories.first { $0.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue }
        #expect(sleep?.valueNames[HKCategoryValueSleepAnalysis.asleepCore.rawValue] == "asleepCore")
        #expect(sleep?.valueNames[HKCategoryValueSleepAnalysis.inBed.rawValue] == "inBed")
    }

    @Test func readsNoClinicalRecordsAndNeverWrites() {
        let types = HealthCatalog.readTypes
        #expect(types.count > 190)
        #expect(!types.contains { $0 is HKClinicalType })
        #expect(!types.contains { $0 is HKCorrelationType })
        #expect(!types.contains { $0.requiresPerObjectAuthorization() })
        #expect(types.contains(HKObjectType.workoutType()))
        #expect(types.contains(HKSeriesType.workoutRoute()))
    }

    @Test func namesEnums() {
        #expect(HealthCatalog.activityName(.running) == "running")
        #expect(HealthCatalog.name("HKElectrocardiogramClassification", HKElectrocardiogram.Classification.sinusRhythm.rawValue) == "sinusRhythm")
        #expect(HealthCatalog.name("HKBloodType", HKBloodType.aPositive.rawValue) == "aPositive")
        #expect(HealthCatalog.name("HKWorkoutEventType", HKWorkoutEventType.pause.rawValue) == "pause")
    }
}

@Suite struct IndexTests {
    private let now = ISO8601DateFormatter().date(from: "2026-11-05T06:12:05Z")!

    @Test func mergesTypeOverviewAcrossMonths() {
        let early = Date(timeIntervalSince1970: 1_000), mid = Date(timeIntervalSince1970: 2_000), late = Date(timeIntervalSince1970: 3_000)
        var state = SyncState()
        state.months["2026-10"] = MonthRecord(updatedAt: now, records: 5, bytes: 1, fileID: nil,
                                              types: ["HR": TypeStat(first: early, last: mid, records: 5)])
        state.months["2026-11"] = MonthRecord(updatedAt: now, records: 2, bytes: 1, fileID: nil,
                                              types: ["HR": TypeStat(first: mid, last: late, records: 2)])
        #expect(state.typeOverview["HR"] == TypeStat(first: early, last: late, records: 7))
    }

    @Test func writesIndexFile() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        var state = SyncState()
        for (name, records) in [("2026-11", 18_234), ("2026-10", 148_210)] {
            state.months[name] = MonthRecord(updatedAt: now, records: records, bytes: 4_193_221, fileID: "x",
                                             types: ["HKQuantityTypeIdentifierHeartRate": TypeStat(first: now, last: now, records: records)])
        }
        try IndexWriter.write(to: url, state: state, exporter: HealthExporter(store: HKHealthStore()), now: now)

        let json = try parse(url)
        #expect(json["format"] as? String == "health50")
        #expect(json["kind"] as? String == "index")
        #expect(json["generatedAt"] as? String == "2026-11-05T06:12:05Z")
        #expect((json["access"] as? String)?.contains("allowed") == true)
        let files = try #require(json["files"] as? [[String: Any]])
        #expect(files.map { $0["month"] as? String } == ["2026-10", "2026-11"])
        #expect(files[0]["name"] as? String == "health50-2026-10.json")
        #expect(files[0]["monthClosed"] as? Bool == true)
        #expect(files[1]["monthClosed"] as? Bool == false)
        let types = try #require(json["types"] as? [String: [String: Any]])
        #expect(types["HKQuantityTypeIdentifierHeartRate"]?["records"] as? Int == 166_444)
    }
}

@Suite struct OutcomeTests {
    @Test func backgroundProblemsStayQuiet() {
        #expect(DriveSync.outcome(for: DriveError.network, foreground: false) == .waiting(.wifi))
        #expect(DriveSync.outcome(for: ExportError.locked, foreground: false) == .waiting(.locked))
        #expect(DriveSync.outcome(for: CancellationError(), foreground: false) == .waiting(.system))
    }

    @Test func manualProblemsAreShown() {
        #expect(DriveSync.outcome(for: DriveError.network, foreground: true) == .failed(.upload))
        #expect(DriveSync.outcome(for: ExportError.noSpace, foreground: true) == .failed(.storage))
        #expect(DriveSync.outcome(for: DriveError.needsReconnect, foreground: true) == .needsReconnect)
    }

    @Test func outcomeSurvivesStorage() throws {
        for outcome in [SyncOutcome.upToDate(Date(timeIntervalSince1970: 5)), .noData, .needsReconnect, .waiting(.locked), .failed(.upload)] {
            let data = try JSONEncoder().encode(outcome)
            #expect(try JSONDecoder().decode(SyncOutcome.self, from: data) == outcome)
        }
    }
}
