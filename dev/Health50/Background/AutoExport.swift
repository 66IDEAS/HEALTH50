import BackgroundTasks
import Foundation
import UserNotifications

/// The user's choices, kept in UserDefaults so background runs can read them without the UI.
enum Settings {
    private static var defaults: UserDefaults { .standard }

    static var hasOnboarded: Bool {
        get { defaults.bool(forKey: "hasOnboarded") }
        set { defaults.set(newValue, forKey: "hasOnboarded") }
    }

    static var automaticExport: Bool {
        get { defaults.bool(forKey: "automaticExport") }
        set { defaults.set(newValue, forKey: "automaticExport") }
    }

    /// Whole days between automatic exports. Default and minimum are one day.
    static var intervalDays: Int {
        get { max(1, defaults.integer(forKey: "intervalDays")) }
        set { defaults.set(max(1, newValue), forKey: "intervalDays") }
    }

    static var useCellular: Bool {
        get { defaults.bool(forKey: "useCellular") }
        set { defaults.set(newValue, forKey: "useCellular") }
    }

    static var notificationsAsked: Bool {
        get { defaults.bool(forKey: "notificationsAsked") }
        set { defaults.set(newValue, forKey: "notificationsAsked") }
    }

    /// Result of the latest automatic run, shown on the status card when the app opens.
    static var lastOutcome: SyncOutcome? {
        get { defaults.data(forKey: "lastOutcome").flatMap { try? JSONDecoder().decode(SyncOutcome.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "lastOutcome") }
    }
}

/// Schedules and runs the automatic export in the background.
enum AutoExport {
    static let taskID = "com.66ideas.health50.sync"

    /// Must be called before the app finishes launching.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            let box = TaskBox(task)
            let work = Task {
                let outcome = await runInBackground()
                if case .upToDate = outcome {
                    box.task.setTaskCompleted(success: true)
                } else {
                    box.task.setTaskCompleted(success: false)
                }
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    /// Asks iOS to run the next export. The date is a target: iOS decides when the app may run.
    static func schedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
        guard Settings.automaticExport else { return }
        let request = BGProcessingTaskRequest(identifier: taskID)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = nextRun()
        BGTaskScheduler.shared.submitTaskRequest(request) { _ in }
    }

    static func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
    }

    /// When the next export is due. After a run that could not finish, the app tries again within the hour.
    static func nextRun(now: Date = .now) -> Date {
        let state = SyncStateStore.load()
        if case .waiting = Settings.lastOutcome { return now.addingTimeInterval(60 * 60) }
        guard let last = state.lastSuccess else { return now.addingTimeInterval(15 * 60) }
        return last.addingTimeInterval(Double(Settings.intervalDays) * 24 * 60 * 60)
    }

    @discardableResult
    static func runInBackground() async -> SyncOutcome {
        guard Settings.automaticExport else { return .waiting(.system) }
        let outcome = await DriveSync.shared.run(foreground: false, allowsCellular: Settings.useCellular)
        Settings.lastOutcome = outcome
        switch outcome {
        case .needsReconnect: await Notifications.post(title: "status.attention.drive.title", body: "notify.reconnect.body", id: "reconnect")
        case .noData: await Notifications.post(title: "status.noData.title", body: "notify.noData.body", id: "noData")
        default: break
        }
        schedule()
        return outcome
    }

    /// BGTask is handed to exactly one task and only used to report completion.
    private struct TaskBox: @unchecked Sendable {
        let task: BGTask
        init(_ task: BGTask) { self.task = task }
    }
}

/// Notifications are created on the phone and only sent when the user has to act.
enum Notifications {
    /// Shows the iOS permission dialog once. Returns whether notifications are allowed.
    static func requestPermission() async -> Bool {
        Settings.notificationsAsked = true
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    static func post(title: String.LocalizationValue, body: String.LocalizationValue, id: String) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: title)
        content.body = String(localized: body)
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func clear() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
