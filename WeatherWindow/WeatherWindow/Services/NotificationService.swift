//
//  NotificationService.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import OSLog
import UserNotifications

private let logger = Logger(subsystem: "edu.monash.cboudon.WeatherWindow", category: "notifications")

@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private(set) var isDenied = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

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

    private func isAllowed() async -> Bool {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        isDenied = await center.notificationSettings().authorizationStatus != .authorized
        return !isDenied
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
