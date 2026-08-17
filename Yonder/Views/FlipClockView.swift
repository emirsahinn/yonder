//
//  FlipClockView.swift
//  Yonder
//

import SwiftUI

/// Time unit enum for individual hour, minute, and second selection.
enum TimeUnit: String, CaseIterable, Identifiable {
    case hours
    case minutes
    case seconds

    var id: String { rawValue }
}

/// Combines FlipClockDigitView instances to display a full MM:SS or HH:MM:SS countdown.
///
/// Supports interactive unit selection (Hours, Minutes, Seconds) with visual highlighting
/// and indicator line when `selectedUnit` and `onSelectUnit` are provided.
struct FlipClockView: View {

    let hours: Int
    let minutes: Int
    let seconds: Int
    let showHours: Bool
    let isRunning: Bool
    var showSeconds: Bool = true
    var showSecondsHint: Bool = false
    var animatesDigitChanges: Bool = true

    /// Optional selected unit for interactive setup mode (nil when timer is running).
    var selectedUnit: TimeUnit? = nil
    /// Callback when user taps a unit (hours, minutes, seconds).
    var onSelectUnit: ((TimeUnit) -> Void)? = nil
    /// Callback when user taps the seconds group directly in clock mode.
    var onTapSeconds: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let safeW = max(1.0, geo.size.width)
            let safeH = max(1.0, geo.size.height)
            let dims = clockDimensions(in: CGSize(width: safeW, height: safeH))
            clockContent(dims: dims)
                .frame(width: safeW, height: safeH)
        }
    }

    // MARK: - Layout Calculation

    private struct ClockDims {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let digitSpacing: CGFloat
        let colonSpacing: CGFloat
        let colonDotSize: CGFloat
        let colonGap: CGFloat
    }

    private func clockDimensions(in available: CGSize) -> ClockDims {
        var numCards = 4
        var numColons = 1
        if showHours && showSeconds {
            numCards = 6
            numColons = 2
        } else if showHours && !showSeconds {
            numCards = 4
            numColons = 1
        } else if !showHours && showSeconds {
            numCards = 4
            numColons = 1
        } else {
            numCards = 2
            numColons = 0
        }

        let cardAspect: CGFloat = 0.67

        let digitSpacingFraction: CGFloat = 0.08
        let colonWidthFraction: CGFloat   = 0.28
        let colonSpacingFraction: CGFloat = 0.16

        let maxH = available.height * 0.92
        let maxW = available.width * 0.96

        let cardWidthPerH = cardAspect
        let digitSpacingPerH = digitSpacingFraction * cardWidthPerH
        let colonWidthPerH  = colonWidthFraction  * cardWidthPerH
        let colonSpacingPerH = colonSpacingFraction * cardWidthPerH

        let pairsOfDigits = numCards / 2
        let totalWidthPerH =
            CGFloat(numCards) * cardWidthPerH
            + CGFloat(pairsOfDigits) * digitSpacingPerH
            + CGFloat(numColons) * (colonWidthPerH + 2 * colonSpacingPerH)

        let hFromWidth  = maxW / totalWidthPerH
        let hFromHeight = maxH

        var cardH = min(hFromWidth, hFromHeight)
        cardH = max(cardH, 36)

        let cardW    = cardH * cardAspect
        let digitSp  = cardW * digitSpacingFraction
        let colonW   = cardW * colonWidthFraction
        let colonSp  = cardW * colonSpacingFraction
        let colonDot = max(4, colonW * 0.45)
        let colonGap = cardH * 0.20

        return ClockDims(
            cardWidth: cardW,
            cardHeight: cardH,
            digitSpacing: digitSp,
            colonSpacing: colonSp,
            colonDotSize: colonDot,
            colonGap: colonGap
        )
    }

    // MARK: - Clock Layout

    @ViewBuilder
    private func clockContent(dims: ClockDims) -> some View {
        HStack(spacing: dims.colonSpacing) {
            if showHours {
                unitGroup(unit: .hours, tens: hours / 10, ones: hours % 10, dims: dims)
                colonSeparator(dims: dims)
            }
            unitGroup(unit: .minutes, tens: minutes / 10, ones: minutes % 10, dims: dims)
            if showSeconds {
                colonSeparator(dims: dims)
                unitGroup(unit: .seconds, tens: seconds / 10, ones: seconds % 10, dims: dims)
            }
        }
    }

    /// Two side-by-side digit cards representing a single unit group (Hours, Minutes, or Seconds).
    private func unitGroup(unit: TimeUnit, tens: Int, ones: Int, dims: ClockDims) -> some View {
        let isSelectionMode = selectedUnit != nil
        let isSelected = selectedUnit == unit

        let groupOpacity: Double = isSelectionMode ? (isSelected ? 1.0 : 0.38) : 1.0

        return VStack(spacing: dims.cardHeight * 0.05) {
            HStack(spacing: dims.digitSpacing) {
                FlipClockDigitView(digit: tens, cardWidth: dims.cardWidth, cardHeight: dims.cardHeight, animatesChanges: animatesDigitChanges)
                FlipClockDigitView(digit: ones, cardWidth: dims.cardWidth, cardHeight: dims.cardHeight, animatesChanges: animatesDigitChanges)
            }

            // Indicator line under active unit in interactive setup mode
            if isSelectionMode {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? Color.white : Color.clear)
                    .frame(height: max(2, dims.cardHeight * 0.04))
                    .shadow(color: isSelected ? .white.opacity(0.8) : .clear, radius: 3)
            }
        }
        .opacity(groupOpacity)
        .contentShape(Rectangle())
        .onTapGesture {
            if let onSelectUnit = onSelectUnit {
                onSelectUnit(unit)
            } else if unit == .seconds, let onTapSeconds = onTapSeconds {
                onTapSeconds()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedUnit)
    }

    /// Pulsing colon separator — two dots stacked vertically.
    private func colonSeparator(dims: ClockDims) -> some View {
        VStack(spacing: dims.colonGap) {
            Circle()
                .fill(Color(white: 0.4))
                .frame(width: dims.colonDotSize, height: dims.colonDotSize)
            Circle()
                .fill(Color(white: 0.4))
                .frame(width: dims.colonDotSize, height: dims.colonDotSize)
        }
        .opacity(isRunning ? 1.0 : 0.5)
        .animation(
            isRunning
                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                : .default,
            value: isRunning
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FlipClockView(
            hours: 1,
            minutes: 25,
            seconds: 0,
            showHours: true,
            isRunning: false,
            selectedUnit: .minutes,
            onSelectUnit: { _ in }
        )
        .padding()
    }
}
