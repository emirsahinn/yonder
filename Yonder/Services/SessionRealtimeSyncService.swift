//
//  SessionRealtimeSyncService.swift
//  Yonder
//
//  Listens to real-time changes on Firestore `users/{uid}/sessions` collection
//  and synchronizes them into the local SwiftData store.
//

import Foundation
import FirebaseFirestore
import SwiftData

/// Real-time listener service for Firestore focus sessions.
@MainActor
final class SessionRealtimeSyncService {

    static let shared = SessionRealtimeSyncService()

    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private var activeUID: String?

    private init() {}

    func start(uid: String, modelContext: ModelContext) {
        if activeUID == uid && listenerRegistration != nil {
            return
        }

        stop()
        activeUID = uid

        print("[SessionRealtimeSyncService] Starting real-time listener for uid: \(uid)")

        listenerRegistration = db
            .collection("users")
            .document(uid)
            .collection("sessions")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("[SessionRealtimeSyncService] Snapshot error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else { return }

                Task { @MainActor in
                    self.applyRemoteSessions(snapshot.documentChanges, modelContext: modelContext)
                }
            }
    }

    func stop() {
        if listenerRegistration != nil {
            print("[SessionRealtimeSyncService] Stopping real-time listener")
            listenerRegistration?.remove()
            listenerRegistration = nil
        }
        activeUID = nil
    }

    private func applyRemoteSessions(_ documentChanges: [DocumentChange], modelContext: ModelContext) {
        guard !documentChanges.isEmpty else { return }

        let descriptor = FetchDescriptor<FocusSession>()
        guard let localSessions = try? modelContext.fetch(descriptor) else { return }

        var localByID: [String: FocusSession] = [:]
        for session in localSessions {
            localByID[session.id.uuidString] = session
        }

        var didMutate = false

        for change in documentChanges {
            let data = change.document.data()
            let documentID = change.document.documentID
            let idString = (data["id"] as? String) ?? documentID

            switch change.type {
            case .added, .modified:
                guard let parsed = parseSession(from: data, fallbackID: documentID) else { continue }

                if let existing = localByID[parsed.id.uuidString] {
                    apply(parsed, to: existing)
                } else {
                    modelContext.insert(parsed)
                    localByID[parsed.id.uuidString] = parsed
                }
                didMutate = true

            case .removed:
                if let existing = localByID[idString] {
                    modelContext.delete(existing)
                    localByID.removeValue(forKey: idString)
                    didMutate = true
                }
            }
        }

        guard didMutate else { return }

        do {
            try modelContext.save()
            updateTodayWidgetData(from: Array(localByID.values))
            print("[SessionRealtimeSyncService] SwiftData context saved with session changes")
        } catch {
            print("[SessionRealtimeSyncService] Save error: \(error.localizedDescription)")
        }
    }

    private func parseSession(from data: [String: Any], fallbackID: String) -> FocusSession? {
        let idString = (data["id"] as? String) ?? fallbackID
        guard
            let id = UUID(uuidString: idString),
            let dateTs = data["date"] as? Timestamp,
            let durationSeconds = intValue(data["durationSeconds"]),
            let completed = data["completed"] as? Bool
        else { return nil }

        let intentionNote = data["intentionNote"] as? String
        let subject = data["subject"] as? String
        let modeRawValue = data["mode"] as? String ?? FocusSessionMode.solo.rawValue
        let roomId = data["roomId"] as? String
        let startedAt = (data["startedAt"] as? Timestamp)?.dateValue()
        let endedAt = (data["endedAt"] as? Timestamp)?.dateValue()
        let plannedDurationSeconds = intValue(data["plannedDurationSeconds"])

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

    private func apply(_ remote: FocusSession, to local: FocusSession) {
        local.date = remote.date
        local.durationSeconds = remote.durationSeconds
        local.completed = remote.completed
        local.intentionNote = remote.intentionNote
        local.subject = remote.subject
        local.startedAt = remote.startedAt
        local.endedAt = remote.endedAt
        local.plannedDurationSeconds = remote.plannedDurationSeconds
        local.modeRawValue = remote.modeRawValue
        local.roomId = remote.roomId
    }

    private func updateTodayWidgetData(from sessions: [FocusSession]) {
        let calendar = Calendar.current
        let todayTotal = sessions
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationSeconds }
        WidgetDataService.shared.updateWidgetData(todayTotalSeconds: todayTotal)
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let int64 = value as? Int64 {
            return Int(int64)
        }
        if let double = value as? Double {
            return Int(double)
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }
}
