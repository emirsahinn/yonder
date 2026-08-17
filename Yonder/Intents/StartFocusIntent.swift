//
//  StartFocusIntent.swift
//  Yonder
//

import AppIntents
import SwiftUI

/// App Intent for launching a focus session via Siri voice command or Shortcuts app.
struct StartFocusIntent: AppIntent {

    static var title: LocalizedStringResource = "Odaklanma Başlat"
    static var description = IntentDescription("Yonder uygulamasında belirtilen süreyle odaklanma oturumu başlatır.")

    /// Always opens the app when executed so user sees the confirmation screen.
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Süre (Dakika)", default: 25)
    var durationMinutes: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        let durationSeconds = max(60, durationMinutes * 60)
        QuickActionService.shared.triggerIntentDuration(durationSeconds)
        return .result()
    }
}

/// Provides App Shortcuts for Siri and Shortcuts app integration.
struct YonderShortcutsProvider: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "\(.applicationName)'da odaklan",
                "\(.applicationName) ile odaklan",
                "\(.applicationName)'da 25 dakika başlat",
                "\(.applicationName)'da 45 dakika başlat",
                "\(.applicationName)'da 60 dakika başlat"
            ],
            shortTitle: "Odaklanma Başlat",
            systemImageName: "hourglass"
        )
    }
}
