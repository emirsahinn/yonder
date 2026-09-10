//
//  OnboardingView.swift
//  Yonder
//
//  Main Onboarding flow manager.
//  Orchestrates OnboardingLanguageView -> OnboardingIntroPagerView transition.
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {

    var onFinished: () -> Void

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("hasSelectedLanguage") private var hasSelectedLanguage: Bool = false
    @State private var showNotificationPermissionPrompt: Bool = false

    var body: some View {
        ZStack {
            if showNotificationPermissionPrompt {
                OnboardingNotificationPermissionView(
                    onAllow: requestNotificationPermissionAndFinish,
                    onSkip: finish
                )
                .transition(.opacity)
            } else if hasSelectedLanguage {
                OnboardingIntroPagerView {
                    showNotificationPermissionIfNeeded()
                }
                .transition(.opacity)
            } else {
                OnboardingLanguageView { code in
                    appLanguage = code
                    LanguageService.shared.applyLanguage(code)
                    withAnimation(.easeInOut(duration: 0.45)) {
                        hasSelectedLanguage = true
                    }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func showNotificationPermissionIfNeeded() {
        Task {
            let status = await NotificationService.shared.checkAuthorizationStatus()
            await MainActor.run {
                guard status == .notDetermined else {
                    finish()
                    return
                }

                withAnimation(.easeInOut(duration: 0.45)) {
                    showNotificationPermissionPrompt = true
                }
            }
        }
    }

    private func requestNotificationPermissionAndFinish() {
        Task {
            _ = await NotificationService.shared.requestAuthorization()
            await MainActor.run {
                finish()
            }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        // Onboarding already handled the notification ask (shown it, or found
        // permission was already decided) — the post-update prompt shown to
        // existing users on YonderApp's root level shouldn't ask again.
        UserDefaults.standard.set(true, forKey: "hasSeenNotificationPermissionPrompt")
        withAnimation(.easeInOut(duration: 0.45)) {
            onFinished()
        }
    }
}

struct OnboardingNotificationPermissionView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var appear: Bool = false

    private var isIPad: Bool { hSizeClass == .regular }
    private let accentColor = Color(red: 0.58, green: 0.64, blue: 0.99)

    var body: some View {
        GeometryReader { geometry in
            let shouldUsePortraitViewport = !isIPad && geometry.size.width > geometry.size.height
            let viewportWidth = shouldUsePortraitViewport ? min(geometry.size.width, geometry.size.height) : geometry.size.width
            let viewportHeight = shouldUsePortraitViewport ? max(geometry.size.width, geometry.size.height) : geometry.size.height
            let horizontalPadding = max(20, min(32, viewportWidth * 0.06))
            let contentWidth = max(1, min(viewportWidth - horizontalPadding * 2, isIPad ? 520 : 430))

            ZStack {
                Color.black.ignoresSafeArea()

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentColor.opacity(0.32), accentColor.opacity(0.10), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 260
                        )
                    )
                    .frame(width: 520, height: 520)
                    .blur(radius: 60)
                    .offset(y: -60)
                    .allowsHitTesting(false)

                ScrollView(.vertical, showsIndicators: false) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(spacing: 0) {
                            Spacer(minLength: max(geometry.safeAreaInsets.top + 28, 58))

                            ZStack {
                                Circle()
                                    .stroke(accentColor.opacity(0.26), lineWidth: 1)
                                    .frame(width: isIPad ? 176 : 148, height: isIPad ? 176 : 148)

                                Circle()
                                    .fill(Color.white.opacity(0.07))
                                    .frame(width: isIPad ? 132 : 112, height: isIPad ? 132 : 112)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                                    )

                                Image(systemName: "bell.badge")
                                    .font(.system(size: isIPad ? 48 : 40, weight: .semibold))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(accentColor, .white.opacity(0.9))
                            }
                            .opacity(appear ? 1 : 0)
                            .scaleEffect(appear ? 1 : 0.88)
                            .offset(y: appear ? 0 : 12)

                            Spacer().frame(height: isIPad ? 46 : 34)

                            VStack(spacing: 12) {
                                Text(appLanguage == "tr" ? "Ritmini hatırlatalım" : "Let Yonder remind you")
                                    .font(.system(size: isIPad ? 30 : 25, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)

                                Text(appLanguage == "tr"
                                     ? "Yonder sana doğru zamanda hatırlatmalar gönderebilmek için bildirim izni kullanır."
                                     : "Yonder uses notification permission to send reminders at the right time.")
                                    .font(.system(size: isIPad ? 17 : 15, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color(white: 0.58))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, isIPad ? 36 : 18)
                            }
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 8)

                            Spacer().frame(height: isIPad ? 42 : 32)

                            VStack(spacing: 12) {
                                Button {
                                    HapticService.medium()
                                    onAllow()
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(appLanguage == "tr" ? "Bildirimleri Aç" : "Allow Notifications")
                                            .font(.system(size: isIPad ? 19 : 17, weight: .semibold, design: .rounded))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.82)

                                        Image(systemName: "arrow.right")
                                            .font(.system(size: isIPad ? 15 : 13, weight: .semibold))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: isIPad ? 56 : 50)
                                    .background(
                                        Capsule()
                                            .fill(Color.white)
                                            .shadow(color: accentColor.opacity(0.45), radius: 20, y: 6)
                                    )
                                }
                                .buttonStyle(PressableButtonStyle())

                                Button {
                                    HapticService.light()
                                    onSkip()
                                } label: {
                                    Text(appLanguage == "tr" ? "Şimdilik Geç" : "Not Now")
                                        .font(.system(size: isIPad ? 16 : 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color(white: 0.62))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: isIPad ? 46 : 42)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 8)

                            Spacer(minLength: max(geometry.safeAreaInsets.bottom + 20, 36))
                        }
                        .frame(width: contentWidth)
                        .frame(minHeight: geometry.size.height)

                        Spacer(minLength: 0)
                    }
                    .frame(width: viewportWidth)
                }
                .frame(width: viewportWidth, height: viewportHeight)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appear = true
            }
        }
        .environment(\.locale, Locale(identifier: appLanguage))
    }
}

/// Shown once, at the app's root level, to users who already completed
/// onboarding before this prompt existed (i.e. updated from an older
/// version). Mirrors the onboarding notification screen so returning users
/// get the same one-time ask instead of it staying buried inside Reminders.
struct PostUpdateNotificationPermissionPrompt: View {
    @Binding var hasSeenNotificationPermissionPrompt: Bool
    @State private var shouldShowPrompt: Bool = false

    var body: some View {
        Group {
            if shouldShowPrompt {
                OnboardingNotificationPermissionView(
                    onAllow: requestAndDismiss,
                    onSkip: dismiss
                )
                .transition(.opacity)
            }
        }
        .task {
            let status = await NotificationService.shared.checkAuthorizationStatus()
            await MainActor.run {
                guard status == .notDetermined else {
                    hasSeenNotificationPermissionPrompt = true
                    return
                }
                withAnimation(.easeInOut(duration: 0.45)) {
                    shouldShowPrompt = true
                }
            }
        }
    }

    private func requestAndDismiss() {
        Task {
            _ = await NotificationService.shared.requestAuthorization()
            await MainActor.run { dismiss() }
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.45)) {
            hasSeenNotificationPermissionPrompt = true
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
