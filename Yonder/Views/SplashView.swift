//
//  SplashView.swift
//  Yonder
//

import SwiftUI

/// Animated splash screen shown once after the native launch screen dismisses.
///
/// Sequence:
/// 1. Logo + LED Light Ring fade in and scale up over 0.6 s.
/// 2. LED light arc rotates continuously (360° repeatForever) around the logo.
/// 3. "YONDER" text fades in 0.2 s later.
/// 4. After total ~1.4 s dwell time, `onFinished` callback triggers crossfade to HomeView.
struct SplashView: View {

    /// Called when the splash sequence is complete — parent flips to HomeView.
    var onFinished: () -> Void

    @State private var logoOpacity:   Double = 0
    @State private var logoScale:     Double = 0.88
    @State private var titleOpacity:  Double = 0
    @State private var rotationAngle: Double = 0

    @Environment(\.verticalSizeClass) private var vSizeClass

    private var containerHeight: CGFloat {
        vSizeClass == .compact ? 160 : 250
    }

    var body: some View {
        ZStack {
            // Exact same near-black as the native launch screen
            Color(red: 0.039, green: 0.039, blue: 0.039)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // ── Logo + LED Ring ───────────────────────────────────────
                GeometryReader { geo in
                    let maxDimension = min(geo.size.width, geo.size.height)
                    let logoSide = maxDimension * 0.36
                    let ringSize = logoSide * 1.38

                    ZStack {
                        // 1. Static base ring
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1.5)

                        // 2. Soft outer glow of the LED light arc
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [.clear, .clear, .clear, Color.white.opacity(0.4), Color.white],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .blur(radius: 4)
                            .rotationEffect(.degrees(rotationAngle))

                        // 3. Sharp bright LED light arc (comet tail)
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [.clear, .clear, .clear, Color.white.opacity(0.3), Color.white],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .shadow(color: .white.opacity(0.8), radius: 3)
                            .rotationEffect(.degrees(rotationAngle))

                        // 4. Logo centered inside ring
                        Image("SplashLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: logoSide, height: logoSide)
                    }
                    .frame(width: ringSize, height: ringSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(height: containerHeight)
                .opacity(logoOpacity)
                .scaleEffect(logoScale)

                // ── Wordmark ──────────────────────────────────────────────
                Text("YONDER")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.82))
                    .tracking(12)
                    .opacity(titleOpacity)
            }
        }
        .onAppear { runSequence() }
    }

    // MARK: - Animation sequence

    private func runSequence() {
        // Continuous rotation for LED light arc
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Step 1 — logo and ring appear (0.6 s, easeOut)
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1
            logoScale   = 1.0
        }

        // Step 2 — wordmark fades in 0.2 s later
        withAnimation(.easeOut(duration: 0.45).delay(0.2)) {
            titleOpacity = 1
        }

        // Step 3 — Concurrently wait for animation dwell time (1.4s) AND Auth completion
        Task {
            let animTask = Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
            }
            let authTask = Task {
                await AuthService.shared.ensureSignedInAsync()
            }

            _ = await (animTask.value, authTask.value)

            await MainActor.run {
                onFinished()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SplashView(onFinished: {})
}

#Preview("Landscape", traits: .landscapeLeft) {
    SplashView(onFinished: {})
}
