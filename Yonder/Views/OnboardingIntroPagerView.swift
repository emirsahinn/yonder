//
//  OnboardingIntroPagerView.swift
//  Yonder
//
//  4-page horizontal intro pager shown during onboarding.
//  Independent layout from language selection screen.
//

import SwiftUI

private let onboardingAccentColors: [Color] = [
    Color(red: 0.58, green: 0.64, blue: 0.99),  // page 1 — cool blue/violet
    Color(red: 0.98, green: 0.72, blue: 0.45),  // page 2 — warm amber
    Color(red: 0.48, green: 0.88, blue: 0.78),  // page 3 — mint/teal
    Color(red: 0.95, green: 0.78, blue: 0.35)   // page 4 — signature gold (matches PRO accent)
]

private struct IntroMetrics {
    let width: CGFloat
    let height: CGFloat
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let isRegularWidth: Bool
    let isCompactHeight: Bool

    init(size: CGSize, safeAreaInsets: EdgeInsets, hSizeClass: UserInterfaceSizeClass?, vSizeClass: UserInterfaceSizeClass?) {
        let shouldUsePortraitViewport = hSizeClass != .regular && size.width > size.height
        self.width = shouldUsePortraitViewport ? min(size.width, size.height) : size.width
        self.height = shouldUsePortraitViewport ? max(size.width, size.height) : size.height
        self.safeTop = safeAreaInsets.top
        self.safeBottom = safeAreaInsets.bottom
        self.isRegularWidth = hSizeClass == .regular && self.width >= 700
        self.isCompactHeight = vSizeClass == .compact || self.height < 620
    }

    var isVeryShort: Bool { height < 430 }
    var isShort: Bool { height < 620 }
    var isLandscape: Bool { width > height || isCompactHeight }
    var effectiveSafeTop: CGFloat {
        if isRegularWidth { return max(safeTop, 24) }
        if isLandscape { return max(safeTop, 12) }
        return max(safeTop, 64)
    }
    var effectiveSafeBottom: CGFloat {
        if isLandscape { return max(safeBottom, 8) }
        return max(safeBottom, 20)
    }
    var contentSafeTop: CGFloat {
        if isRegularWidth { return max(safeTop, 18) }
        if isLandscape { return max(safeTop, 8) }
        return max(safeTop, 24)
    }

    var horizontalPadding: CGFloat {
        min(max(width * (isRegularWidth ? 0.07 : 0.055), 18), isRegularWidth ? 72 : 28)
    }

    var contentMaxWidth: CGFloat {
        max(220, min(width * 0.82, width - (horizontalPadding * 2), isRegularWidth ? 720 : 390))
    }

    var topBarWidth: CGFloat {
        max(220, min(width * 0.84, width - (horizontalPadding * 2), isRegularWidth ? 640 : 360))
    }

    var progressBarWidth: CGFloat {
        topBarWidth * (isRegularWidth ? 0.78 : 0.68)
    }

    var topBarPadding: CGFloat {
        effectiveSafeTop + (isVeryShort ? 12 : 22)
    }

    var bottomButtonPadding: CGFloat {
        effectiveSafeBottom + (isVeryShort ? 10 : 22)
    }

    var topChromeReserve: CGFloat {
        contentSafeTop + (isVeryShort ? 38 : (isShort ? 48 : 58))
    }

    var bottomChromeReserve: CGFloat {
        effectiveSafeBottom + (isVeryShort ? 74 : (isShort ? 90 : 108))
    }

    var pageGap: CGFloat {
        isVeryShort ? 18 : (isShort ? 28 : (isRegularWidth ? 58 : 44))
    }

    var titleSize: CGFloat {
        isVeryShort ? 21 : (isRegularWidth ? 32 : 26)
    }

    var largeTitleSize: CGFloat {
        isVeryShort ? 23 : (isRegularWidth ? 36 : 30)
    }

    var subtitleSize: CGFloat {
        isVeryShort ? 13 : (isRegularWidth ? 18 : 15)
    }

    var textHorizontalInset: CGFloat {
        isRegularWidth ? 44 : 20
    }

    var nextButtonWidth: CGFloat {
        max(220, min(width * 0.82, width - (horizontalPadding * 2), isRegularWidth ? 440 : 390))
    }

    var nextButtonHeight: CGFloat {
        isVeryShort ? 46 : (isRegularWidth ? 56 : 50)
    }

    func illustrationScale(phone: CGFloat = 1.0, regular: CGFloat = 1.35) -> CGFloat {
        if isVeryShort { return 0.58 }
        if isShort { return 0.82 }
        return isRegularWidth ? regular : phone
    }

    var heatmapCellSpacing: CGFloat {
        isVeryShort ? 4 : (isRegularWidth ? 8 : 6)
    }

    var heatmapCellSize: CGFloat {
        let maxPreferred: CGFloat = isRegularWidth ? 38 : 28
        let available = contentMaxWidth - (heatmapCellSpacing * 6)
        return min(maxPreferred, max(18, available / 7))
    }
}

struct OnboardingIntroPagerView: View {
    var onFinished: () -> Void

    @State private var currentPage: Int = 0
    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    private let totalPages = 4

    private var currentAccent: Color {
        onboardingAccentColors[min(currentPage, onboardingAccentColors.count - 1)]
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = IntroMetrics(
                size: geo.size,
                safeAreaInsets: geo.safeAreaInsets,
                hSizeClass: hSizeClass,
                vSizeClass: vSizeClass
            )

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                // Ambient Glow
                ForEach(Array(onboardingAccentColors.enumerated()), id: \.offset) { index, color in
                    OnboardingAmbientGlow(color: color)
                        .opacity(currentPage == index ? 1 : 0)
                        .animation(.easeInOut(duration: 0.7), value: currentPage)
                }

                // TabView Pages
                TabView(selection: $currentPage) {
                    IntroPage1(metrics: metrics).tag(0)
                    IntroPage2(metrics: metrics).tag(1)
                    IntroPage3(metrics: metrics).tag(2)
                    IntroPage4(metrics: metrics, onFinished: onFinished).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.4), value: currentPage)
                .frame(width: metrics.width, height: geo.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                // Top Bar: Progress + Skip
                VStack {
                    HStack(spacing: 14) {
                        OnboardingProgressBar(totalPages: totalPages, currentPage: currentPage, accent: currentAccent)
                            .frame(width: metrics.progressBarWidth)

                        if currentPage < totalPages - 1 {
                            Button {
                                onFinished()
                            } label: {
                                Text("onboarding_skip")
                                    .font(.system(size: metrics.isRegularWidth ? 14 : 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(white: 0.7))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(.white.opacity(0.08))
                                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                                    )
                            }
                            .buttonStyle(IntroPressableStyle())
                            .transition(.opacity)
                        }
                    }
                    .frame(width: metrics.topBarWidth)
                    .padding(.top, metrics.topBarPadding)

                    Spacer()
                }
                .frame(width: metrics.width, height: geo.size.height, alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                // Bottom Next Button (pages 0-2)
                if currentPage < totalPages - 1 {
                    VStack {
                        Spacer()
                        nextButton(metrics: metrics)
                    }
                    .frame(width: metrics.width, height: geo.size.height, alignment: .bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.locale, Locale(identifier: appLanguage))
    }

    private func nextButton(metrics: IntroMetrics) -> some View {
        Button {
            HapticService.light()
            withAnimation(.easeInOut(duration: 0.35)) {
                currentPage += 1
            }
        } label: {
            HStack(spacing: 8) {
                Text("onboarding_next")
                    .font(.system(size: metrics.isRegularWidth ? 18 : 16, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: metrics.isRegularWidth ? 15 : 13, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: metrics.nextButtonHeight)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: currentAccent.opacity(0.45), radius: 20, y: 6)
            )
        }
        .buttonStyle(IntroPressableStyle())
        .frame(width: metrics.nextButtonWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, metrics.bottomButtonPadding)
    }
}

// MARK: - Components

private struct OnboardingAmbientGlow: View {
    let color: Color
    @State private var pulse: Bool = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.32), color.opacity(0.10), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 260
                )
            )
            .frame(width: 520, height: 520)
            .blur(radius: 60)
            .scaleEffect(pulse ? 1.08 : 0.92)
            .offset(y: -80)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

private struct OnboardingProgressBar: View {
    let totalPages: Int
    let currentPage: Int
    var accent: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? accent : Color.white.opacity(0.14))
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentPage)
    }
}

private struct IntroPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct IntroEyebrow: View {
    let index: Int
    let accent: Color
    var isIPad: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(accent)
                .frame(width: 14, height: 2.5)

            Text(String(format: "%02d", index + 1))
                .font(.system(size: isIPad ? 13 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .tracking(2)
        }
    }
}

private struct IntroTextBlock: View {
    let eyebrowIndex: Int
    let accent: Color
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let metrics: IntroMetrics
    var titleSize: CGFloat? = nil

    var body: some View {
        VStack(spacing: metrics.isVeryShort ? 10 : 16) {
            IntroEyebrow(index: eyebrowIndex, accent: accent, isIPad: metrics.isRegularWidth)

            Text(titleKey)
                .font(.system(size: titleSize ?? metrics.titleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .tracking(0.2)
                .lineLimit(3)
                .minimumScaleFactor(0.76)

            Text(subtitleKey)
                .font(.system(size: metrics.subtitleSize, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, metrics.textHorizontalInset)
        }
        .frame(maxWidth: metrics.contentMaxWidth)
    }
}

// MARK: - Pages

private struct IntroPage1: View {
    let metrics: IntroMetrics
    @State private var breatheScale: CGFloat = 0.92
    @State private var glowOpacity: Double = 0.25
    @State private var appear: Bool = false
    private var accent: Color { onboardingAccentColors[0] }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: metrics.topChromeReserve)

                ZStack {
                    Circle()
                        .stroke(accent.opacity(glowOpacity), lineWidth: 1)
                        .frame(width: 190, height: 190)
                        .scaleEffect(breatheScale * 1.12)
                        .animation(
                            .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                            value: breatheScale
                        )

                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        .frame(width: 150, height: 150)

                    Circle()
                        .trim(from: 0.0, to: 0.28)
                        .stroke(
                            LinearGradient(
                                colors: [.clear, accent.opacity(0.7), accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: accent.opacity(0.6), radius: 4)

                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .scaleEffect(breatheScale)
                        .animation(
                            .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                            value: breatheScale
                        )
                }
                .frame(width: 190, height: 190)
                .scaleEffect(metrics.illustrationScale(regular: 1.32))
                .frame(
                    width: 190 * metrics.illustrationScale(regular: 1.32),
                    height: 190 * metrics.illustrationScale(regular: 1.32)
                )
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.9)
                .offset(y: appear ? 0 : 12)

                Spacer().frame(height: metrics.pageGap)

                IntroTextBlock(
                    eyebrowIndex: 0,
                    accent: accent,
                    titleKey: "onboarding_page1_title",
                    subtitleKey: "onboarding_page1_subtitle",
                    metrics: metrics
                )
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)

                Spacer(minLength: metrics.bottomChromeReserve)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: metrics.height)
            .padding(.horizontal, metrics.horizontalPadding)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                breatheScale = 1.04
                glowOpacity = 0.55
            }
        }
    }
}

private struct IntroPage2: View {
    let metrics: IntroMetrics
    @State private var appear: Bool = false
    @State private var handAngle: Double = -90
    private var accent: Color { onboardingAccentColors[1] }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: metrics.topChromeReserve)

                ZStack {
                    Circle()
                        .stroke(Color(white: 0.2), lineWidth: 1)
                        .frame(width: 150, height: 150)

                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(i % 3 == 0 ? accent.opacity(0.85) : Color(white: 0.3))
                            .frame(width: 1.5, height: i % 3 == 0 ? 8 : 4)
                            .offset(y: -67)
                            .rotationEffect(.degrees(Double(i) * 30))
                    }

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.8))
                        .frame(width: 2, height: 48)
                        .offset(y: -24)
                        .rotationEffect(.degrees(0))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent)
                        .frame(width: 2.5, height: 32)
                        .offset(y: -16)
                        .rotationEffect(.degrees(handAngle))
                        .shadow(color: accent.opacity(0.5), radius: 3)

                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                }
                .frame(width: 170, height: 170)
                .scaleEffect(metrics.illustrationScale(regular: 1.32))
                .frame(
                    width: 170 * metrics.illustrationScale(regular: 1.32),
                    height: 170 * metrics.illustrationScale(regular: 1.32)
                )
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.9)
                .offset(y: appear ? 0 : 12)

                Spacer().frame(height: metrics.pageGap)

                IntroTextBlock(
                    eyebrowIndex: 1,
                    accent: accent,
                    titleKey: "onboarding_page2_title",
                    subtitleKey: "onboarding_page2_subtitle",
                    metrics: metrics
                )
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)

                Spacer(minLength: metrics.bottomChromeReserve)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: metrics.height)
            .padding(.horizontal, metrics.horizontalPadding)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                handAngle = 60
            }
        }
    }
}

private struct IntroPage3: View {
    let metrics: IntroMetrics
    @AppStorage("app_language") private var appLanguage: String = "en"
    @State private var appear: Bool = false
    @State private var filledCells: Set<Int> = []
    private var accent: Color { onboardingAccentColors[2] }

    private let columns = 7
    private let rows = 4
    private let fillPattern: [Int] = [0,1,2,4,5,7,8,9,11,14,15,16,17,19,20,21,22,23,25,26]

    private var cellSize: CGFloat { metrics.heatmapCellSize }
    private var cellSpacing: CGFloat { metrics.heatmapCellSpacing }

    private var dayLabels: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        let symbols = formatter.veryShortStandaloneWeekdaySymbols
        let order = [1, 2, 3, 4, 5, 6, 0]
        return order.compactMap { idx in
            guard idx < (symbols?.count ?? 0) else { return nil }
            return symbols?[idx].uppercased()
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: metrics.topChromeReserve)

                VStack(spacing: cellSpacing) {
                    HStack(spacing: cellSpacing) {
                        ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, day in
                            Text(day)
                                .font(.system(size: metrics.isRegularWidth ? 12 : 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.35))
                                .frame(width: cellSize)
                        }
                    }

                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<columns, id: \.self) { col in
                                let idx = row * columns + col
                                let isFilled = filledCells.contains(idx)
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isFilled ? accent.opacity(0.85) : Color(white: 0.12))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .strokeBorder(isFilled ? accent : Color(white: 0.2), lineWidth: 0.5)
                                    )
                                    .scaleEffect(isFilled ? 1.0 : 0.88)
                                    .animation(
                                        .spring(response: 0.4, dampingFraction: 0.65)
                                            .delay(Double(idx) * 0.04),
                                        value: filledCells
                                    )
                            }
                        }
                    }
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 14)

                Spacer().frame(height: metrics.pageGap)

                IntroTextBlock(
                    eyebrowIndex: 2,
                    accent: accent,
                    titleKey: "onboarding_page3_title",
                    subtitleKey: "onboarding_page3_subtitle",
                    metrics: metrics
                )
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)

                Spacer(minLength: metrics.bottomChromeReserve)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: metrics.height)
            .padding(.horizontal, metrics.horizontalPadding)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                appear = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                fillPattern.forEach { idx in
                    filledCells.insert(idx)
                }
            }
        }
        .onDisappear {
            filledCells = []
        }
    }
}

private struct IntroPage4: View {
    let metrics: IntroMetrics
    var onFinished: () -> Void
    @AppStorage("app_language") private var appLanguage: String = "en"
    @State private var appear: Bool = false
    private var accent: Color { onboardingAccentColors[3] }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: metrics.topChromeReserve)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        .frame(width: 150, height: 150)

                    Circle()
                        .trim(from: 0.0, to: 0.25)
                        .stroke(
                            LinearGradient(
                                colors: [.clear, accent.opacity(0.6), accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-45))
                        .shadow(color: accent.opacity(0.5), radius: 3)

                    Circle()
                        .stroke(accent.opacity(0.35), lineWidth: 1)
                        .frame(width: 110, height: 110)

                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                }
                .frame(width: 150, height: 150)
                .scaleEffect(metrics.illustrationScale(regular: 1.32))
                .frame(
                    width: 150 * metrics.illustrationScale(regular: 1.32),
                    height: 150 * metrics.illustrationScale(regular: 1.32)
                )
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.85)

                Spacer().frame(height: metrics.pageGap)

                IntroTextBlock(
                    eyebrowIndex: 3,
                    accent: accent,
                    titleKey: "onboarding_page4_title",
                    subtitleKey: "onboarding_page4_subtitle",
                    metrics: metrics,
                    titleSize: metrics.largeTitleSize
                )
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)

                Spacer().frame(height: metrics.isVeryShort ? 22 : 40)

                Button {
                    HapticService.medium()
                    onFinished()
                } label: {
                    HStack(spacing: 8) {
                        Text(appLanguage == "tr" ? "İlk ritmini başlat" : "Start your first rhythm")
                            .font(.system(size: metrics.isRegularWidth ? 20 : 18, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Image(systemName: "arrow.right")
                            .font(.system(size: metrics.isRegularWidth ? 16 : 14, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.nextButtonHeight + 4)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: accent.opacity(0.55), radius: 22, y: 8)
                    )
                }
                .buttonStyle(IntroPressableStyle())
                .frame(width: metrics.nextButtonWidth)
                .opacity(appear ? 1 : 0)

                Spacer(minLength: max(metrics.effectiveSafeBottom + 20, 36))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: metrics.height)
            .padding(.horizontal, metrics.horizontalPadding)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                appear = true
            }
        }
    }
}

#Preview {
    OnboardingIntroPagerView(onFinished: {})
}
