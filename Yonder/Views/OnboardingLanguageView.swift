//
//  OnboardingLanguageView.swift
//  Yonder
//
//  First-launch language selection screen.
//  Independent layout centered across all iOS device dimensions.
//

import SwiftUI

struct OnboardingLanguageView: View {
    let onSelectLanguage: (String) -> Void

    @State private var appear: Bool = false
    @Environment(\.horizontalSizeClass) private var hSizeClass

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

                // Ambient glow
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
                            Spacer(minLength: max(geometry.safeAreaInsets.top + 20, 48))

                            // Logo & Brand
                            VStack(spacing: isIPad ? 16 : 12) {
                                Image("SplashLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: isIPad ? 64 : 52, height: isIPad ? 64 : 52)

                                Text("YONDER")
                                    .font(.system(size: isIPad ? 16 : 13, weight: .light, design: .rounded))
                                    .foregroundStyle(Color(white: 0.4))
                                    .tracking(8)
                            }
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 10)

                            Spacer().frame(height: isIPad ? 48 : 36)

                            // Title & Subtitle
                            VStack(spacing: 8) {
                                Text("Choose your language")
                                    .font(.system(size: isIPad ? 26 : 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.85)

                                Text("Dilini seç")
                                    .font(.system(size: isIPad ? 17 : 15, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color(white: 0.5))
                                    .multilineTextAlignment(.center)
                            }
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 8)

                            Spacer().frame(height: isIPad ? 40 : 28)

                            // Language Buttons
                            VStack(spacing: 14) {
                                languageButton(
                                    code: "en",
                                    nativeName: "English",
                                    subtitle: "Continue in English"
                                )
                                languageButton(
                                    code: "tr",
                                    nativeName: "Türkçe",
                                    subtitle: "Türkçe devam et"
                                )
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
    }

    private func languageButton(code: String, nativeName: String, subtitle: String) -> some View {
        Button {
            HapticService.light()
            onSelectLanguage(code)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(nativeName)
                        .font(.system(size: isIPad ? 19 : 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: isIPad ? 13 : 12, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
            }
            .padding(.horizontal, isIPad ? 22 : 18)
            .frame(maxWidth: .infinity)
            .frame(height: isIPad ? 68 : 60)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(LanguagePressableStyle())
    }
}

private struct LanguagePressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingLanguageView(onSelectLanguage: { _ in })
}
