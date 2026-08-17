//
//  FlipClockDigitView.swift
//  Yonder
//

import SwiftUI

/// A single flip-clock digit with a mechanical card-flip animation.
///
/// The card dimensions are provided externally so the parent can fully
/// control sizing via GeometryReader — no hardcoded widths/heights here.
struct FlipClockDigitView: View {

    let digit: Int

    /// Card width in points — provided by FlipClockView.
    var cardWidth: CGFloat
    /// Card height in points — provided by FlipClockView.
    var cardHeight: CGFloat
    /// Allows setup screens to update digits instantly while countdown screens keep the flip motion.
    var animatesChanges: Bool = true

    // MARK: - Animation State

    @State private var currentDigit: Int = 0
    @State private var previousDigit: Int = 0
    @State private var isFlipping: Bool = false

    // MARK: - Derived Dimensions

    private var fontSize: CGFloat    { cardHeight * 0.76 }
    private var cornerRadius: CGFloat { cardWidth * 0.12 }
    private var dividerHeight: CGFloat { max(1.0, cardHeight * 0.012) }

    // MARK: - Colors

    private let cardBackground = Color(white: 0.12)
    private let digitColor      = Color(white: 0.95)
    private let dividerColor    = Color(white: 0.06)

    var body: some View {
        ZStack {
            // Bottom layer: shows new digit (revealed after flip)
            bottomCard(digit: currentDigit)

            // Top static half: shows current digit (top portion)
            topHalfStatic(digit: currentDigit)
                .opacity(isFlipping ? 0 : 1)

            // Flipping top half: animates from old digit
            if isFlipping {
                topHalfFlipping(digit: previousDigit)
            }

            // Center divider line
            Rectangle()
                .fill(dividerColor)
                .frame(height: dividerHeight)
        }
        .frame(width: cardWidth, height: cardHeight)
        .onAppear {
            currentDigit  = digit
            previousDigit = digit
        }
        .onChange(of: digit) { oldValue, newValue in
            guard oldValue != newValue else { return }
            guard animatesChanges else {
                previousDigit = newValue
                currentDigit = newValue
                isFlipping = false
                return
            }
            triggerFlip(from: oldValue, to: newValue)
        }
    }

    // MARK: - Flip Logic

    private func triggerFlip(from old: Int, to new: Int) {
        previousDigit = old
        isFlipping = true

        withAnimation(.easeIn(duration: 0.25)) {
            isFlipping = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentDigit = new
            withAnimation(.easeOut(duration: 0.15)) {
                isFlipping = false
            }
        }
    }

    // MARK: - Card Components

    /// Full card showing a digit (used as the base/bottom layer).
    private func bottomCard(digit: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardBackground)

            Text("\(digit)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(digitColor)
                .monospacedDigit()
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    /// Top half of the card (static, clipped).
    private func topHalfStatic(digit: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardBackground)

            Text("\(digit)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(digitColor)
                .monospacedDigit()
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(TopHalfShape())
    }

    /// Top half that flips down (animates rotation).
    private func topHalfFlipping(digit: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardBackground)

            Text("\(digit)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(digitColor)
                .monospacedDigit()
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(TopHalfShape())
        .rotation3DEffect(
            .degrees(isFlipping ? -89.9 : 0),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.4
        )
        .animation(.easeIn(duration: 0.25), value: isFlipping)
    }
}

// MARK: - Clip Shapes

/// Clips to the top half of the view.
struct TopHalfShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: 0, y: 0, width: rect.width, height: rect.height / 2))
        return path
    }
}

/// Clips to the bottom half of the view.
struct BottomHalfShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: 0, y: rect.height / 2, width: rect.width, height: rect.height / 2))
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FlipClockDigitView(digit: 5, cardWidth: 80, cardHeight: 120)
    }
}
