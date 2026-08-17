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

/// Reusable branded loading indicator featuring a breathing logo animation,
/// optional status message, and graceful cancellation option for long-running network tasks.
struct LoadingIndicatorView: View {

    var messageKey: LocalizedStringKey? = nil
    var message: String? = nil
    var onCancel: (() -> Void)? = nil
    var showCancelAfter: TimeInterval = 3.0

    @State private var breathePulse: Bool = false
    @State private var allowCancel: Bool = false

    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isIPad: Bool { hSizeClass == .regular }

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                // Breathing Logo Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1.5)
                        .frame(width: isIPad ? 76 : 64, height: isIPad ? 76 : 64)

                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isIPad ? 48 : 40, height: isIPad ? 48 : 40)
                        .opacity(breathePulse ? 1.0 : 0.45)
                        .scaleEffect(breathePulse ? 1.05 : 0.94)
                }

                // Optional Message
                if let key = messageKey {
                    Text(key)
                        .font(.system(size: isIPad ? 15 : 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                } else if let msg = message {
                    Text(msg)
                        .font(.system(size: isIPad ? 15 : 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.75))
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
            .padding(.vertical, isIPad ? 28 : 22)
            .padding(.horizontal, isIPad ? 36 : 28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color(white: 0.18), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                breathePulse = true
            }

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

/// Convenience typealias for LoadingIndicatorView when used as a transition overlay.
typealias YonderTransitionOverlay = LoadingIndicatorView

// MARK: - Preview

#Preview {
    LoadingIndicatorView(messageKey: "create_room_loading", onCancel: {})
}
