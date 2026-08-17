//
//  ReminderRowView.swift
//  Yonder
//

import SwiftUI
import SwiftData

/// Individual reminder card row displaying time, repeat schedule, toggle, edit, and delete actions.
/// v1: Pro badge and lock state removed — all reminders are freely accessible.
struct ReminderRowView: View {

    let reminder: FocusReminder
    let allReminders: [FocusReminder]
    let isPremiumUser: Bool
    let appLanguage: String
    let repeatDaysSummaryText: String
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPaywallPrompt: () -> Void

    var body: some View {
        let workTitle = reminder.normalizedWorkItem ?? (appLanguage == "tr" ? "Genel odak" : "General focus")

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.95))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(reminder.formattedTime)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(reminder.isEnabled ? Color.white : Color(white: 0.4))
                        .monospacedDigit()

                    Text("·")
                        .foregroundStyle(Color(white: 0.3))

                    Text(repeatDaysSummaryText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(reminder.isEnabled ? Color(white: 0.55) : Color(white: 0.35))
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Toggle("", isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { newValue in
                        onToggle(newValue)
                    }
                ))
                .labelsHidden()
                .tint(Color.white)

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.6))
                        .frame(width: 28, height: 28)
                        .background(Color(white: 0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45))
                        .frame(width: 28, height: 28)
                        .background(Color(white: 0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
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
