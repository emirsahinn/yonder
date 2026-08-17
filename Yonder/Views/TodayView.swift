//
//  TodayView.swift
//  Yonder
//
//  The "Today's Rhythm" ("Bugünkü Ritmin") entry point view welcoming the user,
//  displaying their current day's focus summary, primary CTA, quick continue action,
//  quiet room sheet option, mini metrics & insight, and report navigation link.
//

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import Combine

/// The "Today's Rhythm" entry point view welcoming the user to their daily focus.
struct TodayView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("daily_focus_goal_seconds") private var dailyFocusGoalSeconds: Int = 0
    @AppStorage("use_24_hour_clock") private var use24HourClock: Bool = true
    @AppStorage("active_room_id") private var activeRoomId: String = ""
    @Query(sort: \FocusSession.date, order: .reverse) private var sessions: [FocusSession]
    @ObservedObject private var goalStore = WorkGoalStore.shared

    @State private var breathePulse: Bool = false
    @State private var showFocusPicker: Bool = false
    @State private var showCreateRoom: Bool = false
    @State private var showJoinRoom: Bool = false
    @State private var showRoomActionsSheet: Bool = false
    @State private var showActiveRoomTimer: Bool = false
    @State private var showClockView: Bool = false
    @State private var showRotationMask: Bool = false
    @State private var reminderDurationSeconds: Int? = nil
    @State private var pickerPrefillDuration: Int? = nil
    @State private var pickerPrefillSubject: String? = nil
    @State private var currentTime: Date = Date()
    @State private var activeTimerRestoreState: ActiveTimerState? = nil
    @State private var restoredTimerVM: TimerViewModel? = nil
    @Environment(AuthService.self) private var authService
    @Environment(\.scenePhase) private var scenePhase

    var onNavigateToReport: (() -> Void)? = nil
    var onNavigateToSettings: (() -> Void)? = nil

    private let miniClockTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    private var isLandscape: Bool { vSizeClass == .compact }

    // Responsive layout — YonderLayout utility kullanılıyor.
    // Cihaz ismine özel hack yok. Tüm kararlar screenWidth üzerinden.

    // MARK: - Today Calculations

    private var todaySessions: [FocusSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.date) }
    }

    private var todayTotalSeconds: Int {
        todaySessions.reduce(0) { $0 + $1.durationSeconds }
    }

    private var dailyGoalTargetSeconds: Int {
        goalStore.totalGoal(for: .daily)?.targetSeconds ?? dailyFocusGoalSeconds
    }

    private var formattedTimeStr: String {
        formatDuration(todayTotalSeconds)
    }

    private var uniqueSubjectsTodayCount: Int {
        let set = Set(todaySessions.compactMap { displaySubject(for: $0)?.lowercased() })
        return set.count
    }

    // MARK: - Yesterday Calculations

    private var yesterdaySessions: [FocusSession] {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return [] }
        return sessions.filter { calendar.isDate($0.date, inSameDayAs: yesterday) }
    }

    private var yesterdayTotalSeconds: Int {
        yesterdaySessions.reduce(0) { $0 + $1.durationSeconds }
    }

    // MARK: - Top Subject Today

    private var topSubjectToday: (name: String, seconds: Int)? {
        var totals: [String: (displayName: String, seconds: Int)] = [:]
        for session in todaySessions {
            guard let subject = displaySubject(for: session) else { continue }
            let key = subject.lowercased()
            let existing = totals[key]
            totals[key] = (
                displayName: existing?.displayName ?? subject,
                seconds: (existing?.seconds ?? 0) + session.durationSeconds
            )
        }
        guard let top = totals.values.max(by: { $0.seconds < $1.seconds }) else { return nil }
        return (top.displayName, top.seconds)
    }

    private var todayTimeBlockInsightName: String? {
        guard todaySessions.count >= 2 else { return nil }
        var hourCounts: [String: Int] = [:]
        let calendar = Calendar.current

        for session in todaySessions {
            let hour = calendar.component(.hour, from: session.date)
            let block: String
            switch hour {
            case 5..<12: block = appLanguage == "tr" ? "Sabah" : "Morning"
            case 12..<17: block = appLanguage == "tr" ? "Öğle" : "Afternoon"
            case 17..<22: block = appLanguage == "tr" ? "Akşam" : "Evening"
            default: block = appLanguage == "tr" ? "Gece" : "Night"
            }
            hourCounts[block, default: 0] += 1
        }

        if let (dominantBlock, count) = hourCounts.max(by: { $0.value < $1.value }), count >= 2 {
            return dominantBlock
        }
        return nil
    }

    // MARK: - Daily Mini Insight Text

    private var dailyInsightText: String {
        if todayTotalSeconds > 0 {
            if let top = topSubjectToday {
                return appLanguage == "tr"
                    ? "\(top.name) bugünün ana çalışması."
                    : "\(top.name) is today's main work area."
            } else if let block = todayTimeBlockInsightName {
                return appLanguage == "tr"
                    ? "\(block) ritmin bugün belirgin."
                    : "Your \(block.lowercased()) rhythm is showing today."
            } else {
                let count = todaySessions.count
                if appLanguage == "tr" {
                    return "Bugün \(count) oturum tamamladın."
                } else {
                    return "You completed \(count) \(count == 1 ? "session" : "sessions") today."
                }
            }
        } else {
            if yesterdayTotalSeconds > 0 {
                let yestDur = formatDuration(yesterdayTotalSeconds)
                return appLanguage == "tr"
                    ? "Dün \(yestDur) odaklanmıştın."
                    : "You focused for \(yestDur) yesterday."
            } else {
                return ""
            }
        }
    }

    // MARK: - Last Rhythm Calculations

    private var lastSession: FocusSession? {
        sessions.first
    }

    private var lastSubjectName: String? {
        for s in sessions {
            if let name = displaySubject(for: s), !name.isEmpty {
                return name
            }
        }
        return nil
    }

    private var lastDurationSeconds: Int {
        if let s = lastSession {
            let target = (s.plannedDurationSeconds ?? 0) > 0 ? s.plannedDurationSeconds! : s.durationSeconds
            if target > 0 { return target }
        }

        let recentCompleted = sessions.prefix(10).filter(\.completed)
        if let firstValid = recentCompleted.first(where: { ($0.plannedDurationSeconds ?? $0.durationSeconds) > 0 }) {
            return firstValid.plannedDurationSeconds ?? firstValid.durationSeconds
        }

        return 1500 // 25 min default
    }

    private var lastDurationFormatted: String {
        formatDuration(lastDurationSeconds)
    }

    private var continueButtonTitle: String {
        if let subj = lastSubjectName {
            return appLanguage == "tr" ? "\(subj)'e devam et" : "Continue \(subj)"
        } else {
            return appLanguage == "tr" ? "Son ritmine dön" : "Return to your last rhythm"
        }
    }

    private var continueButtonSubtitle: String {
        if lastSubjectName != nil {
            return appLanguage == "tr" ? "\(lastDurationFormatted) · son ritmin" : "\(lastDurationFormatted) · your last rhythm"
        } else {
            return appLanguage == "tr" ? "\(lastDurationFormatted) · son oturumun" : "\(lastDurationFormatted) · your last session"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        if appLanguage == "tr" {
            if hrs > 0 { return "\(hrs) sa \(mins) dk" }
            return "\(mins) dk"
        } else {
            if hrs > 0 { return "\(hrs)h \(mins)m" }
            return "\(mins)m"
        }
    }

    private func displaySubject(for session: FocusSession) -> String? {
        if let subject = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines), !subject.isEmpty {
            return subject
        }
        if let note = session.intentionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return note
        }
        return nil
    }

    private var miniClockTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = use24HourClock ? Locale(identifier: appLanguage) : Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24HourClock ? "HH:mm" : "h:mm a"
        return formatter.string(from: currentTime)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let layout = YonderLayout(screenWidth: geo.size.width)

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                if showRotationMask {
                    YonderTransitionOverlay()
                        .transition(.opacity)
                        .zIndex(10)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // Top spacer (avatar bar'ın altına yer açıyor)
                        Spacer(minLength: isLandscape ? 12 : (layout.isWide ? 36 : 24))

                        // ── 1. Logo + Brand Title ─────────────────────────────
                        VStack(spacing: isLandscape ? 6 : (layout.isWide ? 12 : 10)) {
                            Image("SplashLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width:  isLandscape ? 70 : (layout.isWide ? 132 : 104),
                                    height: isLandscape ? 70 : (layout.isWide ? 132 : 104)
                                )
                                .opacity(breathePulse ? 1.0 : 0.7)
                                .scaleEffect(breathePulse ? 1.03 : 0.97)

                            Text("YONDER")
                                .font(.system(size: layout.isWide ? 21 : 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(white: 0.88))
                                .tracking(layout.isWide ? 4.8 : 3.8)
                        }
                        .padding(.top, isLandscape ? 12 : (layout.isWide ? 52 : 36))

                        Spacer(minLength: isLandscape ? 28 : (layout.isWide ? 72 : 56))

                        // ── 2. Ana Aksiyon Alanı ─────────────────────────────
                        VStack(spacing: layout.isWide ? 14 : 10) {

                            // Odaklan (Primary CTA)
                            Button {
                                pickerPrefillDuration = nil
                                pickerPrefillSubject = nil
                                showFocusPicker = true
                            } label: {
                                Text(appLanguage == "tr" ? "Odaklan" : "Focus")
                                    .font(.system(size: layout.isWide ? 19 : 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: layout.ctaMaxWidth)
                                    .frame(height: layout.isWide ? 54 : 50)
                                    .background(
                                        Capsule()
                                            .fill(.white)
                                            .shadow(color: .white.opacity(0.16), radius: 10)
                                    )
                            }
                            .buttonStyle(.plain)

                            // Online Oda (Secondary CTA)
                            Button {
                                showRoomActionsSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 15, weight: .medium))
                                    Text(appLanguage == "tr" ? "Online Oda" : "Online Room")
                                        .font(.system(size: layout.isWide ? 18 : 16, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(Color(white: 0.90))
                                .frame(maxWidth: layout.ctaMaxWidth)
                                .frame(height: layout.isWide ? 54 : 50)
                                .background(
                                    Capsule()
                                        .fill(Color(white: 0.08))
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(Color(white: 0.18), lineWidth: 0.5)
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            // Aktif oda geri dön (Varsa) — ana CTA çiftinin altında kalır
                            if !activeRoomId.isEmpty {
                                activeRoomReturnButton(layout: layout)
                                    .padding(.top, layout.isWide ? 4 : 2)
                            }

                            // Yarım kalmış solo timer/kronometre (Varsa) — relaunch sonrası geri dön
                            if let restoreState = activeTimerRestoreState {
                                activeTimerReturnButton(state: restoreState, layout: layout)
                                    .padding(.top, layout.isWide ? 4 : 2)
                            }
                        }

                        Spacer(minLength: isLandscape ? 16 : (layout.isWide ? 36 : 28))

                        // ── 3. Günlük Hedef ─────────────────────────────
                        VStack(spacing: 10) {
                            dailyGoalProgressRow(layout: layout)
                        }
                        .padding(.bottom, isLandscape ? 16 : (layout.isWide ? 36 : 24))
                    }
                    // Aksiyon/metin içerik layout.hPad ile şekilleniyor
                    // (frame+center yok — butonlar zaten maxWidth ile ortalı)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(0, geo.size.height - 44))
                }

                // ── Top Header Bar (Avatar + Saat Chip) ─────────────────
                // layout.hPad ile içerik bandının kenarlarına hizalanıyor
                HStack {
                    Button {
                        onNavigateToSettings?()
                    } label: {
                        ProfileAvatarView(
                            imageData: authService.avatarImageData,
                            googlePhotoURL: authService.googlePhotoURL,
                            name: authService.displayName,
                            size: layout.isWide ? 36 : 32,
                            showEditBadge: false
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        showClockView = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.system(size: layout.isWide ? 12 : 11, weight: .regular))
                                .foregroundStyle(Color(white: 0.45))

                            Text(miniClockTimeString)
                                .font(.system(size: layout.isWide ? 15 : 13, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Color(white: 0.85))
                        }
                        .padding(.horizontal, layout.isWide ? 15 : 13)
                        .padding(.vertical, layout.isWide ? 8 : 7)
                        .background(
                            Capsule()
                                .fill(Color(white: 0.08))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color(white: 0.18), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, layout.isWide ? 20 : 12)
                .padding(.horizontal, layout.hPad) // ← YonderLayout.hPad ile hizalı
            }
            .sheet(isPresented: $showRoomActionsSheet) {
                QuietRoomSheetView(
                    onCreateRoom: { showCreateRoom = true },
                    onJoinRoom: { showJoinRoom = true }
                )
            }
            .sheet(isPresented: $showFocusPicker, onDismiss: {
                reminderDurationSeconds = nil
                pickerPrefillDuration = nil
                pickerPrefillSubject = nil
            }) {
                FocusPickerView(
                    initialDurationSeconds: pickerPrefillDuration ?? reminderDurationSeconds,
                    initialWorkItem: pickerPrefillSubject
                )
            }
            .sheet(isPresented: $showCreateRoom) {
                CreateRoomView(durationInSeconds: lastDurationSeconds, subject: lastSubjectName)
            }
            .sheet(isPresented: $showJoinRoom) {
                JoinRoomView()
            }
            .fullScreenCover(isPresented: $showClockView, onDismiss: showRotationTransitionMask) {
                ClockView(onWillDismiss: showRotationTransitionMask)
            }
            .fullScreenCover(isPresented: $showActiveRoomTimer) {
                RoomTimerView(roomId: activeRoomId)
            }
            .fullScreenCover(item: $restoredTimerVM) { vm in
                TimerView(timerVM: vm, onFinishAll: {
                    restoredTimerVM = nil
                    refreshActiveTimerCard()
                })
            }
            .onReceive(miniClockTimer) { newDate in
                currentTime = newDate
            }
            .onReceive(NotificationCenter.default.publisher(for: .didTapFocusReminderNotification)) { notification in
                if let duration = notification.userInfo?["durationSeconds"] as? Int {
                    reminderDurationSeconds = duration
                    showFocusPicker = true
                }
            }
            .onAppear {
                validateActiveRoom()
                refreshActiveTimerCard()
                let calendar = Calendar.current
                let todayTotal = sessions.filter { calendar.isDateInToday($0.date) }.reduce(0) { $0 + $1.durationSeconds }
                WidgetDataService.shared.updateWidgetData(todayTotalSeconds: todayTotal)
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    breathePulse = true
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshActiveTimerCard()
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Active Room Return Button

    private func activeRoomReturnButton(layout: YonderLayout) -> some View {
        Button {
            showActiveRoomTimer = true
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appLanguage == "tr" ? "Online odaya dön" : "Return to online room")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(appLanguage == "tr" ? "Devam eden oda · \(activeRoomId)" : "Active room · \(activeRoomId)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.60))
                        .monospacedDigit()
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.40))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: layout.ctaMaxWidth)
            .frame(height: layout.isWide ? 54 : 50)
            .background(
                Capsule()
                    .fill(Color(white: 0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(white: 0.18), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active Solo Timer Return Card

    private func activeTimerReturnButton(state: ActiveTimerState, layout: YonderLayout) -> some View {
        Button {
            resumeActiveTimer()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appLanguage == "tr" ? "Odaklanma oturumuna dön" : "Return to focus session")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(activeTimerSubtitle(state))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.60))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.40))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: layout.ctaMaxWidth)
            .frame(height: layout.isWide ? 54 : 50)
            .background(
                Capsule()
                    .fill(Color(white: 0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(white: 0.18), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func activeTimerSubtitle(_ state: ActiveTimerState) -> String {
        let note = state.intentionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let modeLabel = state.isStopwatchMode
            ? (appLanguage == "tr" ? "Kronometre" : "Stopwatch")
            : (appLanguage == "tr" ? "Geri sayım" : "Countdown")
        let statusLabel = state.isRunning
            ? (appLanguage == "tr" ? "devam ediyor" : "in progress")
            : (appLanguage == "tr" ? "duraklatıldı" : "paused")

        if !note.isEmpty {
            return "\(note) · \(statusLabel)"
        }
        return "\(modeLabel) · \(statusLabel)"
    }

    /// Reconstructs the persisted session and opens it full-screen, same as tapping
    /// "Start" from FocusPickerView would — restoredTimerVM drives the fullScreenCover.
    private func resumeActiveTimer() {
        guard let vm = TimerViewModel.restoreIfAvailable() else {
            activeTimerRestoreState = nil
            return
        }
        restoredTimerVM = vm
    }

    /// Re-reads the persisted state so the card reflects reality after a cold launch,
    /// a foreground return, or a session being saved/discarded/reset elsewhere.
    private func refreshActiveTimerCard() {
        activeTimerRestoreState = ActiveTimerStateStore.load()
    }

    private func validateActiveRoom() {
        guard !activeRoomId.isEmpty else { return }
        let code = activeRoomId
        Task {
            do {
                let snapshot = try await Firestore.firestore().collection("rooms").document(code).getDocument()
                if !snapshot.exists {
                    await MainActor.run { self.activeRoomId = "" }
                } else if let status = snapshot.data()?["status"] as? String, status == "ended" {
                    await MainActor.run { self.activeRoomId = "" }
                }
            } catch {
                // Keep activeRoomId if offline / network error
            }
        }
    }

    /// Briefly covers the screen with a loading mask when returning from a
    /// landscape-allowed screen (e.g. the Clock), so the instant of landscape-to-portrait
    /// rotation catch-up doesn't visibly flash before settling.
    private func showRotationTransitionMask() {
        withAnimation(.easeInOut(duration: 0.12)) {
            showRotationMask = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.easeOut(duration: 0.25)) {
                showRotationMask = false
            }
        }
    }

    // MARK: - Quick Continue Button

    private func quickContinueButton(layout: YonderLayout) -> some View {
        Button {
            pickerPrefillDuration = lastDurationSeconds
            pickerPrefillSubject = lastSubjectName
            showFocusPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(white: 0.85))

                VStack(alignment: .leading, spacing: 2) {
                    Text(continueButtonTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.92))
                        .lineLimit(1)

                    Text(continueButtonSubtitle)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: layout.secondaryMaxWidth)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(white: 0.15), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Daily Goal Progress Row

    private func dailyGoalProgressRow(layout: YonderLayout) -> some View {
        Group {
            if dailyGoalTargetSeconds > 0 {
                let current = todayTotalSeconds
                let target = dailyGoalTargetSeconds
                let ratio = min(1.0, CGFloat(current) / CGFloat(target))
                let currentStr = formatDuration(current)
                let targetStr = formatDuration(target)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(appLanguage == "tr"
                             ? "Günlük hedef: \(currentStr) / \(targetStr)"
                             : "Daily goal: \(currentStr) / \(targetStr)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.65))
                            .monospacedDigit()

                        Spacer()
                    }

                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 3)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.60))
                                .frame(width: max(current > 0 ? 3 : 0, g.size.width * ratio), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .frame(maxWidth: layout.secondaryMaxWidth)
                .padding(.bottom, 2)
            }
        }
    }

    // MARK: - Mini Metrics Bar

    private func miniMetricsBar(layout: YonderLayout) -> some View {
        HStack(spacing: 0) {
            miniStatItem(
                title: appLanguage == "tr" ? "Süre" : "Time",
                value: todayTotalSeconds > 0 ? formattedTimeStr : (appLanguage == "tr" ? "0 dk" : "0m")
            )

            Divider()
                .background(Color(white: 0.16))
                .frame(height: 22)

            miniStatItem(
                title: appLanguage == "tr" ? "Oturum" : "Sessions",
                value: "\(todaySessions.count)"
            )

            Divider()
                .background(Color(white: 0.16))
                .frame(height: 22)

            miniStatItem(
                title: appLanguage == "tr" ? "Çalışma" : "Work Areas",
                value: "\(uniqueSubjectsTodayCount)"
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.065))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(white: 0.14), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: layout.secondaryMaxWidth)
    }

    private func miniStatItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.38))
                .textCase(.uppercase)
                .tracking(1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.86))
                .lineLimit(1)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Daily Mini Insight Row

    private var dailyInsightRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(white: 0.50))

            Text(dailyInsightText)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.60))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(white: 0.05))
                .overlay(Capsule().strokeBorder(Color(white: 0.12), lineWidth: 0.5))
        )
    }
}

// MARK: - Quiet Room Sheet View

/// Dedicated quiet room action sheet presenting options to create or join a room.
struct QuietRoomSheetView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var onCreateRoom: () -> Void
    var onJoinRoom: () -> Void

    private var isIPad: Bool { horizontalSizeClass == .regular }
    private var isAuthenticated: Bool {
        Auth.auth().currentUser != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // Top Grab Handle / Close Header
                HStack {
                    Spacer()
                    Capsule()
                        .fill(Color(white: 0.25))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(white: 0.45))
                            .padding(14)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 8) {
                    // Emblem / Icon
                    Image(systemName: "person.2.fill")
                        .font(.system(size: isIPad ? 28 : 22, weight: .regular))
                        .foregroundStyle(Color(white: 0.70))
                        .padding(.bottom, 2)

                    // Title
                    Text(appLanguage == "tr" ? "Online Oda" : "Online Room")
                        .font(.system(size: isIPad ? 22 : 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.95))

                    // Subtitle
                    Text(appLanguage == "tr"
                         ? "Aynı sayaçta, dikkat dağıtmadan birlikte çalış."
                         : "Focus together on the same timer, without distractions.")
                        .font(.system(size: isIPad ? 14 : 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if !isAuthenticated {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text(appLanguage == "tr"
                             ? "Online odalar için giriş yapman gerekiyor."
                             : "You need to sign in to use online rooms.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                    }
                    .foregroundStyle(Color(white: 0.50))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.07))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(white: 0.14), lineWidth: 0.5))
                    )
                }

                // Action Buttons
                VStack(spacing: 12) {
                    // Create Room Button
                    Button {
                        dismiss()
                        onCreateRoom()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15, weight: .medium))
                            Text(appLanguage == "tr" ? "Online Oda Oluştur" : "Create Online Room")
                                .font(.system(size: isIPad ? 16 : 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 52 : 46)
                        .background(Capsule().fill(.white))
                    }
                    .buttonStyle(.plain)

                    // Join Room Button
                    Button {
                        dismiss()
                        onJoinRoom()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14, weight: .medium))
                            Text(appLanguage == "tr" ? "Odaya katıl" : "Join Room")
                                .font(.system(size: isIPad ? 16 : 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color(white: 0.90))
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 52 : 46)
                        .background(
                            Capsule()
                                .fill(Color(white: 0.08))
                                .overlay(Capsule().strokeBorder(Color(white: 0.18), lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, isIPad ? 64 : 24)
                .padding(.bottom, isIPad ? 32 : 20)
            }
        }
        .presentationDetents([.height(isAuthenticated ? 320 : 360)])
        .presentationCornerRadius(24)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .modelContainer(for: FocusSession.self, inMemory: true)
}
