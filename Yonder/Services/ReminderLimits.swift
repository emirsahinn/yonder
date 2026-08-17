//
//  ReminderLimits.swift
//  Yonder
//

import Foundation

/// Central definition for reminder limit rules.
/// v1 launch: all limits removed — all users get unlimited reminders and repeat days.
/// Keep the enum and function signatures intact for easy re-introduction later.
enum ReminderLimits {
    /// v1: unlimited for all users.
    static let freeActiveReminderLimit: Int = Int.max
    /// v1: unlimited for all users.
    static let freeRepeatDayLimit: Int = Int.max

    /// Returns all non-expired reminder IDs as active (no Pro gate).
    static func activeReminderIDs(from reminders: [FocusReminder], isPremiumUser: Bool) -> Set<UUID> {
        Set(reminders.filter { !$0.isExpired }.map { $0.id })
    }

    /// v1: reminders are never locked.
    static func isReminderLocked(_ reminder: FocusReminder, allReminders: [FocusReminder], isPremiumUser: Bool) -> Bool {
        return false
    }

    /// v1: always allowed to enable another reminder.
    static func canEnableAnotherReminder(allReminders: [FocusReminder], isPremiumUser: Bool) -> Bool {
        return true
    }

    /// Returns all selected repeat days without any plan restriction.
    static func effectiveRepeatDays(for reminder: FocusReminder, isPremiumUser: Bool) -> [Int] {
        Array(Set(reminder.repeatDays)).sorted()
    }

    /// v1: any day set is allowed.
    static func canUseRepeatDays(_ days: Set<Int>, isPremiumUser: Bool) -> Bool {
        return true
    }
}
