//
//  FocusPickerView.swift
//  Yonder
//

import SwiftUI
import SwiftData

enum TimerModeSelection: String, CaseIterable, Identifiable {
    case duration  = "timer_mode_duration"
    case stopwatch = "timer_mode_stopwatch"

    var id: String { rawValue }

    func title(appLanguage: String) -> String {
        String.localized(rawValue, lang: appLanguage)
    }
}

/// Duration picker sheet containing circular dial, multi-unit flip clock,
/// instant start button, and secondary room options link.
struct FocusPickerView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Query private var sessions: [FocusSession]
    @Query(sort: \Subject.lastUsedDate, order: .reverse) private var savedSubjects: [Subject]
    @Environment(\.modelContext) private var modelContext

    var initialDurationSeconds: Int? = nil
    var initialWorkItem: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass)   private var vSizeClass

    @State private var timerVM = TimerViewModel()
    @State private var showSoloTimer = false
    @State private var showWorkItemPickerSheet = false
    @State private var conflictingActiveSession: TimerViewModel? = nil

    @State private var selectedWorkItem: String? = nil
    @State private var selectedTimerMode: TimerModeSelection = .duration

    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 25
    @State private var selectedSeconds: Int = 0

    // Width thresholds — YonderLayout utility kullanılıyor.
    // Cihaz ismine özel hack yok; sadece available width üzerinden.
    private func makeLayout(_ width: CGFloat) -> YonderLayout { YonderLayout(screenWidth: width) }

    private var isLandscapePhone: Bool { vSizeClass == .compact }

    private var totalSeconds: Int {
        (selectedHours * 3600) + (selectedMinutes * 60) + selectedSeconds
    }

    private var intentionNote: String {
        selectedWorkItem ?? ""
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 4) {
            ForEach(TimerModeSelection.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimerMode = mode
                    }
                } label: {
                    Text(mode.title(appLanguage: appLanguage))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(selectedTimerMode == mode ? Color.black : Color(white: 0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTimerMode == mode ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color(white: 0.10))
        )
    }

    // MARK: - Stopwatch Description

    private func stopwatchDescriptionView(availableWidth: CGFloat) -> some View {
        let layout = makeLayout(availableWidth)
        let wide = layout.isWide
        let landscape = isLandscapePhone

        return VStack(spacing: landscape ? 14 : 18) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color(white: 0.16), lineWidth: 2)
                        .frame(
                            width: landscape ? 64 : (wide ? 110 : 86),
                            height: landscape ? 64 : (wide ? 110 : 86)
                        )

                    Image(systemName: "stopwatch")
                        .font(.system(size: landscape ? 30 : (wide ? 48 : 38), weight: .light))
                        .foregroundStyle(Color(white: 0.72))
                }

                VStack(spacing: 5) {
                    Text(appLanguage == "tr" ? "Süresiz Odak" : "Open Focus")
                        .font(.system(size: landscape ? 17 : (wide ? 24 : 21), weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.86))
                        .tracking(1.2)

                    Text(String.localized("stopwatch_mode_description", lang: appLanguage))
                        .font(.system(size: wide ? 15 : 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.42))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }

            HStack(spacing: 8) {
                stopwatchSetupTile(
                    title: appLanguage == "tr" ? "Başlangıç" : "Starts At",
                    value: "00:00:00",
                    icon: "timer",
                    availableWidth: availableWidth
                )
                stopwatchSetupTile(
                    title: appLanguage == "tr" ? "Bitiş" : "Finish",
                    value: appLanguage == "tr" ? "Sen belirle" : "Any time",
                    icon: "flag.checkered",
                    availableWidth: availableWidth
                )
            }

            if !intentionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 10, weight: .semibold))
                    Text(intentionNote.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: wide ? 13 : 11, weight: .medium, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(Color(white: 0.78))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color(white: 0.12))
                        .overlay(Capsule().strokeBorder(Color(white: 0.22), lineWidth: 0.5))
                )
            }
        }
        .padding(.horizontal, landscape ? 16 : makeLayout(availableWidth).hPad)
        .frame(maxWidth: .infinity)
    }

    private func stopwatchSetupTile(title: String, value: String, icon: String, availableWidth: CGFloat) -> some View {
        let wide = makeLayout(availableWidth).isWide
        let landscape = isLandscapePhone

        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: landscape ? 11 : 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.46))

            Text(value)
                .font(.system(size: landscape ? 13 : (wide ? 17 : 15), weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.88))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.system(size: landscape ? 8 : 9, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.36))
                .textCase(.uppercase)
                .tracking(1.1)
                .lineLimit(1)
        }
        .frame(maxWidth: wide ? 180 : .infinity, alignment: .leading)
        .padding(.horizontal, landscape ? 10 : 12)
        .padding(.vertical, landscape ? 9 : 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.065))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(white: 0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Work Item Picker Field

    @ViewBuilder
    private func workItemPickerField(isCompact: Bool, availableWidth: CGFloat = 400) -> some View {
        let wide = makeLayout(availableWidth).isWide
        if let selected = selectedWorkItem, !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HStack(spacing: 8) {
                Button {
                    showWorkItemPickerSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: isCompact ? 10 : (wide ? 13 : 11)))
                            .foregroundStyle(Color.black)

                        Text(selected)
                            .font(.system(size: isCompact ? 11 : (wide ? 14 : 13), weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.black)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedWorkItem = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: isCompact ? 12 : (wide ? 16 : 14)))
                        .foregroundStyle(Color(white: 0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isCompact ? 10 : 14)
            .padding(.vertical, isCompact ? 6 : 8)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.white.opacity(0.12), radius: 6)
            )
        } else {
            Button {
                showWorkItemPickerSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: isCompact ? 11 : 13, weight: .regular))
                        .foregroundStyle(Color(white: 0.45))

                    Text(appLanguage == "tr" ? "Ne üzerinde çalışacaksın?" : "What will you focus on?")
                        .font(.system(size: isCompact ? 11 : (wide ? 15 : 13), weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: isCompact ? 10 : 12))
                        .foregroundStyle(Color(white: 0.35))
                }
                .padding(.horizontal, isCompact ? 10 : 14)
                .frame(maxWidth: isCompact ? 240 : .infinity)
                .frame(height: isCompact ? 36 : (wide ? 46 : 42))
                .background(
                    RoundedRectangle(cornerRadius: isCompact ? 10 : 12)
                        .fill(Color(white: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 10 : 12)
                                .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Top Grab Handle / Dismiss ──────────────────────────
                    topDismissHeader

                    if isLandscapePhone {
                        landscapePhoneLayout(availableWidth: geo.size.width)
                    } else if makeLayout(geo.size.width).isWide {
                        iPadWideLayout(availableWidth: geo.size.width, availableHeight: geo.size.height)
                    } else {
                        portraitLayout(availableWidth: geo.size.width)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showSoloTimer) {
            TimerView(timerVM: timerVM, onFinishAll: {
                dismiss()
            })
        }
        .sheet(isPresented: $showWorkItemPickerSheet) {
            WorkItemPickerSheet(selectedWorkItem: $selectedWorkItem)
        }
        .confirmationDialog(
            appLanguage == "tr" ? "Bitmemiş bir oturumun var" : "You have an unfinished session",
            isPresented: Binding(
                get: { conflictingActiveSession != nil },
                set: { if !$0 { conflictingActiveSession = nil } }
            ),
            titleVisibility: .visible,
            presenting: conflictingActiveSession
        ) { _ in
            Button(appLanguage == "tr" ? "Yeni oturum başlat (eskisi silinir)" : "Start new session (discard old)", role: .destructive) {
                conflictingActiveSession = nil
                proceedWithStartingTimer()
            }
            Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {
                conflictingActiveSession = nil
            }
        } message: { conflicting in
            Text(
                appLanguage == "tr"
                ? "\(ReportMetrics.formattedTime(seconds: conflicting.displaySeconds, lang: appLanguage)) süren kaydedilmemiş bir odaklanma oturumun var. Yeni oturum başlatırsan bu kaybolur. Onu kaydetmek için önce ana sayfadan devam et."
                : "You have an unsaved focus session with \(ReportMetrics.formattedTime(seconds: conflicting.displaySeconds, lang: appLanguage)) on it. Starting a new one will lose it. Go back to the home screen to resume and save it first."
            )
        }
        .onAppear {
            if let initial = initialDurationSeconds, initial > 0 {
                selectedHours = initial / 3600
                selectedMinutes = (initial % 3600) / 60
                selectedSeconds = initial % 60
            }
            if let initialSubject = initialWorkItem, !initialSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedWorkItem = initialSubject
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(showSoloTimer || timerVM.sessionStartedAt != nil)
    }

    // MARK: - Top Dismiss Header

    private var topDismissHeader: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(Color(white: 0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)
            Spacer()
        }
    }

    // MARK: - iPad Wide Layout (≥700pt width) — Two-column

    private func iPadWideLayout(availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        let layout = makeLayout(availableWidth)
        let hPad = layout.hPad
        // İki kolon için toplam içerik genisi = tum ekran - iki yan padding
        let contentWidth = layout.contentWidth

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 12)

                // Title + Mode Selector centered at top
                VStack(spacing: 10) {
                    VStack(spacing: 4) {
                        Text("yonder")
                            .font(.system(size: 30, weight: .light, design: .rounded))
                            .foregroundStyle(Color(white: 0.6))
                            .tracking(6)
                            .textCase(.uppercase)

                        Text(String.localized("select_duration", lang: appLanguage))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.35))
                    }
                    modeSelector
                }
                .padding(.bottom, 20)
                .padding(.horizontal, hPad)

                if selectedTimerMode == .duration {
                    // ── Two-column layout ──────────────────────────────────
                    HStack(alignment: .top, spacing: 32) {
                        // Sol kolon: FlipClock + Wheel
                        VStack(spacing: 16) {
                            FlipClockView(
                                hours: selectedHours,
                                minutes: selectedMinutes,
                                seconds: selectedSeconds,
                                showHours: true,
                                isRunning: false,
                                animatesDigitChanges: false
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 190)

                            durationWheelView(availableWidth: contentWidth * 0.52)
                        }
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)

                        // Divider
                        Rectangle()
                            .fill(Color(white: 0.12))
                            .frame(width: 0.5)
                            .padding(.vertical, 8)

                        // Sağ kolon: Work item + Start button
                        VStack(alignment: .leading, spacing: 16) {
                            Spacer(minLength: 8)

                            workItemPickerSection(isCompact: false, availableWidth: contentWidth * 0.44)
                                .frame(maxWidth: .infinity)

                            startButton(availableWidth: contentWidth * 0.44)
                        }
                        .frame(maxWidth: contentWidth * 0.42)
                    }
                    .padding(.horizontal, hPad)
                    .padding(.bottom, 28)

                } else {
                    stopwatchDescriptionView(availableWidth: contentWidth)
                        .padding(.horizontal, hPad)
                        .layoutPriority(1)
                        .padding(.bottom, 16)

                    VStack(spacing: 14) {
                        workItemPickerSection(isCompact: false, availableWidth: contentWidth * 0.60)
                            .frame(maxWidth: contentWidth * 0.60)

                        startButton(availableWidth: contentWidth * 0.60)
                    }
                    .padding(.horizontal, hPad)
                    .padding(.bottom, 28)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Portrait Layout (iPhone + small iPad / split view)

    private func portraitLayout(availableWidth: CGFloat) -> some View {
        let layout = makeLayout(availableWidth)
        // YonderLayout.hPad: clamp(w × 0.062, 20, 72)
        let hPad = layout.hPad

        return VStack(spacing: 0) {
            Spacer(minLength: 8)

            // Title & Mode Selector
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("yonder")
                        .font(.system(size: layout.isMedium ? 30 : 24, weight: .light, design: .rounded))
                        .foregroundStyle(Color(white: 0.6))
                        .tracking(6)
                        .textCase(.uppercase)

                    Text(String.localized("select_duration", lang: appLanguage))
                        .font(.system(size: layout.isMedium ? 14 : 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.35))
                }

                modeSelector
            }
            .padding(.bottom, 8)

            Spacer(minLength: 0)

            if selectedTimerMode == .duration {
                durationComposerView(availableWidth: availableWidth)
                    .padding(.horizontal, hPad)
                    .layoutPriority(1)
            } else {
                stopwatchDescriptionView(availableWidth: availableWidth)
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)

            // Action buttons — aynı hPad ile hizalı
            VStack(spacing: layout.isMedium ? 14 : 10) {
                workItemPickerSection(isCompact: false, availableWidth: layout.contentWidth)

                startButton(availableWidth: layout.contentWidth)
            }
            .padding(.horizontal, hPad)
            .padding(.bottom, layout.isMedium ? 28 : 20)
        }
    }

    // MARK: - Landscape Phone Layout

    private func landscapePhoneLayout(availableWidth: CGFloat) -> some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    HStack(spacing: 20) {
                        if selectedTimerMode == .duration {
                            durationComposerView(availableWidth: availableWidth * 0.48)
                                .frame(maxWidth: .infinity)
                        } else {
                            stopwatchDescriptionView(availableWidth: availableWidth * 0.48)
                                .frame(maxWidth: .infinity)
                        }

                        // Right Column
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("yonder")
                                    .font(.system(size: 20, weight: .light, design: .rounded))
                                    .foregroundStyle(Color(white: 0.6))
                                    .tracking(6)
                                    .textCase(.uppercase)

                                modeSelector
                            }

                            actionButtonsSectionCompact
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                    Spacer(minLength: 0)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Duration Composer

    private func durationComposerView(availableWidth: CGFloat) -> some View {
        let landscape = isLandscapePhone
        let layout = makeLayout(availableWidth)
        let clockHeight: CGFloat = landscape ? 96 : (layout.isWide ? 190 : (layout.isMedium ? 165 : 138))

        return VStack(spacing: landscape ? 10 : 16) {
            FlipClockView(
                hours: selectedHours,
                minutes: selectedMinutes,
                seconds: selectedSeconds,
                showHours: true,
                isRunning: false,
                animatesDigitChanges: false
            )
            .frame(maxWidth: .infinity)
            .frame(height: clockHeight)

            durationWheelView(availableWidth: availableWidth)
        }
    }

    // MARK: - Duration Wheel

    private func durationWheelView(availableWidth: CGFloat) -> some View {
        let landscape = isLandscapePhone
        let wheelHeight: CGFloat = landscape ? 76 : 96
        let containerHeight: CGFloat = landscape ? 100 : 126

        return HStack(spacing: landscape ? 8 : 10) {
            durationWheelColumn(
                title: unitTitle(.hours),
                selection: $selectedHours,
                values: 0...12,
                wheelHeight: wheelHeight
            )

            durationWheelColumn(
                title: unitTitle(.minutes),
                selection: $selectedMinutes,
                values: 0...59,
                wheelHeight: wheelHeight
            )

            durationWheelColumn(
                title: unitTitle(.seconds),
                selection: $selectedSeconds,
                values: 0...59,
                wheelHeight: wheelHeight
            )
        }
        .frame(height: containerHeight)
    }

    private func durationWheelColumn(title: String, selection: Binding<Int>, values: ClosedRange<Int>, wheelHeight: CGFloat) -> some View {
        let landscape = isLandscapePhone
        return VStack(spacing: 4) {
            Text(title)
                .font(.system(size: landscape ? 9 : 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.42))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Picker(title, selection: selection) {
                ForEach(Array(values), id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .font(.system(size: landscape ? 18 : 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: wheelHeight)
            .clipped()
            .compositingGroup()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.075))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                    )
            )
        }
    }

    // MARK: - Action Buttons (Shared Helpers)

    private var isDurationZero: Bool {
        selectedTimerMode == .duration && totalSeconds == 0
    }

    private var workItemOptionalNotice: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(white: 0.55))

            Text(appLanguage == "tr" ? "İstersen çalışma alanını sonra seçebilirsin." : "You can choose a work area later.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.55))
                .lineLimit(1)
        }
        .padding(.top, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func workItemPickerSection(isCompact: Bool, availableWidth: CGFloat = 400) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            workItemPickerField(isCompact: isCompact, availableWidth: availableWidth)
            if selectedWorkItem?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                workItemOptionalNotice
            }
        }
    }

    // MARK: - Action Buttons (Shared Helpers)

    /// Ana başlat butonu — YonderLayout.ctaMaxWidth ile dengeli
    private func startButton(availableWidth: CGFloat) -> some View {
        let layout = makeLayout(availableWidth)
        let maxW = layout.ctaMaxWidth

        return Button {
            handleStartButtonTap()
        } label: {
            Text(String.localized("start_solo", lang: appLanguage))
                .font(.system(size: layout.isWide ? 18 : 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: maxW)
                .frame(height: layout.isWide ? 54 : 48)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: .white.opacity(0.15), radius: 8)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDurationZero)
        .opacity(isDurationZero ? 0.30 : 1.0)
    }

    // MARK: - Action Buttons Section (landscape compact)

    private var actionButtonsSectionCompact: some View {
        VStack(spacing: 8) {
            workItemPickerSection(isCompact: true, availableWidth: 300)

            Button {
                handleStartButtonTap()
            } label: {
                Text(String.localized("start_solo", lang: appLanguage))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: 240)
                    .frame(height: 42)
                    .background(
                        Capsule()
                            .fill(.white)
                            .shadow(color: .white.opacity(0.15), radius: 6)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isDurationZero)
            .opacity(isDurationZero ? 0.30 : 1.0)
        }
    }

    private func handleStartButtonTap() {
        if isDurationZero {
            HapticService.warning()
            return
        }

        startSoloTimer()
    }

    // MARK: - Actions

    private func startSoloTimer() {
        if selectedTimerMode == .duration {
            guard totalSeconds > 0 else { return }
        }

        // Starting a new session wipes any unfinished one still on disk (setDuration/
        // setStopwatchMode both clear ActiveTimerStateStore). Surface it first instead
        // of silently discarding hours of unsaved solo-timer progress — this is how a
        // background stopwatch left running for hours used to vanish with no record.
        if let conflicting = TimerViewModel.restoreIfAvailable() {
            conflictingActiveSession = conflicting
            return
        }

        proceedWithStartingTimer()
    }

    private func proceedWithStartingTimer() {
        let trimmedSubject = selectedWorkItem?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmedSubject.isEmpty {
            if let existing = savedSubjects.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmedSubject) == .orderedSame }) {
                existing.lastUsedDate = Date()
                try? modelContext.save()
            }
        }

        timerVM.intentionNote = trimmedSubject

        if selectedTimerMode == .stopwatch {
            timerVM.setStopwatchMode()
        } else {
            timerVM.setDuration(totalSeconds)
        }

        timerVM.start()
        showSoloTimer = true
    }

    private func unitTitle(_ unit: TimeUnit) -> String {
        switch unit {
        case .hours:
            return appLanguage == "tr" ? "Saat" : "Hour"
        case .minutes:
            return appLanguage == "tr" ? "Dakika" : "Minute"
        case .seconds:
            return appLanguage == "tr" ? "Saniye" : "Second"
        }
    }

    private func setPresetMinutes(_ totalMinutes: Int) {
        selectedHours = totalMinutes / 60
        selectedMinutes = totalMinutes % 60
        selectedSeconds = 0
    }
}

// MARK: - Preview

#Preview {
    FocusPickerView()
}
