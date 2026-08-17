//
//  WorkItemMaintenanceHelper.swift
//  Yonder
//

import Foundation
import SwiftData

enum WorkItemMaintenanceHelper {

    /// Cleans, normalizes, and merges duplicate Subject records in SwiftData.
    /// Also updates historical FocusSession subject titles if duplicates are consolidated.
    @MainActor
    static func cleanAndNormalizeSubjects(
        modelContext: ModelContext,
        savedSubjects: [Subject],
        allSessions: [FocusSession]
    ) {
        guard !savedSubjects.isEmpty else { return }

        // Group subjects by their lowercased normalized name
        var normalizedGroups: [String: [Subject]] = [:]

        for subject in savedSubjects {
            let normName = subject.name.normalizedWorkItemName()
            if normName.isEmpty {
                // Delete empty/whitespace-only subject
                SyncService.shared.deleteSubject(subject)
                modelContext.delete(subject)
                continue
            }

            let key = normName.lowercased()
            normalizedGroups[key, default: []].append(subject)
        }

        var didMutate = false

        for (key, group) in normalizedGroups {
            let targetName = group.first?.name.normalizedWorkItemName() ?? key.capitalized

            if group.count == 1 {
                let single = group[0]
                if single.name != targetName {
                    single.name = targetName
                    if single.updatedAt == nil {
                        single.updatedAt = Date()
                    }
                    SyncService.shared.syncSubject(single)
                    didMutate = true
                }
            } else {
                // Multiple duplicate subjects matching the same normalized name.
                // Keep the one with the latest lastUsedDate.
                let sorted = group.sorted { $0.lastUsedDate > $1.lastUsedDate }
                let winner = sorted[0]
                let duplicates = sorted.dropFirst()

                if winner.name != targetName {
                    winner.name = targetName
                    winner.updatedAt = Date()
                }
                SyncService.shared.syncSubject(winner)

                for dup in duplicates {
                    let dupName = dup.name
                    // Re-point past sessions matching dupName to targetName
                    for session in allSessions {
                        if let sName = session.subject, sName.localizedCaseInsensitiveCompare(dupName) == .orderedSame {
                            session.subject = targetName
                        }
                    }
                    SyncService.shared.deleteSubject(dup)
                    modelContext.delete(dup)
                }
                didMutate = true
            }
        }

        if didMutate {
            do {
                try modelContext.save()
                print("[WorkItemMaintenanceHelper] ✅ Successfully normalized and merged subjects.")
            } catch {
                print("[WorkItemMaintenanceHelper] ❌ Maintenance save error: \(error.localizedDescription)")
            }
        }
    }
}
