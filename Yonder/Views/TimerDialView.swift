//
//  TimerDialView.swift
//  Yonder
//

import SwiftUI
import UIKit

/// A circular mechanical timer dial component supporting multi-unit control.
///
/// Behaviors depending on `selectedUnit`:
/// - `.hours`: Controls 0-12 hours range (30° steps per hour).
/// - `.minutes`: Controls 0-59 minutes range with 25/45/60 preset indicators and magnetic snapping.
/// - `.seconds`: Controls 0-59 seconds range.
///
/// Features embedded live `FlipClockView` with interactive unit tapping,
/// breathing pulse animation until first interaction, and long-press instant start on presets.
struct TimerDialView: View {

    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    @Binding var selectedUnit: TimeUnit

    /// Size of the dial container (width & height).
    var dialSize: CGFloat

    /// Dynamic minute preset values (defaults to [25, 45, 60] or user habits).
    var minutePresets: [Int] = [25, 45, 60]

    /// Optional callback when a preset tick (25/45/60 min) is long pressed.
    var onPresetLongPress: ((Int) -> Void)? = nil

    // MARK: - State

    @State private var lightHaptic  = UIImpactFeedbackGenerator(style: .light)
    @State private var mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    @State private var lastHapticValue: Int = 25
    @State private var isDragging: Bool = false
    @State private var hasInteracted: Bool = false
    @State private var breathePulse: Bool = false

    // MARK: - Preset Targets for Minutes

    private var minuteSnapTargets: [Int] {
        minutePresets + [0]
    }

    // MARK: - Body

    var body: some View {
        let center = CGPoint(x: dialSize / 2, y: dialSize / 2)
        let trackRadius = dialSize * 0.38

        ZStack {
            // 1. Static Outer Track Ring
            Circle()
                .stroke(Color(white: 0.12), lineWidth: 2)
                .frame(width: trackRadius * 2, height: trackRadius * 2)

            // 2. Active Progress Arc
            progressArc(center: center, radius: trackRadius)

            // 3. Tick Marks & Preset Labels
            tickMarks(center: center, radius: trackRadius)

            // 4. Center Flip Clock Display (showing HH:MM:SS)
            centerFlipClock(diameter: trackRadius * 1.35)

            // 5. Dial Thumb / Indicator Handle
            thumbIndicator(center: center, radius: trackRadius)
        }
        .frame(width: dialSize, height: dialSize)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !hasInteracted {
                        hasInteracted = true
                    }
                    isDragging = true
                    updateCurrentUnitValue(at: value.location, center: center)
                }
                .onEnded { value in
                    isDragging = false
                    updateCurrentUnitValue(at: value.location, center: center, isFinal: true)
                }
        )
        .onAppear {
            lightHaptic.prepare()
            mediumHaptic.prepare()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathePulse = true
            }
        }
    }

    // MARK: - Helper Properties for Current Unit

    private var currentValue: Int {
        switch selectedUnit {
        case .hours:   return hours
        case .minutes: return minutes
        case .seconds: return seconds
        }
    }

    private var maxUnitValue: Int {
        switch selectedUnit {
        case .hours:   return 12
        case .minutes: return 59
        case .seconds: return 59
        }
    }

    /// Angle in degrees for current unit value (0° at 12 o'clock / -90° in SwiftUI).
    private var currentUnitAngleDegrees: Double {
        switch selectedUnit {
        case .hours:
            return Double(hours) * 30.0 - 90.0
        case .minutes:
            return Double(minutes) * 6.0 - 90.0
        case .seconds:
            return Double(seconds) * 6.0 - 90.0
        }
    }

    // MARK: - Subviews

    /// Active progress arc from 12 o'clock (-90°) to the current unit angle.
    private func progressArc(center: CGPoint, radius: CGFloat) -> some View {
        let startDegrees: Double = -90.0
        let endDegrees: Double = currentUnitAngleDegrees

        return Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(startDegrees),
                endAngle: .degrees(endDegrees),
                clockwise: false
            )
        }
        .stroke(
            LinearGradient(
                colors: [Color(white: 0.35), Color(white: 0.75)],
                startPoint: .top,
                endPoint: .bottom
            ),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        .animation(.easeOut(duration: 0.15), value: currentUnitAngleDegrees)
    }

    /// Ticks rendering dynamically based on active selectedUnit.
    @ViewBuilder
    private func tickMarks(center: CGPoint, radius: CGFloat) -> some View {
        switch selectedUnit {
        case .hours:
            hoursTicks(center: center, radius: radius)
        case .minutes:
            minutesTicks(center: center, radius: radius)
        case .seconds:
            secondsTicks(center: center, radius: radius)
        }
    }

    /// Ticks for Hours (1h to 12h, 30° intervals).
    private func hoursTicks(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(1...12, id: \.self) { hour in
            let angleDeg = Double(hour) * 30.0 - 90.0
            let angleRad = angleDeg * .pi / 180.0

            let isMajor = hour % 3 == 0

            let tickLength: CGFloat = isMajor ? 12 : 7
            let tickWidth: CGFloat  = isMajor ? 2.0 : 1.2
            let tickColor           = isMajor ? Color(white: 0.85) : Color(white: 0.35)

            let innerRadius = radius - 16
            let outerRadius = innerRadius + tickLength

            let innerX = center.x + innerRadius * cos(angleRad)
            let innerY = center.y + innerRadius * sin(angleRad)
            let outerX = center.x + outerRadius * cos(angleRad)
            let outerY = center.y + outerRadius * sin(angleRad)

            let labelRadius = innerRadius - 16
            let labelX = center.x + labelRadius * cos(angleRad)
            let labelY = center.y + labelRadius * sin(angleRad)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: innerX, y: innerY))
                    path.addLine(to: CGPoint(x: outerX, y: outerY))
                }
                .stroke(tickColor, lineWidth: tickWidth)

                if isMajor {
                    Text("\(hour)h")
                        .font(.system(size: max(10, dialSize * 0.034), weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: 0.85))
                        .position(x: labelX, y: labelY)
                }
            }
        }
    }

    /// Ticks for Minutes (5-min intervals with highlights & long press triggers).
    private func minutesTicks(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(stride(from: 5, through: 60, by: 5).map { $0 }, id: \.self) { minute in
            let angleDeg = Double(minute) * 6.0 - 90.0
            let angleRad = angleDeg * .pi / 180.0

            let isPreset = minutePresets.contains(minute)
            let isQuarter = minute % 15 == 0

            let tickLength: CGFloat = isPreset ? 14 : (isQuarter ? 10 : 6)
            let tickWidth: CGFloat  = isPreset ? 2.2 : (isQuarter ? 1.4 : 1.0)
            let tickColor           = isPreset
                ? Color(white: 0.9)
                : (isQuarter ? Color(white: 0.45) : Color(white: 0.22))

            let innerRadius = radius - 16
            let outerRadius = innerRadius + tickLength

            let innerX = center.x + innerRadius * cos(angleRad)
            let innerY = center.y + innerRadius * sin(angleRad)
            let outerX = center.x + outerRadius * cos(angleRad)
            let outerY = center.y + outerRadius * sin(angleRad)

            let labelRadius = innerRadius - 14
            let labelX = center.x + labelRadius * cos(angleRad)
            let labelY = center.y + labelRadius * sin(angleRad)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: innerX, y: innerY))
                    path.addLine(to: CGPoint(x: outerX, y: outerY))
                }
                .stroke(tickColor, lineWidth: tickWidth)

                if isPreset {
                    Text("\(minute)")
                        .font(.system(size: max(10, dialSize * 0.036), weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: 0.85))
                        .position(x: labelX, y: labelY)
                        .contentShape(Circle())
                        .onLongPressGesture(minimumDuration: 0.4) {
                            mediumHaptic.impactOccurred()
                            hasInteracted = true
                            minutes = minute == 60 ? 60 : minute
                            onPresetLongPress?(minute)
                        }
                }
            }
        }
    }

    /// Ticks for Seconds (5-second intervals).
    private func secondsTicks(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(stride(from: 5, through: 60, by: 5).map { $0 }, id: \.self) { second in
            let angleDeg = Double(second) * 6.0 - 90.0
            let angleRad = angleDeg * .pi / 180.0

            let isQuarter = second % 15 == 0

            let tickLength: CGFloat = isQuarter ? 10 : 6
            let tickWidth: CGFloat  = isQuarter ? 1.5 : 1.0
            let tickColor           = isQuarter ? Color(white: 0.6) : Color(white: 0.25)

            let innerRadius = radius - 16
            let outerRadius = innerRadius + tickLength

            let innerX = center.x + innerRadius * cos(angleRad)
            let innerY = center.y + innerRadius * sin(angleRad)
            let outerX = center.x + outerRadius * cos(angleRad)
            let outerY = center.y + outerRadius * sin(angleRad)

            Path { path in
                path.move(to: CGPoint(x: innerX, y: innerY))
                path.addLine(to: CGPoint(x: outerX, y: outerY))
            }
            .stroke(tickColor, lineWidth: tickWidth)
        }
    }

    /// Center flip-clock component with unit selection callback.
    private func centerFlipClock(diameter: CGFloat) -> some View {
        FlipClockView(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            showHours: true,
            isRunning: false,
            selectedUnit: selectedUnit,
            onSelectUnit: { unit in
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedUnit = unit
                }
            }
        )
        .frame(width: diameter, height: diameter * 0.55)
    }

    /// Thumb handle indicating current unit angle with breathing pulse animation until touched.
    private func thumbIndicator(center: CGPoint, radius: CGFloat) -> some View {
        let angleDeg = currentUnitAngleDegrees
        let angleRad = angleDeg * .pi / 180.0

        let thumbX = center.x + radius * cos(angleRad)
        let thumbY = center.y + radius * sin(angleRad)

        let thumbSize: CGFloat = max(16, dialSize * 0.055)

        // Breathing scale & opacity pulse calculation
        let currentScale: CGFloat = (!hasInteracted && breathePulse) ? 1.08 : 1.0
        let currentOpacity: Double = (!hasInteracted && breathePulse) ? 1.0 : (hasInteracted ? 1.0 : 0.6)

        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: thumbSize * 1.5, height: thumbSize * 1.5)
                .blur(radius: 4)

            Circle()
                .fill(Color(white: 0.12))
                .frame(width: thumbSize, height: thumbSize)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                )

            Circle()
                .fill(Color.white)
                .frame(width: thumbSize * 0.4, height: thumbSize * 0.4)
        }
        .scaleEffect(currentScale)
        .opacity(currentOpacity)
        .position(x: thumbX, y: thumbY)
        .shadow(color: .black.opacity(0.6), radius: 3)
        .animation(.easeOut(duration: 0.15), value: currentUnitAngleDegrees)
    }

    // MARK: - Drag Calculation & Haptics

    private func updateCurrentUnitValue(at location: CGPoint, center: CGPoint, isFinal: Bool = false) {
        let dx = location.x - center.x
        let dy = location.y - center.y

        let angleRad = atan2(dy, dx)

        var angleDeg = angleRad * 180.0 / .pi + 90.0
        if angleDeg < 0 { angleDeg += 360.0 }

        switch selectedUnit {
        case .hours:
            let newHours = max(0, min(12, Int(round(angleDeg / 30.0))))
            if newHours != hours {
                lightHaptic.impactOccurred()
                hours = newHours
            }

        case .minutes:
            var newMinutes = Int(round(angleDeg / 6.0)) % 60

            for target in minuteSnapTargets {
                let checkTarget = target == 60 ? 0 : target
                if abs(newMinutes - checkTarget) <= 2 {
                    newMinutes = checkTarget
                    break
                }
            }

            if newMinutes != minutes {
                if minuteSnapTargets.contains(newMinutes) || newMinutes == 0 {
                    mediumHaptic.impactOccurred()
                } else if newMinutes % 5 == 0 && newMinutes != lastHapticValue {
                    lightHaptic.impactOccurred()
                }
                lastHapticValue = newMinutes
                minutes = newMinutes
            }

        case .seconds:
            let newSeconds = Int(round(angleDeg / 6.0)) % 60
            if newSeconds != seconds {
                if newSeconds % 5 == 0 && newSeconds != lastHapticValue {
                    lightHaptic.impactOccurred()
                }
                lastHapticValue = newSeconds
                seconds = newSeconds
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TimerDialView(
            hours: .constant(2),
            minutes: .constant(25),
            seconds: .constant(0),
            selectedUnit: .constant(.minutes),
            dialSize: 320
        )
    }
}
