//
//  TimerViewModel.swift
//  Yonder
//

import Foundation
import Combine

/// Manages the countdown and count-up (stopwatch) timer state and logic.
@Observable
final class TimerViewModel {

    /// Live Activities have no meaningful "end" in stopwatch mode, but ActivityKit
    /// still needs a staleDate/endDate. iOS itself force-ends any Live Activity after
    /// ~8h regardless of app code, so there's no benefit picking anything shorter here
    /// — a smaller value (e.g. 1h) would just make the Lock Screen/Dynamic Island
    /// freeze at 00:00 while the in-app stopwatch keeps counting up correctly underneath.
    private static let stopwatchLiveActivityWindowSeconds = 8 * 3600

    // MARK: - Published State

    /// Total seconds remaining on the timer (countdown mode).
    private(set) var remainingSeconds: Int = 0

    /// Seconds elapsed on the timer (stopwatch mode).
    private(set) var elapsedSeconds: Int = 0

    /// The total duration that was originally selected (in seconds).
    private(set) var totalDuration: Int = 0

    /// Whether the timer is in open-ended stopwatch (count-up) mode.
    private(set) var isStopwatchMode: Bool = false

    /// Whether the timer is actively running.
    private(set) var isRunning: Bool = false

    /// Whether the timer has reached 00:00 (countdown mode only).
    private(set) var isCompleted: Bool = false

    /// Optional intention / subject note set by the user before starting the timer.
    var intentionNote: String = ""

    /// The first time this focus session started. Pause/resume keeps the original start.
    private(set) var sessionStartedAt: Date?

    /// Countdown target for the current running segment.
    private var countdownEndDate: Date?

    /// Stopwatch segment start for the current running segment.
    private var stopwatchRunStartedAt: Date?

    /// Stopwatch elapsed seconds before the current running segment started.
    private var stopwatchElapsedBeforeRun: Int = 0

    // MARK: - Derived Properties

    var displaySeconds: Int {
        isStopwatchMode ? elapsedSeconds : remainingSeconds
    }

    var hours: Int { displaySeconds / 3600 }
    var minutes: Int { (displaySeconds % 3600) / 60 }
    var seconds: Int { displaySeconds % 60 }

    /// Individual digits for the flip-clock display.
    var hourTens: Int { hours / 10 }
    var hourOnes: Int { hours % 10 }
    var minuteTens: Int { minutes / 10 }
    var minuteOnes: Int { minutes % 10 }
    var secondTens: Int { seconds / 10 }
    var secondOnes: Int { seconds % 10 }

    /// Formatted time string (HH:MM:SS or MM:SS).
    var formattedTime: String {
        if showHours {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Whether to show hours digits.
    var showHours: Bool {
        isStopwatchMode ? (elapsedSeconds >= 3600) : (totalDuration >= 3600)
    }

    // MARK: - Private

    private var timerCancellable: AnyCancellable?

    // MARK: - Actions

    /// Set the timer duration in seconds (Countdown Mode).
    func setDuration(_ seconds: Int) {
        isStopwatchMode = false
        remainingSeconds = seconds
        totalDuration = seconds
        elapsedSeconds = 0
        isCompleted = false
        isRunning = false
        countdownEndDate = nil
        stopwatchRunStartedAt = nil
        stopwatchElapsedBeforeRun = 0
        timerCancellable?.cancel()
        ActiveTimerStateStore.clear()
    }

    /// Set the timer duration in minutes.
    func setDurationMinutes(_ minutes: Int) {
        setDuration(minutes * 60)
    }

    /// Configure for open-ended Stopwatch Mode (Count-up).
    func setStopwatchMode() {
        isStopwatchMode = true
        elapsedSeconds = 0
        remainingSeconds = 0
        totalDuration = 0
        isCompleted = false
        isRunning = false
        countdownEndDate = nil
        stopwatchRunStartedAt = nil
        stopwatchElapsedBeforeRun = 0
        timerCancellable?.cancel()
        ActiveTimerStateStore.clear()
    }

    /// Start or resume the timer.
    func start() {
        guard !isRunning else { return }

        if isStopwatchMode {
            guard !isCompleted else { return }
            if sessionStartedAt == nil {
                sessionStartedAt = Date()
            }
            stopwatchElapsedBeforeRun = elapsedSeconds
            stopwatchRunStartedAt = Date()
            isRunning = true

            LiveActivityService.shared.startActivity(
                totalDurationSeconds: Self.stopwatchLiveActivityWindowSeconds,
                intentionNote: intentionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : intentionNote,
                isStopwatchMode: true
            )

            timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.tick()
                }
        } else {
            guard remainingSeconds > 0, !isCompleted else { return }
            if sessionStartedAt == nil {
                sessionStartedAt = Date()
            }
            countdownEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            isRunning = true

            LiveActivityService.shared.startActivity(
                totalDurationSeconds: remainingSeconds,
                intentionNote: intentionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : intentionNote
            )

            timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.tick()
                }
        }

        persistActiveState()
    }

    /// Pause the timer.
    func pause() {
        syncWithCurrentTime()
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        countdownEndDate = nil
        stopwatchRunStartedAt = nil

        let endDate = Date().addingTimeInterval(TimeInterval(isStopwatchMode ? Self.stopwatchLiveActivityWindowSeconds : remainingSeconds))
        LiveActivityService.shared.updateActivity(
            endDate: endDate,
            isPaused: true,
            totalDurationSeconds: isStopwatchMode ? elapsedSeconds : totalDuration,
            intentionNote: intentionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : intentionNote,
            isStopwatchMode: isStopwatchMode
        )

        persistActiveState()
    }

    /// Toggle between start and pause.
    func toggleRunning() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    /// Reset to 00:00 (stopwatch) or original duration (countdown).
    func reset() {
        pause()
        if isStopwatchMode {
            elapsedSeconds = 0
            stopwatchElapsedBeforeRun = 0
        } else {
            remainingSeconds = totalDuration
        }
        isCompleted = false
        sessionStartedAt = nil
        countdownEndDate = nil
        stopwatchRunStartedAt = nil
        LiveActivityService.shared.endActivity()
        ActiveTimerStateStore.clear()
    }

    /// Completely stop and clear the timer.
    func clear() {
        pause()
        remainingSeconds = 0
        elapsedSeconds = 0
        totalDuration = 0
        isStopwatchMode = false
        isCompleted = false
        sessionStartedAt = nil
        countdownEndDate = nil
        stopwatchRunStartedAt = nil
        stopwatchElapsedBeforeRun = 0
        LiveActivityService.shared.endActivity()
        ActiveTimerStateStore.clear()
    }

    /// Recalculate timer values from wall-clock time. This keeps timers correct after backgrounding.
    func syncWithCurrentTime(now: Date = Date()) {
        guard isRunning else { return }

        if isStopwatchMode {
            guard let stopwatchRunStartedAt else { return }
            let elapsed = max(0, Int(now.timeIntervalSince(stopwatchRunStartedAt)))
            elapsedSeconds = stopwatchElapsedBeforeRun + elapsed
        } else {
            guard let countdownEndDate else { return }
            remainingSeconds = max(0, Int(ceil(countdownEndDate.timeIntervalSince(now))))

            if remainingSeconds == 0 {
                isCompleted = true
                isRunning = false
                timerCancellable?.cancel()
                timerCancellable = nil
                self.countdownEndDate = nil
                LiveActivityService.shared.endActivity()
            }
        }
    }

    // MARK: - Restore

    /// Reconstructs an in-flight solo session from the last persisted `ActiveTimerState`,
    /// if any. Reuses `syncWithCurrentTime()` to fast-forward exactly as it already does
    /// after backgrounding — relaunch is treated as just a longer background gap.
    /// Returns `nil` if there is nothing to restore.
    static func restoreIfAvailable() -> TimerViewModel? {
        guard let state = ActiveTimerStateStore.load() else { return nil }

        let vm = TimerViewModel()
        vm.isStopwatchMode = state.isStopwatchMode
        vm.totalDuration = state.totalDuration
        vm.sessionStartedAt = state.sessionStartedAt
        vm.intentionNote = state.intentionNote
        vm.remainingSeconds = state.remainingSecondsSnapshot
        vm.elapsedSeconds = state.elapsedSecondsSnapshot
        vm.isRunning = state.isRunning
        vm.countdownEndDate = state.countdownEndDate
        vm.stopwatchRunStartedAt = state.stopwatchRunStartedAt
        vm.stopwatchElapsedBeforeRun = state.elapsedSecondsSnapshot

        // A Live Activity started before termination outlives the app process —
        // reattach before any sync-driven pause/end call so it isn't orphaned.
        LiveActivityService.shared.reattachExistingActivityIfNeeded()

        if vm.isRunning {
            vm.timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak vm] _ in
                    vm?.tick()
                }
            // Fast-forwards remaining/elapsed seconds and flips isCompleted if the
            // countdown finished while the app was terminated.
            vm.syncWithCurrentTime()
        }

        // Intentionally not re-persisted here: the on-disk "isRunning + past
        // countdownEndDate" entry is self-correcting on any future restore (it
        // re-derives isCompleted via the same syncWithCurrentTime() call above),
        // whereas overwriting it would lose the completed/isCompleted signal since
        // that flag isn't part of the persisted snapshot. The store is only ever
        // updated again by the normal start/pause/reset/clear transitions.
        return vm
    }

    // MARK: - Private

    private func tick() {
        syncWithCurrentTime()
    }

    /// Writes the current state to disk. Called only on start/pause/reset/clear/
    /// setDuration/setStopwatchMode transitions — never on every tick.
    private func persistActiveState() {
        guard sessionStartedAt != nil else {
            ActiveTimerStateStore.clear()
            return
        }

        let state = ActiveTimerState(
            isStopwatchMode: isStopwatchMode,
            isRunning: isRunning,
            totalDuration: totalDuration,
            sessionStartedAt: sessionStartedAt,
            intentionNote: intentionNote,
            countdownEndDate: countdownEndDate,
            stopwatchRunStartedAt: stopwatchRunStartedAt,
            remainingSecondsSnapshot: remainingSeconds,
            elapsedSecondsSnapshot: elapsedSeconds,
            savedAt: Date()
        )
        ActiveTimerStateStore.save(state)
    }
}
