//
//  GoalCardView.swift
//  Yonder
//

import SwiftUI

/// Reusable navigation card for Work Goals Hub options (General Work Goals vs Work Area Specific Goals).
struct GoalCardView: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let detailSummary: String
    let isWide: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: isWide ? 17 : 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.95))

                    Text(subtitle)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))

                    Text(detailSummary)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.65))
                        .monospacedDigit()
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.40))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(isWide ? 22 : 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(white: 0.15), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
