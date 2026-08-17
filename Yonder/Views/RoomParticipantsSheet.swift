//
//  RoomParticipantsSheet.swift
//  Yonder
//

import SwiftUI

/// Bottom sheet displaying the list of current room participants, their readiness, work items, timing, and host status.
struct RoomParticipantsSheet: View {

    let roomId: String
    let room: RoomModel?
    let participants: [ParticipantModel]
    let currentUserId: String?
    let remainingSeconds: Int
    let appLanguage: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                // Drag Handle
                Capsule()
                    .fill(Color(white: 0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                // Header
                HStack {
                    Text(appLanguage == "tr" ? "Katılımcılar" : "Participants")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.95))

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(white: 0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                // Room Info Summary Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(roomId)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .tracking(2)

                        Spacer()

                        Text(ReportMetrics.formattedTime(seconds: remainingSeconds, lang: appLanguage))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.70))
                            .monospacedDigit()
                    }

                    if let subject = room?.subject, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(subject)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.50))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 20)

                // Participants List
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(participants) { participant in
                            participantRow(participant)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Explanatory Note
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.40))
                    Text(appLanguage == "tr"
                         ? "Mola sadece durumunu değiştirir; ortak sayaç devam eder."
                         : "Break only changes your status; the shared timer keeps running.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(24)
        .preferredColorScheme(.dark)
    }

    private func participantRow(_ participant: ParticipantModel) -> some View {
        let isMe = participant.id == currentUserId
        let isHost = participant.id == room?.hostId

        let statusText: String = {
            if room?.isWaiting == true {
                return participant.isReady
                    ? (appLanguage == "tr" ? "Hazır" : "Ready")
                    : (appLanguage == "tr" ? "Bekliyor" : "Waiting")
            } else if room?.status == "ended" {
                return appLanguage == "tr" ? "Tamamlandı" : "Completed"
            } else {
                return participant.isStudying
                    ? (appLanguage == "tr" ? "Çalışıyor" : "Studying")
                    : (appLanguage == "tr" ? "Molada" : "On break")
            }
        }()

        let workItemName = participant.workItemName?.nilIfEmpty

        return HStack(spacing: 12) {
            Text(initials(for: participant.displayName))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.86))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(white: 0.14)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(participant.displayName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)

                    if isMe {
                        Text(appLanguage == "tr" ? "Sen" : "You")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(white: 0.90))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(white: 0.20)))
                    }

                    if isHost {
                        Text("Host")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(white: 0.60))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(white: 0.12)))
                    }
                }

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 9))
                        Text(workItemName ?? (appLanguage == "tr" ? "Çalışma seçilmedi" : "No work selected"))
                            .font(.system(size: 11, weight: workItemName == nil ? .regular : .medium, design: .rounded))
                    }
                    .foregroundStyle(workItemName == nil ? Color(white: 0.40) : Color(white: 0.75))

                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.30))

                    Text(statusText)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(participant.isStudying || participant.isReady ? Color(white: 0.65) : Color(white: 0.40))
                }

                // Active & Break time summary
                Text(timingSummaryText(for: participant))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.50))
                    .monospacedDigit()
            }

            Spacer()

            Circle()
                .fill(participant.isStudying || participant.isReady ? Color.white : Color(white: 0.25))
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(white: 0.14), lineWidth: 0.5)
                )
        )
    }

    private func timingSummaryText(for participant: ParticipantModel) -> String {
        let activeSec = participant.currentActiveSeconds()
        let breakSec = participant.currentBreakSeconds()

        if activeSec == 0 && breakSec == 0 {
            return appLanguage == "tr" ? "Henüz süre yok" : "No time yet"
        }

        let activeFormatted = formattedTimeBadge(seconds: activeSec)
        let breakFormatted = formattedTimeBadge(seconds: breakSec)

        if appLanguage == "tr" {
            return "Aktif süre: \(activeFormatted) · Mola: \(breakFormatted)"
        } else {
            return "Active time: \(activeFormatted) · Break: \(breakFormatted)"
        }
    }

    private func formattedTimeBadge(seconds: Int) -> String {
        guard seconds > 0 else {
            return appLanguage == "tr" ? "0 dk" : "0m"
        }
        let mins = seconds / 60
        let secs = seconds % 60
        if mins == 0 {
            return appLanguage == "tr" ? "\(secs) sn" : "\(secs)s"
        } else {
            return appLanguage == "tr" ? "\(mins) dk" : "\(mins)m"
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

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
