//
//  RemindersView.swift
//  Yonder
//

import SwiftUI
import SwiftData
import UserNotifications

/// Reminders management screen matching Yonder's calm focus philosophy.
struct RemindersView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false
    @AppStorage("weekly_recap_enabled") private var weeklyRecapEnabled: Bool = true

    @Query(sort: \FocusReminder.dateCreated, order: .reverse) private var reminders: [FocusReminder]
    @Query(sort: \Subject.name) private var savedSubjects: [Subject]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showAddSheet: Bool = false
    @State private var reminderToEdit: FocusReminder? = nil
    @State private var reminderToDelete: FocusReminder? = nil
    @State private var showNotificationSettingsPrompt: Bool = false

    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isIPad: Bool { hSizeClass == .regular }

    private var activeReminders: [FocusReminder] {
        reminders.filter { !$0.isExpired }
    }

    private var notificationsAllowed: Bool {
        Self.notificationsAllowed(authStatus)
    }

    private func performExpiredRemindersCleanup() {
        let expired = reminders.filter { $0.isExpired }
        for r in expired {
            NotificationService.shared.cancelReminder(r)
            modelContext.delete(r)
        }
        if !expired.isEmpty {
            try? modelContext.save()
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top Header Bar ─────────────────────────────────────────
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: isIPad ? 18 : 15, weight: .medium))
                            .foregroundStyle(Color(white: 0.5))
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
                .padding(.trailing, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isIPad ? 28 : 22) {

                        // ── Screen Title & Subtitle ─────────────────────────
                        VStack(spacing: 6) {
                            Text(appLanguage == "tr" ? "HATIRLATICILAR" : "REMINDERS")
                                .font(.system(size: isIPad ? 22 : 16, weight: .light, design: .rounded))
                                .foregroundStyle(Color(white: 0.5))
                                .tracking(4)
                                .textCase(.uppercase)

                            Text(appLanguage == "tr" ? "Günün içinde ritmine dön." : "Return to your rhythm during the day.")
                                .font(.system(size: isIPad ? 15 : 13, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(white: 0.45))
                        }
                        .padding(.top, 4)

                        // ── Notification Permission Warning ───────────────
                        if !notificationsAllowed {
                            permissionStatusSection
                                .padding(.horizontal, isIPad ? 60 : 20)
                        }

                        // ── Daily / Work Area Reminders Section ────────────
                        remindersListSection
                            .padding(.horizontal, isIPad ? 60 : 20)

                        // ── Weekly Recap Section ──────────────────────────
                        weeklyRecapSection
                            .padding(.horizontal, isIPad ? 60 : 20)
                    }
                    .frame(maxWidth: isIPad ? 680 : .infinity)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            checkAuthStatus()
            performExpiredRemindersCleanup()
            rescheduleAllActiveReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkAuthStatus()
            performExpiredRemindersCleanup()
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditReminderSheet(reminder: nil, savedSubjects: savedSubjects.filter { !$0.isArchived }, allReminders: activeReminders)
        }
        .sheet(item: $reminderToEdit) { reminder in
            AddEditReminderSheet(reminder: reminder, savedSubjects: savedSubjects.filter { !$0.isArchived }, allReminders: activeReminders)
        }
        .confirmationDialog(
            appLanguage == "tr" ? "Hatırlatıcıyı Sil" : "Delete Reminder",
            isPresented: Binding(
                get: { reminderToDelete != nil },
                set: { if !$0 { reminderToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(appLanguage == "tr" ? "Sil" : "Delete", role: .destructive) {
                if let r = reminderToDelete {
                    deleteReminder(r)
                }
            }
            Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {}
        } message: {
            Text(appLanguage == "tr" ? "Bu hatırlatıcı kalıcı olarak silinecek." : "This reminder will be permanently deleted.")
        }
        .confirmationDialog(
            Text(appLanguage == "tr" ? "Bildirim izni gerekli" : "Notification permission required"),
            isPresented: $showNotificationSettingsPrompt,
            titleVisibility: .visible
        ) {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(appLanguage == "tr" ? "Ayarları Aç" : "Open Settings")
            }

            Button(role: .cancel) {} label: {
                Text(appLanguage == "tr" ? "Vazgeç" : "Cancel")
            }
        } message: {
            Text(appLanguage == "tr"
                 ? "Hatırlatıcı eklemek için önce Yonder bildirimlerine izin vermelisin."
                 : "To add a reminder, first allow notifications for Yonder.")
        }
    }

    // MARK: - Auth Status Check & Notification Sync

    private static func notificationsAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private func checkAuthStatus() {
        Task {
            let status = await NotificationService.shared.checkAuthorizationStatus()
            await MainActor.run {
                self.authStatus = status
            }
        }
    }

    private func rescheduleAllActiveReminders() {
        for reminder in activeReminders {
            if reminder.isEnabled {
                NotificationService.shared.scheduleReminder(reminder, allReminders: activeReminders)
            } else {
                NotificationService.shared.cancelReminder(reminder)
            }
        }
    }

    private func beginAddReminderFlow() {
        Task {
            let allowed = await ensureNotificationPermissionForReminder()
            await MainActor.run {
                guard allowed else {
                    HapticService.warning()
                    showNotificationSettingsPrompt = authStatus != .notDetermined
                    return
                }
                showAddSheet = true
            }
        }
    }

    private func ensureNotificationPermissionForReminder() async -> Bool {
        let currentStatus = await NotificationService.shared.checkAuthorizationStatus()

        if Self.notificationsAllowed(currentStatus) {
            await MainActor.run {
                authStatus = currentStatus
            }
            return true
        }

        guard currentStatus == .notDetermined else {
            await MainActor.run {
                authStatus = currentStatus
            }
            return false
        }

        _ = await NotificationService.shared.requestAuthorization()
        let updatedStatus = await NotificationService.shared.checkAuthorizationStatus()
        await MainActor.run {
            authStatus = updatedStatus
        }
        return Self.notificationsAllowed(updatedStatus)
    }

    // MARK: - Permission Status Section

    private var permissionStatusSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(appLanguage == "tr" ? "Hatırlatıcılar için bildirim izni gerekli." : "Notifications are required for reminders.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.9))

                Text(appLanguage == "tr" ? "İzin vermezsen hatırlatıcılar gönderilemez." : "Reminders cannot be delivered without permission.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
            }

            Spacer()

            Button {
                if authStatus == .notDetermined {
                    Task {
                        _ = await NotificationService.shared.requestAuthorization()
                        checkAuthStatus()
                    }
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(authStatus == .notDetermined ? (appLanguage == "tr" ? "İzin Ver" : "Allow") : (appLanguage == "tr" ? "Ayarları Aç" : "Open Settings"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(white: 0.14), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Reminders List Section

    private var remindersListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appLanguage == "tr" ? "HATIRLATMALARIM" : "MY REMINDERS")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .tracking(2)

                Spacer()

                Button {
                    beginAddReminderFlow()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(appLanguage == "tr" ? "Hatırlatıcı Ekle" : "Add Reminder")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
            }

            if activeReminders.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 10) {
                    ForEach(activeReminders) { reminder in
                        reminderCardRow(reminder)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color(white: 0.35))
                .padding(.top, 12)

            Text(appLanguage == "tr" ? "Henüz hatırlatıcı yok." : "No reminders yet.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.75))

            Text(appLanguage == "tr" ? "Günün içinde ritmine dönmek için ilk hatırlatıcını ekle." : "Add your first reminder to return to your rhythm during the day.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color(white: 0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer()
                .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(white: 0.12), lineWidth: 0.5)
                )
        )
    }

    private func reminderCardRow(_ reminder: FocusReminder) -> some View {
        ReminderRowView(
            reminder: reminder,
            allReminders: reminders,
            isPremiumUser: isPremiumUser,
            appLanguage: appLanguage,
            repeatDaysSummaryText: repeatDaysSummary(reminder.repeatDays),
            onToggle: { newValue in
                reminder.isEnabled = newValue
                try? modelContext.save()
                if newValue {
                    NotificationService.shared.scheduleReminder(reminder, allReminders: reminders)
                } else {
                    NotificationService.shared.cancelReminder(reminder)
                }
            },
            onEdit: {
                reminderToEdit = reminder
            },
            onDelete: {
                reminderToDelete = reminder
            },
            onPaywallPrompt: {
                // v1: no paywall for reminders
            }
        )
    }

    private func repeatDaysSummary(_ days: [Int]) -> String {
        let sorted = days.sorted()
        if sorted.isEmpty {
            return appLanguage == "tr" ? "Tek seferlik" : "One-time"
        }

        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        if sorted == [todayWeekday] {
            return appLanguage == "tr" ? "Bugün" : "Today"
        }
        if Set(sorted) == Set([1, 2, 3, 4, 5, 6, 7]) {
            return appLanguage == "tr" ? "Her gün" : "Every day"
        }
        if Set(sorted) == Set([2, 3, 4, 5, 6]) {
            return appLanguage == "tr" ? "Hafta içi" : "Weekdays"
        }
        if Set(sorted) == Set([1, 7]) {
            return appLanguage == "tr" ? "Hafta sonu" : "Weekend"
        }

        let dayNamesTR = ["", "Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]
        let dayNamesEN = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        return sorted.map { idx in
            appLanguage == "tr" ? dayNamesTR[idx] : dayNamesEN[idx]
        }.joined(separator: ", ")
    }

    private func deleteReminder(_ reminder: FocusReminder) {
        NotificationService.shared.cancelReminder(reminder)
        modelContext.delete(reminder)
        try? modelContext.save()
        rescheduleAllActiveReminders()
    }

    // MARK: - Weekly Recap Section

    private var weeklyRecapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appLanguage == "tr" ? "HAFTALIK ÖZET" : "WEEKLY RECAP")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.45))
                .tracking(2)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appLanguage == "tr" ? "Haftalık Gelişim Bildirimi" : "Weekly Progress Notification")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(white: 0.9))

                        Text(appLanguage == "tr" ? "Her Pazar 20:00'de haftalık ritim özetin iletilir." : "Delivered every Sunday at 20:00 with your rhythm recap.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { weeklyRecapEnabled },
                        set: { newValue in
                            weeklyRecapEnabled = newValue
                            if newValue {
                                NotificationService.shared.scheduleWeeklyRecapNotification(weekday: 1, hour: 20, minute: 0)
                            } else {
                                NotificationService.shared.cancelWeeklyRecapNotification()
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(Color.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(white: 0.14), lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Add / Edit Reminder Sheet

struct AddEditReminderSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false

    let reminder: FocusReminder?
    let savedSubjects: [Subject]
    let allReminders: [FocusReminder]

    @State private var selectedWorkArea: String? = nil // nil means "Genel odak"
    @State private var selectedDate: Date
    @State private var selectedWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7] // Default every day
    @State private var isEnabled: Bool = true
    @State private var isOneTime: Bool = false

    @State private var showWorkItemManagement: Bool = false

    init(reminder: FocusReminder?, savedSubjects: [Subject], allReminders: [FocusReminder]) {
        self.reminder = reminder
        self.savedSubjects = savedSubjects
        self.allReminders = allReminders

        if let r = reminder {
            let initialDate = Calendar.current.date(bySettingHour: r.hour, minute: r.minute, second: 0, of: Date()) ?? Date()
            _selectedDate = State(initialValue: initialDate)
            _selectedWorkArea = State(initialValue: r.workItemName)
            _selectedWeekdays = State(initialValue: Set(r.repeatDays.isEmpty ? [Calendar.current.component(.weekday, from: Date())] : r.repeatDays))
            _isEnabled = State(initialValue: r.isEnabled)
            _isOneTime = State(initialValue: r.checkIsOneTime)
        } else {
            let defaultDate = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
            let today = Calendar.current.component(.weekday, from: Date())
            _selectedDate = State(initialValue: defaultDate)
            _selectedWorkArea = State(initialValue: nil)
            _selectedWeekdays = State(initialValue: Set([today]))
            _isEnabled = State(initialValue: true)
            _isOneTime = State(initialValue: false)
        }
    }

    private var isSaveDisabled: Bool {
        selectedWeekdays.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Text(reminder == nil ? (appLanguage == "tr" ? "Yeni Hatırlatıcı" : "New Reminder") : (appLanguage == "tr" ? "Hatırlatıcı Düzenle" : "Edit Reminder"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: 0.95))

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(white: 0.45))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {

                        // Work Area Target Picker
                        workAreaTargetPicker

                        // Time Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appLanguage == "tr" ? "SAAT" : "TIME")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(white: 0.45))
                                .tracking(1)

                            DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(height: 120)
                        }

                        // Days Selection & Presets
                        daysSelectionSection

                        // Enabled Toggle
                        HStack {
                            Text(appLanguage == "tr" ? "Hatırlatıcı Aktif" : "Reminder Active")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.9))

                            Spacer()

                            Toggle("", isOn: $isEnabled)
                                .labelsHidden()
                                .tint(Color.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(white: 0.08))
                        )

                        // Save CTA Button
                        Button {
                            saveReminder()
                        } label: {
                            Text(appLanguage == "tr" ? "Kaydet" : "Save")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSaveDisabled ? Color(white: 0.4) : Color.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Capsule().fill(isSaveDisabled ? Color(white: 0.15) : Color.white))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaveDisabled)
                        .padding(.top, 8)
                    }
                }
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showWorkItemManagement) {
            WorkItemManagementView()
        }
    }

    // MARK: - Work Area Target Picker

    private var workAreaTargetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appLanguage == "tr" ? "HEDEF ÇALIŞMA" : "TARGET WORK AREA")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.45))
                .tracking(1)

            VStack(spacing: 6) {
                // "Genel odak" option
                let isGeneral = selectedWorkArea == nil || selectedWorkArea!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedWorkArea = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                            .foregroundStyle(isGeneral ? Color.black : Color(white: 0.5))

                        Text(appLanguage == "tr" ? "Genel odak" : "General focus")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(isGeneral ? Color.black : Color(white: 0.9))

                        Spacer()

                        if isGeneral {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.black)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isGeneral ? Color.white : Color(white: 0.08))
                    )
                }
                .buttonStyle(.plain)

                // Saved subjects list
                ForEach(savedSubjects) { subject in
                    let isSelected = selectedWorkArea?.localizedCaseInsensitiveCompare(subject.name) == .orderedSame
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedWorkArea = subject.name
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 12))
                                .foregroundStyle(isSelected ? Color.black : Color(white: 0.5))

                            Text(subject.name)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(isSelected ? Color.black : Color(white: 0.9))
                                .lineLimit(1)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.black)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.white : Color(white: 0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }

                // If user has no saved subjects, present link to My Work Areas
                if savedSubjects.isEmpty {
                    Button {
                        showWorkItemManagement = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13))
                            Text(appLanguage == "tr" ? "Çalışma eklemek için Çalışmalarım'a Git" : "Go to My Work Areas to add one")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Color(white: 0.55))
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Days Selection & Presets

    private var daysSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appLanguage == "tr" ? "TEKRAR GÜNLERİ" : "REPEAT DAYS")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.45))
                .tracking(1)

            // Preset Action Buttons
            HStack(spacing: 6) {
                presetButton(label: appLanguage == "tr" ? "Bugün" : "Today") {
                    let today = Calendar.current.component(.weekday, from: Date())
                    selectedWeekdays = [today]
                    isOneTime = true
                }
                presetButton(label: appLanguage == "tr" ? "Her gün" : "Every day") {
                    selectedWeekdays = [1, 2, 3, 4, 5, 6, 7]
                    isOneTime = false
                }
            }

            // Weekday Checkbox Toggles (Mon -> Sun)
            let daysTR = [(2, "Pzt"), (3, "Sal"), (4, "Çar"), (5, "Per"), (6, "Cum"), (7, "Cmt"), (1, "Paz")]
            let daysEN = [(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")]
            let list = appLanguage == "tr" ? daysTR : daysEN

            HStack(spacing: 4) {
                ForEach(list, id: \.0) { item in
                    let dayNum = item.0
                    let dayLabel = item.1
                    let isChecked = selectedWeekdays.contains(dayNum)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isChecked {
                                selectedWeekdays.remove(dayNum)
                            } else {
                                selectedWeekdays.insert(dayNum)
                            }
                            isOneTime = false
                        }
                    } label: {
                        Text(dayLabel)
                            .font(.system(size: 11, weight: isChecked ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(isChecked ? Color.black : Color(white: 0.7))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isChecked ? Color.white : Color(white: 0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

        }
    }

    private func presetButton(label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                action()
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(Color(white: 0.12))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save Handler

    private func saveReminder() {
        guard !isSaveDisabled else { return }

        let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedDate)
        let h = comps.hour ?? 20
        let m = comps.minute ?? 0
        let sortedDays = Array(selectedWeekdays).sorted()

        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }

        var targetOneTimeDate: Date? = nil
        if isOneTime {
            let cal = Calendar.current
            var dateComps = cal.dateComponents([.year, .month, .day], from: Date())
            dateComps.hour = h
            dateComps.minute = m
            var candidate = cal.date(from: dateComps) ?? selectedDate
            if candidate <= Date() {
                candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            targetOneTimeDate = candidate
        }

        if let existing = reminder {
            existing.hour = h
            existing.minute = m
            existing.repeatDays = sortedDays
            existing.workItemName = selectedWorkArea
            existing.isEnabled = isEnabled
            existing.isOneTime = isOneTime
            existing.oneTimeDate = targetOneTimeDate
            try? modelContext.save()
            NotificationService.shared.scheduleReminder(existing, allReminders: allReminders)
        } else {
            let newReminder = FocusReminder(
                hour: h,
                minute: m,
                repeatDays: sortedDays,
                durationSeconds: 1500,
                isEnabled: isEnabled,
                workItemName: selectedWorkArea,
                isOneTime: isOneTime,
                oneTimeDate: targetOneTimeDate
            )
            modelContext.insert(newReminder)
            try? modelContext.save()
            NotificationService.shared.scheduleReminder(newReminder, allReminders: allReminders)
        }

        dismiss()
    }
}
