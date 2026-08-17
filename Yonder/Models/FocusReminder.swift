//
//  FocusReminder.swift
//  Yonder
//

import Foundation
import SwiftData

/// SwiftData model representing a scheduled focus reminder.
@Model
final class FocusReminder {
    var id: UUID
    var hour: Int
    var minute: Int
    /// Array of weekday integers (1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday).
    /// Empty array represents a one-time reminder.
    var repeatDays: [Int]
    var durationSeconds: Int
    var isEnabled: Bool
    var dateCreated: Date
    /// Optional target work area name. If nil or empty, represents a general focus reminder ("Genel odak").
    var workItemName: String? = nil
    /// Migration-safe optional flag indicating if this is a single one-time reminder.
    var isOneTime: Bool? = false
    /// Migration-safe target Date for one-time reminders.
    var oneTimeDate: Date? = nil

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        repeatDays: [Int] = [],
        durationSeconds: Int = 1500,
        isEnabled: Bool = true,
        dateCreated: Date = Date(),
        workItemName: String? = nil,
        isOneTime: Bool? = false,
        oneTimeDate: Date? = nil
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.durationSeconds = durationSeconds
        self.isEnabled = isEnabled
        self.dateCreated = dateCreated
        self.workItemName = workItemName
        self.isOneTime = isOneTime
        self.oneTimeDate = oneTimeDate
    }

    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var formattedDuration: String {
        let mins = durationSeconds / 60
        if mins >= 60 {
            let hrs = mins / 60
            let remMins = mins % 60
            return remMins > 0 ? "\(hrs) sa \(remMins) dk" : "\(hrs) sa"
        }
        return "\(mins) dk"
    }

    /// Normalized work area name or nil if general focus.
    var normalizedWorkItem: String? {
        guard let name = workItemName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }
        return name
    }

    /// Determines if this is a single one-time (non-repeating) reminder.
    var checkIsOneTime: Bool {
        if let flag = isOneTime, flag == true { return true }
        if oneTimeDate != nil { return true }
        if repeatDays.isEmpty { return true }
        if repeatDays.count == 1 {
            let cal = Calendar.current
            let createdWeekday = cal.component(.weekday, from: dateCreated)
            if repeatDays.contains(createdWeekday) {
                return true
            }
        }
        return false
    }

    /// Returns `true` if this is a one-time reminder whose scheduled trigger date/time has passed.
    var isExpired: Bool {
        guard checkIsOneTime else {
            // Recurring reminders (Every day, Weekdays, Weekend, or custom repeating weekdays) NEVER expire.
            return false
        }

        let now = Date()
        let cal = Calendar.current

        if let target = oneTimeDate {
            return now > target
        }

        // Fallback target date calculation:
        let scheduledTarget = cal.date(bySettingHour: hour, minute: minute, second: 0, of: dateCreated) ?? dateCreated
        return now > scheduledTarget
    }
}