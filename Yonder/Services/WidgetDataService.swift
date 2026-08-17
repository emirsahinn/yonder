//
//  WidgetDataService.swift
//  Yonder
//

import Foundation
import WidgetKit

/// Synchronizes focus statistics with WidgetKit using App Groups.
final class WidgetDataService {

    static let shared = WidgetDataService()

    private let appGroupSuiteName = "group.com.emir.Yonder"

    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupSuiteName) ?? .standard
    }

    private init() {}

    /// Update today's total focus duration seconds & most used focus duration in App Group storage.
    func updateWidgetData(todayTotalSeconds: Int, mostUsedDurationSeconds: Int = 1500) {
        userDefaults.set(todayTotalSeconds, forKey: "todayTotalSeconds")
        userDefaults.set(mostUsedDurationSeconds, forKey: "mostUsedDurationSeconds")
        userDefaults.set(Date().timeIntervalSince1970, forKey: "lastUpdated")

        // Reload WidgetKit timelines immediately
        WidgetCenter.shared.reloadAllTimelines()
        print("[WidgetDataService] Reloaded WidgetKit timelines with todayTotalSeconds: \(todayTotalSeconds)")
    }

    /// Read today's total seconds stored in App Group suite.
    var todayTotalSeconds: Int {
        userDefaults.integer(forKey: "todayTotalSeconds")
    }

    /// Read most used duration seconds (defaults to 1500s / 25m).
    var mostUsedDurationSeconds: Int {
        let val = userDefaults.integer(forKey: "mostUsedDurationSeconds")
        return val > 0 ? val : 1500
    }
}
