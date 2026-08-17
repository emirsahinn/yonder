//
//  ActiveTimerState.swift
//  Yonder
//

import Foundation

/// Wall-clock snapshot of an in-flight solo countdown/stopwatch session, persisted
/// across app termination so `TimerViewModel` can restore it on next launch.
/// Mirrors `TimerViewModel`'s private timer-anchor fields — no new time math lives here.
struct ActiveTimerState: Codable {
    var isStopwatchMode: Bool
    var isRunning: Bool
    var totalDuration: Int
    var sessionStartedAt: Date?
    var intentionNote: String

    /// Non-nil only while running (countdown mode).
    var countdownEndDate: Date?
    /// Non-nil only while running (stopwatch mode).
    var stopwatchRunStartedAt: Date?

    /// Frozen/baseline display values at the moment this snapshot was written.
    var remainingSecondsSnapshot: Int
    var elapsedSecondsSnapshot: Int

    var savedAt: Date
}

/// Persists `ActiveTimerState` to `UserDefaults` as JSON. No business logic — pure storage.
enum ActiveTimerStateStore {
    private static let key = "yonder_active_timer_state_v1"

    static func save(_ state: ActiveTimerState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> ActiveTimerState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ActiveTimerState.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
