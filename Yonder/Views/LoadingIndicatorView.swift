//
//  LoadingIndicatorView.swift
//  Yonder
//

import SwiftUI
import UIKit

/// Helper for executing async operations with a minimum display duration (default 0.45s)
/// to ensure a calm, smooth transition without visual flashing.
enum YonderTransitionHelper {
    static func withMinimumDuration(seconds: Double = 0.45, _ action: @escaping () async -> Void) async {
        let start = Date()
        await action()
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < seconds {
            let remaining = seconds - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }
}

/// Shared timing for exits from landscape-allowed focus screens back into portrait-only UI.
enum YonderPortraitTransition {
    static func shouldMask(verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone
            && (verticalSizeClass == .compact || UIDevice.current.orientation.isLandscape)
    }

    static func delayNanoseconds(needsMask: Bool) -> UInt64 {
        needsMask ? 700_000_000 : 120_000_000
    }
}

/// Reusable transition/loading indicator with optional status message and graceful
/// cancellation option for long-running network tasks.
struct LoadingIndicatorView: View {

    var messageKey: LocalizedStringKey? = nil
    var message: String? = nil
    var onCancel: (() -> Void)? = nil
    var showCancelAfter: TimeInterval = 3.0

    @State private var allowCancel: Bool = false

    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isIPad: Bool { hSizeClass == .regular }

    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()

            VStack(spacing: messageKey == nil && message == nil ? 0 : 12) {
                HourglassTransitionMark(size: isIPad ? 58 : 50)

                if let key = messageKey {
                    Text(key)
                        .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.68))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                } else if let msg = message {
                    Text(msg)
                        .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.68))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Optional Cancel Action (appears after 3 seconds if task hangs)
                if allowCancel, let cancelAction = onCancel {
                    Button {
                        cancelAction()
                    } label: {
                        Text("cancel_button")
                            .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(white: 0.12))
                                    .overlay(Capsule().strokeBorder(Color(white: 0.2), lineWidth: 0.5))
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.vertical, isIPad ? 18 : 15)
            .padding(.horizontal, isIPad ? 28 : 22)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.085).opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
        }
        .onAppear {
            if onCancel != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + showCancelAfter) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        allowCancel = true
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct HourglassTransitionMark: View {
    let size: CGFloat

    @State private var rotation: Double = 0
    @State private var sandShift: Bool = false
    @State private var glint: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.055))

            Circle()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)

            Image(systemName: "hourglass")
                .font(.system(size: size * 0.47, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.white.opacity(0.92), Color.white.opacity(0.42))
                .rotationEffect(.degrees(rotation))
                .shadow(color: Color.white.opacity(0.12), radius: 8)

            VStack(spacing: 3) {
                sandDot(delay: 0.0)
                sandDot(delay: 0.18)
                sandDot(delay: 0.36)
            }
            .offset(y: sandShift ? size * 0.15 : -size * 0.15)
            .opacity(sandShift ? 0.18 : 0.75)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.30), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.10, height: size * 0.66)
                .rotationEffect(.degrees(30))
                .offset(x: glint ? size * 0.24 : -size * 0.24)
                .opacity(glint ? 0.0 : 0.55)
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: false)) {
                rotation = 180
            }

            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: false)) {
                sandShift = true
            }

            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: false)) {
                glint = true
            }
        }
    }

    private func sandDot(delay: Double) -> some View {
        Circle()
            .fill(Color.white.opacity(0.72))
            .frame(width: size * 0.045, height: size * 0.045)
            .scaleEffect(sandShift ? 0.65 : 1.0)
            .animation(.easeInOut(duration: 1.45).delay(delay).repeatForever(autoreverses: false), value: sandShift)
    }
}

/// Convenience typealias for LoadingIndicatorView when used as a transition overlay.
typealias YonderTransitionOverlay = LoadingIndicatorView

// MARK: - Preview

#Preview {
    LoadingIndicatorView(messageKey: "create_room_loading", onCancel: {})
}
