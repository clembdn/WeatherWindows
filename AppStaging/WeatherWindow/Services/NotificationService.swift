import Foundation
import UserNotifications

// Departure reminders. Permission is asked the first time the user taps "Remind me", never at launch.
@Observable
final class NotificationService {
    private(set) var isDenied = false

    // Schedules the reminder, replacing an older one with the same id, and returns the sentence to show.
    func scheduleReminder(id: String, at date: Date, body: String) async -> String {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        guard await center.notificationSettings().authorizationStatus == .authorized else {
            isDenied = true
            return "Notifications are off, so no reminder was set."
        }
        isDenied = false

        let content = UNMutableNotificationContent()
        content.title = "Time to leave"
        content.body = body
        content.sound = .default
        let moment = Melbourne.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: moment, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            return "Reminder set for \(Melbourne.time(date))."
        } catch {
            return "The reminder couldn't be set. \(error.localizedDescription)"
        }
    }
}
