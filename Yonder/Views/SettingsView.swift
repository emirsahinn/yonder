//
//  SettingsView.swift
//  Yonder
//

import SwiftUI
import SwiftData

/// Settings view matching Fliqlo minimalist dark design.
struct SettingsView: View {

    @AppStorage("app_language") private var selectedLanguage: String = "en"
    @AppStorage("show_clock_seconds") private var showClockSeconds: Bool = true
    @AppStorage("use_24_hour_clock") private var use24HourClock: Bool = true
    @AppStorage("weekly_focus_intention_seconds") private var weeklyFocusIntentionSeconds: Int = 0
    @AppStorage("daily_focus_goal_seconds") private var dailyFocusGoalSeconds: Int = 0
    @AppStorage("weekly_focus_goal_seconds") private var weeklyFocusGoalSeconds: Int = 0
    @AppStorage("monthly_focus_goal_seconds") private var monthlyFocusGoalSeconds: Int = 0
    @AppStorage("timer_clock_style") private var timerClockStyleRaw: String = "flip"
    @AppStorage("daily_focus_goal_enabled") private var dailyFocusGoalEnabled: Bool = true
    @AppStorage("weekly_focus_goal_enabled") private var weeklyFocusGoalEnabled: Bool = true
    @AppStorage("monthly_focus_goal_enabled") private var monthlyFocusGoalEnabled: Bool = true
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false
    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workGoalStore: WorkGoalStore
    @State private var remindersEnabled: Bool = true
    @State private var showReminders: Bool = false
    @State private var showWorkItemManagement: Bool = false
    @State private var showSignOutConfirmation: Bool = false
    @State private var showSignInView: Bool = false
    @State private var showProfileEditSheet: Bool = false
    @State private var showFocusGoals: Bool = false
    @State private var showClockStyleSelection: Bool = false // v1: unused, clock style UI hidden
    @State private var showLocalDataMergeConfirmation: Bool = false
    @State private var showProPaywall: Bool = false
    @StateObject private var proStore = ProStore.shared
    @State private var showFirstDeletionConfirmation: Bool = false
    @State private var showSecondDeletionSheet: Bool = false
    @State private var isDeletingAccount: Bool = false
    @State private var deletionErrorMessage: String? = nil
    @State private var showDeletionErrorAlert: Bool = false

    private func formatDurationShort(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        if selectedLanguage == "tr" {
            if hrs > 0 && mins > 0 { return "\(hrs) sa \(mins) dk" }
            if hrs > 0 { return "\(hrs) sa" }
            return "\(mins) dk"
        } else {
            if hrs > 0 && mins > 0 { return "\(hrs)h \(mins)m" }
            if hrs > 0 { return "\(hrs)h" }
            return "\(mins)m"
        }
    }

    private var goalsSummaryText: String {
        var parts: [String] = []

        if dailyFocusGoalEnabled && dailyFocusGoalSeconds > 0 {
            let dur = formatDurationShort(dailyFocusGoalSeconds)
            parts.append(selectedLanguage == "tr" ? "Günlük \(dur)" : "Daily \(dur)")
        } else {
            parts.append(selectedLanguage == "tr" ? "Günlük hedef yok" : "No daily goal")
        }

        if weeklyFocusGoalEnabled && weeklyFocusGoalSeconds > 0 {
            let dur = formatDurationShort(weeklyFocusGoalSeconds)
            parts.append(selectedLanguage == "tr" ? "Haftalık \(dur)" : "Weekly \(dur)")
        } else {
            parts.append(selectedLanguage == "tr" ? "Haftalık hedef yok" : "No weekly goal")
        }

        if monthlyFocusGoalEnabled && monthlyFocusGoalSeconds > 0 {
            let dur = formatDurationShort(monthlyFocusGoalSeconds)
            parts.append(selectedLanguage == "tr" ? "Aylık \(dur)" : "Monthly \(dur)")
        } else {
            parts.append(selectedLanguage == "tr" ? "Aylık hedef yok" : "No monthly goal")
        }

        return parts.joined(separator: " · ")
    }


    @Query private var allSessions: [FocusSession]
    @Query private var savedSubjects: [Subject]

    @Environment(\.horizontalSizeClass) private var hSizeClass

    init() {}

    private var isIPad: Bool { hSizeClass == .regular }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var hasLocalDeviceData: Bool {
        !allSessions.isEmpty || !savedSubjects.isEmpty || !workGoalStore.goals.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
                Text(selectedLanguage == "tr" ? "AYARLAR" : "SETTINGS")
                    .font(.system(size: isIPad ? 28 : 20, weight: .light, design: .rounded))
                    .foregroundStyle(Color(white: 0.6))
                    .tracking(6)
                    .textCase(.uppercase)
                    .padding(.top, isIPad ? 32 : 20)
                    .padding(.bottom, isIPad ? 24 : 16)

                ScrollView {
                    VStack(spacing: isIPad ? 24 : 18) {
                        // ── 1. Profil ───────────────────────────────────
                        settingsSection(title: selectedLanguage == "tr" ? "PROFİL" : "PROFILE") {
                            SettingsProfileSection(
                                authService: authService,
                                selectedLanguage: selectedLanguage,
                                isIPad: isIPad,
                                onEditProfile: {
                                    showProfileEditSheet = true
                                }
                            )
                        }

                        // ── 2. Yonder PRO ─────────────────────────────
                        settingsSection(title: "YONDER PRO") {
                            Button {
                                if proStore.hasPro {
                                    Task {
                                        await proStore.showManageSubscriptions()
                                    }
                                } else {
                                    showProPaywall = true
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.12))
                                            .frame(width: 38, height: 38)

                                        Image(systemName: proStore.hasPro ? "sparkles" : "lock.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(proStore.hasPro ? (selectedLanguage == "tr" ? "PRO aktif" : "PRO active") : (selectedLanguage == "tr" ? "Yonder PRO'yu Aç" : "Unlock Yonder PRO"))
                                            .font(.system(size: isIPad ? 16 : 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color(white: 0.90))

                                        Text(proStore.hasPro
                                             ? (selectedLanguage == "tr" ? "Apple hesabındaki aboneliği yönet." : "Manage the subscription on your Apple account.")
                                             : (selectedLanguage == "tr" ? "Sınırsız çalışma alanı ve hedefler." : "Unlimited work areas and goals."))
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(Color(white: 0.45))
                                    }

                                    Spacer()

                                    if proStore.hasPro {
                                        HStack(spacing: 6) {
                                            Text("PRO")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundStyle(.black)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(Color(red: 0.95, green: 0.78, blue: 0.35)))

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color(white: 0.4))
                                        }
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(white: 0.4))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        // ── 3. Çalışma Alanı ───────────────────────────
                        settingsSection(title: selectedLanguage == "tr" ? "ÇALIŞMA ALANI" : "WORKSPACE") {
                            VStack(spacing: 14) {
                                // Dil / Language
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(selectedLanguage == "tr" ? "Dil" : "Language")
                                            .font(.system(size: isIPad ? 16 : 14, weight: .regular, design: .rounded))
                                            .foregroundStyle(Color(white: 0.85))
                                    }

                                    Spacer()

                                    Picker("Language", selection: $selectedLanguage) {
                                        Text("English").tag("en")
                                        Text("Türkçe").tag("tr")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: isIPad ? 200 : 160)
                                    .onChange(of: selectedLanguage) { _, newLang in
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            LanguageService.shared.applyLanguage(newLang)
                                        }
                                    }
                                }

                                Divider().background(Color(white: 0.14))

                                // Çalışmalarım / Work Areas
                                Button {
                                    showWorkItemManagement = true
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(selectedLanguage == "tr" ? "Çalışmalarım" : "My Work Areas")
                                                .font(.system(size: isIPad ? 16 : 14, weight: .regular, design: .rounded))
                                                .foregroundStyle(Color(white: 0.85))

                                            Text(selectedLanguage == "tr" ? "Kayıtlı çalışma alanları ve hedefler" : "Manage work areas and focus targets")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(Color(white: 0.45))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(white: 0.4))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Divider().background(Color(white: 0.14))

                                // Hedefler / Work Goals (PRO)
                                Button {
                                    showFocusGoals = true
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(selectedLanguage == "tr" ? "Hedefler" : "Goals")
                                                    .font(.system(size: isIPad ? 16 : 14, weight: .medium, design: .rounded))
                                                    .foregroundStyle(Color(white: 0.90))

                                                // Premium Badge
                                                HStack(spacing: 3) {
                                                    Image(systemName: "sparkles")
                                                        .font(.system(size: 8, weight: .bold))
                                                    Text("PRO")
                                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                                }
                                                .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.12))
                                                        .overlay(
                                                            Capsule()
                                                                .strokeBorder(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.35), lineWidth: 0.5)
                                                        )
                                                )
                                            }

                                            Text(selectedLanguage == "tr" ? "Günlük, haftalık ve aylık çalışma hedeflerini planla." : "Plan your daily, weekly, and monthly work goals.")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(Color(white: 0.45))

                                            Text(goalsSummaryText)
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color(white: 0.60))
                                                .padding(.top, 1)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(white: 0.4))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Divider().background(Color(white: 0.14))

                                // Saat Formatı / Time Format
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(selectedLanguage == "tr" ? "Saat Formatı" : "Time Format")
                                            .font(.system(size: isIPad ? 16 : 14, weight: .regular, design: .rounded))
                                            .foregroundStyle(Color(white: 0.85))

                                        Text(selectedLanguage == "tr" ? "Saat ekranında 24 saat veya AM/PM kullan." : "Use 24-hour time or AM/PM on clock screens.")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(Color(white: 0.45))
                                    }

                                    Spacer()

                                    Picker("Time Format", selection: $use24HourClock) {
                                        Text("24h").tag(true)
                                        Text("AM/PM").tag(false)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: isIPad ? 180 : 144)
                                }

                                Divider().background(Color(white: 0.14))

                                // Saat Saniyeleri / Clock Seconds
                                Toggle(isOn: $showClockSeconds) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(selectedLanguage == "tr" ? "Saat Saniyeleri" : "Clock Seconds")
                                            .font(.system(size: isIPad ? 16 : 14, weight: .regular, design: .rounded))
                                            .foregroundStyle(Color(white: 0.85))

                                        Text(selectedLanguage == "tr" ? "Tam ekran saatinde saniyeleri göster" : "Show seconds in full-screen clock")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(Color(white: 0.45))
                                    }
                                }
                                .tint(.white)

                            }
                        }

                        // ── 4. Hatırlatıcılar ───────────────────────────
                        settingsSection(title: selectedLanguage == "tr" ? "HATIRLATICILAR" : "REMINDERS") {
                            Button {
                                showReminders = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.badge")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(white: 0.7))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(selectedLanguage == "tr" ? "Çalışma Hatırlatıcıları" : "Focus Reminders")
                                            .font(.system(size: isIPad ? 16 : 14, weight: .regular, design: .rounded))
                                            .foregroundStyle(Color(white: 0.85))

                                        Text(selectedLanguage == "tr" ? "Ritmini korumak için bildirimler" : "Notifications to maintain your rhythm")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(Color(white: 0.45))
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(white: 0.4))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        // ── 5. Hesap ve Sync ───────────────────────────
                        settingsSection(title: selectedLanguage == "tr" ? "HESAP VE SYNC" : "ACCOUNT & SYNC") {
                            if authService.isCloudAccountLinked {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(white: 0.14))
                                                .frame(width: 34, height: 34)
                                            if authService.isAppleLinked && !authService.isGoogleLinked {
                                                Image(systemName: "applelogo")
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(Color.white.opacity(0.86))
                                            } else {
                                                Text("G")
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(selectedLanguage == "tr" ? "\(authService.linkedProviderName) hesabı bağlı" : "\(authService.linkedProviderName) account connected")
                                                .font(.system(size: isIPad ? 12 : 11, design: .rounded))
                                                .foregroundStyle(Color(white: 0.4))
                                                .textCase(.uppercase)
                                                .tracking(1)

                                            Text(authService.linkedAccountEmail ?? "")
                                                .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color(white: 0.85))
                                        }

                                        Spacer()

                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color(white: 0.35))
                                    }

                                    Divider().background(Color(white: 0.15))

                                    Button {
                                        showSignOutConfirmation = true
                                    } label: {
                                        HStack {
                                            Text(selectedLanguage == "tr" ? "Çıkış yap" : "Sign out")
                                                .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                                                .foregroundStyle(.red)
                                            Spacer()
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.system(size: 13))
                                                .foregroundStyle(.red.opacity(0.8))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Button {
                                    showSignInView = true
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(white: 0.14))
                                                .frame(width: 34, height: 34)
                                            Text("G")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(Color(white: 0.5))
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(selectedLanguage == "tr" ? "Ritmini cihazlar arasında sakla" : "Keep your rhythm across devices")
                                                .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color(white: 0.85))
                                            Text(selectedLanguage == "tr" ? "Geçmişini sakla ve online odalara katıl" : "Keep your history and join online rooms")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(Color(white: 0.38))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(white: 0.3))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // ── 6. Tehlikeli Alan ───────────────────────────
                        if authService.isCloudAccountLinked {
                            settingsSection(title: selectedLanguage == "tr" ? "TEHLİKELİ ALAN" : "DANGER ZONE") {
                                Button {
                                    showFirstDeletionConfirmation = true
                                } label: {
                                    HStack {
                                        Text(selectedLanguage == "tr" ? "Hesabımı ve Verilerimi Sil" : "Delete My Account and Data")
                                            .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35))
                                        Spacer()
                                        Image(systemName: "trash")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35).opacity(0.8))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // ── 6. Hakkında ─────────────────────────────────
                        settingsSection(title: selectedLanguage == "tr" ? "HAKKINDA" : "ABOUT") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Yonder")
                                        .font(.system(size: isIPad ? 17 : 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Spacer()

                                    HStack(spacing: 4) {
                                        Text(selectedLanguage == "tr" ? "Sürüm" : "Version")
                                        Text(appVersion)
                                    }
                                    .font(.system(size: isIPad ? 14 : 12, design: .rounded))
                                    .foregroundStyle(Color(white: 0.45))
                                }

                                Divider().background(Color(white: 0.15))

                                Text(selectedLanguage == "tr"
                                     ? "Yonder; odak oturumlarını, çalışmalarını ve hedeflerini sade bir yerde toplar. Zamanla nasıl çalıştığını görmen ve kendi düzenini daha net kurman için tasarlandı."
                                     : "Yonder brings your focus sessions, work areas, and goals into one calm place. It is designed to help you understand how you work and build a clearer routine over time.")
                                    .font(.system(size: isIPad ? 14 : 12, design: .rounded))
                                    .foregroundStyle(Color(white: 0.5))
                                    .lineSpacing(3)
                            }
                        }
                    }
                    .frame(maxWidth: isIPad ? 680 : .infinity)
                    .padding(.horizontal, isIPad ? 60 : 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showProfileEditSheet) {
            ProfileEditSheet()
        }
        .sheet(isPresented: $showProPaywall) {
            YonderPaywallSheetView(onUnlockPremium: {
                isPremiumUser = true
                showProPaywall = false
            })
        }
        .sheet(isPresented: $showReminders) {
            RemindersView()
        }
        .sheet(isPresented: $showWorkItemManagement) {
            WorkItemManagementView()
        }
        .sheet(isPresented: $showFocusGoals) {
            FocusGoalsView()
        }
        .sheet(isPresented: $showSignInView) {
            SignInView(
                onSignedIn: {
                    showSignInView = false
                    if hasLocalDeviceData {
                        showLocalDataMergeConfirmation = true
                    } else {
                        triggerGoogleSync(uploadLocalChanges: true)
                    }
                },
                onSkip: {
                    showSignInView = false
                }
            )
        }
        .confirmationDialog(
            Text(selectedLanguage == "tr" ? "Çıkış yapmak istediğine emin misin?" : "Are you sure you want to sign out?"),
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                AuthService.shared.signOut()
            } label: {
                Text(selectedLanguage == "tr" ? "Çıkış yap" : "Sign out")
            }
            Button(role: .cancel) {} label: {
                Text(selectedLanguage == "tr" ? "Vazgeç" : "Cancel")
            }
        }
        .confirmationDialog(
            Text(selectedLanguage == "tr"
                 ? "Bu cihazdaki veriler hesabına eklensin mi?"
                 : "Add this device's data to your account?"),
            isPresented: $showLocalDataMergeConfirmation,
            titleVisibility: .visible
        ) {
            Button {
                triggerGoogleSync(uploadLocalChanges: true)
            } label: {
                Text(selectedLanguage == "tr" ? "Ekle ve senkronize et" : "Add and sync")
            }

            Button(role: .destructive) {
                triggerGoogleSync(uploadLocalChanges: false)
            } label: {
                Text(selectedLanguage == "tr" ? "Ekleme, sadece hesabımı kullan" : "Do not add, use account only")
            }

            Button(role: .cancel) {} label: {
                Text(selectedLanguage == "tr" ? "Şimdilik vazgeç" : "Not now")
            }
        } message: {
            Text(selectedLanguage == "tr"
                 ? "Eklersen bu cihazdaki çalışmalar, oturumlar ve hedefler bağlı hesabına taşınır ve diğer cihazlarında görünür."
                 : "If you add them, this device's work areas, sessions, and goals move to your connected account and appear on your other devices.")
        }
        .confirmationDialog(
            Text(selectedLanguage == "tr" ? "Hesabını silmek istediğine emin misin?" : "Are you sure you want to delete your account?"),
            isPresented: $showFirstDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                showSecondDeletionSheet = true
            } label: {
                Text(selectedLanguage == "tr" ? "Devam Et" : "Continue")
            }
            Button(role: .cancel) {} label: {
                Text(selectedLanguage == "tr" ? "Vazgeç" : "Cancel")
            }
        } message: {
            Text(selectedLanguage == "tr"
                 ? "Bu işlem bağlı hesabını, buluttaki oturumlarını, çalışmalarını, hedeflerini ve oda verilerini siler. Bu işlem geri alınamaz."
                 : "This deletes your connected account, cloud sessions, work areas, goals, and room data. This cannot be undone.")
        }
        .sheet(isPresented: $showSecondDeletionSheet) {
            AccountDeletionSheetView(
                lang: selectedLanguage,
                isIPad: isIPad,
                onConfirm: {
                    showSecondDeletionSheet = false
                    executeAccountDeletion()
                },
                onCancel: {
                    showSecondDeletionSheet = false
                }
            )
        }
        .alert(
            selectedLanguage == "tr" ? "Hesap Silinemedi" : "Account Deletion Failed",
            isPresented: $showDeletionErrorAlert,
            actions: {
                Button(selectedLanguage == "tr" ? "Tamam" : "OK", role: .cancel) {}
            },
            message: {
                Text(deletionErrorMessage ?? "")
            }
        )
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)

                        Text(selectedLanguage == "tr" ? "Verilerin siliniyor" : "Deleting your data")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.85))
                    }
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.12))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(white: 0.2), lineWidth: 0.5))
                    )
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func executeAccountDeletion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isDeletingAccount = true
        }

        Task {
            do {
                try await AccountDeletionService.shared.deleteCurrentAccountAndData(
                    modelContext: modelContext,
                    workGoalStore: workGoalStore
                )
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDeletingAccount = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDeletingAccount = false
                        deletionErrorMessage = error.localizedDescription
                        showDeletionErrorAlert = true
                    }
                }
            }
        }
    }


    private func triggerGoogleSync(uploadLocalChanges: Bool) {
        Task {
            await SyncCoordinator.shared.triggerFullSync(
                modelContext: modelContext,
                goalStore: workGoalStore,
                uploadLocalChanges: uploadLocalChanges
            )
        }
    }

    // MARK: - Helper Section Card

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: isIPad ? 13 : 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.4))
                .textCase(.uppercase)
                .tracking(2)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(isIPad ? 20 : 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Clock Style Selection

struct ClockStyleSelectionView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("timer_clock_style") private var timerClockStyleRaw: String = "flip"
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showPaywall: Bool = false

    private var isIPad: Bool { hSizeClass == .regular }

    private var selectedStyle: TimerClockStyle {
        TimerClockStyle.resolved(rawValue: timerClockStyleRaw, isPremiumUser: isPremiumUser)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                let contentWidth = min(max(geometry.size.width - horizontalPadding(for: geometry.size.width) * 2, 1), isIPad ? 860 : 520)

                ScrollView {
                    VStack(alignment: .leading, spacing: isIPad ? 22 : 18) {
                        header

                        LazyVStack(spacing: isIPad ? 18 : 14) {
                            ForEach(TimerClockStyle.allCases) { style in
                                clockStyleCard(style: style, width: contentWidth)
                            }
                        }
                    }
                    .frame(width: contentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.top, isIPad ? 28 : 22)
                    .padding(.bottom, 34)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if (TimerClockStyle(rawValue: timerClockStyleRaw) ?? .flip).isPro && !isPremiumUser {
                timerClockStyleRaw = TimerClockStyle.flip.rawValue
            }
        }
        .sheet(isPresented: $showPaywall) {
            YonderPaywallSheetView(onUnlockPremium: {
                isPremiumUser = true
                showPaywall = false
            })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appLanguage == "tr" ? "SAAT GÖRÜNÜMÜ" : "CLOCK STYLE")
                        .font(.system(size: isIPad ? 28 : 21, weight: .light, design: .rounded))
                        .foregroundStyle(Color(white: 0.72))
                        .tracking(5)

                    Text(appLanguage == "tr"
                         ? "Yonder’ın zaman ekranını kendi ritmine göre seç."
                         : "Choose the time style that matches your rhythm.")
                        .font(.system(size: isIPad ? 14 : 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.48))
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.55))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(white: 0.12))
                                .overlay(Circle().strokeBorder(Color(white: 0.22), lineWidth: 0.6))
                        )
                }
                .buttonStyle(.plain)
            }

            Text(appLanguage == "tr"
                 ? "Flip Clock ücretsizdir. Diğer görünümler Yonder PRO ile açılır."
                 : "Flip Clock is free. Other styles unlock with Yonder PRO.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.82))
        }
    }

    private func clockStyleCard(style: TimerClockStyle, width: CGFloat) -> some View {
        let isLocked = style.isPro && !isPremiumUser
        let isSelected = selectedStyle == style
        let cardHeight: CGFloat = isIPad ? 248 : 202
        let previewHeight: CGFloat = isIPad ? 136 : 106

        return Button {
            if isLocked {
                HapticService.light()
                showPaywall = true
            } else {
                HapticService.selection()
                timerClockStyleRaw = style.rawValue
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(style.localizedName(lang: appLanguage))
                                .font(.system(size: isIPad ? 17 : 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(white: 0.94))

                            if style.isPro {
                                proBadge
                            }
                        }

                        Text(style.localizedDescription(lang: appLanguage))
                            .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : (isLocked ? "lock.fill" : "circle"))
                        .font(.system(size: isIPad ? 20 : 17, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white : Color(white: 0.38))
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color(white: 0.13), lineWidth: 0.7)
                        )

                    TimerClockDisplayView(
                        style: style,
                        hours: 0,
                        minutes: 25,
                        seconds: 0,
                        showHours: false,
                        showSeconds: true,
                        isRunning: false,
                        remainingSeconds: 900,
                        totalSeconds: 1500
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .opacity(isLocked ? 0.42 : 1.0)
                }
                .frame(height: previewHeight)
            }
            .padding(isIPad ? 18 : 15)
            .frame(width: width, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? Color.white.opacity(0.55) : Color(white: 0.17), lineWidth: isSelected ? 1.1 : 0.7)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var proBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .bold))
            Text("PRO")
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.12))
                .overlay(Capsule().strokeBorder(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.36), lineWidth: 0.5))
        )
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        guard width.isFinite, width > 0 else { return 20 }
        return min(max(width * 0.06, 20), 72)
    }
}

// MARK: - Account Deletion Confirmation Sheet

struct AccountDeletionSheetView: View {
    let lang: String
    let isIPad: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var inputText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    private var requiredKeyword: String {
        lang == "tr" ? "SİL" : "DELETE"
    }

    private var isValidInput: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed == "SİL" || trimmed == "DELETE" || trimmed == requiredKeyword
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Text(lang == "tr" ? "HESAP VE VERİ SİLME" : "ACCOUNT & DATA DELETION")
                        .font(.system(size: isIPad ? 16 : 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.35))
                        .tracking(3)

                    Spacer()

                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(white: 0.55))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color(white: 0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text(lang == "tr"
                         ? "Bu işlem bağlı hesabını, buluttaki oturumlarını, çalışmalarını, hedeflerini ve oda verilerini siler. Bu işlem geri alınamaz."
                         : "This deletes your connected account, cloud sessions, work areas, goals, and room data. This cannot be undone.")
                        .font(.system(size: isIPad ? 15 : 13, design: .rounded))
                        .foregroundStyle(Color(white: 0.75))
                        .lineSpacing(3)

                    Text(lang == "tr"
                         ? "Devam etmek için aşağıdaki alana tam olarak \"\(requiredKeyword)\" yazın:"
                         : "Type \"\(requiredKeyword)\" in the box below to proceed:")
                        .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.6))
                        .padding(.top, 4)

                    TextField(
                        lang == "tr" ? "SİL yaz" : "Type DELETE",
                        text: $inputText
                    )
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(isValidInput ? Color(red: 0.95, green: 0.35, blue: 0.35) : Color(white: 0.2), lineWidth: 1)
                            )
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .focused($isTextFieldFocused)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        if isValidInput {
                            onConfirm()
                        }
                    } label: {
                        Text(lang == "tr" ? "Kalıcı Olarak Sil" : "Delete Permanently")
                            .font(.system(size: isIPad ? 16 : 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isValidInput ? Color(red: 0.85, green: 0.2, blue: 0.2) : Color(white: 0.16))
                            )
                    }
                    .disabled(!isValidInput)
                    .buttonStyle(.plain)

                    Button {
                        onCancel()
                    } label: {
                        Text(lang == "tr" ? "Vazgeç" : "Cancel")
                            .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, isIPad ? 40 : 20)
        }
        .presentationDetents([.height(isIPad ? 420 : 380)])
        .preferredColorScheme(.dark)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: FocusSession.self, inMemory: true)
}
