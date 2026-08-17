//
//  RoomSummaryView.swift
//  Yonder
//
//  Summary screen presented when an online focus room completes or when a user leaves.
//  Displays personal focus stats (active work time, break time, work item), participant breakdown,
//  and saves the user's active work time to reports as a FocusSession.
//

import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

struct RoomSummaryView: View {

    let room: RoomModel?
    let participants: [ParticipantModel]
    let currentUserId: String?
    let appLanguage: String
    let onDone: () -> Void

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.modelContext) private var modelContext

    @Query private var allSessions: [FocusSession]
    @Query(sort: \Subject.lastUsedDate, order: .reverse) private var savedSubjects: [Subject]

    @State private var selectedWorkItem: String? = nil
    @State private var showWorkItemPicker: Bool = false
    @State private var hasSavedToReports: Bool = false
    @State private var localWorkItemOverride: String? = nil
    @State private var isLeavingSummary: Bool = false

    private var isIPad: Bool { hSizeClass == .regular }

    private var userParticipant: ParticipantModel? {
        participants.first { $0.id == currentUserId }
    }

    private var wasEarlyEnd: Bool {
        guard let room else { return false }
        return room.endedAt != nil && (room.endTimestamp == nil || room.endedAt! < room.endTimestamp!.addingTimeInterval(-10))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: isIPad ? 28 : 20) {
                        headerSection
                        personalSummaryCard
                        saveStatusBanner
                        participantsSection
                    }
                    .padding(.vertical, isIPad ? 36 : 24)
                    .padding(.horizontal, isIPad ? 40 : 24)
                    .frame(maxWidth: isIPad ? 680 : .infinity)
                }

                bottomActionBar
                    .frame(maxWidth: isIPad ? 680 : .infinity)
                    .padding(.horizontal, isIPad ? 40 : 24)
                    .padding(.bottom, isIPad ? 36 : 20)
            }

            if isLeavingSummary {
                YonderTransitionOverlay(message: appLanguage == "tr" ? "Ana ekran hazırlanıyor" : "Preparing home")
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isLeavingSummary)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showWorkItemPicker) {
            WorkItemPickerSheet(selectedWorkItem: $selectedWorkItem)
        }
        .onChange(of: selectedWorkItem) { _, newItem in
            if let newItem, !newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                localWorkItemOverride = newItem
                if let roomId = room?.id {
                    Task {
                        try? await RoomService.shared.updateMyWorkItem(roomId: roomId, workItemName: newItem)
                    }
                }
                saveSessionToReportsIfNeeded(overrideWorkItem: newItem)
            }
        }
        .onAppear {
            saveSessionToReportsIfNeeded()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: wasEarlyEnd ? "clock.badge.checkmark" : "checkmark.circle.fill")
                .font(.system(size: isIPad ? 64 : 48, weight: .thin))
                .foregroundStyle(Color(white: 0.90))

            VStack(spacing: 4) {
                Text(wasEarlyEnd
                     ? (appLanguage == "tr" ? "Oda sona erdi" : "Room ended")
                     : (appLanguage == "tr" ? "Oda tamamlandı" : "Room completed"))
                    .font(.system(size: isIPad ? 26 : 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.96))

                Text(appLanguage == "tr" ? "Birlikte çalışma özeti" : "Shared focus summary")
                    .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.50))
            }
        }
        .padding(.top, isIPad ? 12 : 4)
    }

    // MARK: - Personal Summary Card

    private var personalSummaryCard: some View {
        let activeSec = userParticipant?.currentActiveSeconds() ?? 0
        let breakSec = userParticipant?.currentBreakSeconds() ?? 0
        let rawWork = localWorkItemOverride ?? userParticipant?.workItemName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let workName = (rawWork?.isEmpty == false ? rawWork : room?.subject)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(spacing: 14) {
            HStack {
                Text(appLanguage == "tr" ? "SENİN AKTİF SÜREN" : "YOUR ACTIVE TIME")
                    .font(.system(size: isIPad ? 12 : 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .textCase(.uppercase)
                    .tracking(2)

                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formattedSummaryTime(seconds: activeSec))
                    .font(.system(size: isIPad ? 44 : 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()
            }

            Divider()
                .overlay(Color(white: 0.14))

            HStack(spacing: 16) {
                // Break Duration
                HStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                    Text(appLanguage == "tr"
                         ? "Mola: \(formattedSummaryTime(seconds: breakSec))"
                         : "Break: \(formattedSummaryTime(seconds: breakSec))")
                        .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.70))
                }

                Text("·")
                    .foregroundStyle(Color(white: 0.25))

                // Work Item
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                    Text(workName != nil && !workName!.isEmpty
                         ? (appLanguage == "tr" ? "Çalışma: \(workName!)" : "Work: \(workName!)")
                         : (appLanguage == "tr" ? "Çalışma seçilmedi" : "No work selected"))
                        .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                        .foregroundStyle(workName != nil && !workName!.isEmpty ? Color(white: 0.70) : Color(white: 0.40))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.075))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Save Status Banner & Work Selection Prompt

    private var saveStatusBanner: some View {
        let activeSec = userParticipant?.currentActiveSeconds() ?? 0
        let rawWork = localWorkItemOverride ?? userParticipant?.workItemName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let workName = (rawWork?.isEmpty == false ? rawWork : room?.subject)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(spacing: 8) {
            if activeSec == 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color(white: 0.45))
                    Text(appLanguage == "tr" ? "Kaydedilecek aktif süre yok." : "No active time to save.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.50))
                }
            } else if workName == nil || workName!.isEmpty {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.85))
                        Text(appLanguage == "tr"
                             ? "Raporlara kaydetmek için çalışma seç"
                             : "Choose work to save this to reports")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.90))
                    }

                    Button {
                        showWorkItemPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 12))
                            Text(appLanguage == "tr" ? "Çalışma Seç" : "Choose Work")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.10))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(white: 0.22), lineWidth: 0.5))
                )
            } else if hasSavedToReports {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(white: 0.80))
                    Text(isAlreadySavedInDatabase
                         ? (appLanguage == "tr" ? "Bu oturum zaten kaydedildi." : "This session was already saved.")
                         : (appLanguage == "tr" ? "Bu oturum rapora kaydedildi." : "This session was saved to reports."))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.60))
                }
            }
        }
    }

    // MARK: - Participants Summary List

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appLanguage == "tr"
                     ? "KATILIMCILAR (\(max(participants.count, 1)))"
                     : "PARTICIPANTS (\(max(participants.count, 1)))")
                    .font(.system(size: isIPad ? 12 : 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .textCase(.uppercase)
                    .tracking(2)

                Spacer()
            }

            VStack(spacing: 8) {
                if participants.isEmpty {
                    fallbackParticipantRow
                } else {
                    ForEach(participants) { participant in
                        participantSummaryRow(participant)
                    }
                }
            }
        }
    }

    private func participantSummaryRow(_ participant: ParticipantModel) -> some View {
        let isMe = participant.id == currentUserId
        let isHost = participant.id == room?.hostId
        let activeSec = participant.currentActiveSeconds()
        let breakSec = participant.currentBreakSeconds()
        let rawWork = (isMe ? localWorkItemOverride : nil) ?? participant.workItemName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let workName = (rawWork?.isEmpty == false ? rawWork : (isMe ? room?.subject : nil))?.trimmingCharacters(in: .whitespacesAndNewlines)

        let displayName = participant.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (appLanguage == "tr" ? "Katılımcı" : "Participant")
            : participant.displayName

        let activeFormatted = formattedSummaryTime(seconds: activeSec)
        let breakFormatted = formattedSummaryTime(seconds: breakSec)

        let timingLine: String = {
            let workStr = workName ?? (appLanguage == "tr" ? "Çalışma seçilmedi" : "No work selected")
            if appLanguage == "tr" {
                return "\(workStr) · \(activeFormatted) aktif · \(breakFormatted) mola"
            } else {
                return "\(workStr) · \(activeFormatted) active · \(breakFormatted) break"
            }
        }()

        return HStack(spacing: 12) {
            Text(initials(for: displayName))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.86))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color(white: 0.13)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.88))

                    if isMe {
                        Text(appLanguage == "tr" ? "Sen" : "You")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(white: 0.90))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(white: 0.20)))
                    }

                    if isHost {
                        Text("Host")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(white: 0.60))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(white: 0.12)))
                    }
                }

                Text(timingLine)
                    .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.50))
                    .monospacedDigit()
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(white: 0.10), lineWidth: 0.5)
                )
        )
    }

    private var fallbackParticipantRow: some View {
        HStack(spacing: 12) {
            Text("Y")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.86))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color(white: 0.13)))

            VStack(alignment: .leading, spacing: 3) {
                Text(appLanguage == "tr" ? "Katılımcı" : "Participant")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.88))

                Text(appLanguage == "tr" ? "Çalışma seçilmedi · 0 dk aktif" : "No work selected · 0m active")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.50))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(white: 0.10), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        Button(action: handleDone) {
            Text(appLanguage == "tr" ? "Ana Ekrana Dön" : "Back Home")
                .font(.system(size: isIPad ? 17 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: isIPad ? 52 : 46)
                .background(Capsule().fill(.white))
        }
        .buttonStyle(.plain)
        .disabled(isLeavingSummary)
        .opacity(isLeavingSummary ? 0.65 : 1.0)
    }

    private func handleDone() {
        guard !isLeavingSummary else { return }
        isLeavingSummary = true
        HapticService.light()
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            await MainActor.run {
                onDone()
            }
        }
    }

    // MARK: - Save Logic

    private var isAlreadySavedInDatabase: Bool {
        guard let roomId = room?.id, !roomId.isEmpty else { return false }
        return allSessions.contains(where: {
            $0.roomId == roomId && $0.modeRawValue == FocusSessionMode.room.rawValue
        })
    }

    private func saveSessionToReportsIfNeeded(overrideWorkItem: String? = nil) {
        guard let room = room, !room.id.isEmpty else { return }
        let activeSeconds = userParticipant?.currentActiveSeconds() ?? 0
        guard activeSeconds > 0 else { return }

        if isAlreadySavedInDatabase {
            hasSavedToReports = true
            return
        }

        let rawWork = overrideWorkItem ?? localWorkItemOverride ?? userParticipant?.workItemName ?? room.subject
        let trimmedWork = rawWork?.normalizedWorkItemName() ?? ""
        guard !trimmedWork.isEmpty else { return }

        let now = Date()
        let plannedDuration = room.duration > 0 ? room.duration : activeSeconds
        let joinedAt = userParticipant?.joinedAt ?? now.addingTimeInterval(-TimeInterval(activeSeconds))
        let startedAt = joinedAt
        let endedAt = now

        let wasEarlyEnd = room.endedAt != nil && (room.endTimestamp == nil || room.endedAt! < room.endTimestamp!.addingTimeInterval(-10))
        let isCompletedNaturally = !wasEarlyEnd && activeSeconds >= max(1, plannedDuration - 10)

        // Find or update Subject
        if let existingSubject = savedSubjects.first(where: {
            $0.name.normalizedWorkItemName().localizedCaseInsensitiveCompare(trimmedWork) == .orderedSame
        }) {
            existingSubject.name = trimmedWork
            existingSubject.lastUsedDate = now
            existingSubject.updatedAt = now
            SyncService.shared.syncSubject(existingSubject)
        }

        let session = FocusSession(
            durationSeconds: activeSeconds,
            completed: isCompletedNaturally,
            intentionNote: trimmedWork,
            subject: trimmedWork,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedDurationSeconds: plannedDuration,
            modeRawValue: FocusSessionMode.room.rawValue,
            roomId: room.id
        )

        modelContext.insert(session)
        try? modelContext.save()
        SyncService.shared.syncSession(session)

        let todayTotal = allSessions
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationSeconds } + activeSeconds

        WidgetDataService.shared.updateWidgetData(todayTotalSeconds: todayTotal, mostUsedDurationSeconds: plannedDuration)

        hasSavedToReports = true
    }

    // MARK: - Time Formatter Helper

    private func formattedSummaryTime(seconds: Int) -> String {
        guard seconds > 0 else {
            return appLanguage == "tr" ? "0 dk" : "0m"
        }

        if seconds < 60 {
            return appLanguage == "tr" ? "1 dk'dan az" : "less than 1m"
        }

        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60

        if hours == 0 {
            return appLanguage == "tr" ? "\(mins) dk" : "\(mins)m"
        } else if mins == 0 {
            return appLanguage == "tr" ? "\(hours) sa" : "\(hours)h"
        } else {
            return appLanguage == "tr" ? "\(hours) sa \(mins) dk" : "\(hours)h \(mins)m"
        }
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Y" }

        let parts = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(2)
            .compactMap { $0.first }

        let value = String(parts).uppercased()
        return value.isEmpty ? "Y" : value
    }
}

#Preview {
    RoomSummaryView(
        room: nil,
        participants: [],
        currentUserId: "123",
        appLanguage: "tr",
        onDone: {}
    )
}
