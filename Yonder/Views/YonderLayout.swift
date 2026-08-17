//
//  YonderLayout.swift
//  Yonder
//
//  Centralized responsive layout utilities shared across TodayView,
//  FocusPickerView, and any other screen that needs consistent spacing.
//
//  Design principle:
//    - No device-name hacks (no "iPhone 16", "iPad Pro", etc.)
//    - All layout decisions driven by actual available CGFloat width
//    - Proportional padding: edges breathe with the screen, never fixed-narrow
//    - iPhone: ~20-28pt edge breathing room
//    - iPad small / split-view: ~40-52pt edge breathing room
//    - iPad large: ~56-72pt edge breathing room
//
//  Usage:
//    let layout = YonderLayout(screenWidth: geo.size.width)
//    .padding(.horizontal, layout.hPad)
//    .frame(maxWidth: layout.contentWidth)
//

import SwiftUI

/// Centralized responsive layout utilities shared across TodayView, FocusPickerView,
/// FocusGoalsView and other screens to ensure consistent, non-negative, finite dimensions.
struct YonderLayout {

    let screenWidth: CGFloat

    /// Safe screen width handling initial 0 bounds, negative, NaN or infinite values.
    var safeWidth: CGFloat {
        guard screenWidth.isFinite && screenWidth > 0 else { return 375.0 }
        return max(1.0, screenWidth)
    }

    /// Yatay kenar boşluğu — her iki taraf.
    /// Formül: clamp(safeWidth × 0.062, min: 20, max: 72)
    var hPad: CGFloat {
        let raw = safeWidth * 0.062
        return min(max(raw, 20.0), 72.0)
    }

    /// Kenar boşlukları çıkarılmış, içerik için kullanılabilir genişlik.
    /// Non-negative ve en az 1.0pt.
    var contentWidth: CGFloat {
        max(1.0, safeWidth - hPad * 2.0)
    }

    /// FlipClock ve benzer büyük ama sınırlı olması gereken elementler için max genişlik.
    var clockMaxWidth: CGFloat {
        max(1.0, min(contentWidth * 0.80, 600.0))
    }

    /// Ana CTA butonu (Odaklan, Başlat) için max genişlik.
    var ctaMaxWidth: CGFloat {
        if contentWidth > 700 { return max(1.0, min(contentWidth * 0.65, 560.0)) }
        if contentWidth > 500 { return max(1.0, min(contentWidth * 0.72, 480.0)) }
        return contentWidth
    }

    /// İkincil butonlar (Sessiz Oda, Devam et, Birlikte Çalış) için max genişlik.
    var secondaryMaxWidth: CGFloat {
        if contentWidth > 700 { return max(1.0, min(contentWidth * 0.72, 620.0)) }
        if contentWidth > 500 { return max(1.0, min(contentWidth * 0.80, 520.0)) }
        return contentWidth
    }

    /// Geniş ekran eşiği — ≥700pt ise iki kolon veya genişletilmiş layout
    var isWide: Bool { safeWidth >= 700.0 }

    /// Orta boy eşiği — ≥520pt ise biraz daha büyük elemanlar
    var isMedium: Bool { safeWidth >= 520.0 }
}

// MARK: - Safe Dimension Extension

extension CGFloat {
    /// Ensures dimension value is finite and non-negative.
    var safeDimension: CGFloat {
        guard self.isFinite && self > 0 else { return 0 }
        return self
    }
}
