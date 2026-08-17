//
//  TimerClockStyle.swift
//  Yonder
//

import Foundation

/// Defines the display style of timer and passive clock screens.
enum TimerClockStyle: String, CaseIterable, Identifiable {
    case flip
    case digital
    case minimal
    case focusBar
    case bloom
    case rain
    case orbit
    case pulse
    case glass
    case liquid

    var id: String { rawValue }

    var isPro: Bool {
        self != .flip
    }

    /// v1 launch: always return the default flip style regardless of stored preference.
    static func resolved(rawValue: String, isPremiumUser: Bool) -> TimerClockStyle {
        return .flip
    }

    func localizedName(lang: String) -> String {
        switch self {
        case .flip:
            return "Flip Clock"
        case .digital:
            return lang == "tr" ? "Dijital" : "Digital"
        case .minimal:
            return "Minimal"
        case .focusBar:
            return lang == "tr" ? "Odak Çizgisi" : "Focus Bar"
        case .bloom:
            return "Bloom"
        case .rain:
            return lang == "tr" ? "Yağmur" : "Rain"
        case .orbit:
            return "Orbit"
        case .pulse:
            return "Pulse"
        case .glass:
            return "Glass"
        case .liquid:
            return "Liquid"
        }
    }

    func localizedDescription(lang: String) -> String {
        switch self {
        case .flip:
            return lang == "tr" ? "Klasik Yonder görünümü" : "The classic Yonder look"
        case .digital:
            return lang == "tr" ? "Büyük ve net dijital süre" : "Large, clear digital time"
        case .minimal:
            return lang == "tr" ? "Sade ve sessiz zaman" : "Quiet, minimal time"
        case .focusBar:
            return lang == "tr" ? "Süreyi ince bir ilerleme çizgisiyle gösterir" : "Shows time with a subtle progress line"
        case .bloom:
            return lang == "tr" ? "İnce çiçek dokularıyla sakin bir zaman ekranı" : "A calm time display with subtle floral details"
        case .rain:
            return lang == "tr" ? "İnce yağmur çizgileriyle dingin bir ekran" : "A quiet display with fine rain lines"
        case .orbit:
            return lang == "tr" ? "Zamanın etrafında yavaş bir odak halkası" : "A slow focus orbit around time"
        case .pulse:
            return lang == "tr" ? "Nefes alan halkalarla sakin ilerleme hissi" : "Breathing rings for a calm sense of progress"
        case .glass:
            return lang == "tr" ? "Yumuşak cam panel üzerinde net zaman" : "Clear time on a soft glass panel"
        case .liquid:
            return lang == "tr" ? "Akışkan bir odak sahnesi" : "A fluid focus scene"
        }
    }
}
