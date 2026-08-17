//
//  SessionLogView.swift
//  Yonder
//
//  Displays a quiet, chronological archive of all recorded focus sessions grouped by day.
//

import SwiftUI
import SwiftData

/// Displays a chronological focus archive grouped by day.
struct SessionLogView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FocusSession.date, order: .reverse) private var sessions: [FocusSession]
    @Query(sort: \Subject.lastUsedDate, order: .reverse) private var savedSubjects: [Subject]
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false

    @State private var editingSession: FocusSession?
    @State private var sessionPendingDeletion: FocusSession?
    @State private var showDeleteConfirmation: Bool = false

    private var isIPad: Bool { hSizeClass == .regular }

    private var currentLocale: Locale {
        Locale(identifier: appLanguage)
    }

    // MARK: - Grouping Model

    private struct DayGroup: Identifiable {
        let id: Date
        let date: Date
        let sessions: [FocusSession]
    }

    private var groupedSessions: [DayGroup] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.date)
        }

        let sortedDates = grouped.keys.sorted(by: >)

        return sortedDates.map { date in
            DayGroup(
                id: date,
                date: date,
                sessions: grouped[date] ?? []
            )
        }
    }

    private func dayGroupTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return appLanguage == "tr" ? "BUGÜN" : "TODAY"
        }
        if calendar.isDateInYesterday(date) {
            return appLanguage == "tr" ? "DÜN" : "YESTERDAY"
        }
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date).uppercased()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        ReportMetrics.formattedTime(seconds: seconds, lang: appLanguage)
    }

    private func displaySubject(for session: FocusSession) -> String {
        if let subject = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines), !subject.isEmpty {
            return subject
        }
        if let note = session.intentionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return note
        }
        return appLanguage == "tr" ? "Adlandırılmamış odak" : "Unnamed focus"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header & Close Button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(white: 0.45))
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
                .padding(.trailing, 16)

                // Screen Title
                Text(appLanguage == "tr" ? "OTURUM ARŞİVİ" : "SESSION ARCHIVE")
                    .font(.system(size: isIPad ? 22 : 16, weight: .light, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .tracking(3.0)
                    .padding(.bottom, isIPad ? 24 : 16)

                if sessions.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 20) {
                            ForEach(groupedSessions) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    // Day Header
                                    Text(dayGroupTitle(for: group.date))
                                        .font(.system(size: isIPad ? 12 : 10, weight: .regular, design: .rounded))
                                        .foregroundStyle(Color(white: 0.38))
                                        .tracking(1.5)
                                        .padding(.leading, 4)

                                    // Session Rows for this Day
                                    VStack(spacing: 8) {
                                        ForEach(group.sessions) { session in
                                            sessionRow(session)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: isIPad ? 680 : .infinity)
                        .padding(.horizontal, isIPad ? 60 : 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(item: $editingSession) { session in
            SessionEditSheet(
                session: session,
                onSave: { subject, durationSeconds, completed in
                    updateSession(
                        session,
                        subject: subject,
                        durationSeconds: durationSeconds,
                        completed: completed
                    )
                    editingSession = nil
                },
                onCancel: {
                    editingSession = nil
                }
            )
        }
        .confirmationDialog(
            String(localized: "delete_session_title", defaultValue: "Bu oturumu silmek istediğine emin misin?", locale: currentLocale),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete_button", defaultValue: "Sil", locale: currentLocale), role: .destructive) {
                if let session = sessionPendingDeletion {
                    deleteSession(session)
                }
                sessionPendingDeletion = nil
            }
            Button(String(localized: "cancel_button", defaultValue: "Vazgeç", locale: currentLocale), role: .cancel) {
                sessionPendingDeletion = nil
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "archivebox")
                .font(.system(size: isIPad ? 52 : 38, weight: .ultraLight))
                .foregroundStyle(Color(white: 0.30))

            Text(appLanguage == "tr" ? "İlk odak oturumundan sonra arşivin burada oluşacak." : "Your archive will start forming after your first focus session.")
                .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.50))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()
        }
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        let startTime = formatTime(session.startedAt ?? session.date)
        let durationStr = formatDuration(session.durationSeconds)
        let subjectStr = displaySubject(for: session)
        let statusStr = session.completed
            ? (appLanguage == "tr" ? "Tamamlandı" : "Completed")
            : (appLanguage == "tr" ? "Yarım kaldı" : "Ended early")
        let isRoom = session.modeRawValue == "room"

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Subject / Intention Title
                Text(subjectStr)
                    .font(.system(size: isIPad ? 15 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                // Subtitle Row: Duration · Start Time · Status (· Room)
                HStack(spacing: 4) {
                    Text("\(durationStr) · \(startTime) · \(statusStr)")
                        .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .monospacedDigit()

                    if isRoom {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.3))

                        let roomTagText: String = {
                            if let rid = session.roomId?.trimmingCharacters(in: .whitespacesAndNewlines), !rid.isEmpty {
                                return appLanguage == "tr" ? "Oda · \(rid)" : "Room · \(rid)"
                            } else {
                                return appLanguage == "tr" ? "Oda" : "Room"
                            }
                        }()

                        Text(roomTagText)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                            .monospacedDigit()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color(white: 0.08))
                            )
                    }
                }
            }

            Spacer()

            // Ellipsis Action Menu
            Menu {
                Button {
                    editingSession = session
                } label: {
                    Label(String(localized: "edit_session_button", defaultValue: "Düzenle", locale: currentLocale), systemImage: "pencil")
                }

                Button(role: .destructive) {
                    sessionPendingDeletion = session
                    showDeleteConfirmation = true
                } label: {
                    Label(String(localized: "delete_button", defaultValue: "Sil", locale: currentLocale), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.40))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color(white: 0.06))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.038))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(white: 0.08), lineWidth: 0.5)
                )
        )
    }

    private func updateSession(
        _ session: FocusSession,
        subject: String?,
        durationSeconds: Int,
        completed: Bool
    ) {
        let trimmedSubject = (subject ?? "").normalizedWorkItemName()
        session.durationSeconds = max(1, durationSeconds)
        session.completed = completed
        session.intentionNote = trimmedSubject.isEmpty ? nil : trimmedSubject
        session.subject = trimmedSubject.isEmpty ? nil : trimmedSubject

        if !trimmedSubject.isEmpty {
            if let existing = savedSubjects.first(where: { $0.name.normalizedWorkItemName().localizedCaseInsensitiveCompare(trimmedSubject) == .orderedSame }) {
                existing.name = trimmedSubject
                existing.lastUsedDate = Date()
                existing.updatedAt = Date()
                SyncService.shared.syncSubject(existing)
            } else if !WorkItemLimits.isLimitReached(currentCount: savedSubjects.count, isPremiumUser: isPremiumUser) {
                let newSubject = Subject(name: trimmedSubject)
                modelContext.insert(newSubject)
                try? modelContext.save()
                SyncService.shared.syncSubject(newSubject)
            }
        }

        try? modelContext.save()
        SyncService.shared.syncSession(session)
        updateTodayWidgetData()
    }

    private func deleteSession(_ session: FocusSession) {
        SyncService.shared.deleteSession(session)
        modelContext.delete(session)
        try? modelContext.save()
        updateTodayWidgetData(excluding: session)
    }

    private func updateTodayWidgetData(excluding excludedSession: FocusSession? = nil) {
        let calendar = Calendar.current
        let todayTotal = sessions
            .filter { session in
                calendar.isDateInToday(session.date) && session.id != excludedSession?.id
            }
            .reduce(0) { $0 + $1.durationSeconds }

        let mostUsedDuration = mostUsedDurationSeconds(excluding: excludedSession)
        WidgetDataService.shared.updateWidgetData(
            todayTotalSeconds: todayTotal,
            mostUsedDurationSeconds: mostUsedDuration
        )
    }

    private func mostUsedDurationSeconds(excluding excludedSession: FocusSession? = nil) -> Int {
        var counts: [Int: Int] = [:]
        for session in sessions where session.id != excludedSession?.id {
            let roundedMinutes = max(1, (session.durationSeconds + 30) / 60)
            counts[roundedMinutes, default: 0] += 1
        }

        guard let top = counts.sorted(by: {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key < $1.key
        }).first else {
            return 1500
        }

        return top.key * 60
    }
}

// MARK: - SessionEditSheet

private struct SessionEditSheet: View {
    let session: FocusSession
    let onSave: (String?, Int, Bool) -> Void
    let onCancel: () -> Void

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var subject: String
    @State private var durationMinutes: Int
    @State private var completed: Bool

    private var isIPad: Bool { hSizeClass == .regular }
    private var currentLocale: Locale { Locale(identifier: appLanguage) }

    init(
        session: FocusSession,
        onSave: @escaping (String?, Int, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.session = session
        self.onSave = onSave
        self.onCancel = onCancel
        self._subject = State(initialValue: session.subject ?? session.intentionNote ?? "")
        self._durationMinutes = State(initialValue: max(1, (session.durationSeconds + 30) / 60))
        self._completed = State(initialValue: session.completed)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(white: 0.45))
                            .padding(12)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                Text(String(localized: "edit_session_title", defaultValue: "Oturumu Düzenle", locale: currentLocale))
                    .font(.system(size: isIPad ? 22 : 16, weight: .light, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .tracking(3.0)
                    .textCase(.uppercase)

                VStack(spacing: 14) {
                    fieldLabel("working_on_label")
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(white: 0.45))

                        TextField(
                            "",
                            text: $subject,
                            prompt: Text(String(localized: "intention_placeholder", defaultValue: "Ne üzerinde çalıştın?"))
                                .foregroundStyle(Color(white: 0.35))
                        )
                        .font(.system(size: isIPad ? 17 : 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.9))
                        .textInputAutocapitalization(.words)
                    }
                    .inputSurface()

                    Divider()
                        .background(Color(white: 0.12))

                    Stepper(value: $durationMinutes, in: 1...720, step: 5) {
                        VStack(alignment: .leading, spacing: 4) {
                            fieldLabel("duration_minutes_label")
                            Text(formatDuration(minutes: durationMinutes))
                                .font(.system(size: isIPad ? 18 : 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(white: 0.9))
                                .monospacedDigit()
                        }
                    }
                    .tint(.white)

                    Toggle(isOn: $completed) {
                        fieldLabel("completed_session_label")
                    }
                    .tint(.white)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(white: 0.038))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color(white: 0.08), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, isIPad ? 72 : 24)

                Spacer()

                Button {
                    let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(
                        trimmedSubject.isEmpty ? nil : trimmedSubject,
                        durationMinutes * 60,
                        completed
                    )
                } label: {
                    Text(String(localized: "save_session_button", defaultValue: "Kaydet", locale: currentLocale))
                        .font(.system(size: isIPad ? 18 : 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 54 : 48)
                        .background(
                            Capsule()
                                .fill(.white)
                                .shadow(color: .white.opacity(0.15), radius: 8)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, isIPad ? 80 : 32)
                .padding(.bottom, isIPad ? 40 : 28)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func fieldLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
            .foregroundStyle(Color(white: 0.45))
            .textCase(.uppercase)
            .tracking(1.4)
    }

    private func formatDuration(minutes: Int) -> String {
        if appLanguage == "tr" {
            if minutes >= 60 {
                let hours = minutes / 60
                let remainder = minutes % 60
                return remainder == 0 ? "\(hours) sa" : "\(hours) sa \(remainder) dk"
            }
            return "\(minutes) dk"
        }

        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }
        return "\(minutes)m"
    }
}

private extension View {
    func inputSurface() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(white: 0.12), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Preview

#Preview {
    SessionLogView()
}
