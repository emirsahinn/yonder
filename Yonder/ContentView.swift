//
//  ContentView.swift
//  Yonder
//

import SwiftUI
import SwiftData

/// Root content view — maintains selectedTab state outside TabView so language changes
/// re-render TabView without resetting the active tab selection.
///
/// Also acts as the sync trigger gate: once `triggerSyncOnAppear` flips to `true`
/// (set by YonderApp after the splash finishes), a background full-sync is kicked off
/// with the live `modelContext` from the SwiftData environment.
struct ContentView: View {

    @State private var selectedTab: Int = 0
    @Binding var triggerSyncOnAppear: Bool

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workGoalStore: WorkGoalStore
    @Environment(AuthService.self) private var authService

    init(triggerSyncOnAppear: Binding<Bool> = .constant(false)) {
        self._triggerSyncOnAppear = triggerSyncOnAppear
    }

    var body: some View {
        RootTabView(selectedTab: $selectedTab)
            .onChange(of: triggerSyncOnAppear) { _, shouldSync in
                guard shouldSync else { return }
                triggerSyncOnAppear = false
                Task {
                    await SyncCoordinator.shared.triggerFullSync(
                        modelContext: modelContext,
                        goalStore: workGoalStore
                    )
                }
            }
            .onAppear {
                manageRealtimeSync()
            }
            .onChange(of: authService.isCloudAccountLinked) { wasLinked, isLinked in
                manageRealtimeSync()
                // A cloud-linked account just disconnected (sign-out). The data that was
                // synced locally for that account already lives safely in that account's
                // own Firestore documents, so it is safe — and necessary — to clear the
                // local cache here. Without this, the next account signed into on this
                // device would see the previous account's sessions/subjects/goals, and
                // could even have them silently uploaded into its own Firestore data via
                // the "add this device's data" merge flow. See SettingsView's merge sheet.
                if wasLinked && !isLinked {
                    clearLocalCacheAfterSignOut()
                }
            }
            .onChange(of: authService.currentUserId) { _, _ in
                manageRealtimeSync()
            }
    }

    private func manageRealtimeSync() {
        if authService.isCloudAccountLinked, let uid = authService.currentUserId {
            SubjectRealtimeSyncService.shared.start(uid: uid, modelContext: modelContext)
        } else {
            SubjectRealtimeSyncService.shared.stop()
        }
    }

    /// Clears locally cached, cloud-synced entities after a sign-out so the next
    /// account used on this device never inherits or re-uploads the previous
    /// account's data. Local-only reminders are intentionally left untouched —
    /// they are never synced to Firestore, so clearing them here would be a
    /// real, unrecoverable data loss rather than just clearing a re-downloadable cache.
    private func clearLocalCacheAfterSignOut() {
        if let sessions = try? modelContext.fetch(FetchDescriptor<FocusSession>()) {
            for session in sessions {
                modelContext.delete(session)
            }
        }
        if let subjects = try? modelContext.fetch(FetchDescriptor<Subject>()) {
            for subject in subjects {
                modelContext.delete(subject)
            }
        }
        try? modelContext.save()
        workGoalStore.replaceWithRemoteGoals([])
    }
}

#Preview {
    ContentView()
}
