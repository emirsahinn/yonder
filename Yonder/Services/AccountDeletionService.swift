//
//  AccountDeletionService.swift
//  Yonder
//
//  Handles full deletion of cloud data, Firebase Auth user account,
//  and local state wiping per Apple Guideline 5.1.1(v).
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData
import UserNotifications

enum AccountDeletionError: LocalizedError {
    case notAuthenticated
    case requiresRecentLogin
    case custom(String)

    var errorDescription: String? {
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "en"
        switch self {
        case .notAuthenticated:
            return lang == "tr"
                ? "Oturum açmış bir kullanıcı bulunamadı."
                : "No authenticated user found."
        case .requiresRecentLogin:
            return lang == "tr"
                ? "Güvenlik için yeniden giriş yapman gerekiyor. Lütfen çıkış yapıp tekrar giriş yaptıktan sonra yeniden dene."
                : "For security, you need to sign in again. Please sign out, sign back in, and try again."
        case .custom(let message):
            return message
        }
    }
}

/// Singleton service responsible for safely executing two-stage account and data deletion.
@MainActor
final class AccountDeletionService {

    static let shared = AccountDeletionService()
    private let db = Firestore.firestore()

    private init() {}

    /// Permanently deletes the current user's cloud data, auth account, and wipes local device data.
    func deleteCurrentAccountAndData(modelContext: ModelContext, workGoalStore: WorkGoalStore) async throws {
        guard let currentUser = Auth.auth().currentUser, !currentUser.isAnonymous else {
            throw AccountDeletionError.notAuthenticated
        }

        let uid = currentUser.uid
        print("[AccountDeletionService] ⚠️ Beginning account and data deletion for uid: \(uid)")

        // 1. Delete Cloud Data (Firestore)
        try await deleteCloudUserData(uid: uid)

        // 2. Delete Firebase Auth User
        do {
            try await currentUser.delete()
            print("[AccountDeletionService] ✅ Firebase Auth user deleted: \(uid)")
        } catch let nsError as NSError {
            print("[AccountDeletionService] ❌ Auth delete failed: \(nsError.localizedDescription) (code: \(nsError.code))")
            if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue ||
               nsError.domain == AuthErrorDomain && nsError.code == 17014 ||
               nsError.localizedDescription.localizedCaseInsensitiveContains("recent login") {
                throw AccountDeletionError.requiresRecentLogin
            }
            throw AccountDeletionError.custom(nsError.localizedDescription)
        }

        // 3. Wipe Local Data (executed ONLY after successful Auth deletion)
        await wipeLocalData(modelContext: modelContext, workGoalStore: workGoalStore)

        print("[AccountDeletionService] 🎉 Account deletion flow complete for uid: \(uid)")
    }

    // MARK: - Cloud Data Deletion

    private func deleteCloudUserData(uid: String) async throws {
        let userDocRef = db.collection("users").document(uid)

        // Subcollections to delete: sessions, subjects, goals
        let subcollections = ["sessions", "subjects", "goals"]
        for sub in subcollections {
            try await deleteCollectionInBatches(userDocRef.collection(sub))
        }

        // Delete parent user document
        try await userDocRef.delete()
        print("[AccountDeletionService] ✅ Deleted users/\(uid) and subcollections.")

        // Delete participant docs in rooms where user is participant
        try await deleteUserParticipantRecords(uid: uid)

        // End rooms hosted by the user that are currently active
        try await endUserHostedRooms(uid: uid)
    }

    private func deleteCollectionInBatches(_ collectionRef: CollectionReference) async throws {
        while true {
            let snapshot = try await collectionRef.limit(to: 400).getDocuments()
            if snapshot.documents.isEmpty { break }

            let batch = db.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
            if snapshot.documents.count < 400 { break }
        }
    }

    private func deleteUserParticipantRecords(uid: String) async throws {
        do {
            let snapshot = try await db.collectionGroup("participants")
                .whereField(FieldPath.documentID(), isEqualTo: uid)
                .getDocuments()

            if !snapshot.documents.isEmpty {
                let batch = db.batch()
                for doc in snapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
                print("[AccountDeletionService] ✅ Deleted \(snapshot.documents.count) room participant records for uid: \(uid)")
            }
        } catch {
            print("[AccountDeletionService] ⚠️ Error querying/deleting participant records: \(error.localizedDescription)")
            // Non-critical, allow account deletion flow to continue
        }
    }

    private func endUserHostedRooms(uid: String) async throws {
        do {
            let snapshot = try await db.collection("rooms")
                .whereField("hostId", isEqualTo: uid)
                .whereField("status", in: ["waiting", "running"])
                .getDocuments()

            if !snapshot.documents.isEmpty {
                let batch = db.batch()
                for doc in snapshot.documents {
                    batch.updateData([
                        "status": "ended",
                        "endedAt": Timestamp(date: Date())
                    ], forDocument: doc.reference)
                }
                try await batch.commit()
                print("[AccountDeletionService] ✅ Ended \(snapshot.documents.count) active hosted rooms for uid: \(uid)")
            }
        } catch {
            print("[AccountDeletionService] ⚠️ Error ending user hosted rooms: \(error.localizedDescription)")
            // Non-critical
        }
    }

    // MARK: - Local Data Wipe

    private func wipeLocalData(modelContext: ModelContext, workGoalStore: WorkGoalStore) async {
        // Stop real-time listener
        SubjectRealtimeSyncService.shared.stop()

        // Wipe SwiftData models
        do {
            let sessionDescriptor = FetchDescriptor<FocusSession>()
            if let sessions = try? modelContext.fetch(sessionDescriptor) {
                for s in sessions { modelContext.delete(s) }
            }

            let subjectDescriptor = FetchDescriptor<Subject>()
            if let subjects = try? modelContext.fetch(subjectDescriptor) {
                for s in subjects { modelContext.delete(s) }
            }

            let reminderDescriptor = FetchDescriptor<FocusReminder>()
            if let reminders = try? modelContext.fetch(reminderDescriptor) {
                for r in reminders { modelContext.delete(r) }
            }

            try modelContext.save()
            print("[AccountDeletionService] ✅ SwiftData local models wiped.")
        } catch {
            print("[AccountDeletionService] ❌ Error wiping SwiftData: \(error.localizedDescription)")
        }

        // Clear WorkGoalStore
        workGoalStore.goals.removeAll()
        print("[AccountDeletionService] ✅ Work goals wiped.")

        // Cancel all local notification requests & delivered notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("[AccountDeletionService] ✅ Local notifications cancelled.")

        // Clear AuthService local state & sign out to anonymous state
        AuthService.shared.signOut()
        print("[AccountDeletionService] ✅ AuthService signed out to anonymous mode.")
    }
}
