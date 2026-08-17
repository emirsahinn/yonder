//
//  WorkItemLimits.swift
//  Yonder
//

import Foundation

/// Central definition for work item (subject) limit rules.
enum WorkItemLimits {
    /// Maximum number of active work areas a free user can use.
    static let freeWorkItemLimit: Int = 10

    /// Returns `true` if a non-premium user has reached or exceeded the free work item limit for creating new items.
    static func isLimitReached(currentCount: Int, isPremiumUser: Bool) -> Bool {
        return !isPremiumUser && currentCount >= freeWorkItemLimit
    }

    /// Computes the set of active `Subject` IDs.
    /// If `isPremiumUser` is true, all subjects are active.
    /// Otherwise, subjects are sorted by `lastUsedDate` descending (falling back to `id` for stability),
    /// and the top 10 subjects are active; the rest are locked.
    static func activeSubjectIDs(from subjects: [Subject], isPremiumUser: Bool) -> Set<UUID> {
        let activeSubjects = subjects.filter { !$0.isArchived }
        if isPremiumUser || activeSubjects.count <= freeWorkItemLimit {
            return Set(activeSubjects.map { $0.id })
        }

        // Sort by lastUsedDate descending, tie-breaker id
        let sorted = activeSubjects.sorted { s1, s2 in
            if s1.lastUsedDate != s2.lastUsedDate {
                return s1.lastUsedDate > s2.lastUsedDate
            }
            return s1.id.uuidString > s2.id.uuidString
        }

        let activeSlice = sorted.prefix(freeWorkItemLimit)
        return Set(activeSlice.map { $0.id })
    }

    /// Returns `true` if the specific subject is locked for the user.
    static func isSubjectLocked(_ subject: Subject, allSubjects: [Subject], isPremiumUser: Bool) -> Bool {
        guard !subject.isArchived else { return true }
        let activeSubjects = allSubjects.filter { !$0.isArchived }
        guard !isPremiumUser && activeSubjects.count > freeWorkItemLimit else { return false }
        let activeIDs = activeSubjectIDs(from: allSubjects, isPremiumUser: isPremiumUser)
        return !activeIDs.contains(subject.id)
    }
}
