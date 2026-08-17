//
//  SyncService.swift
//  Yonder
//
//  Handles bidirectional synchronisation of FocusSession, Subject and WorkGoal
//  records between local SwiftData / UserDefaults and Firestore.
//
//  Only active when the current Firebase user is a real (non-anonymous) account.
//  All operations are fire-and-forget; errors are logged, never thrown.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData

// MARK: - SyncService

/// Coordinates read/write of the three synced entity types to Firestore.
final class SyncService {

    static let shared = SyncService()

    private let db = Firestore.firestore()

    private init() {}

    // =========================================================================
    // MARK: - Convenience Guard
    // =========================================================================

    /// Returns the UID of the currently signed-in, non-anonymous user — or nil.
    private var linkedUID: String? {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return nil }
        return user.uid
    }

    // =========================================================================
    // MARK: - FocusSession — Upload (existing behaviour, preserved)
    // =========================================================================

    /// Writes a single FocusSession to `users/{uid}/sessions/{sessionId}`.
    /// No-op if no authenticated non-anonymous user exists.
    func syncSession(_ session: FocusSession) {
        guard let uid = linkedUID else { return }
        let data = sessionData(for: session)
        db.collection("users")
            .document(uid)
            .collection("sessions")
            .document(session.id.uuidString)
            .setData(data, merge: true) { error in
                if let error = error {
                    print("[SyncService] ❌ Error syncing session: \(error.localizedDescription)")
                } else {
                    print("[SyncService] ✅ Session synced: \(session.id.uuidString)")
                }
            }
    }

    /// Uploads all provided local sessions to Firestore in a batch.
    /// Called once after a user links their Google account so past sessions are preserved.
    func backfillSessions(_ sessions: [FocusSession]) {
        guard let uid = linkedUID else { return }
        let batch = db.batch()
        let userRef = db.collection("users").document(uid)
        for session in sessions {
            let docRef = userRef.collection("sessions").document(session.id.uuidString)
            let data = sessionData(for: session)
            batch.setData(data, forDocument: docRef, merge: true)
        }
        batch.commit { error in
            if let error = error {
                print("[SyncService] ❌ Batch backfill error: \(error.localizedDescription)")
            } else {
                print("[SyncService] ✅ Backfilled \(sessions.count) sessions for uid: \(uid)")
            }
        }
    }

    /// Deletes a synced FocusSession from Firestore.
    func deleteSession(_ session: FocusSession) {
        guard let uid = linkedUID else { return }
        db.collection("users")
            .document(uid)
            .collection("sessions")
            .document(session.id.uuidString)
            .delete { error in
                if let error = error {
                    print("[SyncService] ❌ Error deleting session: \(error.localizedDescription)")
                } else {
                    print("[SyncService] ✅ Session deleted: \(session.id.uuidString)")
                }
            }
    }

    // =========================================================================
    // MARK: - FocusSession — Download & Merge
    // =========================================================================

    /// Downloads all sessions from Firestore and merges them into SwiftData.
    /// - Remote ID missing locally → insert
    /// - Remote ID exists locally → update mutable fields
    /// - Local ID missing remotely → upload (backfill)
    func syncDownSessions(
        uid: String,
        modelContext: ModelContext,
        uploadLocalChanges: Bool = true,
        pruneLocalOnly: Bool = false
    ) async {
        do {
            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("sessions")
                .getDocuments()

            // Build a set of all remote IDs for backfill detection
            var remoteIDs = Set<String>()

            // Fetch all local sessions once
            let localDescriptor = FetchDescriptor<FocusSession>()
            let localSessions = (try? modelContext.fetch(localDescriptor)) ?? []
            let localByID: [String: FocusSession] = Dictionary(
                uniqueKeysWithValues: localSessions.map { ($0.id.uuidString, $0) }
            )

            for doc in snapshot.documents {
                let data = doc.data()
                guard let idStr = data["id"] as? String else { continue }
                remoteIDs.insert(idStr)

                if let local = localByID[idStr] {
                    // Update existing record with remote fields
                    applyRemoteSession(data, to: local)
                } else {
                    // Insert new session from remote
                    if let newSession = parseSessionFromFirestore(data) {
                        modelContext.insert(newSession)
                    }
                }
            }

            // Save all inserts/updates
            try? modelContext.save()
            print("[SyncService] ✅ Session sync-down complete. Remote count: \(snapshot.documents.count)")

            let localOnlySessions = localSessions.filter { !remoteIDs.contains($0.id.uuidString) }
            if uploadLocalChanges {
                if !localOnlySessions.isEmpty {
                    backfillSessions(localOnlySessions)
                }
            } else if pruneLocalOnly {
                for session in localOnlySessions {
                    modelContext.delete(session)
                }
                try? modelContext.save()
            }
        } catch {
            print("[SyncService] ❌ Session sync-down error: \(error.localizedDescription)")
        }
    }

    // =========================================================================
    // MARK: - Subject — Upload
    // =========================================================================

    /// Writes a single Subject to `users/{uid}/subjects/{subjectId}`.
    func syncSubject(_ subject: Subject) {
        guard let uid = linkedUID else { return }
        let data = subjectData(for: subject)
        db.collection("users")
            .document(uid)
            .collection("subjects")
            .document(subject.id.uuidString)
            .setData(data, merge: true) { error in
                if let error = error {
                    print("[SyncService] ❌ Error syncing subject: \(error.localizedDescription)")
                } else {
                    print("[SyncService] ✅ Subject synced: \(subject.name)")
                }
            }
    }

    /// Deletes a synced Subject from Firestore.
    func deleteSubject(_ subject: Subject) {
        guard let uid = linkedUID else { return }
        db.collection("users")
            .document(uid)
            .collection("subjects")
            .document(subject.id.uuidString)
            .delete { error in
                if let error = error {
                    print("[SyncService] ❌ Error deleting subject: \(error.localizedDescription)")
                } else {
                    print("[SyncService] ✅ Subject deleted: \(subject.name)")
                }
            }
    }

    // =========================================================================
    // MARK: - Subject — Download & Merge
    // =========================================================================

    /// Downloads all subjects from Firestore and merges into SwiftData.
    /// Merge key: name (case-insensitive). Tie-breaker: lastUsedDate.
    func syncDownSubjects(
        uid: String,
        modelContext: ModelContext,
        uploadLocalChanges: Bool = true,
        pruneLocalOnly: Bool = false
    ) async {
        do {
            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("subjects")
                .getDocuments()

            let localDescriptor = FetchDescriptor<Subject>()
            let localSubjects = (try? modelContext.fetch(localDescriptor)) ?? []

            // Index by lowercased name for fast case-insensitive lookup
            var localByName: [String: Subject] = [:]
            for s in localSubjects {
                localByName[s.name.lowercased()] = s
            }

            var remoteNames = Set<String>()

            for doc in snapshot.documents {
                let data = doc.data()
                guard let parsed = parseSubjectFromFirestore(data) else { continue }
                let key = parsed.name.lowercased()
                remoteNames.insert(key)

                if let local = localByName[key] {
                    // Tie-break: keep the more recently used date
                    let remoteUpdated = parsed.updatedAt ?? parsed.lastUsedDate
                    let localUpdated = local.updatedAt ?? local.lastUsedDate
                    if parsed.lastUsedDate > local.lastUsedDate || remoteUpdated > localUpdated {
                        local.lastUsedDate = parsed.lastUsedDate
                        local.updatedAt = parsed.updatedAt
                        local.archivedAt = parsed.archivedAt
                    }
                } else {
                    // Insert new subject from remote
                    let newSubject = Subject(
                        id: parsed.id,
                        name: parsed.name,
                        lastUsedDate: parsed.lastUsedDate,
                        updatedAt: parsed.updatedAt,
                        archivedAt: parsed.archivedAt
                    )
                    modelContext.insert(newSubject)
                    localByName[key] = newSubject
                }
            }

            try? modelContext.save()
            print("[SyncService] ✅ Subject sync-down complete. Remote count: \(snapshot.documents.count)")

            let localOnlySubjects = localSubjects.filter { !remoteNames.contains($0.name.lowercased()) }
            if uploadLocalChanges {
                for subject in localOnlySubjects {
                    syncSubject(subject)
                }
            } else if pruneLocalOnly {
                for subject in localOnlySubjects {
                    modelContext.delete(subject)
                }
                try? modelContext.save()
            }
        } catch {
            print("[SyncService] ❌ Subject sync-down error: \(error.localizedDescription)")
        }
    }

    // =========================================================================
    // MARK: - WorkGoal — Upload
    // =========================================================================

    /// Writes a single WorkGoal to `users/{uid}/goals/{goalId}`.
    func syncGoal(_ goal: WorkGoal, uid: String) {
        let data = goalData(for: goal)
        db.collection("users")
            .document(uid)
            .collection("goals")
            .document(goal.id.uuidString)
            .setData(data, merge: true) { error in
                if let error = error {
                    print("[SyncService] ❌ Error syncing goal: \(error.localizedDescription)")
                } else {
                    print("[SyncService] ✅ Goal synced: \(goal.id.uuidString)")
                }
            }
    }

    /// Deletes a WorkGoal from Firestore.
    func deleteGoal(id: UUID, uid: String) {
        db.collection("users")
            .document(uid)
            .collection("goals")
            .document(id.uuidString)
            .delete { error in
                if let error = error {
                    print("[SyncService] ❌ Error deleting goal: \(error.localizedDescription)")
                } else {
                    print("[SyncService] ✅ Goal deleted: \(id.uuidString)")
                }
            }
    }

    // =========================================================================
    // MARK: - WorkGoal — Download & Merge
    // =========================================================================

    /// Downloads all goals from Firestore and merges them into WorkGoalStore.
    /// Primary key: id. Tie-breaker: updatedAt.
    /// Duplicate guard: scope + period + mode + workAreaName — no duplication.
    func syncDownGoals(
        uid: String,
        goalStore: WorkGoalStore,
        uploadLocalChanges: Bool = true,
        replaceLocalWithRemote: Bool = false
    ) async {
        do {
            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("goals")
                .getDocuments()

            var remoteGoals: [WorkGoal] = []
            for doc in snapshot.documents {
                if let goal = parseGoalFromFirestore(doc.data()) {
                    remoteGoals.append(goal)
                }
            }

            await MainActor.run {
                if replaceLocalWithRemote {
                    goalStore.replaceWithRemoteGoals(remoteGoals)
                } else {
                    goalStore.applyRemoteGoals(remoteGoals)
                }
            }

            print("[SyncService] ✅ Goal sync-down complete. Remote count: \(remoteGoals.count)")

            if uploadLocalChanges {
                let remoteIDs = Set(remoteGoals.map { $0.id.uuidString })
                let toUpload = goalStore.goals.filter { !remoteIDs.contains($0.id.uuidString) }
                for goal in toUpload {
                    syncGoal(goal, uid: uid)
                }
            }
        } catch {
            print("[SyncService] ❌ Goal sync-down error: \(error.localizedDescription)")
        }
    }

    // =========================================================================
    // MARK: - Firestore Data Serialisation
    // =========================================================================

    private func sessionData(for session: FocusSession) -> [String: Any] {
        var data: [String: Any] = [
            "id": session.id.uuidString,
            "date": Timestamp(date: session.date),
            "durationSeconds": session.durationSeconds,
            "completed": session.completed,
            "intentionNote": session.intentionNote ?? "",
            "subject": session.subject ?? session.intentionNote ?? "",
            "mode": session.modeRawValue,
            "syncedAt": FieldValue.serverTimestamp()
        ]
        data["startedAt"] = session.startedAt.map { Timestamp(date: $0) } ?? NSNull()
        data["endedAt"] = session.endedAt.map { Timestamp(date: $0) } ?? NSNull()
        data["plannedDurationSeconds"] = session.plannedDurationSeconds ?? NSNull()
        data["roomId"] = (session.roomId?.isEmpty == false) ? session.roomId! : NSNull()
        return data
    }

    private func subjectData(for subject: Subject) -> [String: Any] {
        let normName = subject.name.normalizedWorkItemName()
        return [
            "id": subject.id.uuidString,
            "name": normName.isEmpty ? subject.name : normName,
            "lastUsedDate": Timestamp(date: subject.lastUsedDate),
            "updatedAt": Timestamp(date: subject.updatedAt ?? subject.lastUsedDate),
            "archivedAt": subject.archivedAt.map { Timestamp(date: $0) } ?? NSNull()
        ]
    }

    private func goalData(for goal: WorkGoal) -> [String: Any] {
        var data: [String: Any] = [
            "id": goal.id.uuidString,
            "scope": goal.scope.rawValue,
            "period": goal.period.rawValue,
            "mode": goal.mode.rawValue,
            "targetSeconds": goal.targetSeconds,
            "isEnabled": goal.isEnabled,
            "createdAt": Timestamp(date: goal.createdAt),
            "updatedAt": Timestamp(date: goal.updatedAt)
        ]
        data["workAreaName"] = goal.workAreaName ?? NSNull()
        data["startDate"] = goal.startDate.map { Timestamp(date: $0) } ?? NSNull()
        data["endDate"] = goal.endDate.map { Timestamp(date: $0) } ?? NSNull()
        return data
    }

    // =========================================================================
    // MARK: - Firestore Data Deserialisation
    // =========================================================================

    private func parseSessionFromFirestore(_ data: [String: Any]) -> FocusSession? {
        guard
            let idStr = data["id"] as? String,
            let id = UUID(uuidString: idStr),
            let dateTs = data["date"] as? Timestamp,
            let durationSeconds = data["durationSeconds"] as? Int,
            let completed = data["completed"] as? Bool
        else { return nil }

        let intentionNote = data["intentionNote"] as? String
        let subject = data["subject"] as? String
        let modeRawValue = data["mode"] as? String ?? FocusSessionMode.solo.rawValue
        let roomId = data["roomId"] as? String
        let startedAt = (data["startedAt"] as? Timestamp)?.dateValue()
        let endedAt = (data["endedAt"] as? Timestamp)?.dateValue()
        let plannedDurationSeconds = data["plannedDurationSeconds"] as? Int

        return FocusSession(
            id: id,
            date: dateTs.dateValue(),
            durationSeconds: durationSeconds,
            completed: completed,
            intentionNote: intentionNote?.isEmpty == false ? intentionNote : nil,
            subject: subject?.isEmpty == false ? subject : nil,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedDurationSeconds: plannedDurationSeconds,
            modeRawValue: modeRawValue,
            roomId: roomId?.isEmpty == false ? roomId : nil
        )
    }

    private func applyRemoteSession(_ data: [String: Any], to local: FocusSession) {
        if let dateTs = data["date"] as? Timestamp {
            local.date = dateTs.dateValue()
        }
        if let duration = data["durationSeconds"] as? Int {
            local.durationSeconds = duration
        }
        if let completed = data["completed"] as? Bool {
            local.completed = completed
        }
        if let note = data["intentionNote"] as? String {
            local.intentionNote = note.isEmpty ? nil : note
        }
        if let subject = data["subject"] as? String {
            local.subject = subject.isEmpty ? nil : subject
        }
        if let startedAt = (data["startedAt"] as? Timestamp)?.dateValue() {
            local.startedAt = startedAt
        }
        if let endedAt = (data["endedAt"] as? Timestamp)?.dateValue() {
            local.endedAt = endedAt
        }
        if let planned = data["plannedDurationSeconds"] as? Int {
            local.plannedDurationSeconds = planned
        }
        if let mode = data["mode"] as? String {
            local.modeRawValue = mode
        }
        if let roomId = data["roomId"] as? String, !roomId.isEmpty {
            local.roomId = roomId
        }
    }

    private func parseSubjectFromFirestore(_ data: [String: Any])
        -> (id: UUID, name: String, lastUsedDate: Date, updatedAt: Date?, archivedAt: Date?)?
    {
        guard
            let idStr = data["id"] as? String,
            let id = UUID(uuidString: idStr),
            let name = data["name"] as? String,
            !name.normalizedWorkItemName().isEmpty,
            let lastUsedTs = data["lastUsedDate"] as? Timestamp
        else { return nil }

        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? lastUsedTs.dateValue()
        let archivedAt = (data["archivedAt"] as? Timestamp)?.dateValue()
        return (id: id, name: name.normalizedWorkItemName(), lastUsedDate: lastUsedTs.dateValue(), updatedAt: updatedAt, archivedAt: archivedAt)
    }

    private func parseGoalFromFirestore(_ data: [String: Any]) -> WorkGoal? {
        guard
            let idStr = data["id"] as? String,
            let id = UUID(uuidString: idStr),
            let scopeStr = data["scope"] as? String,
            let scope = WorkGoalScope(rawValue: scopeStr),
            let periodStr = data["period"] as? String,
            let period = WorkGoalPeriod(rawValue: periodStr),
            let modeStr = data["mode"] as? String,
            let mode = WorkGoalMode(rawValue: modeStr),
            let targetSeconds = data["targetSeconds"] as? Int
        else { return nil }

        let isEnabled = data["isEnabled"] as? Bool ?? true
        let workAreaName = data["workAreaName"] as? String
        let startDate = (data["startDate"] as? Timestamp)?.dateValue()
        let endDate = (data["endDate"] as? Timestamp)?.dateValue()
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return WorkGoal(
            id: id,
            scope: scope,
            workAreaName: workAreaName?.isEmpty == false ? workAreaName : nil,
            period: period,
            mode: mode,
            startDate: startDate,
            endDate: endDate,
            targetSeconds: targetSeconds,
            isEnabled: isEnabled,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
