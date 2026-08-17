//
//  FocusGoalsView.swift
//  Yonder
//
//  Redesigned Work Goals Hub & detail views.
//  Separates General Work Goals and Work Area Specific Goals,
//  supports recurring vs period-specific goals ("Her gün / Bugün"),
//  and restricts work area targets strictly to existing subjects created in "Çalışmalarım".
//

import SwiftUI
import SwiftData

enum GoalsHubScreenState {
    case hub
    case generalGoals
    case workAreaGoals
}

/// Work Goals container managing navigation between Hub, General Goals, and Work Area Goals.
struct FocusGoalsView: View {

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.lastUsedDate, order: .reverse) private var savedSubjects: [Subject]
    @Query private var sessions: [FocusSession]
    @ObservedObject private var goalStore = WorkGoalStore.shared

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false

    @State private var currentScreen: GoalsHubScreenState = .hub
    @State private var showWorkItemManagementSheet: Bool = false
    @State private var selectedSubjectForEditing: Subject? = nil
    @State private var showPaywallSheet: Bool = false
    @State private var retryGeneralGoalSaveAfterUnlock: Bool = false
    @State private var toastMessage: String? = nil

    private var activeSubjects: [Subject] {
        savedSubjects.filter { !$0.isArchived }
    }

    var body: some View {
        GeometryReader { geo in
            let layout = YonderLayout(screenWidth: geo.size.width)

            ZStack {
                Color.black.ignoresSafeArea()

                switch currentScreen {
                case .hub:
                    focusGoalsHubView(layout: layout)
                case .generalGoals:
                    generalGoalsView(layout: layout)
                case .workAreaGoals:
                    workAreaGoalsView(layout: layout)
                }

                // Toast Notification Banner
                if let msg = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(msg)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(white: 0.12))
                                .overlay(Capsule().strokeBorder(Color(white: 0.22), lineWidth: 0.5))
                        )
                        .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showWorkItemManagementSheet) {
            WorkItemManagementView()
        }
        .sheet(item: $selectedSubjectForEditing) { subject in
            WorkAreaGoalDetailSheet(
                subject: subject,
                sessions: sessions,
                onSave: { msg in
                    showToast(msg)
                }
            )
        }
        .sheet(isPresented: $showPaywallSheet) {
            YonderPaywallSheetView(
                onUnlockPremium: {
                    isPremiumUser = true
                    showPaywallSheet = false
                    if retryGeneralGoalSaveAfterUnlock {
                        retryGeneralGoalSaveAfterUnlock = false
                        saveGeneralGoal()
                    } else {
                        showToast(appLanguage == "tr" ? "Yonder PRO aktifleştirildi" : "Yonder PRO unlocked")
                    }
                }
            )
        }
        .onAppear {
            let validNames = Set(activeSubjects.map { $0.name })
            goalStore.cleanupOrphanGoals(validNames: validNames)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 1. HUB VIEW (Hedefler Ana Sayfası)

    private func focusGoalsHubView(layout: YonderLayout) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text(appLanguage == "tr" ? "Ayarlar" : "Settings")
                            .font(.system(size: 14, design: .rounded))
                    }
                    .foregroundStyle(Color(white: 0.7))
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 5) {
                    Text(appLanguage == "tr" ? "Hedefler" : "Goals")
                        .font(.system(size: layout.isWide ? 18 : 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.9))

                    proBadge
                }

                Spacer()

                Color.clear.frame(width: 70, height: 20)
            }
            .padding(.horizontal, layout.hPad)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: layout.isWide ? 26 : 20) {

                    // Subtitle Header
                    VStack(spacing: 6) {
                        Text(appLanguage == "tr" ? "Hedefler" : "Goals")
                            .font(.system(size: layout.isWide ? 26 : 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(white: 0.95))

                        Text(appLanguage == "tr"
                             ? "Çalışmanı sürekli veya döneme özel hedeflerle planla."
                             : "Plan your work with recurring and period-specific targets.")
                            .font(.system(size: layout.isWide ? 15 : 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.50))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    // Option A: Genel Çalışma Hedefleri Card
                    GoalCardView(
                        icon: "target",
                        iconColor: Color(red: 0.45, green: 0.85, blue: 0.65),
                        title: appLanguage == "tr" ? "Genel Çalışma Hedefleri" : "General Work Goals",
                        subtitle: appLanguage == "tr"
                            ? "Günlük, haftalık ve aylık toplam çalışma hedeflerini belirle."
                            : "Set daily, weekly, and monthly total work duration goals.",
                        detailSummary: goalStore.totalGoalsSummary(lang: appLanguage),
                        isWide: layout.isWide,
                        action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .generalGoals
                            }
                        }
                    )
                    .frame(maxWidth: layout.secondaryMaxWidth)

                    // Option B: Çalışma Bazlı Hedefler Card
                    GoalCardView(
                        icon: "square.and.pencil",
                        iconColor: Color(red: 0.42, green: 0.82, blue: 0.88),
                        title: appLanguage == "tr" ? "Çalışma Bazlı Hedefler" : "Work Area Goals",
                        subtitle: appLanguage == "tr"
                            ? "Çalışmalarına ayrı ayrı hedefler koy."
                            : "Set specific target durations for each work area.",
                        detailSummary: goalStore.workAreaGoalsSummary(lang: appLanguage),
                        isWide: layout.isWide,
                        action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentScreen = .workAreaGoals
                            }
                        }
                    )
                    .frame(maxWidth: layout.secondaryMaxWidth)

                }
                .padding(.horizontal, layout.hPad)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - 2. GENERAL GOALS VIEW (Genel Çalışma Hedefleri)

    @State private var generalPeriod: WorkGoalPeriod = .daily
    @State private var generalMode: WorkGoalMode = .recurring
    @State private var generalHours: Int = 0
    @State private var generalMinutes: Int = 0
    @State private var generalEnabled: Bool = true

    private func generalGoalsView(layout: YonderLayout) -> some View {
        let totalSecs = (generalHours * 3600) + (generalMinutes * 60)

        return VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentScreen = .hub
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text(appLanguage == "tr" ? "Hedefler" : "Goals")
                            .font(.system(size: 14, design: .rounded))
                    }
                    .foregroundStyle(Color(white: 0.7))
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 5) {
                    Text(appLanguage == "tr" ? "Genel Hedefler" : "General Goals")
                        .font(.system(size: layout.isWide ? 18 : 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.9))

                    proBadge
                }

                Spacer()

                Color.clear.frame(width: 70, height: 20)
            }
            .padding(.horizontal, layout.hPad)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: layout.isWide ? 26 : 20) {

                    // Subtitle Header
                    VStack(spacing: 6) {
                        Text(appLanguage == "tr" ? "Genel Çalışma Hedefleri" : "General Work Goals")
                            .font(.system(size: layout.isWide ? 26 : 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(white: 0.95))

                        Text(appLanguage == "tr"
                             ? "Toplam çalışmanı sürekli veya döneme özel hedeflerle planla."
                             : "Plan your total work with recurring or period-specific goals.")
                            .font(.system(size: layout.isWide ? 15 : 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.50))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    // Period Segmented Control
                    periodSegmentControl(selection: $generalPeriod)

                    // Mode Segmented Control ("Her gün / Sadece bugün")
                    HStack(spacing: 4) {
                        ForEach(WorkGoalMode.allCases) { mode in
                            let isSelected = generalMode == mode
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    generalMode = mode
                                    loadGeneralPeriodState(generalPeriod)
                                }
                            } label: {
                                Text(mode.label(period: generalPeriod, lang: appLanguage))
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.black : Color(white: 0.55))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(isSelected ? Color.white : Color.clear))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Capsule().fill(Color(white: 0.08)).overlay(Capsule().strokeBorder(Color(white: 0.14), lineWidth: 0.5)))
                    .frame(maxWidth: layout.secondaryMaxWidth)

                    Text(modeExplanation(period: generalPeriod, mode: generalMode))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: layout.secondaryMaxWidth)

                    // Main Configuration Card
                    VStack(spacing: 20) {

                        // Active Toggle
                        Toggle(isOn: $generalEnabled) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(appLanguage == "tr" ? "Bu hedef aktif" : "This goal is active")
                                    .font(.system(size: layout.isWide ? 16 : 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(white: 0.92))

                                Text(appLanguage == "tr"
                                     ? "İlerleme bu genel hedefe göre takip edilir."
                                     : "Progress is tracked against this general target.")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Color(white: 0.45))
                            }
                        }
                        .tint(Color.white)

                        Divider().background(Color(white: 0.14))

                        // Large Duration Display
                        VStack(spacing: 6) {
                            Text(appLanguage == "tr" ? "HEDEF SÜRE" : "TARGET DURATION")
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(white: 0.40))
                                .tracking(1.2)

                            Text(totalSecs > 0 ? formatDuration(totalSecs) : (appLanguage == "tr" ? "Hedef Belirlenmedi" : "No Target Set"))
                                .font(.system(size: layout.isWide ? 28 : 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(totalSecs > 0 ? Color(white: 0.95) : Color(white: 0.35))
                                .monospacedDigit()
                        }

                        // Hour & Minute Pickers
                        HStack(spacing: 12) {
                            pickerColumn(
                                title: appLanguage == "tr" ? "Saat" : "Hours",
                                selection: $generalHours,
                                range: Array(0...maxHours(for: generalPeriod))
                            )

                            pickerColumn(
                                title: appLanguage == "tr" ? "Dakika" : "Minutes",
                                selection: $generalMinutes,
                                range: Array(stride(from: 0, through: 55, by: 5))
                            )
                        }
                        .opacity(generalEnabled ? 1.0 : 0.4)
                        .disabled(!generalEnabled)

                        let generalErr = goalStore.validateGoal(
                            scope: .total,
                            workAreaName: nil,
                            period: generalPeriod,
                            mode: generalMode,
                            targetSeconds: totalSecs,
                            isEnabled: generalEnabled,
                            lang: appLanguage
                        )

                        if let err = generalErr {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.45))
                                Text(err)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.45))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.95, green: 0.72, blue: 0.45).opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(red: 0.95, green: 0.72, blue: 0.45).opacity(0.3), lineWidth: 0.5))
                            )
                        }

                        // Quick Presets
                        VStack(alignment: .leading, spacing: 8) {
                            Text(appLanguage == "tr" ? "Hızlı Seçim" : "Quick Presets")
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(white: 0.40))
                                .textCase(.uppercase)

                            HStack(spacing: 8) {
                                ForEach(presets(for: generalPeriod)) { item in
                                    let isSelected = totalSecs == (item.minutes * 60)
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            generalHours = item.minutes / 60
                                            generalMinutes = item.minutes % 60
                                        }
                                    } label: {
                                        Text(appLanguage == "tr" ? item.labelTR : item.labelEN)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(isSelected ? Color.black : Color(white: 0.75))
                                            .monospacedDigit()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(isSelected ? Color.white : Color(white: 0.10))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .strokeBorder(Color(white: isSelected ? 1.0 : 0.18), lineWidth: 0.5)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .opacity(generalEnabled ? 1.0 : 0.4)
                        .disabled(!generalEnabled)

                        // Save General Goal Button
                        Button {
                            if generalErr == nil {
                                saveGeneralGoal()
                            }
                        } label: {
                            Text(appLanguage == "tr" ? "Hedefi Kaydet" : "Save Goal")
                                .font(.system(size: layout.isWide ? 17 : 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: layout.isWide ? 52 : 48)
                                .background(
                                    Capsule()
                                        .fill(Color.white)
                                        .shadow(color: Color.white.opacity(0.15), radius: 8)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled((totalSecs == 0 && generalEnabled) || generalErr != nil)
                        .opacity(((totalSecs == 0 && generalEnabled) || generalErr != nil) ? 0.4 : 1.0)
                    }
                    .padding(layout.isWide ? 24 : 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(white: 0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(Color(white: 0.15), lineWidth: 0.5)
                            )
                    )
                    .frame(maxWidth: layout.secondaryMaxWidth)

                }
                .padding(.horizontal, layout.hPad)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            loadGeneralPeriodState(generalPeriod)
        }
        .onChange(of: generalPeriod) { _, newPeriod in
            loadGeneralPeriodState(newPeriod)
        }
    }

    // MARK: - 3. WORK AREA GOALS VIEW (Çalışma Bazlı Hedefler)

    private func workAreaGoalsView(layout: YonderLayout) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentScreen = .hub
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text(appLanguage == "tr" ? "Hedefler" : "Goals")
                            .font(.system(size: 14, design: .rounded))
                    }
                    .foregroundStyle(Color(white: 0.7))
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 5) {
                    Text(appLanguage == "tr" ? "Çalışma Hedefleri" : "Work Area Goals")
                        .font(.system(size: layout.isWide ? 18 : 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.9))

                    proBadge
                }

                Spacer()

                Color.clear.frame(width: 70, height: 20)
            }
            .padding(.horizontal, layout.hPad)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: layout.isWide ? 26 : 20) {

                    // Subtitle Header
                    VStack(spacing: 6) {
                        Text(appLanguage == "tr" ? "Çalışma Bazlı Hedefler" : "Work Area Goals")
                            .font(.system(size: layout.isWide ? 26 : 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(white: 0.95))

                        Text(appLanguage == "tr"
                             ? "Çalışmalarına ayrı ayrı sürekli veya döneme özel hedefler koy."
                             : "Set recurring or period-specific target durations for your work areas.")
                            .font(.system(size: layout.isWide ? 15 : 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.50))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    if activeSubjects.isEmpty {
                        // Empty State Card: No work areas created yet
                        emptyWorkAreasCard(layout: layout)
                    } else {
                        // List of existing subjects (Strictly NO textfield to write new ones)
                        VStack(spacing: 14) {
                            ForEach(activeSubjects, id: \.id) { subject in
                                workAreaSubjectCard(subject: subject, layout: layout)
                            }
                        }
                        .frame(maxWidth: layout.secondaryMaxWidth)
                    }

                }
                .padding(.horizontal, layout.hPad)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Work Area Subject Card Item

    private func workAreaSubjectCard(subject: Subject, layout: YonderLayout) -> some View {
        let activeGoals = goalStore.allGoalsForWorkArea(subject.name)
        let primaryGoal = activeGoals.first(where: { $0.isEnabled }) ?? activeGoals.first
        let isLocked = WorkItemLimits.isSubjectLocked(subject, allSubjects: activeSubjects, isPremiumUser: isPremiumUser)

        return Button {
            if isLocked {
                HapticService.warning()
                showPaywallSheet = true
            } else {
                selectedSubjectForEditing = subject
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(isLocked ? Color(red: 0.95, green: 0.78, blue: 0.35) : workAccentColor(for: subject.name))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(subject.name)
                            .font(.system(size: layout.isWide ? 17 : 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(isLocked ? Color(white: 0.65) : Color(white: 0.95))

                        if isLocked {
                            Text("PRO")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(red: 0.95, green: 0.78, blue: 0.35)))
                        }
                    }

                    if isLocked {
                        Text(appLanguage == "tr" ? "PRO ile tekrar aktif olur" : "Unlocks with PRO")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35))
                    } else if let goal = primaryGoal {
                        let periodTitle = goal.period.title(lang: appLanguage).lowercased()
                        let modeTitle = goal.mode.label(period: goal.period, lang: appLanguage)
                        Text("\(formatDuration(goal.targetSeconds)) / \(periodTitle) (\(modeTitle))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.50))
                            .monospacedDigit()
                    } else {
                        Text(appLanguage == "tr" ? "Hedef belirlenmedi" : "No goal set")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(white: 0.35))
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(isLocked ? (appLanguage == "tr" ? "Kilitli" : "Locked") : (primaryGoal != nil ? (appLanguage == "tr" ? "Düzenle" : "Edit") : (appLanguage == "tr" ? "Hedef Belirle" : "Set Goal")))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))

                    Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isLocked ? Color(red: 0.95, green: 0.78, blue: 0.35) : Color(white: 0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isLocked ? Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.12) : Color(white: 0.10))
                        .overlay(Capsule().strokeBorder(isLocked ? Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.3) : Color(white: 0.18), lineWidth: 0.5))
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(layout.isWide ? 18 : 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(white: 0.12), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func emptyWorkAreasCard(layout: YonderLayout) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 56, height: 56)

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Color(white: 0.60))
            }

            VStack(spacing: 6) {
                Text(appLanguage == "tr" ? "Henüz Çalışma Eklemedin" : "No Work Areas Added Yet")
                    .font(.system(size: layout.isWide ? 18 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.95))

                Text(appLanguage == "tr"
                     ? "Çalışma bazlı hedef koyabilmek için önce 'Çalışmalarım' ekranından bir çalışma eklemelisin."
                     : "To set work area goals, first add a work area from the 'My Work Areas' screen.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color(white: 0.50))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }

            Button {
                showWorkItemManagementSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text(appLanguage == "tr" ? "Çalışmalarım'a Git" : "Go to My Work Areas")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(layout.isWide ? 28 : 20)
        .frame(maxWidth: layout.secondaryMaxWidth)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color(white: 0.12), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Component Helpers

    private var proBadge: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.15))
                    .overlay(Capsule().strokeBorder(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.3), lineWidth: 0.5))
            )
    }

    private func periodSegmentControl(selection: Binding<WorkGoalPeriod>) -> some View {
        HStack(spacing: 4) {
            ForEach(WorkGoalPeriod.allCases) { period in
                let isSelected = selection.wrappedValue == period
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection.wrappedValue = period
                    }
                } label: {
                    Text(period.title(lang: appLanguage))
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.black : Color(white: 0.50))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(white: 0.08))
                .overlay(Capsule().strokeBorder(Color(white: 0.14), lineWidth: 0.5))
        )
    }

    private func pickerColumn(title: String, selection: Binding<Int>, range: [Int]) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.45))
                .textCase(.uppercase)

            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { val in
                    Text("\(val)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .tag(val)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .clipped()
            .compositingGroup()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.09)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(white: 0.16), lineWidth: 0.5)))
        }
    }

    private struct PresetItem: Identifiable {
        let id = UUID()
        let minutes: Int
        let labelTR: String
        let labelEN: String
    }

    private func presets(for period: WorkGoalPeriod) -> [PresetItem] {
        switch period {
        case .daily:
            return [
                PresetItem(minutes: 30, labelTR: "30 dk", labelEN: "30m"),
                PresetItem(minutes: 60, labelTR: "1 sa", labelEN: "1h"),
                PresetItem(minutes: 120, labelTR: "2 sa", labelEN: "2h"),
                PresetItem(minutes: 180, labelTR: "3 sa", labelEN: "3h")
            ]
        case .weekly:
            return [
                PresetItem(minutes: 300, labelTR: "5 sa", labelEN: "5h"),
                PresetItem(minutes: 600, labelTR: "10 sa", labelEN: "10h"),
                PresetItem(minutes: 900, labelTR: "15 sa", labelEN: "15h"),
                PresetItem(minutes: 1200, labelTR: "20 sa", labelEN: "20h")
            ]
        case .monthly:
            return [
                PresetItem(minutes: 1200, labelTR: "20 sa", labelEN: "20h"),
                PresetItem(minutes: 2400, labelTR: "40 sa", labelEN: "40h"),
                PresetItem(minutes: 3600, labelTR: "60 sa", labelEN: "60h"),
                PresetItem(minutes: 4800, labelTR: "80 sa", labelEN: "80h")
            ]
        }
    }

    private func maxHours(for p: WorkGoalPeriod) -> Int {
        switch p {
        case .daily: return 12
        case .weekly: return 80
        case .monthly: return 300
        }
    }

    private func loadGeneralPeriodState(_ p: WorkGoalPeriod) {
        if let g = goalStore.totalGoal(for: p, mode: generalMode) {
            generalHours = g.targetSeconds / 3600
            generalMinutes = (g.targetSeconds % 3600) / 60
            generalEnabled = g.isEnabled
        } else {
            generalHours = defaultHours(for: p)
            generalMinutes = 0
            generalEnabled = true
        }
    }

    private func defaultHours(for p: WorkGoalPeriod) -> Int {
        switch p {
        case .daily: return 1
        case .weekly: return 10
        case .monthly: return 40
        }
    }

    private func modeExplanation(period: WorkGoalPeriod, mode: WorkGoalMode) -> String {
        switch (mode, period) {
        case (.recurring, .daily):
            return appLanguage == "tr"
                ? "Bu hedef her gün otomatik yeniden başlar."
                : "This goal repeats automatically every day."
        case (.recurring, .weekly):
            return appLanguage == "tr"
                ? "Bu hedef her hafta otomatik yeniden başlar."
                : "This goal repeats automatically every week."
        case (.recurring, .monthly):
            return appLanguage == "tr"
                ? "Bu hedef her ay otomatik yeniden başlar."
                : "This goal repeats automatically every month."
        case (.periodSpecific, .daily):
            return appLanguage == "tr"
                ? "Bu hedef yalnızca bugün için geçerlidir; yarın tekrar etmez."
                : "This goal applies only to today and will not repeat tomorrow."
        case (.periodSpecific, .weekly):
            return appLanguage == "tr"
                ? "Bu hedef yalnızca bu hafta için geçerlidir; gelecek hafta tekrar etmez."
                : "This goal applies only to this week and will not repeat next week."
        case (.periodSpecific, .monthly):
            return appLanguage == "tr"
                ? "Bu hedef yalnızca bu ay için geçerlidir; gelecek ay tekrar etmez."
                : "This goal applies only to this month and will not repeat next month."
        }
    }

    private func saveGeneralGoal() {
        if !isPremiumUser {
            retryGeneralGoalSaveAfterUnlock = true
            showPaywallSheet = true
            return
        }
        let secs = (generalHours * 3600) + (generalMinutes * 60)
        goalStore.setTotalGoal(period: generalPeriod, mode: generalMode, seconds: secs, enabled: generalEnabled)
        HapticService.success()
        showToast(appLanguage == "tr" ? "Genel hedef kaydedildi" : "General goal saved")
    }

    private func showToast(_ msg: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.25)) {
                toastMessage = nil
            }
        }
    }

    private func workAccentColor(for name: String) -> Color {
        WorkItemColorPalette.color(for: name)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        if appLanguage == "tr" {
            if hrs > 0 && mins > 0 { return "\(hrs) sa \(mins) dk" }
            if hrs > 0 { return "\(hrs) sa" }
            return "\(mins) dk"
        } else {
            if hrs > 0 && mins > 0 { return "\(hrs)h \(mins)m" }
            if hrs > 0 { return "\(hrs)h" }
            return "\(mins)m"
        }
    }
}

// MARK: - 4. WORK AREA GOAL DETAIL SHEET (Çalışma Hedefi Düzenleme Sheet)

struct WorkAreaGoalDetailSheet: View {

    let subject: Subject
    let sessions: [FocusSession]
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var goalStore = WorkGoalStore.shared

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false

    @State private var period: WorkGoalPeriod = .weekly
    @State private var mode: WorkGoalMode = .recurring
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var isEnabled: Bool = true
    @State private var showPaywall: Bool = false

    private var currentSecs: Int {
        (hours * 3600) + (minutes * 60)
    }

    private var existingGoal: WorkGoal? {
        goalStore.goal(forWorkArea: subject.name, period: period, mode: mode)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {

                // Sheet Top Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appLanguage == "tr" ? "\(subject.name) Hedefi" : "\(subject.name) Goal")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(white: 0.95))

                        Text(appLanguage == "tr" ? "Çalışma hedefini özelleştir." : "Customize work goal.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(white: 0.45))
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                }

                // Period Segment
                HStack(spacing: 4) {
                    ForEach(WorkGoalPeriod.allCases) { p in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                period = p
                                loadGoalForPeriod(p)
                            }
                        } label: {
                            Text(p.title(lang: appLanguage))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(period == p ? Color.black : Color(white: 0.55))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(period == p ? Color.white : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Capsule().fill(Color(white: 0.09)).overlay(Capsule().strokeBorder(Color(white: 0.16), lineWidth: 0.5)))

                // Mode Segment ("Her gün / Sadece bugün")
                HStack(spacing: 4) {
                    ForEach(WorkGoalMode.allCases) { m in
                        let isSelected = mode == m
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = m
                                loadGoalForPeriod(period)
                            }
                        } label: {
                            Text(m.label(period: period, lang: appLanguage))
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(isSelected ? Color.black : Color(white: 0.55))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(isSelected ? Color.white : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Capsule().fill(Color(white: 0.08)).overlay(Capsule().strokeBorder(Color(white: 0.14), lineWidth: 0.5)))

                Text(modeExplanation(period: period, mode: mode))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .multilineTextAlignment(.center)

                // Active Toggle
                Toggle(isOn: $isEnabled) {
                    Text(appLanguage == "tr" ? "Bu hedef aktif" : "This goal is active")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.90))
                }
                .tint(Color.white)

                Divider().background(Color(white: 0.14))

                // Duration Display
                VStack(spacing: 4) {
                    Text(appLanguage == "tr" ? "HEDEF SÜRE" : "TARGET DURATION")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.40))
                        .tracking(1.0)

                    Text(currentSecs > 0 ? formatDuration(currentSecs) : (appLanguage == "tr" ? "Hedef Yok" : "No Target"))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(currentSecs > 0 ? Color(white: 0.95) : Color(white: 0.35))
                        .monospacedDigit()
                }

                // Hours + Minutes Pickers
                HStack(spacing: 12) {
                    pickerColumn(title: appLanguage == "tr" ? "Saat" : "Hours", selection: $hours, range: Array(0...maxHours(for: period)))
                    pickerColumn(title: appLanguage == "tr" ? "Dakika" : "Minutes", selection: $minutes, range: Array(stride(from: 0, through: 55, by: 5)))
                }
                .opacity(isEnabled ? 1.0 : 0.4)
                .disabled(!isEnabled)

                let workAreaErr = goalStore.validateGoal(
                    scope: .workArea,
                    workAreaName: subject.name,
                    period: period,
                    mode: mode,
                    targetSeconds: currentSecs,
                    isEnabled: isEnabled,
                    lang: appLanguage
                )

                if let err = workAreaErr {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.45))
                        Text(err)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.45))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.95, green: 0.72, blue: 0.45).opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(red: 0.95, green: 0.72, blue: 0.45).opacity(0.3), lineWidth: 0.5))
                    )
                }

                // Save Goal Button
                Button {
                    if workAreaErr == nil {
                        saveGoal()
                    }
                } label: {
                    Text(appLanguage == "tr" ? "Hedefi Kaydet" : "Save Goal")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
                .disabled((currentSecs == 0 && isEnabled) || workAreaErr != nil)
                .opacity(((currentSecs == 0 && isEnabled) || workAreaErr != nil) ? 0.4 : 1.0)

                // Delete / Remove Goal Action if existing
                if existingGoal != nil {
                    Button {
                        if let g = existingGoal {
                            goalStore.removeGoal(id: g.id)
                            HapticService.light()
                            onSave(appLanguage == "tr" ? "\(subject.name) hedefi kaldırıldı" : "\(subject.name) goal removed")
                            dismiss()
                        }
                    } label: {
                        Text(appLanguage == "tr" ? "Hedefi Sil" : "Delete Goal")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            loadGoalForPeriod(period)
        }
        .sheet(isPresented: $showPaywall) {
            YonderPaywallSheetView(onUnlockPremium: {
                isPremiumUser = true
                showPaywall = false
                saveGoal()
            })
        }
        .preferredColorScheme(.dark)
    }

    private func pickerColumn(title: String, selection: Binding<Int>, range: [Int]) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.45))
                .textCase(.uppercase)

            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { val in
                    Text("\(val)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .tag(val)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .clipped()
            .compositingGroup()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.09)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(white: 0.16), lineWidth: 0.5)))
        }
    }

    private func loadGoalForPeriod(_ p: WorkGoalPeriod) {
        if let g = goalStore.goal(forWorkArea: subject.name, period: p, mode: mode) {
            hours = g.targetSeconds / 3600
            minutes = (g.targetSeconds % 3600) / 60
            isEnabled = g.isEnabled
        } else {
            hours = 0
            minutes = 30
            isEnabled = true
        }
    }

    private func saveGoal() {
        if !isPremiumUser {
            showPaywall = true
            return
        }
        let secs = (hours * 3600) + (minutes * 60)
        goalStore.setWorkAreaGoal(name: subject.name, period: period, mode: mode, seconds: secs, enabled: isEnabled)
        HapticService.success()
        onSave(appLanguage == "tr" ? "\(subject.name) hedefi kaydedildi" : "\(subject.name) goal saved")
        dismiss()
    }

    private func maxHours(for p: WorkGoalPeriod) -> Int {
        switch p {
        case .daily: return 12
        case .weekly: return 80
        case .monthly: return 300
        }
    }

    private func modeExplanation(period: WorkGoalPeriod, mode: WorkGoalMode) -> String {
        switch (mode, period) {
        case (.recurring, .daily):
            return appLanguage == "tr"
                ? "Bu hedef her gün otomatik yeniden başlar."
                : "This goal repeats automatically every day."
        case (.recurring, .weekly):
            return appLanguage == "tr"
                ? "Bu hedef her hafta otomatik yeniden başlar."
                : "This goal repeats automatically every week."
        case (.recurring, .monthly):
            return appLanguage == "tr"
                ? "Bu hedef her ay otomatik yeniden başlar."
                : "This goal repeats automatically every month."
        case (.periodSpecific, .daily):
            return appLanguage == "tr"
                ? "Bu hedef yalnızca bugün için geçerlidir; yarın tekrar etmez."
                : "This goal applies only to today and will not repeat tomorrow."
        case (.periodSpecific, .weekly):
            return appLanguage == "tr"
                ? "Bu hedef yalnızca bu hafta için geçerlidir; gelecek hafta tekrar etmez."
                : "This goal applies only to this week and will not repeat next week."
        case (.periodSpecific, .monthly):
            return appLanguage == "tr"
                ? "Bu hedef yalnızca bu ay için geçerlidir; gelecek ay tekrar etmez."
                : "This goal applies only to this month and will not repeat next month."
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        if appLanguage == "tr" {
            if hrs > 0 && mins > 0 { return "\(hrs) sa \(mins) dk" }
            if hrs > 0 { return "\(hrs) sa" }
            return "\(mins) dk"
        } else {
            if hrs > 0 && mins > 0 { return "\(hrs)h \(mins)m" }
            if hrs > 0 { return "\(hrs)h" }
            return "\(mins)m"
        }
    }
}



// MARK: - Preview

#Preview {
    FocusGoalsView()
}
