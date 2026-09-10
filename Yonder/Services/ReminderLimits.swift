//
//  ReminderLimits.swift
//  Yonder
//

import Foundation

/// Central definition for reminder limit rules.
/// Reminders are a Pro-only feature — free users can't enable or schedule any.
enum ReminderLimits {
    /// Free users get no active reminders.
    static let freeActiveReminderLimit: Int = 0
    /// Free users get no repeat days scheduled.
    static let freeRepeatDayLimit: Int = 0

    /// Returns non-expired reminder IDs as active, but only for Pro users.
    static func activeReminderIDs(from reminders: [FocusReminder], isPremiumUser: Bool) -> Set<UUID> {
        guard isPremiumUser else { return [] }
        return Set(reminders.filter { !$0.isExpired }.map { $0.id })
    }

    /// Reminders require Pro; every reminder is locked for a free user.
    static func isReminderLocked(_ reminder: FocusReminder, allReminders: [FocusReminder], isPremiumUser: Bool) -> Bool {
        return !isPremiumUser
    }

    /// Only Pro users can enable another reminder.
    static func canEnableAnotherReminder(allReminders: [FocusReminder], isPremiumUser: Bool) -> Bool {
        return isPremiumUser
    }

    /// Returns the selected repeat days for Pro users; none for free users.
    static func effectiveRepeatDays(for reminder: FocusReminder, isPremiumUser: Bool) -> [Int] {
        guard isPremiumUser else { return [] }
        return Array(Set(reminder.repeatDays)).sorted()
    }

    /// Only Pro users can use any repeat day configuration.
    static func canUseRepeatDays(_ days: Set<Int>, isPremiumUser: Bool) -> Bool {
        return isPremiumUser
    }
}
