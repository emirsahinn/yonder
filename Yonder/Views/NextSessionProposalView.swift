//
//  NextSessionProposalView.swift
//  Yonder
//

import SwiftUI

/// Presented after a break finishes or is skipped, asking if the user wants to continue
/// with a new focus session or finish for today.
struct NextSessionProposalView: View {

    let onContinue: () -> Void
    let onFinish: () -> Void

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isIPad: Bool { hSizeClass == .regular }

    private var currentLocale: Locale {
        Locale(identifier: appLanguage)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: isIPad ? 32 : 24) {
                Spacer()

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: isIPad ? 64 : 48, weight: .thin))
                    .foregroundStyle(Color(white: 0.75))

                VStack(spacing: 8) {
                    Text(String(localized: "continue_question_title", defaultValue: "Devam etmek ister misin?", locale: currentLocale))
                        .font(.system(size: isIPad ? 24 : 18, weight: .light, design: .rounded))
                        .foregroundStyle(Color(white: 0.9))

                    Text(String(localized: "continue_question_subtitle", defaultValue: "Yeni bir odaklanma oturumu başlatabilir ya da bugünü tamamlayabilirsin.", locale: currentLocale))
                        .font(.system(size: isIPad ? 15 : 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Actions Section
                VStack(spacing: 14) {
                    // Option 1: "Devam Et"
                    Button {
                        onContinue()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text(String(localized: "continue_session_button", defaultValue: "Devam Et", locale: currentLocale))
                                .font(.system(size: isIPad ? 18 : 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 54 : 48)
                        .background(
                            Capsule()
                                .fill(.white)
                                .shadow(color: .white.opacity(0.18), radius: 8)
                        )
                    }
                    .buttonStyle(.plain)

                    // Option 2: "Bugünü Bitir"
                    Button {
                        onFinish()
                    } label: {
                        Text(String(localized: "finish_today_button", defaultValue: "Bugünü Bitir", locale: currentLocale))
                            .font(.system(size: isIPad ? 16 : 14, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.5))
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, isIPad ? 80 : 32)
                .padding(.bottom, isIPad ? 40 : 28)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    NextSessionProposalView(onContinue: {}, onFinish: {})
}
