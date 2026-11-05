import HealthKit
import SwiftUI

/// The one model behind the single screen. Everything the status card shows comes from `status`.
@MainActor
@Observable
final class AppModel {
    enum Status: Equatable {
        case ready
        case upToDate(Date)
        case reconnect(last: Date?)
        case exporting(progress: Double, upload: Bool)
        case saved(folder: String, bytes: Int64, date: Date)
        case failed(FailReason, retry: Retry)
        case waiting(WaitReason, last: Date?)
        case noData
    }

    enum Retry: Equatable { case save, upload }

    static let privacyURL = URL(string: "https://github.com/66IDEAS/HEALTH50/blob/main/PRIVACY.md")!
    static let supportURL = URL(string: "https://github.com/66IDEAS/HEALTH50/blob/main/SUPPORT.md")!
    static let defaultFolderName = "Health50"

    var status: Status = .ready
    var hasOnboarded = Settings.hasOnboarded
    var automaticExport = Settings.automaticExport
    var intervalDays = Settings.intervalDays {
        didSet { Settings.intervalDays = intervalDays; AutoExport.schedule() }
    }
    var useCellular = Settings.useCellular {
        didSet { Settings.useCellular = useCellular }
    }

    var driveConnected = false
    var driveEmail: String?
    var driveFolder: String?
    var lastSuccess: Date?
    var notificationsDenied = false
    var hasTypesToReview = false

    var showDriveSheet = false
    var showHealthSheet = false
    var showFolderPicker = false
    var showNotificationExplainer = false
    var signingIn = false
    var driveSheetError: LocalizedStringKey?

    private let exporter = HealthExporter(store: HKHealthStore())
    private var lastSaveFolder: URL?

    var isBusy: Bool {
        if case .exporting = status { true } else { false }
    }

    var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "1.0") (\(info["CFBundleVersion"] as? String ?? "1"))"
    }

    init() {
        TempFiles.removeAll()
        loadDriveState()
        status = restingStatus()
        #if DEBUG
        applyDemoState()
        #endif
    }

    // MARK: State

    /// Called whenever the app comes to the foreground.
    func refresh() async {
        guard !isDemo else { return }
        loadDriveState()
        notificationsDenied = Settings.notificationsAsked ? await Notifications.isDenied() : false
        hasTypesToReview = await exporter.hasTypesToReview()
        if !isBusy, !isTransient { status = restingStatus() }
        Notifications.clear()
    }

    private var isTransient: Bool {
        switch status {
        case .saved, .failed: true
        default: false
        }
    }

    private func loadDriveState() {
        let state = SyncStateStore.load()
        driveConnected = GoogleAuth.shared.isConnected && state.folderID != nil
        driveEmail = state.email
        driveFolder = state.folderName
        lastSuccess = state.lastSuccess
    }

    /// The state the card returns to when nothing is running.
    private func restingStatus() -> Status {
        guard automaticExport else { return .ready }
        guard driveConnected else { return .reconnect(last: lastSuccess) }
        switch Settings.lastOutcome {
        case .upToDate(let date): return .upToDate(date)
        case .needsReconnect: return .reconnect(last: lastSuccess)
        case .noData: return .noData
        case .waiting(let reason): return .waiting(reason, last: lastSuccess)
        case .failed(let reason): return .failed(reason, retry: .upload)
        case nil: return lastSuccess.map { .upToDate($0) } ?? .ready
        }
    }

    // MARK: Health access

    func finishOnboarding() async {
        try? await exporter.requestAccess()
        Settings.hasOnboarded = true
        withAnimation { hasOnboarded = true }
        await refresh()
    }

    func reviewNewTypes() async {
        try? await exporter.requestAccess()
        hasTypesToReview = await exporter.hasTypesToReview()
    }

    func openHealthApp() {
        if let url = URL(string: "x-apple-health://") { UIApplication.shared.open(url) }
    }

    // MARK: Manual export

    /// "Save to Files…": the location was picked first, now the full history is written there.
    func save(to folder: URL) async {
        guard !isBusy else { return }
        lastSaveFolder = folder
        status = .exporting(progress: 0, upload: false)
        let file = TempFiles.url(named: "health50-export.json")
        defer { TempFiles.remove(file) }
        do {
            let summary = try await exporter.export(.full, to: file) { [weak self] value in
                Task { @MainActor in self?.report(progress: value, upload: false) }
            }
            guard summary.records > 0 else { status = .noData; return }
            do {
                try await Self.deliver(file, into: folder)
            } catch {
                status = .failed(.save, retry: .save)
                return
            }
            status = .saved(folder: Self.displayName(of: folder), bytes: summary.bytes, date: .now)
        } catch ExportError.noSpace {
            status = .failed(.storage, retry: .save)
        } catch {
            status = .failed(.generic, retry: .save)
        }
    }

    private func report(progress: Double, upload: Bool) {
        if case .exporting(let current, _) = status, progress >= current {
            status = .exporting(progress: progress, upload: upload)
        }
    }

    /// The folder's name as the Files app shows it, for example "On My iPhone".
    private static func displayName(of folder: URL) -> String {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let name = (try? folder.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? folder.lastPathComponent
        // The top level of the phone's own storage reports an internal name.
        return name == "File Provider Storage" ? String(localized: "files.onMyIPhone") : name
    }

    /// Copies the finished file into the folder the user picked, replacing an older export of the same name.
    private nonisolated static func deliver(_ file: URL, into folder: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            let scoped = folder.startAccessingSecurityScopedResource()
            defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
            let destination = folder.appendingPathComponent("health50-export.json")
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { url in
                do {
                    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                    try FileManager.default.copyItem(at: file, to: url)
                } catch {
                    copyError = error
                }
            }
            if let error = coordinationError ?? copyError { throw error }
        }.value
    }

    /// "Upload to Google Drive now": brings the folder up to date right away.
    func uploadNow() async {
        guard !isBusy, driveConnected else { return }
        status = .exporting(progress: 0, upload: true)
        let outcome = await DriveSync.shared.run(foreground: true, allowsCellular: useCellular) { [weak self] value in
            Task { @MainActor in self?.report(progress: value, upload: true) }
        }
        Settings.lastOutcome = outcome
        loadDriveState()
        switch outcome {
        case .upToDate(let date): status = .upToDate(date)
        case .noData: status = .noData
        case .needsReconnect: status = .reconnect(last: lastSuccess)
        case .waiting(let reason): status = .waiting(reason, last: lastSuccess)
        case .failed(let reason): status = .failed(reason, retry: .upload)
        }
        AutoExport.schedule()
    }

    func retry(_ action: Retry) async {
        switch action {
        case .save:
            if let lastSaveFolder { await save(to: lastSaveFolder) } else { showFolderPicker = true }
        case .upload:
            await uploadNow()
        }
    }

    // MARK: Automatic export

    func setAutomaticExport(_ on: Bool) {
        if on {
            if driveConnected {
                enableAutomaticExport()
            } else {
                driveSheetError = nil
                showDriveSheet = true
            }
        } else {
            automaticExport = false
            Settings.automaticExport = false
            AutoExport.cancel()
            if !isBusy { status = restingStatus() }
        }
    }

    private func enableAutomaticExport() {
        automaticExport = true
        Settings.automaticExport = true
        AutoExport.schedule()
        if !isBusy { status = restingStatus() }
    }

    /// "Sign in with Google" in the Google Drive sheet. Suggests a new folder named Health50.
    func signIn() async {
        signingIn = true
        driveSheetError = nil
        defer { signingIn = false }
        do {
            try await GoogleAuth.shared.signIn()
            let drive = DriveClient(allowsCellular: true)
            let email = try await drive.email()
            var state = SyncStateStore.load()
            let name = state.folderName ?? Self.defaultFolderName
            let folderID = try await drive.ensureFolder(named: name)
            if state.folderID != folderID { state = SyncState() }
            state.folderID = folderID
            state.folderName = name
            state.email = email
            SyncStateStore.save(state)
            loadDriveState()
        } catch GoogleAuthError.notConfigured {
            driveSheetError = "drive.notConfigured"
        } catch GoogleAuthError.cancelled {
            // The user closed Google's page. Nothing to report.
        } catch {
            await GoogleAuth.shared.disconnect()
            loadDriveState()
            driveSheetError = "drive.signIn.failed"
        }
    }

    /// "Choose another folder": the app can only use folders it created, so it creates one of that name.
    func chooseFolder(named name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != driveFolder else { return }
        do {
            let folderID = try await DriveClient(allowsCellular: true).ensureFolder(named: trimmed)
            var state = SyncState()
            state.folderID = folderID
            state.folderName = trimmed
            state.email = driveEmail
            SyncStateStore.save(state)
            Settings.lastOutcome = nil
            loadDriveState()
        } catch {
            driveSheetError = "drive.signIn.failed"
        }
    }

    /// "Done" in the Google Drive sheet.
    func finishDriveSetup() {
        showDriveSheet = false
        guard driveConnected else { return }
        let firstSetup = !automaticExport
        enableAutomaticExport()
        if !Settings.notificationsAsked {
            showNotificationExplainer = true
        } else if firstSetup || lastSuccess == nil {
            Task { await uploadNow() }
        }
    }

    /// After the explaining line: the iOS notification dialog, then the first upload.
    func askForNotifications() async {
        let allowed = await Notifications.requestPermission()
        notificationsDenied = !allowed
        await uploadNow()
    }

    func disconnect() async {
        await GoogleAuth.shared.disconnect()
        SyncStateStore.reset()
        Settings.lastOutcome = nil
        automaticExport = false
        Settings.automaticExport = false
        AutoExport.cancel()
        loadDriveState()
        showDriveSheet = false
        status = .ready
    }

    // MARK: Demo states for screenshots and UI checks (debug builds only)

    private(set) var isDemo = false

    #if DEBUG
    /// Launch with `-demo <name>` to show a state without real data, for example `-demo upToDate`.
    private func applyDemoState() {
        // `-debugLocalSync YES` runs the monthly export into Documents/DebugSync instead of Google Drive.
        if UserDefaults.standard.bool(forKey: "debugLocalSync") {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("DebugSync")
            Task {
                let outcome = await DriveSync.shared.debugLocalRun(into: folder)
                try? "\(outcome)".write(to: folder.appendingPathComponent("outcome.txt"), atomically: true, encoding: .utf8)
            }
        }
        guard let demo = UserDefaults.standard.string(forKey: "demo") else { return }
        isDemo = true
        hasOnboarded = demo != "welcome"
        let morning = Calendar.current.date(bySettingHour: 7, minute: 12, second: 0, of: .now) ?? .now
        func connected() {
            automaticExport = true
            driveConnected = true
            driveEmail = "alex@example.com"
            driveFolder = Self.defaultFolderName
            lastSuccess = morning
        }
        switch demo {
        case "upToDate": connected(); status = .upToDate(morning)
        case "reconnect": connected(); driveConnected = false; status = .reconnect(last: morning.addingTimeInterval(-3 * 86400))
        case "exporting": connected(); status = .exporting(progress: 0.62, upload: false)
        case "saved": connected(); status = .saved(folder: "Exports", bytes: 48_300_000, date: .now)
        case "failed": connected(); status = .failed(.storage, retry: .save)
        case "waiting": connected(); lastSuccess = morning.addingTimeInterval(-86400); status = .waiting(.wifi, last: lastSuccess)
        case "noData": status = .noData
        case "driveSignIn": showDriveSheet = true
        case "driveConnected": connected(); status = .upToDate(morning); showDriveSheet = true
        case "healthSheet": connected(); status = .upToDate(morning); hasTypesToReview = true; showHealthSheet = true
        default: break
        }
    }
    #endif
}

/// Dates as the status card words them: "today at 07:12", "2 Nov".
enum Dates {
    static func relative(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let absolute = formatter.string(from: date)
        formatter.doesRelativeDateFormatting = true
        let relative = formatter.string(from: date)
        // "Today" inside a sentence is written in lower case; a real date keeps its spelling.
        guard relative != absolute, let first = relative.first else { return relative }
        return first.lowercased() + relative.dropFirst()
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func standalone(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
}
