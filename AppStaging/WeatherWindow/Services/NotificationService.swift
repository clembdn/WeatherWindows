import Foundation
import OSLog
import UserNotifications

/// Departure reminders; permission is asked the first time the user taps "Remind me", never at launch.
@Observable
final class NotificationService {
    private(set) var isDenied = false

    /// Schedules (or replaces) the reminder with this identifier. Returns false when notifications are off.
    func scheduleReminder(id: String, at date: Date, title: String, body: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            }
            guard await center.notificationSettings().authorizationStatus == .authorized else {
                isDenied = true
                return false
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let moment = AppClock.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: moment, repeats: false)
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            isDenied = false
            return true
        } catch {
            Logger.data.error("Reminder could not be scheduled: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
