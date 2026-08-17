//
//  HapticService.swift
//  Yonder
//
//  Subtle, premium haptic feedback helper for key application events.
//

import UIKit

@MainActor
enum HapticService {

    /// Light impact feedback for subtle UI toggles (e.g. pause, break mode, step adjustment).
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Medium impact feedback for primary start/action triggers.
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Success feedback for completions, successful copies, and session saves.
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Warning feedback for destructive confirmations or early exits.
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Error feedback for failed network calls or validation errors.
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    /// Selection feedback for picker or segment selection changes.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
