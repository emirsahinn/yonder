//
//  ClockView.swift
//  Yonder
//
//  Passive full-screen real-time wall clock display.
//  Shows current time (HH:MM:SS) updating live every second,
//  rendering dynamically according to user's selected Clock Style (Flip, Digital, Minimal).
//

import SwiftUI
import Combine
import UIKit

struct ClockView: View {

    /// Called the instant the user taps close, before the dismiss animation and
    /// the portrait-lock rotation start — lets the presenter mask the brief
    /// landscape flash that would otherwise show while both animations settle.
    var onWillDismiss: (() -> Void)? = nil

    @AppStorage("show_clock_seconds") private var showClockSeconds: Bool = true
    @AppStorage("use_24_hour_clock") private var use24HourClock: Bool = true
    @AppStorage("timer_clock_style") private var timerClockStyleRaw: String = "flip"
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass)   private var vSizeClass

    @State private var nowDate: Date = Date()
    @State private var showControls: Bool = true
    @State private var hideTask: Task<Void, Never>? = nil
    @State private var isClosingToPortrait: Bool = false
    @State private var closeTask: Task<Void, Never>? = nil

    private var isIPad: Bool { hSizeClass == .regular }
    private var isLandscapePhone: Bool { vSizeClass == .compact }

    private var selectedStyle: TimerClockStyle {
        TimerClockStyle.resolved(rawValue: timerClockStyleRaw, isPremiumUser: isPremiumUser)
    }

    private var hours: Int {
        let hour = Calendar.current.component(.hour, from: nowDate)
        if use24HourClock {
            return hour
        }
        let hour12 = hour % 12
        return hour12 == 0 ? 12 : hour12
    }

    private var minutes: Int {
        Calendar.current.component(.minute, from: nowDate)
    }

    private var seconds: Int {
        Calendar.current.component(.second, from: nowDate)
    }

    private var meridiemText: String? {
        guard !use24HourClock else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "a"
        return formatter.string(from: nowDate)
    }

    private let timerPublisher = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Pure black background — tap to toggle close button
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showControls.toggle()
                    }
                    if showControls { scheduleHideControls() }
                }

            // True Center Clock Display
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                TimerClockDisplayView(
                    style: selectedStyle,
                    hours: hours,
                    minutes: minutes,
                    seconds: seconds,
                    showHours: true,
                    showSeconds: showClockSeconds,
                    isRunning: true,
                    meridiemText: meridiemText
                )
                .padding(.horizontal, isIPad ? 60 : 20)

                Spacer(minLength: 0)
            }

            // Top Bar Overlay
            VStack {
                HStack {
                    Spacer()

                    Button {
                        closeToHome()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: isIPad ? 18 : 15, weight: .medium))
                            .foregroundStyle(Color(white: 0.5))
                            .padding(isIPad ? 14 : 10)
                            .background(
                                Circle()
                                    .fill(Color(white: 0.12))
                                    .overlay(Circle().strokeBorder(Color(white: 0.20), lineWidth: 0.5))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, isIPad ? 32 : 16)
                    .padding(.trailing, isIPad ? 32 : 20)
                    .opacity(showControls ? 1.0 : 0.0)
                    .disabled(!showControls || isClosingToPortrait)
                }

                Spacer()
            }

            if isClosingToPortrait {
                YonderTransitionOverlay(message: "Yonder")
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .rotatesForPhoneUpsideDown()
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .interactiveDismissDisabled(true)
        .allowsPhoneLandscape("clock")
        .onReceive(timerPublisher) { input in
            nowDate = input
        }
        .onAppear {
            scheduleHideControls()
        }
        .onDisappear {
            closeTask?.cancel()
            hideTask?.cancel()
        }
    }

    private func scheduleHideControls() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
    }

    private func closeToHome() {
        guard !isClosingToPortrait else { return }
        hideTask?.cancel()
        onWillDismiss?()
        withAnimation(.easeInOut(duration: 0.18)) {
            isClosingToPortrait = true
            showControls = false
        }
        OrientationLock.shared.lockPhonePortrait("clock")

        let shouldDelayForRotation = YonderPortraitTransition.shouldMask(verticalSizeClass: vSizeClass)

        closeTask = Task {
            let delay = YonderPortraitTransition.delayNanoseconds(needsMask: shouldDelayForRotation)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ClockView()
}
