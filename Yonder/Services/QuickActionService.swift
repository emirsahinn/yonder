//
//  QuickActionService.swift
//  Yonder
//

import UIKit
import Combine

/// Manages Home Screen Quick Action shortcuts (Haptic Touch 25/45/60 min instant start).
final class QuickActionService: ObservableObject {

    static let shared = QuickActionService()

    @Published var selectedDurationSeconds: Int? = nil

    private init() {}

    /// Process incoming shortcut item from AppDelegate / SceneDelegate.
    @discardableResult
    func handleShortcutItem(_ item: UIApplicationShortcutItem) -> Bool {
        print("[QuickActionService] Handling shortcut item type: \(item.type)")

        switch item.type {
        case "com.emir.Yonder.start25":
            DispatchQueue.main.async {
                self.selectedDurationSeconds = 1500
            }
            return true

        case "com.emir.Yonder.start45":
            DispatchQueue.main.async {
                self.selectedDurationSeconds = 2700
            }
            return true

        case "com.emir.Yonder.start60":
            DispatchQueue.main.async {
                self.selectedDurationSeconds = 3600
            }
            return true

        default:
            return false
        }
    }

    /// Triggered by Siri App Intents or Shortcuts app.
    func triggerIntentDuration(_ seconds: Int) {
        DispatchQueue.main.async {
            self.selectedDurationSeconds = seconds
        }
    }
}
