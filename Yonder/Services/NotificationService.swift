//
//  NotificationService.swift
//  Yonder
//

import Foundation
import UserNotifications
import Combine

extension Notification.Name {
    /// Notification posted when a user taps a focus reminder notification.
    static let didTapFocusReminderNotification = Notification.Name("didTapFocusReminderNotification")
    /// Notification posted when user taps the weekly recap summary notification.
    static let didTapWeeklyRecapNotification = Notification.Name("didTapWeeklyRecapNotification")
}

/// Singleton managing local notification authorization, calendar triggers, and tap handling.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Authorization

    /// Requests notification permission lazily when the user creates or enables their first reminder.
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            return try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        } catch {
            print("[NotificationService] Authorization error: \(error.localizedDescription)")
            return false
        }
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Notification Copy Helpers

    private func notificationContent(for workItemName: String?) -> (title: String, body: String) {
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "en"

        if let name = workItemName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            let title = name
            let body = lang == "tr" ? "\(name) için iyi bir zaman." : "A good time for \(name)."
            return (title, body)
        } else {
            let title = "Yonder"
            let body = lang == "tr" ? "Odaklanmak için iyi bir zaman." : "A good time to focus."
            return (title, body)
        }
    }

    // MARK: - Schedule & Cancel

    /// Schedules calendar triggers for a FocusReminder.
    func scheduleReminder(_ reminder: FocusReminder, allReminders: [FocusReminder] = []) {
        // Cancel existing triggers for this reminder first
        cancelReminder(reminder)

        guard reminder.isEnabled && !reminder.isExpired else { return }

        let isPremiumUser = UserDefaults.standard.bool(forKey: "is_premium_user")
        let activeReminders = allReminders.isEmpty ? [reminder] : allReminders

        if ReminderLimits.isReminderLocked(reminder, allReminders: activeReminders, isPremiumUser: isPremiumUser) {
            print("[NotificationService] 🔒 Reminder is locked under Free plan. Skipping schedule.")
            return
        }

        let (title, body) = notificationContent(for: reminder.workItemName)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["durationSeconds": reminder.durationSeconds]

        if reminder.checkIsOneTime {
            let now = Date()
            let cal = Calendar.current
            let targetDate: Date
            if let customOneTime = reminder.oneTimeDate {
                targetDate = customOneTime
            } else {
                targetDate = cal.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0, of: reminder.dateCreated) ?? reminder.dateCreated
            }

            // If scheduled target date/time is in the past, do not schedule
            guard targetDate > now else {
                print("[NotificationService] ⏳ One-time reminder is in the past. Skipping schedule.")
                return
            }

            let triggerComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

            let request = UNNotificationRequest(
                identifier: notificationIdentifier(id: reminder.id, day: 0),
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[NotificationService] Error scheduling one-time reminder: \(error.localizedDescription)")
                }
            }
        } else {
            // Repeating reminder for specified weekdays
            let scheduledWeekdays = ReminderLimits.effectiveRepeatDays(for: reminder, isPremiumUser: isPremiumUser)
            if !isPremiumUser && reminder.repeatDays.count > scheduledWeekdays.count {
                print("[NotificationService] 🔒 Free plan schedules only one repeat day per reminder.")
            }

            for weekday in scheduledWeekdays {
                var dateComponents = DateComponents()
                dateComponents.hour = reminder.hour
                dateComponents.minute = reminder.minute
                dateComponents.weekday = weekday // 1=Sunday, 2=Monday, ..., 7=Saturday

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: notificationIdentifier(id: reminder.id, day: weekday),
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("[NotificationService] Error scheduling repeating reminder for day \(weekday): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Cancels all scheduled triggers for a FocusReminder.
    func cancelReminder(_ reminder: FocusReminder) {
        var identifiersToCancel = [notificationIdentifier(id: reminder.id, day: 0)]
        for day in 1...7 {
            identifiersToCancel.append(notificationIdentifier(id: reminder.id, day: day))
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
    }

    private func notificationIdentifier(id: UUID, day: Int) -> String {
        "yonder.reminder.\(id.uuidString).day\(day)"
    }

    // MARK: - Weekly Recap Notification

    private let weeklyRecapIdentifier = "yonder.weeklyRecap"

    /// Schedules a repeating weekly notification prompting the user to view their weekly focus recap.
    func scheduleWeeklyRecapNotification(weekday: Int = 1, hour: Int = 20, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyRecapIdentifier])

        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "en"
        let content = UNMutableNotificationContent()
        content.title = lang == "tr" ? "Bu haftanın özeti hazır" : "Your weekly recap is ready"
        content.body  = lang == "tr" ? "Odaklanma yolculuğuna bir bakış at." : "Take a moment to view your focus journey."
        content.sound = .default
        content.userInfo = ["type": "weeklyRecap"]

        var components = DateComponents()
        components.weekday = weekday // 1 = Sunday
        components.hour   = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyRecapIdentifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("[NotificationService] Weekly recap scheduling error: \(error.localizedDescription)")
            } else {
                print("[NotificationService] Weekly recap notification scheduled for weekday \(weekday) at \(hour):\(minute)")
            }
        }
    }

    /// Cancels the weekly recap notification (e.g. if user opts out).
    func cancelWeeklyRecapNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [weeklyRecapIdentifier])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let duration = userInfo["durationSeconds"] as? Int {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .didTapFocusReminderNotification,
                    object: nil,
                    userInfo: ["durationSeconds": duration]
                )
            }
        } else if let type = userInfo["type"] as? String, type == "weeklyRecap" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .didTapWeeklyRecapNotification,
                    object: nil
                )
            }
        }
        completionHandler()
    }
}
