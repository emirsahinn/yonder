//
//  SubjectRealtimeSyncService.swift
//  Yonder
//
//  Listens to real-time changes on Firestore `users/{uid}/subjects` collection
//  and synchronises them into the local SwiftData store.
//
//  Active ONLY when a user is signed in with a Google account.
//  Stops automatically on sign-out or when no Google user is active.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData

/// Real-time listener service for Firestore subjects collection.
@MainActor
final class SubjectRealtimeSyncService {

    static let shared = SubjectRealtimeSyncService()

    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private var activeUID: String?

    private init() {}

    // =========================================================================
    // MARK: - Lifecycle
    // =========================================================================

    /// Starts listening for real-time updates on `users/{uid}/subjects`.
    /// Listener runs only for non-anonymous Google accounts.
    func start(uid: String, modelContext: ModelContext) {
        // Guard against duplicate initialization for the same user
        if activeUID == uid && listenerRegistration != nil {
            return
        }

        stop()
        activeUID = uid

        print("[SubjectRealtimeSyncService] 🎧 Starting real-time listener for uid: \(uid)")

        let collectionRef = db.collection("users").document(uid).collection("subjects")

        listenerRegistration = collectionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("[SubjectRealtimeSyncService] ❌ Snapshot error: \(error.localizedDescription)")
                return
            }

            guard let snapshot = snapshot else { return }

            Task { @MainActor in
                self.applyRemoteSubjects(snapshot.documentChanges, modelContext: modelContext)
            }
        }
    }

    /// Stops the snapshot listener and cleans up state.
    func stop() {
        if listenerRegistration != nil {
            print("[SubjectRealtimeSyncService] 🛑 Stopping real-time listener")
            listenerRegistration?.remove()
            listenerRegistration = nil
        }
        activeUID = nil
    }

    // =========================================================================
    // MARK: - Snapshot Processing & Merge
    // =========================================================================

    /// Applies document changes from Firestore snapshot to the local SwiftData store.
    func applyRemoteSubjects(_ documentChanges: [DocumentChange], modelContext: ModelContext) {
        guard !documentChanges.isEmpty else { return }

        let localDescriptor = FetchDescriptor<Subject>()
        guard let localSubjects = try? modelContext.fetch(localDescriptor) else { return }

        // Maps for fast case-insensitive name matching and ID matching
        var localByName: [String: Subject] = [:]
        var localByID: [String: Subject] = [:]

        for subject in localSubjects {
            let key = subject.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            localByName[key] = subject
            localByID[subject.id.uuidString] = subject
        }

        var didMutate = false

        for change in documentChanges {
            let data = change.document.data()
            guard let parsed = parseSubject(from: data) else { continue }
            let nameKey = parsed.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            switch change.type {
            case .added, .modified:
                // Check if subject exists locally by ID or case-insensitive name
                if let existing = localByID[parsed.id.uuidString] ?? localByName[nameKey] {
                    // Update if remote date is newer or name formatting changed
                    let remoteDate = parsed.lastUsedDate
                    let remoteUpdated = parsed.updatedAt ?? remoteDate

                    if remoteDate > existing.lastUsedDate || remoteUpdated > (existing.updatedAt ?? existing.lastUsedDate) {
                        existing.lastUsedDate = remoteDate
                        existing.updatedAt = remoteUpdated
                        existing.archivedAt = parsed.archivedAt
                        didMutate = true
                    }
                    if existing.name != parsed.name {
                        existing.name = parsed.name
                        didMutate = true
                    }
                } else {
                    // New remote subject — insert into SwiftData (no duplicate created)
                    let newSubject = Subject(
                        id: parsed.id,
                        name: parsed.name,
                        lastUsedDate: parsed.lastUsedDate,
                        updatedAt: parsed.updatedAt ?? parsed.lastUsedDate,
                        archivedAt: parsed.archivedAt
                    )
                    modelContext.insert(newSubject)
                    localByName[nameKey] = newSubject
                    localByID[parsed.id.uuidString] = newSubject
                    didMutate = true
                    print("[SubjectRealtimeSyncService] ➕ Remote subject added locally: \(parsed.name)")
                }

            case .removed:
                if let existing = localByID[parsed.id.uuidString] ?? localByName[nameKey] {
                    modelContext.delete(existing)
                    localByName.removeValue(forKey: nameKey)
                    localByID.removeValue(forKey: parsed.id.uuidString)
                    didMutate = true
                    print("[SubjectRealtimeSyncService] 🗑️ Remote subject deleted locally: \(parsed.name)")
                }
            }
        }

        if didMutate {
            do {
                try modelContext.save()
                print("[SubjectRealtimeSyncService] ✅ SwiftData context saved with real-time changes")
            } catch {
                print("[SubjectRealtimeSyncService] ❌ Save error: \(error.localizedDescription)")
            }
        }
    }

    // =========================================================================
    // MARK: - Parsing Helper
    // =========================================================================

    private func parseSubject(from data: [String: Any]) -> (id: UUID, name: String, lastUsedDate: Date, updatedAt: Date?, archivedAt: Date?)? {
        guard
            let idStr = data["id"] as? String,
            let id = UUID(uuidString: idStr),
            let name = data["name"] as? String,
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let lastUsedTs = data["lastUsedDate"] as? Timestamp
        else { return nil }

        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        let archivedAt = (data["archivedAt"] as? Timestamp)?.dateValue()
        return (
            id: id,
            name: name.normalizedWorkItemName(),
            lastUsedDate: lastUsedTs.dateValue(),
            updatedAt: updatedAt,
            archivedAt: archivedAt
        )
    }
}
