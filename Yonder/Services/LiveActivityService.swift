//
//  LiveActivityService.swift
//  Yonder
//

import Foundation
import ActivityKit

/// Singleton managing ActivityKit Live Activities lifecycle (requesting, updating, ending).
final class LiveActivityService {

    static let shared = LiveActivityService()

    private var currentActivity: Any? = nil

    private init() {}

    /// Returns true if Live Activities are supported and authorized on this device.
    var isLiveActivityEnabled: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    /// Starts a Live Activity for an active focus session.
    func startActivity(totalDurationSeconds: Int, intentionNote: String?, participantCount: Int? = nil, roomCode: String? = nil) {
        guard isLiveActivityEnabled else { return }

        // End any existing activity first
        endActivity()

        if #available(iOS 16.1, *) {
            let startDate = Date()
            let endDate = startDate.addingTimeInterval(TimeInterval(totalDurationSeconds))

            let attributes = YonderActivityAttributes(sessionStartDate: startDate)
            let initialState = YonderActivityAttributes.ContentState(
                endDate: endDate,
                isPaused: false,
                totalDurationSeconds: totalDurationSeconds,
                intentionNote: intentionNote,
                participantCount: participantCount,
                roomCode: roomCode
            )

            do {
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: initialState, staleDate: endDate)
                    let activity = try Activity<YonderActivityAttributes>.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                    self.currentActivity = activity
                } else {
                    let activity = try Activity<YonderActivityAttributes>.request(
                        attributes: attributes,
                        contentState: initialState,
                        pushType: nil
                    )
                    self.currentActivity = activity
                }
                print("[LiveActivityService] Live Activity requested successfully")
            } catch {
                print("[LiveActivityService] Error starting Live Activity: \(error.localizedDescription)")
            }
        }
    }

    /// Updates the running Live Activity state (e.g. on pause/resume or remaining time sync).
    func updateActivity(endDate: Date, isPaused: Bool, totalDurationSeconds: Int, intentionNote: String?, participantCount: Int? = nil, roomCode: String? = nil) {
        if #available(iOS 16.1, *) {
            guard let activity = currentActivity as? Activity<YonderActivityAttributes> else { return }

            let updatedState = YonderActivityAttributes.ContentState(
                endDate: endDate,
                isPaused: isPaused,
                totalDurationSeconds: totalDurationSeconds,
                intentionNote: intentionNote,
                participantCount: participantCount,
                roomCode: roomCode
            )

            Task {
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: updatedState, staleDate: endDate)
                    await activity.update(content)
                } else {
                    await activity.update(using: updatedState)
                }
            }
        }
    }

    /// Reattaches to a Live Activity that was started before the app process was
    /// terminated. ActivityKit activities outlive the host app (they keep rendering
    /// on the Lock Screen/Dynamic Island after termination), but `currentActivity` is
    /// only ever populated in-memory — without this, a restored session's first
    /// `pause()`/`updateActivity()`/`endActivity()` call would silently no-op against
    /// a `nil` reference, leaving an orphaned entry on the Lock Screen.
    /// Call this before issuing any activity call against a restored `TimerViewModel`.
    func reattachExistingActivityIfNeeded() {
        guard currentActivity == nil else { return }
        if #available(iOS 16.1, *) {
            if let existing = Activity<YonderActivityAttributes>.activities.first {
                currentActivity = existing
            }
        }
    }

    /// Ends the current Live Activity.
    func endActivity() {
        if #available(iOS 16.1, *) {
            guard let activity = currentActivity as? Activity<YonderActivityAttributes> else { return }

            let currentState = activity.content.state

            Task {
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: currentState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: currentState, dismissalPolicy: .immediate)
                }
                self.currentActivity = nil
            }
        }
    }
}
