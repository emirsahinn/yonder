//
//  BreakView.swift
//  Yonder
//

import SwiftUI

/// Full-screen 5-minute break timer view with a calm visual tone,
/// flip-clock display, and optional skip action.
struct BreakView: View {

    let onCompleteOrSkip: () -> Void

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("timer_clock_style") private var timerClockStyleRaw: String = "flip"
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false
    @State private var timerVM = TimerViewModel()
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass)   private var vSizeClass
    @Environment(\.scenePhase)          private var scenePhase

    private var isIPad: Bool { hSizeClass == .regular }
    private var isLandscapePhone: Bool { vSizeClass == .compact }

    private var selectedStyle: TimerClockStyle {
        TimerClockStyle.resolved(rawValue: timerClockStyleRaw, isPremiumUser: isPremiumUser)
    }

    private var currentLocale: Locale {
        Locale(identifier: appLanguage)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header / Subtitle
                VStack(spacing: 6) {
                    Text(String(localized: "break_title", defaultValue: "MOLA VERİYORSUN", locale: currentLocale))
                        .font(.system(size: isIPad ? 22 : 16, weight: .light, design: .rounded))
                        .foregroundStyle(Color(white: 0.5))
                        .tracking(4)
                        .textCase(.uppercase)

                    Text(String(localized: "break_subtitle", defaultValue: "Soluklan, dinlen ve zihnini serbest bırak", locale: currentLocale))
                        .font(.system(size: isIPad ? 14 : 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.35))
                }
                .padding(.top, isIPad ? 48 : 32)

                Spacer(minLength: 0)

                // Clock Display with Calmer Dimmed Opacity
                TimerClockDisplayView(
                    style: selectedStyle,
                    hours: timerVM.hours,
                    minutes: timerVM.minutes,
                    seconds: timerVM.seconds,
                    showHours: false,
                    showSeconds: true,
                    isRunning: timerVM.isRunning,
                    remainingSeconds: timerVM.remainingSeconds,
                    totalSeconds: timerVM.totalDuration
                )
                .opacity(0.72)
                .layoutPriority(1)

                Spacer(minLength: 0)

                // Skip Break Button
                Button {
                    timerVM.pause()
                    onCompleteOrSkip()
                } label: {
                    HStack(spacing: 6) {
                        Text(String(localized: "skip_break", defaultValue: "Molayı Atla", locale: currentLocale))
                            .font(.system(size: isIPad ? 16 : 14, weight: .medium, design: .rounded))
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.08))
                            .overlay(Capsule().strokeBorder(Color(white: 0.16), lineWidth: 0.5))
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, isIPad ? 48 : 32)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            timerVM.setDuration(300) // 5 minutes
            timerVM.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timerVM.syncWithCurrentTime()
            }
        }
        .onChange(of: timerVM.isCompleted) { _, completed in
            if completed {
                onCompleteOrSkip()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BreakView(onCompleteOrSkip: {})
}
