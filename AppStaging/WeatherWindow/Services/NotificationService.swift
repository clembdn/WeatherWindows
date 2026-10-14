import Foundation
import OSLog
import UserNotifications

private let logger = Logger(subsystem: "edu.monash.cboudon.WeatherWindow", category: "notifications")

// Departure reminders and rain alerts. Permission is asked the first time one is needed, never at launch.
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private(set) var isDenied = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Schedules the reminder, replacing an older one with the same id, and returns the sentence to show.
    func scheduleReminder(id: String, at date: Date, body: String) async -> String {
        guard await isAllowed() else {
            return "Notifications are off, so no reminder was set."
        }

        let content = UNMutableNotificationContent()
        content.title = "Time to leave"
        content.body = body
        content.sound = .default
        let moment = Melbourne.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: moment, repeats: false)
        do {
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            return "Reminder set for \(Melbourne.time(date))."
        } catch {
            return "The reminder couldn't be set. \(error.localizedDescription)"
        }
    }

    // Notifies right away, for example when rain starts heading for the next walk.
    func alertNow(id: String, body: String) async {
        guard await isAllowed() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rain is coming"
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        do {
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        } catch {
            logger.error("The rain alert couldn't be sent: \(error.localizedDescription)")
        }
    }

    // Asks for permission the first time; afterwards only reads the user's choice.
    private func isAllowed() async -> Bool {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        isDenied = await center.notificationSettings().authorizationStatus != .authorized
        return !isDenied
    }

    // iOS hides notifications while the app is open unless asked; rain alerts come while it is.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
