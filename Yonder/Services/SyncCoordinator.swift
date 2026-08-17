//
//  SyncCoordinator.swift
//  Yonder
//
//  Orchestrates the full bidirectional sync of FocusSession, Subject, and WorkGoal.
//
//  Trigger points:
//    1. App launch (after SplashView finishes — auth is already resolved)
//    2. After a successful Google Sign-In (from SettingsView)
//
//  All work is performed on a background Task; the UI is never blocked.
//  Errors are caught and logged — the app never crashes due to sync failures.
//

import Foundation
import SwiftData

/// Coordinates the full bidirectional sync for all three entity types.
@Observable
final class SyncCoordinator {

    static let shared = SyncCoordinator()

    /// True while a sync is in progress. Can be observed by UI if needed.
    private(set) var isSyncing: Bool = false

    private init() {}

    // -------------------------------------------------------------------------
    // MARK: - Full Sync
    // -------------------------------------------------------------------------

    /// Runs the full bidirectional sync for sessions, subjects, and goals.
    ///
    /// - Parameters:
    ///   - modelContext: The SwiftData `ModelContext` (must be passed in from a View or App).
    ///   - goalStore:    The shared `WorkGoalStore` instance.
    ///
    /// - Note: No-op if the user is anonymous or not signed in.
    @MainActor
    func triggerFullSync(
        modelContext: ModelContext,
        goalStore: WorkGoalStore,
        uploadLocalChanges: Bool = true
    ) async {
        guard !isSyncing else {
            print("[SyncCoordinator] Sync already in progress — skipping.")
            return
        }

        guard
            let user = FirebaseUserProvider.currentNonAnonymousUser()
        else {
            print("[SyncCoordinator] No cloud-linked user — sync skipped.")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let uid = user.uid
        print("[SyncCoordinator] 🔄 Starting full sync for uid: \(uid), uploadLocalChanges: \(uploadLocalChanges)")

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await SyncService.shared.syncDownSessions(
                    uid: uid,
                    modelContext: modelContext,
                    uploadLocalChanges: uploadLocalChanges,
                    pruneLocalOnly: !uploadLocalChanges
                )
            }
            group.addTask {
                await SyncService.shared.syncDownSubjects(
                    uid: uid,
                    modelContext: modelContext,
                    uploadLocalChanges: uploadLocalChanges,
                    pruneLocalOnly: !uploadLocalChanges
                )
            }
            group.addTask {
                await SyncService.shared.syncDownGoals(
                    uid: uid,
                    goalStore: goalStore,
                    uploadLocalChanges: uploadLocalChanges,
                    replaceLocalWithRemote: !uploadLocalChanges
                )
            }
        }

        print("[SyncCoordinator] ✅ Full sync complete.")
    }
}

// MARK: - Firebase User Helper

/// Thin wrapper so SyncCoordinator doesn't directly import FirebaseAuth.
/// This avoids a transitive dependency cycle if the file is ever unit-tested in isolation.
import FirebaseAuth

enum FirebaseUserProvider {
    static func currentNonAnonymousUser() -> User? {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return nil }
        return user
    }
}
