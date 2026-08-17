//
//  TimerClockDisplayView.swift
//  Yonder
//
//  Unified responsive clock display supporting Yonder's timer and clock styles.
//  Scales gracefully across iPhone (portrait & landscape) and iPad,
//  ensuring digital and minimal styles stand out as primary visual elements.
//

import SwiftUI

struct TimerClockDisplayView: View {

    let style: TimerClockStyle
    let hours: Int
    let minutes: Int
    let seconds: Int
    var showHours: Bool = false
    var showSeconds: Bool = true
    var isRunning: Bool = true
    var customFormattedTime: String? = nil
    var remainingSeconds: Int? = nil
    var totalSeconds: Int? = nil
    var meridiemText: String? = nil

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var orbitRotation: Double = 0
    @State private var pulseScale: CGFloat = 1
    @State private var ambientShift: CGFloat = 0

    private var isIPad: Bool { hSizeClass == .regular }

    private var formattedTime: String {
        if let custom = customFormattedTime {
            return custom
        }
        if showHours || hours > 0 {
            if showSeconds {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", hours, minutes)
            }
        } else {
            if showSeconds {
                return String(format: "%02d:%02d", minutes, seconds)
            } else {
                return String(format: "%02d", minutes)
            }
        }
    }

    private func safeDimension(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return fallback }
        return value
    }

    private func safeFrameDimension(_ value: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return 1 }
        return value
    }

    private func clamped(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        guard value.isFinite else { return minValue }
        return Swift.max(minValue, Swift.min(value, maxValue))
    }

    private func typographySize(in size: CGSize, style: TimerClockStyle, isLandscape: Bool) -> CGFloat {
        let safeWidth = safeDimension(size.width, fallback: 320)
        let safeHeight = safeDimension(size.height, fallback: isLandscape ? 220 : 360)
        let characterCount = CGFloat(max(formattedTime.count, 1))
        let widthRatio: CGFloat = {
            switch style {
            case .minimal:
                return 0.48
            case .focusBar:
                return 0.56
            case .bloom:
                return 0.53
            case .rain, .orbit, .pulse, .glass, .liquid:
                return 0.54
            default:
                return 0.52
            }
        }()
        let heightRatio: CGFloat = {
            switch style {
            case .minimal:
                return 0.72
            case .focusBar:
                return 0.58
            case .bloom:
                return 0.62
            case .rain, .orbit, .pulse, .glass, .liquid:
                return 0.60
            default:
                return 0.66
            }
        }()
        let maximum: CGFloat = isIPad ? (style == .minimal ? 320 : 300) : (isLandscape ? 210 : 170)
        let minimum: CGFloat = isIPad ? 118 : (isLandscape ? 70 : 78)

        let sizeFromWidth = safeWidth / (characterCount * widthRatio)
        let sizeFromHeight = safeHeight * heightRatio
        return clamped(min(sizeFromWidth, sizeFromHeight), min: minimum, max: maximum)
    }

    private var progressRatio: CGFloat? {
        guard let totalSeconds, totalSeconds > 0, let remainingSeconds else { return nil }
        let elapsed = max(0, totalSeconds - remainingSeconds)
        return clamped(CGFloat(elapsed) / CGFloat(totalSeconds), min: 0, max: 1)
    }

    var body: some View {
        GeometryReader { geo in
            let safeWidth = safeFrameDimension(geo.size.width)
            let safeHeight = safeFrameDimension(geo.size.height)
            let isLandscape = safeWidth > safeHeight
            let minDimension = min(safeWidth, safeHeight)

            ZStack {
                switch style {
                case .flip:
                    FlipClockView(
                        hours: hours,
                        minutes: minutes,
                        seconds: seconds,
                        showHours: showHours || hours > 0,
                        isRunning: isRunning,
                        showSeconds: showSeconds
                    )
                    .frame(width: safeWidth * 0.96, height: minDimension * 0.80)

                case .digital:
                    let fontSize = typographySize(in: CGSize(width: safeWidth, height: safeHeight), style: .digital, isLandscape: isLandscape)

                    largeTimeText(
                        fontSize: fontSize,
                        weight: .semibold,
                        design: .rounded,
                        tracking: isIPad ? 3 : 2,
                        color: Color(white: 0.96)
                    )

                case .minimal:
                    let fontSize = typographySize(in: CGSize(width: safeWidth, height: safeHeight), style: .minimal, isLandscape: isLandscape)

                    largeTimeText(
                        fontSize: fontSize,
                        weight: .light,
                        design: .rounded,
                        tracking: isIPad ? 8 : 5,
                        color: Color(white: 0.92)
                    )

                case .focusBar:
                    let fontSize = typographySize(in: CGSize(width: safeWidth, height: safeHeight), style: .focusBar, isLandscape: isLandscape)

                    VStack(spacing: clamped(safeHeight * 0.08, min: 12, max: 34)) {
                        largeTimeText(
                            fontSize: fontSize,
                            weight: .medium,
                            design: .rounded,
                            tracking: isIPad ? 5 : 3,
                            color: Color(white: 0.95)
                        )

                        if let progressRatio {
                            GeometryReader { barGeo in
                                let barWidth = safeFrameDimension(barGeo.size.width)
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(white: 0.16))
                                    Capsule()
                                        .fill(Color(white: 0.88))
                                        .frame(width: max(3, barWidth * progressRatio))
                                }
                            }
                            .frame(width: clamped(safeWidth * 0.58, min: 120, max: isIPad ? 520 : 360), height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .bloom:
                    bloomClockView(width: safeWidth, height: safeHeight, isLandscape: isLandscape)

                case .rain:
                    rainClockView(width: safeWidth, height: safeHeight, isLandscape: isLandscape)

                case .orbit:
                    orbitClockView(width: safeWidth, height: safeHeight, isLandscape: isLandscape)

                case .pulse:
                    pulseClockView(width: safeWidth, height: safeHeight, isLandscape: isLandscape)

                case .glass:
                    glassClockView(width: safeWidth, height: safeHeight, isLandscape: isLandscape)

                case .liquid:
                    liquidClockView(width: safeWidth, height: safeHeight, isLandscape: isLandscape)
                }

                if let meridiemText {
                    meridiemBadge(meridiemText)
                        .padding(.trailing, clamped(safeWidth * 0.08, min: 12, max: 52))
                        .padding(.bottom, clamped(safeHeight * 0.08, min: 10, max: 36))
                        .frame(width: safeWidth, height: safeHeight, alignment: .bottomTrailing)
                }
            }
            .frame(width: safeWidth, height: safeHeight)
        }
        .onAppear {
            withAnimation(.linear(duration: 36).repeatForever(autoreverses: false)) {
                orbitRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
            withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
                ambientShift = 1
            }
        }
    }

    private func largeTimeText(
        fontSize: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        tracking: CGFloat,
        color: Color
    ) -> some View {
        Text(formattedTime)
            .font(.system(size: fontSize, weight: weight, design: design))
            .foregroundStyle(color)
            .tracking(tracking)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func meridiemBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: isIPad ? 22 : 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(white: 0.82))
            .tracking(1.8)
            .monospaced()
            .padding(.horizontal, isIPad ? 14 : 10)
            .padding(.vertical, isIPad ? 7 : 5)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.42))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7))
            )
    }

    private func rainClockView(width: CGFloat, height: CGFloat, isLandscape: Bool) -> some View {
        let minDimension = min(width, height)
        let lineCount = 32
        let fontSize = typographySize(in: CGSize(width: width, height: height), style: .rain, isLandscape: isLandscape)
        let lineHeight = clamped(minDimension * 0.22, min: 34, max: isIPad ? 120 : 78)
        let spreadX = clamped(width * 0.92, min: 240, max: isIPad ? 820 : 500)
        let spreadY = clamped(height * 0.78, min: 140, max: isIPad ? 390 : 280)
        let panelWidth = clamped(width * 0.80, min: 220, max: isIPad ? 720 : 460)
        let panelHeight = clamped(height * 0.50, min: 125, max: isIPad ? 300 : 210)

        return ZStack {
            RoundedRectangle(cornerRadius: clamped(panelHeight * 0.12, min: 18, max: 34), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.03, green: 0.08, blue: 0.12).opacity(0.96),
                            Color(red: 0.02, green: 0.03, blue: 0.05).opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: clamped(panelHeight * 0.12, min: 18, max: 34), style: .continuous)
                        .strokeBorder(Color(red: 0.45, green: 0.65, blue: 0.78).opacity(0.22), lineWidth: 1)
                )
                .frame(width: panelWidth, height: panelHeight)

            ForEach(0..<lineCount, id: \.self) { index in
                let xProgress = CGFloat(index) / CGFloat(max(lineCount - 1, 1))
                let xOffset = (xProgress - 0.5) * spreadX
                let yBase = CGFloat((index * 37) % 100) / 100
                let yOffset = (yBase - 0.5) * spreadY + (ambientShift - 0.5) * CGFloat(index.isMultiple(of: 2) ? 22 : -16)
                Capsule(style: .continuous)
                    .fill(Color(red: 0.60, green: 0.82, blue: 0.98).opacity(index.isMultiple(of: 4) ? 0.34 : 0.18))
                    .frame(width: index.isMultiple(of: 5) ? 2.2 : 1.2, height: lineHeight * (index.isMultiple(of: 2) ? 0.72 : 1.0))
                    .rotationEffect(.degrees(16))
                    .offset(x: xOffset, y: yOffset)
                    .blendMode(.screen)
            }

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(red: 0.58, green: 0.78, blue: 0.92).opacity(0.30))
                .frame(width: panelWidth * 0.58, height: 1)
                .offset(y: panelHeight * 0.28)

            Text(formattedTime)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.97))
                .tracking(isIPad ? 4 : 2.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.34)
                .shadow(color: Color(red: 0.50, green: 0.72, blue: 0.94).opacity(0.42), radius: 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func orbitClockView(width: CGFloat, height: CGFloat, isLandscape: Bool) -> some View {
        let minDimension = min(width, height)
        let fontSize = typographySize(in: CGSize(width: width, height: height), style: .orbit, isLandscape: isLandscape)
        let orbitSize = clamped(minDimension * 0.84, min: 168, max: isIPad ? 510 : 330)
        let dotSize = clamped(minDimension * 0.04, min: 7, max: 17)

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.08, green: 0.11, blue: 0.16).opacity(0.92),
                            Color.black.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: orbitSize * 0.62
                    )
                )
                .frame(width: orbitSize * 1.14, height: orbitSize * 1.14)

            Circle()
                .strokeBorder(Color(white: 0.36).opacity(0.52), lineWidth: 1.2)
                .frame(width: orbitSize, height: orbitSize)

            Circle()
                .strokeBorder(Color(red: 0.58, green: 0.84, blue: 0.96).opacity(0.30), lineWidth: 1)
                .frame(width: orbitSize * 0.68, height: orbitSize * 0.68)

            Circle()
                .trim(from: 0.06, to: 0.34)
                .stroke(Color(red: 0.82, green: 0.95, blue: 1.0).opacity(0.75), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: orbitSize, height: orbitSize)
                .rotationEffect(.degrees(orbitRotation))

            Circle()
                .trim(from: 0.58, to: 0.78)
                .stroke(Color(red: 1.0, green: 0.90, blue: 0.62).opacity(0.42), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: orbitSize * 0.68, height: orbitSize * 0.68)
                .rotationEffect(.degrees(-orbitRotation * 0.62))

            ZStack {
                Circle()
                    .fill(Color(red: 0.76, green: 0.94, blue: 1.0).opacity(0.82))
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: -orbitSize / 2)

                Circle()
                    .fill(Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.46))
                    .frame(width: dotSize * 0.72, height: dotSize * 0.72)
                    .offset(y: orbitSize * 0.36)
            }
            .rotationEffect(.degrees(orbitRotation))

            Text(formattedTime)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.97))
                .tracking(isIPad ? 4 : 2.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.34)
                .shadow(color: Color(red: 0.58, green: 0.84, blue: 0.96).opacity(0.24), radius: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pulseClockView(width: CGFloat, height: CGFloat, isLandscape: Bool) -> some View {
        let minDimension = min(width, height)
        let fontSize = typographySize(in: CGSize(width: width, height: height), style: .pulse, isLandscape: isLandscape)
        let ringSize = clamped(minDimension * 0.70, min: 142, max: isIPad ? 420 : 275)
        let ratio = progressRatio ?? 0

        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(
                        Color(red: 0.90, green: 0.82, blue: 1.0).opacity(0.16 - Double(index) * 0.035),
                        lineWidth: index == 0 ? 1.5 : 1
                    )
                    .frame(width: ringSize + CGFloat(index * 34), height: ringSize + CGFloat(index * 34))
                    .scaleEffect(index == 0 ? pulseScale : 1)
            }

            Circle()
                .trim(from: 0, to: max(0.015, ratio))
                .stroke(Color(white: 0.92).opacity(0.82), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)

            Text(formattedTime)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.97))
                .tracking(isIPad ? 4 : 2.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.34)
                .shadow(color: Color(red: 0.90, green: 0.82, blue: 1.0).opacity(0.18), radius: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func glassClockView(width: CGFloat, height: CGFloat, isLandscape: Bool) -> some View {
        let fontSize = typographySize(in: CGSize(width: width, height: height), style: .glass, isLandscape: isLandscape)
        let panelWidth = clamped(width * 0.84, min: 230, max: isIPad ? 760 : 500)
        let panelHeight = clamped(height * 0.54, min: 132, max: isIPad ? 330 : 235)
        let cornerRadius = clamped(panelHeight * 0.16, min: 20, max: 42)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius + 18, style: .continuous)
                .fill(
                    AngularGradient(
                        colors: [
                            Color(red: 0.60, green: 0.86, blue: 0.86).opacity(0.20),
                            Color.white.opacity(0.03),
                            Color(red: 0.92, green: 0.76, blue: 0.56).opacity(0.16),
                            Color.white.opacity(0.04),
                            Color(red: 0.60, green: 0.86, blue: 0.86).opacity(0.20)
                        ],
                        center: .center
                    )
                )
                .frame(width: panelWidth * 1.08, height: panelHeight * 1.18)
                .blur(radius: 12)

            RoundedRectangle(cornerRadius: clamped(panelHeight * 0.12, min: 16, max: 30), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.075),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.26), lineWidth: 1.1)
                )
                .frame(width: panelWidth, height: panelHeight)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.38))
                .frame(width: panelWidth * 0.68, height: 2)
                .offset(x: -panelWidth * 0.06, y: -panelHeight * 0.25)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.13))
                .frame(width: panelWidth * 0.34, height: 1)
                .offset(x: panelWidth * 0.20, y: panelHeight * 0.27)

            Text(formattedTime)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.98))
                .tracking(isIPad ? 4 : 2.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.34)
                .shadow(color: Color.white.opacity(0.32), radius: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func liquidClockView(width: CGFloat, height: CGFloat, isLandscape: Bool) -> some View {
        let fontSize = typographySize(in: CGSize(width: width, height: height), style: .liquid, isLandscape: isLandscape)
        let minDimension = min(width, height)
        let stageWidth = clamped(width * 0.86, min: 235, max: isIPad ? 780 : 520)
        let stageHeight = clamped(height * 0.56, min: 138, max: isIPad ? 350 : 245)
        let waveHeight = clamped(minDimension * 0.18, min: 42, max: isIPad ? 110 : 76)

        return ZStack {
            RoundedRectangle(cornerRadius: clamped(stageHeight * 0.15, min: 22, max: 44), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.09, blue: 0.08).opacity(0.96),
                            Color(red: 0.03, green: 0.04, blue: 0.06).opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: clamped(stageHeight * 0.15, min: 22, max: 44), style: .continuous)
                        .strokeBorder(Color(red: 0.40, green: 0.92, blue: 0.72).opacity(0.22), lineWidth: 1)
                )
                .frame(width: stageWidth, height: stageHeight)

            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.32, green: 0.88, blue: 0.70).opacity(0.34 - Double(index) * 0.08),
                                Color(red: 0.78, green: 0.92, blue: 0.58).opacity(0.16 - Double(index) * 0.03)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: stageWidth * (0.78 + CGFloat(index) * 0.12), height: waveHeight * (0.62 + CGFloat(index) * 0.15))
                    .offset(
                        x: (ambientShift - 0.5) * CGFloat(index.isMultiple(of: 2) ? 34 : -30),
                        y: stageHeight * (0.20 + CGFloat(index) * 0.08)
                    )
                    .blur(radius: CGFloat(index) * 1.8)
                    .blendMode(.screen)
            }

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(red: 0.72, green: 1.0, blue: 0.86).opacity(0.34))
                .frame(width: stageWidth * 0.58, height: 2)
                .offset(y: stageHeight * 0.34)

            Text(formattedTime)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.97))
                .tracking(isIPad ? 4 : 2.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.34)
                .shadow(color: Color(red: 0.34, green: 0.95, blue: 0.76).opacity(0.34), radius: 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bloomClockView(width: CGFloat, height: CGFloat, isLandscape: Bool) -> some View {
        let minDimension = min(width, height)
        let petalCount = 22
        let stageWidth = clamped(width * 0.86, min: 235, max: isIPad ? 780 : 520)
        let stageHeight = clamped(height * 0.58, min: 144, max: isIPad ? 350 : 250)
        let orbitRadius = clamped(minDimension * 0.43, min: 84, max: isIPad ? 270 : 190)
        let petalWidth = clamped(minDimension * 0.055, min: 10, max: isIPad ? 25 : 18)
        let petalHeight = clamped(minDimension * 0.23, min: 42, max: isIPad ? 112 : 82)
        let leafWidth = clamped(minDimension * 0.18, min: 38, max: isIPad ? 120 : 84)
        let leafHeight = clamped(minDimension * 0.055, min: 12, max: isIPad ? 30 : 22)
        let fontSize = typographySize(in: CGSize(width: width, height: height), style: .bloom, isLandscape: isLandscape)

        return ZStack {
            RoundedRectangle(cornerRadius: clamped(stageHeight * 0.16, min: 22, max: 46), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.045, blue: 0.075).opacity(0.94),
                            Color(red: 0.02, green: 0.03, blue: 0.025).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: clamped(stageHeight * 0.16, min: 22, max: 46), style: .continuous)
                        .strokeBorder(Color(red: 1.0, green: 0.72, blue: 0.84).opacity(0.18), lineWidth: 1)
                )
                .frame(width: stageWidth, height: stageHeight)

            ForEach(0..<6, id: \.self) { index in
                let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
                let vertical = CGFloat(index - 2) * stageHeight * 0.115
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.70, green: 0.98, blue: 0.72).opacity(0.24),
                                Color(red: 1.00, green: 0.64, blue: 0.78).opacity(0.10)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: leafWidth, height: leafHeight)
                    .rotationEffect(.degrees(side < 0 ? -24 : 24))
                    .offset(x: side * stageWidth * 0.32, y: vertical + (ambientShift - 0.5) * side * 8)
                    .blendMode(.screen)
            }

            ForEach(0..<petalCount, id: \.self) { index in
                let angle = Double(index) * (360.0 / Double(petalCount))
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.67, blue: 0.80).opacity(index.isMultiple(of: 3) ? 0.38 : 0.24),
                                Color(red: 0.72, green: 0.98, blue: 0.70).opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: petalWidth, height: petalHeight)
                    .offset(y: -orbitRadius)
                    .rotationEffect(.degrees(angle + Double(ambientShift * 4)))
                    .blendMode(.screen)
            }

            Circle()
                .strokeBorder(Color(red: 1.0, green: 0.72, blue: 0.84).opacity(0.25), lineWidth: 1.2)
                .frame(width: orbitRadius * 1.30, height: orbitRadius * 1.30)

            Circle()
                .strokeBorder(Color(red: 0.70, green: 0.98, blue: 0.76).opacity(0.16), lineWidth: 1)
                .frame(width: orbitRadius * 0.92, height: orbitRadius * 0.92)

            Text(formattedTime)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.97))
                .tracking(isIPad ? 4 : 2.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.34)
                .shadow(color: Color(red: 1.0, green: 0.72, blue: 0.86).opacity(0.38), radius: 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
