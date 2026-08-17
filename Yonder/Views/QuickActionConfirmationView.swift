//
//  QuickActionConfirmationView.swift
//  Yonder
//

import SwiftUI

/// Minimal Fliqlo confirmation modal shown when launching Yonder from a Home Screen Quick Action.
struct QuickActionConfirmationView: View {

    let durationSeconds: Int
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isIPad: Bool { hSizeClass == .regular }

    private var durationInMinutes: Int {
        durationSeconds / 60
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Hourglass Icon inside Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: isIPad ? 80 : 64, height: isIPad ? 80 : 64)

                    Image(systemName: "hourglass")
                        .font(.system(size: isIPad ? 32 : 26, weight: .light))
                        .foregroundStyle(Color(white: 0.85))
                }

                // Question & Subtitle
                VStack(spacing: 8) {
                    Text("quick_action_confirm_title_\(durationInMinutes)")
                        .font(.system(size: isIPad ? 20 : 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("quick_action_confirm_subtitle")
                        .font(.system(size: isIPad ? 14 : 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                }

                // Actions: "Başlat" & "Vazgeç"
                VStack(spacing: 12) {
                    Button {
                        onConfirm()
                    } label: {
                        Text("start_button")
                            .font(.system(size: isIPad ? 17 : 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: isIPad ? 52 : 46)
                            .background(
                                Capsule()
                                    .fill(.white)
                                    .shadow(color: .white.opacity(0.15), radius: 6)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onCancel()
                    } label: {
                        Text("cancel_button")
                            .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, isIPad ? 32 : 24)
            .padding(.horizontal, isIPad ? 40 : 28)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, isIPad ? 80 : 36)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    QuickActionConfirmationView(
        durationSeconds: 1500,
        onConfirm: {},
        onCancel: {}
    )
}
