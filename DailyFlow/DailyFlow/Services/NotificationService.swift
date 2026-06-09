import Foundation
import UserNotifications

final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    static let waterCategoryId = "WATER_REMINDER"
    static let taskCategoryId  = "TASK_REMINDER"
    static let emergencyCategoryId = "EMERGENCY_ALERT"

    // Water window: 10 AM → 10 PM
    private let waterStartHour = 10
    private let waterEndHour   = 22

    // Escalation offsets within each hour (minutes after the hour)
    private let escalationOffsets = [0, 10, 30]

    private let waterMessages: [(title: String, body: String)] = [
        ("Hydration Reminder 💧", "Time to drink water — tap to log"),
        ("Stay Hydrated 💧",      "Hourly wellness check — drink some water"),
        ("Wellness Reminder 💧",  "Friendly reminder to stay hydrated"),
        ("Daily Wellness 💧",     "Keep up your hydration routine"),
        ("Refresh Time 💧",       "A moment to hydrate and recharge"),
        ("Hydration Check 💧",    "Don't forget to drink water today"),
    ]

    private let followUpBodies = [
        "Still waiting — please log your water now",
        "Follow-up reminder — hydration check needed",
        "Please respond — log your water intake",
    ]

    @Published private(set) var isEmergencyMuted = false

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Categories
    func registerCategories() {
        let logAction = UNNotificationAction(
            identifier: "LOG_WATER",
            title: "Log Water",
            options: [.foreground]
        )
        let waterCategory = UNNotificationCategory(
            identifier: Self.waterCategoryId,
            actions: [logAction],
            intentIdentifiers: [],
            options: []
        )
        let taskCategory = UNNotificationCategory(
            identifier: Self.taskCategoryId,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let emergencyCategory = UNNotificationCategory(
            identifier: Self.emergencyCategoryId,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([waterCategory, taskCategory, emergencyCategory])
    }

    // MARK: - Permission
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await scheduleWaterReminders()
            }
            return granted
        } catch {
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Emergency Mute
    func setEmergencyMute(until date: Date?) {
        isEmergencyMuted = date.map { $0 > Date() } ?? false
        if isEmergencyMuted {
            cancelWaterRemindersSync()
        } else {
            Task { await scheduleWaterReminders() }
        }
    }

    func muteForToday() {
        let cal = Calendar.current
        var endOfDay = cal.startOfDay(for: Date())
        endOfDay = cal.date(byAdding: .day, value: 1, to: endOfDay) ?? Date()
        setEmergencyMute(until: endOfDay)
    }

    // MARK: - Water Reminders (hourly 10 AM–10 PM, escalate at +10 and +30 min)
    func scheduleWaterReminders() async {
        guard !isEmergencyMuted else { return }
        await cancelWaterReminders()

        var notifIndex = 0

        for hour in waterStartHour...waterEndHour {
            for offset in escalationOffsets {
                let msgIndex = notifIndex % waterMessages.count
                let msg = waterMessages[msgIndex]
                let title = offset == 0 ? msg.title : "Reminder: \(msg.title)"
                let body  = offset == 0
                    ? msg.body
                    : followUpBodies[min((offset == 10 ? 0 : 1), followUpBodies.count - 1)]

                await scheduleRepeatingWaterNotif(
                    id: waterNotifId(hour: hour, offset: offset),
                    title: title,
                    body: body,
                    hour: hour,
                    minute: offset,
                    isFollowUp: offset > 0
                )
                notifIndex += 1
            }
        }
    }

    private func waterNotifId(hour: Int, offset: Int) -> String {
        "water-\(hour)-\(offset)"
    }

    private func scheduleRepeatingWaterNotif(
        id: String, title: String, body: String,
        hour: Int, minute: Int, isFollowUp: Bool
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isFollowUp ? UNNotificationSound.defaultCritical : .default
        content.categoryIdentifier = Self.waterCategoryId
        if isFollowUp {
            content.interruptionLevel = .timeSensitive
        }

        var dc = DateComponents()
        dc.hour   = hour
        dc.minute = minute
        dc.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // Cancel all escalation slots for current hour after user logs water
    func cancelWaterRemindersForCurrentHour() {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        guard hour >= waterStartHour, hour <= waterEndHour else { return }

        let ids = escalationOffsets.map { waterNotifId(hour: hour, offset: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelWaterReminders() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("water-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func cancelWaterRemindersSync() {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("water-") }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Task Reminders
    func scheduleTaskReminder(task: TaskItem) async {
        guard let dueTime = task.dueTime, dueTime > Date() else { return }

        let taskId = task.taskId
        let slots: [(Int, String)] = [(0, ""), (10, "Reminder: "), (30, "Don't forget: ")]

        for (offset, prefix) in slots {
            guard let fireDate = Calendar.current.date(
                byAdding: .minute, value: offset, to: dueTime
            ), fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = task.priority == .urgent ? "⚠️ \(task.title)" : task.title
            content.body = prefix.isEmpty
                ? (task.description.isEmpty ? "Task reminder" : task.description)
                : "\(prefix)\(task.title)"
            content.sound = offset > 0 ? UNNotificationSound.defaultCritical : .default
            content.categoryIdentifier = Self.taskCategoryId

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "task-\(taskId)-\(offset)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelTaskReminders(taskId: String) {
        let ids = [0, 10, 30].map { "task-\(taskId)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func rescheduleAllTaskReminders(tasks: [TaskItem]) async {
        let pending = await center.pendingNotificationRequests()
        let old = pending.map(\.identifier).filter { $0.hasPrefix("task-") }
        center.removePendingNotificationRequests(withIdentifiers: old)
        for task in tasks where task.isActive {
            await scheduleTaskReminder(task: task)
        }
    }

    // MARK: - Cancel All
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

// MARK: - Delegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound, .badge])
    }
}
