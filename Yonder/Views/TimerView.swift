//
//  TimerView.swift
//  Yonder
//

import SwiftUI
import SwiftData
import UIKit

/// Full-screen countdown display with flip-clock animation, SwiftData session recording, and mini summary.
struct TimerView: View {

    @Bindable var timerVM: TimerViewModel
    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass)   private var vSizeClass
    @Environment(\.modelContext)        private var modelContext
    @Environment(\.scenePhase)          private var scenePhase

    @Query private var allSessions: [FocusSession]
    @Query(sort: \Subject.lastUsedDate, order: .reverse) private var savedSubjects: [Subject]

    var onFinishAll: (() -> Void)? = nil

    @State private var controlsVisible = false
    @State private var hideControlsTask: Task<Void, Never>?

    private var currentLocale: Locale {
        Locale(identifier: appLanguage)
    }

    private struct PendingSession: Identifiable {
        let id = UUID()
        let durationSeconds: Int
        let completed: Bool
        let endedAt: Date
    }
    @State private var pendingSession: PendingSession?
    @State private var showBreakView: Bool = false
    @State private var showNextSessionProposal: Bool = false
    @State private var showFinishSessionConfirmation: Bool = false
    @State private var showResetSessionConfirmation: Bool = false
    @State private var showCompletionTransitionMask: Bool = false
    @State private var completionPresentationTask: Task<Void, Never>?

    private var isLandscapePhone: Bool {
        vSizeClass == .compact
    }

    private var isIPad: Bool {
        hSizeClass == .regular
    }

    private var todayTotalSeconds: Int {
        let calendar = Calendar.current
        return allSessions
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    @AppStorage("timer_clock_style") private var timerClockStyleRaw: String = "flip"
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false

    private var selectedStyle: TimerClockStyle {
        TimerClockStyle.resolved(rawValue: timerClockStyleRaw, isPremiumUser: isPremiumUser)
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let shortEdge = min(geometry.size.width, geometry.size.height)
            let clockHeight = shortEdge * 0.80

            ZStack {
                Color.black
                    .ignoresSafeArea()

                // Subtle intention/subject label at top
                VStack {
                    let note = timerVM.intentionNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !note.isEmpty {
                        Text(note)
                            .font(.system(size: isIPad ? 14 : 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.38))
                            .tracking(2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 24)
                            .padding(.top, isIPad ? 36 : 20)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(controlsVisible ? 1.0 : 0.0)
                .allowsHitTesting(false)

                // Clock display based on selected style
                TimerClockDisplayView(
                    style: selectedStyle,
                    hours: timerVM.hours,
                    minutes: timerVM.minutes,
                    seconds: timerVM.seconds,
                    showHours: timerVM.showHours,
                    showSeconds: true,
                    isRunning: timerVM.isRunning,
                    customFormattedTime: timerVM.formattedTime,
                    remainingSeconds: timerVM.remainingSeconds,
                    totalSeconds: timerVM.totalDuration
                )
                .frame(width: geometry.size.width * 0.96, height: clockHeight)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Overlaid Controls (Control Bar)
                VStack(spacing: 0) {
                    Spacer()

                    if !isLandscape {
                        controlBarHorizontal
                            .padding(.bottom, isIPad ? 44 : 24)
                            .padding(.horizontal, isIPad ? 60 : 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .trailing) {
                    if isLandscape {
                        controlBarVertical
                            .frame(width: isIPad ? 92 : 76)
                            .padding(.trailing, isIPad ? 24 : 14)
                    }
                }
                .opacity(controlsVisible ? 1.0 : 0.0)
                .disabled(!controlsVisible)

                if showCompletionTransitionMask {
                    YonderTransitionOverlay(message: appLanguage == "tr" ? "Kaydet ekranı hazırlanıyor" : "Preparing save screen")
                        .transition(.opacity)
                        .zIndex(20)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { toggleControls() }
            .background(
                EscapeKeyInterceptor {
                    handleFinishSession()
                }
                .frame(width: 0, height: 0)
            )
        }
        .onAppear {
            if timerVM.isCompleted {
                // A restored countdown can already be completed by the time this view
                // mounts (it finished while the app was terminated) — the .onChange
                // below only fires on a false→true transition, which already happened
                // before this view existed, so completion has to be checked here too.
                HapticService.success()
                presentCompletionAfterPortraitSettles(
                    PendingSession(durationSeconds: timerVM.totalDuration, completed: true, endedAt: Date())
                )
            } else {
                controlsVisible = true
                scheduleHideControls()
            }
        }
        .onDisappear {
            completionPresentationTask?.cancel()
            showCompletionTransitionMask = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timerVM.syncWithCurrentTime()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: controlsVisible)
        .rotatesForPhoneUpsideDown()
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .interactiveDismissDisabled(true)
        .allowsPhoneLandscape("solo-timer")
        .onChange(of: timerVM.isCompleted) { _, completed in
            if completed {
                HapticService.success()
                presentCompletionAfterPortraitSettles(
                    PendingSession(durationSeconds: timerVM.totalDuration, completed: true, endedAt: Date())
                )
            }
        }
        .fullScreenCover(item: $pendingSession) { pending in
            SessionCompleteView(
                durationSeconds: pending.durationSeconds,
                completed: pending.completed,
                intentionNote: timerVM.intentionNote,
                onSave: { savedWorkArea in
                    let trimmedWorkArea = (savedWorkArea ?? "").normalizedWorkItemName()
                    guard !trimmedWorkArea.isEmpty else { return }

                    if let existing = savedSubjects.first(where: { $0.name.normalizedWorkItemName().localizedCaseInsensitiveCompare(trimmedWorkArea) == .orderedSame }) {
                        existing.name = trimmedWorkArea
                        existing.lastUsedDate = Date()
                        existing.updatedAt = Date()
                        // Push updated subject to Firestore
                        SyncService.shared.syncSubject(existing)
                    }

                    let session = FocusSession(
                        durationSeconds: pending.durationSeconds,
                        completed: pending.completed,
                        intentionNote: trimmedWorkArea,
                        subject: trimmedWorkArea,
                        startedAt: timerVM.sessionStartedAt,
                        endedAt: pending.endedAt,
                        plannedDurationSeconds: timerVM.isStopwatchMode ? nil : timerVM.totalDuration,
                        modeRawValue: FocusSessionMode.solo.rawValue,
                        roomId: nil
                    )
                    modelContext.insert(session)
                    try? modelContext.save()
                    // Sync to Firestore if Google account is linked (no-op for anonymous users)
                    SyncService.shared.syncSession(session)

                    let todayTotal = todayTotalSeconds + pending.durationSeconds
                    WidgetDataService.shared.updateWidgetData(todayTotalSeconds: todayTotal, mostUsedDurationSeconds: timerVM.totalDuration)
                },
                onFinish: {
                    timerVM.clear()
                    onFinishAll?()
                },
                onDiscard: {
                    timerVM.clear()
                    onFinishAll?()
                }
            )
            .interactiveDismissDisabled(true)
            .background(
                EscapeKeyInterceptor {
                    // Consume Escape on the save screen so a completed session
                    // cannot disappear without Save or Discard.
                }
                .frame(width: 0, height: 0)
            )
        }
        .confirmationDialog(
            appLanguage == "tr" ? "Oturumu bitirmek istiyor musun?" : "End this session?",
            isPresented: $showFinishSessionConfirmation,
            titleVisibility: .visible
        ) {
            Button(appLanguage == "tr" ? "Bitir" : "End", role: .destructive) {
                confirmFinishSession()
            }
            Button(appLanguage == "tr" ? "Devam et" : "Continue", role: .cancel) {
                timerVM.start()
            }
        }
        .confirmationDialog(
            String(localized: "reset_session_title", defaultValue: "Süreyi başa sarmak istediğine emin misin?", locale: currentLocale),
            isPresented: $showResetSessionConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "reset_session_action", defaultValue: "Sıfırla", locale: currentLocale), role: .destructive) {
                confirmResetSession()
            }
            Button(String(localized: "cancel_button", defaultValue: "Vazgeç", locale: currentLocale), role: .cancel) {
                timerVM.start()
            }
        }
    }



    // MARK: - Control Bars

    private var controlBarHorizontal: some View {
        HStack(spacing: isIPad ? 52 : 36) {
            controlButton(icon: "xmark", label: "finish_button") {
                handleFinishSession()
            }
            controlButton(
                icon: timerVM.isRunning ? "pause.fill" : "play.fill",
                label: timerVM.isRunning ? "pause_button" : "start_button",
                isPrimary: true
            ) {
                if timerVM.isRunning {
                    HapticService.light()
                } else {
                    HapticService.medium()
                }
                timerVM.toggleRunning()
                scheduleHideControls()
            }
            controlButton(icon: "arrow.counterclockwise", label: "reset_button") {
                handleResetSession()
            }
        }
    }

    private var controlBarVertical: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            controlButton(icon: "xmark", label: "finish_button", compact: true) {
                handleFinishSession()
            }
            controlButton(
                icon: timerVM.isRunning ? "pause.fill" : "play.fill",
                label: timerVM.isRunning ? "pause_button" : "start_button",
                isPrimary: true,
                compact: true
            ) {
                if timerVM.isRunning {
                    HapticService.light()
                } else {
                    HapticService.medium()
                }
                timerVM.toggleRunning()
                scheduleHideControls()
            }
            controlButton(icon: "arrow.counterclockwise", label: "reset_button", compact: true) {
                handleResetSession()
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Finish / Reset Handlers

    private func handleFinishSession() {
        timerVM.pause()
        showFinishSessionConfirmation = true
    }

    private func confirmFinishSession() {
        HapticService.medium()
        let elapsed = timerVM.isStopwatchMode ? timerVM.elapsedSeconds : (timerVM.totalDuration - timerVM.remainingSeconds)
        if elapsed > 0 {
            presentCompletionAfterPortraitSettles(
                PendingSession(
                    durationSeconds: elapsed,
                    completed: timerVM.isStopwatchMode || timerVM.isCompleted,
                    endedAt: Date()
                )
            )
        } else {
            timerVM.clear()
            onFinishAll?()
        }
    }

    private func presentCompletionAfterPortraitSettles(_ session: PendingSession) {
        completionPresentationTask?.cancel()
        hideControlsTask?.cancel()
        OrientationLock.shared.lockPhonePortrait("solo-timer")

        let shouldDelayForRotation = YonderPortraitTransition.shouldMask(verticalSizeClass: vSizeClass)

        withAnimation(.easeInOut(duration: 0.16)) {
            controlsVisible = false
            showCompletionTransitionMask = shouldDelayForRotation
        }

        completionPresentationTask = Task {
            let delay = YonderPortraitTransition.delayNanoseconds(needsMask: shouldDelayForRotation)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                pendingSession = session
                withAnimation(.easeInOut(duration: 0.18)) {
                    showCompletionTransitionMask = false
                }
            }
        }
    }

    private func handleResetSession() {
        timerVM.pause()
        showResetSessionConfirmation = true
    }

    private func confirmResetSession() {
        HapticService.warning()
        timerVM.reset()
        scheduleHideControls()
    }

    // MARK: - Button Component

    private func controlButton(
        icon: String,
        label: LocalizedStringKey,
        isPrimary: Bool = false,
        compact: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let circleSize: CGFloat = compact ? 40 : (isIPad ? 64 : 52)
        let iconSize:   CGFloat = compact ? 15 : (isIPad ? 22 : 18)
        let labelSize:  CGFloat = compact ? 9  : (isIPad ? 12 : 10)

        return Button(action: action) {
            VStack(spacing: compact ? 4 : 6) {
                ZStack {
                    Circle()
                        .fill(isPrimary ? Color.white : Color(white: 0.15))
                        .frame(width: circleSize, height: circleSize)

                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(isPrimary ? .black : Color(white: 0.6))
                }

                Text(label)
                    .font(.system(size: labelSize, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.4))
                    .textCase(.uppercase)
            }
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        var parts: [String] = []

        if appLanguage == "tr" {
            if hrs > 0 { parts.append("\(hrs) saat") }
            if mins > 0 { parts.append("\(mins) dakika") }
            if secs > 0 || parts.isEmpty { parts.append("\(secs) saniye") }
        } else {
            if hrs > 0 { parts.append("\(hrs) \(hrs == 1 ? "hour" : "hours")") }
            if mins > 0 { parts.append("\(mins) \(mins == 1 ? "minute" : "minutes")") }
            if secs > 0 || parts.isEmpty { parts.append("\(secs) \(secs == 1 ? "second" : "seconds")") }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Alternative Clock Styles

    private func digitalClockView(width: CGFloat) -> some View {
        Text(timerVM.formattedTime)
            .font(.system(size: isIPad ? 105 : (isLandscapePhone ? 60 : 72), weight: .semibold, design: .rounded))
            .foregroundStyle(Color(white: 0.96))
            .tracking(2)
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: width)
    }

    private func minimalClockView(width: CGFloat) -> some View {
        Text(timerVM.formattedTime)
            .font(.system(size: isIPad ? 120 : (isLandscapePhone ? 68 : 82), weight: .ultraLight, design: .rounded))
            .foregroundStyle(Color(white: 0.92))
            .tracking(6)
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: width)
    }

    // MARK: - Auto-hide Controls

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            controlsVisible.toggle()
        }
        if controlsVisible { scheduleHideControls() }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()

        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3.0))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    controlsVisible = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("iPhone Portrait") {
    let vm = TimerViewModel()
    vm.setDurationMinutes(25)
    vm.start()
    return TimerView(timerVM: vm)
}
