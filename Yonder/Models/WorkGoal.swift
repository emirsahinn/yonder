//
//  WorkGoal.swift
//  Yonder
//
//  Data model and persistence store for total and work area specific focus rhythm goals.
//  Supports recurring vs period-specific goals with date boundary tracking and hierarchy validation.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth

enum WorkGoalScope: String, Codable, CaseIterable {
    case total
    case workArea
}

enum WorkGoalPeriod: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    func title(lang: String) -> String {
        switch self {
        case .daily:   return lang == "tr" ? "Günlük" : "Daily"
        case .weekly:  return lang == "tr" ? "Haftalık" : "Weekly"
        case .monthly: return lang == "tr" ? "Aylık" : "Monthly"
        }
    }
}

enum WorkGoalMode: String, Codable, CaseIterable, Identifiable {
    case recurring
    case periodSpecific

    var id: String { rawValue }

    func label(period: WorkGoalPeriod, lang: String) -> String {
        switch (self, period) {
        case (.recurring, .daily):
            return lang == "tr" ? "Her gün" : "Every day"
        case (.recurring, .weekly):
            return lang == "tr" ? "Her hafta" : "Every week"
        case (.recurring, .monthly):
            return lang == "tr" ? "Her ay" : "Every month"
        case (.periodSpecific, .daily):
            return lang == "tr" ? "Bugün" : "Today"
        case (.periodSpecific, .weekly):
            return lang == "tr" ? "Bu hafta" : "This week"
        case (.periodSpecific, .monthly):
            return lang == "tr" ? "Bu ay" : "This month"
        }
    }
}

struct WorkGoal: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var scope: WorkGoalScope
    var workAreaId: String? = nil
    var workAreaName: String? = nil
    var period: WorkGoalPeriod
    var mode: WorkGoalMode = .recurring
    var startDate: Date? = nil
    var endDate: Date? = nil
    var targetSeconds: Int
    var isEnabled: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var targetMinutes: Int {
        targetSeconds / 60
    }
}

/// Persistent store managing work rhythm goals.
final class WorkGoalStore: ObservableObject {

    static let shared = WorkGoalStore()
    private let key = "yonder_work_goals_store_v3"

    @Published var goals: [WorkGoal] = [] {
        didSet {
            saveToDisk()
        }
    }

    init() {
        loadFromDisk()
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([WorkGoal].self, from: data) {
            self.goals = decoded
        } else if let legacyData = UserDefaults.standard.data(forKey: "yonder_work_goals_store_v2"),
                  let decoded = try? JSONDecoder().decode([WorkGoal].self, from: legacyData) {
            self.goals = decoded
        } else {
            // Seed initial total goals from AppStorage keys if available
            var initial: [WorkGoal] = []
            let dSecs = UserDefaults.standard.integer(forKey: "daily_focus_goal_seconds")
            let wSecs = UserDefaults.standard.integer(forKey: "weekly_focus_goal_seconds")
            let mSecs = UserDefaults.standard.integer(forKey: "monthly_focus_goal_seconds")

            let dEnabled = UserDefaults.standard.object(forKey: "daily_focus_goal_enabled") as? Bool ?? true
            let wEnabled = UserDefaults.standard.object(forKey: "weekly_focus_goal_enabled") as? Bool ?? true
            let mEnabled = UserDefaults.standard.object(forKey: "monthly_focus_goal_enabled") as? Bool ?? true

            if dSecs > 0 {
                initial.append(WorkGoal(scope: .total, period: .daily, mode: .recurring, targetSeconds: dSecs, isEnabled: dEnabled))
            }
            if wSecs > 0 {
                initial.append(WorkGoal(scope: .total, period: .weekly, mode: .recurring, targetSeconds: wSecs, isEnabled: wEnabled))
            }
            if mSecs > 0 {
                initial.append(WorkGoal(scope: .total, period: .monthly, mode: .recurring, targetSeconds: mSecs, isEnabled: mEnabled))
            }
            self.goals = initial
        }
    }

    private func saveToDisk() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    // MARK: - Date Boundary Helper

    static func periodSpecificDateRange(for period: WorkGoalPeriod, referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let cal = Calendar.current
        switch period {
        case .daily:
            let start = cal.startOfDay(for: referenceDate)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .weekly:
            var c = cal
            c.firstWeekday = 2 // Monday
            let start = c.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? cal.startOfDay(for: referenceDate)
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            return (start, end)
        case .monthly:
            let start = cal.dateInterval(of: .month, for: referenceDate)?.start ?? cal.startOfDay(for: referenceDate)
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        }
    }

    // MARK: - Goal Mutators

    func setTotalGoal(period: WorkGoalPeriod, mode: WorkGoalMode = .recurring, seconds: Int, enabled: Bool, referenceDate: Date = Date()) {
        let (sDate, eDate): (Date?, Date?) = {
            if mode == .periodSpecific {
                let range = WorkGoalStore.periodSpecificDateRange(for: period, referenceDate: referenceDate)
                return (range.start, range.end)
            } else {
                return (nil, nil)
            }
        }()

        let matchIdx = goals.firstIndex { g in
            g.scope == .total && g.period == period && g.mode == mode &&
            (mode == .recurring || (g.startDate == sDate && g.endDate == eDate))
        }

        if let idx = matchIdx {
            if seconds <= 0 {
                let removed = goals[idx]
                goals.remove(at: idx)
                if let uid = linkedUID {
                    SyncService.shared.deleteGoal(id: removed.id, uid: uid)
                }
            } else {
                goals[idx].targetSeconds = seconds
                goals[idx].isEnabled = enabled
                goals[idx].startDate = sDate
                goals[idx].endDate = eDate
                goals[idx].updatedAt = Date()
                if let uid = linkedUID {
                    SyncService.shared.syncGoal(goals[idx], uid: uid)
                }
            }
        } else if seconds > 0 {
            let newGoal = WorkGoal(
                scope: .total,
                period: period,
                mode: mode,
                startDate: sDate,
                endDate: eDate,
                targetSeconds: seconds,
                isEnabled: enabled
            )
            goals.append(newGoal)
            if let uid = linkedUID {
                SyncService.shared.syncGoal(newGoal, uid: uid)
            }
        }
    }

    func setWorkAreaGoal(name: String, period: WorkGoalPeriod, mode: WorkGoalMode = .recurring, seconds: Int, enabled: Bool, referenceDate: Date = Date()) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let (sDate, eDate): (Date?, Date?) = {
            if mode == .periodSpecific {
                let range = WorkGoalStore.periodSpecificDateRange(for: period, referenceDate: referenceDate)
                return (range.start, range.end)
            } else {
                return (nil, nil)
            }
        }()

        let matchIdx = goals.firstIndex { g in
            g.scope == .workArea && g.period == period && g.mode == mode &&
            g.workAreaName?.lowercased() == trimmed.lowercased() &&
            (mode == .recurring || (g.startDate == sDate && g.endDate == eDate))
        }

        if let idx = matchIdx {
            if seconds <= 0 {
                let removed = goals[idx]
                goals.remove(at: idx)
                if let uid = linkedUID {
                    SyncService.shared.deleteGoal(id: removed.id, uid: uid)
                }
            } else {
                goals[idx].targetSeconds = seconds
                goals[idx].isEnabled = enabled
                goals[idx].startDate = sDate
                goals[idx].endDate = eDate
                goals[idx].updatedAt = Date()
                if let uid = linkedUID {
                    SyncService.shared.syncGoal(goals[idx], uid: uid)
                }
            }
        } else if seconds > 0 {
            let newGoal = WorkGoal(
                scope: .workArea,
                workAreaName: trimmed,
                period: period,
                mode: mode,
                startDate: sDate,
                endDate: eDate,
                targetSeconds: seconds,
                isEnabled: enabled
            )
            goals.append(newGoal)
            if let uid = linkedUID {
                SyncService.shared.syncGoal(newGoal, uid: uid)
            }
        }
    }

    func removeGoal(id: UUID) {
        if let idx = goals.firstIndex(where: { $0.id == id }) {
            goals.remove(at: idx)
            // Propagate deletion to Firestore
            if let uid = linkedUID {
                SyncService.shared.deleteGoal(id: id, uid: uid)
            }
        }
    }

    func toggleGoalEnabled(id: UUID) {
        if let idx = goals.firstIndex(where: { $0.id == id }) {
            goals[idx].isEnabled.toggle()
            goals[idx].updatedAt = Date()
            // Propagate update to Firestore
            if let uid = linkedUID {
                SyncService.shared.syncGoal(goals[idx], uid: uid)
            }
        }
    }

    // MARK: - Remote Merge (called by SyncService)

    /// Merges remote goals downloaded from Firestore into the local store.
    ///
    /// Rules:
    ///  - Same `id` → keep the one with the newer `updatedAt`.
    ///  - New remote goal → add, unless a local goal with the same semantic key
    ///    (scope+period+mode+workAreaName) already exists.
    ///  - Local-only goals remain untouched.
    func applyRemoteGoals(_ remoteGoals: [WorkGoal]) {
        var localByID: [String: Int] = [:]
        for (idx, g) in goals.enumerated() {
            localByID[g.id.uuidString] = idx
        }

        var updated = goals

        for remote in remoteGoals {
            let key = remote.id.uuidString
            if let localIdx = localByID[key] {
                // Same ID: keep whichever is newer
                if remote.updatedAt > updated[localIdx].updatedAt {
                    updated[localIdx] = remote
                }
            } else {
                // New remote goal — guard against semantic duplicates
                let semanticMatch = updated.first { g in
                    g.scope == remote.scope &&
                    g.period == remote.period &&
                    g.mode == remote.mode &&
                    (g.workAreaName?.lowercased() ?? "") == (remote.workAreaName?.lowercased() ?? "") &&
                    (remote.mode == .recurring || (g.startDate == remote.startDate && g.endDate == remote.endDate))
                }
                if semanticMatch == nil {
                    updated.append(remote)
                }
            }
        }

        if updated != goals {
            goals = updated   // triggers saveToDisk() via didSet
        }
    }

    /// Replaces local goal state with the Google account state.
    /// Used when the user chooses not to add this device's local data to the account.
    func replaceWithRemoteGoals(_ remoteGoals: [WorkGoal]) {
        if goals != remoteGoals {
            goals = remoteGoals
        }
    }

    // MARK: - Goal Resolution Priority (Report Entegrasyonu)

    func totalGoal(for period: WorkGoalPeriod, date: Date = Date()) -> WorkGoal? {
        let activeTotal = goals.filter { $0.scope == .total && $0.period == period && $0.isEnabled }

        // 1. Period-specific goal matching date
        if let specific = activeTotal.first(where: { g in
            g.mode == .periodSpecific &&
            g.startDate != nil && g.endDate != nil &&
            g.startDate! <= date && date < g.endDate!
        }) {
            return specific
        }

        // 2. Fallback to recurring goal
        return activeTotal.first(where: { $0.mode == .recurring })
    }

    func totalGoal(
        for period: WorkGoalPeriod,
        mode: WorkGoalMode,
        date: Date = Date(),
        includeDisabled: Bool = true
    ) -> WorkGoal? {
        goals.first { goal in
            guard goal.scope == .total && goal.period == period && goal.mode == mode else { return false }
            guard includeDisabled || goal.isEnabled else { return false }
            return matchesCurrentModeRange(goal, period: period, mode: mode, date: date)
        }
    }

    func workAreaGoals(for period: WorkGoalPeriod, date: Date = Date()) -> [WorkGoal] {
        let active = goals.filter { $0.scope == .workArea && $0.period == period && $0.isEnabled }
        let grouped = Dictionary(grouping: active) { $0.workAreaName?.lowercased() ?? "" }

        var resolved: [WorkGoal] = []
        for (_, list) in grouped {
            if let specific = list.first(where: { g in
                g.mode == .periodSpecific &&
                g.startDate != nil && g.endDate != nil &&
                g.startDate! <= date && date < g.endDate!
            }) {
                resolved.append(specific)
            } else if let recurring = list.first(where: { $0.mode == .recurring }) {
                resolved.append(recurring)
            }
        }
        return resolved
    }

    func goal(forWorkArea name: String, period: WorkGoalPeriod, date: Date = Date()) -> WorkGoal? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = goals.filter { $0.scope == .workArea && $0.period == period && $0.workAreaName?.lowercased() == trimmed && $0.isEnabled }

        if let specific = matches.first(where: { g in
            g.mode == .periodSpecific && g.startDate != nil && g.endDate != nil &&
            g.startDate! <= date && date < g.endDate!
        }) {
            return specific
        }
        return matches.first(where: { $0.mode == .recurring })
    }

    func goal(
        forWorkArea name: String,
        period: WorkGoalPeriod,
        mode: WorkGoalMode,
        date: Date = Date(),
        includeDisabled: Bool = true
    ) -> WorkGoal? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return goals.first { goal in
            guard goal.scope == .workArea else { return false }
            guard goal.period == period && goal.mode == mode else { return false }
            guard goal.workAreaName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed else { return false }
            guard includeDisabled || goal.isEnabled else { return false }
            return matchesCurrentModeRange(goal, period: period, mode: mode, date: date)
        }
    }

    private func matchesCurrentModeRange(_ goal: WorkGoal, period: WorkGoalPeriod, mode: WorkGoalMode, date: Date) -> Bool {
        guard mode == .periodSpecific else { return true }
        let range = WorkGoalStore.periodSpecificDateRange(for: period, referenceDate: date)
        return goal.startDate == range.start && goal.endDate == range.end
    }

    func allGoalsForWorkArea(_ name: String) -> [WorkGoal] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return goals.filter { $0.scope == .workArea && $0.workAreaName?.lowercased() == trimmed }
    }

    // MARK: - Validation ("Çelişkili Hedef Kontrolü")

    func validateGoal(
        scope: WorkGoalScope,
        workAreaName: String?,
        period: WorkGoalPeriod,
        mode: WorkGoalMode,
        targetSeconds: Int,
        isEnabled: Bool,
        lang: String = "tr"
    ) -> String? {
        guard isEnabled && targetSeconds > 0 else { return nil }

        let normalizedWorkArea = workAreaName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidateRange = comparableDateRange(period: period, mode: mode)

        if period == .weekly {
            // Weekly goal target cannot be lower than any active Daily goal for same scope & workArea
            let activeDailyGoals = goals.filter { g in
                g.isEnabled && g.scope == scope && g.period == .daily &&
                (scope == .total || g.workAreaName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedWorkArea) &&
                goalsAreComparable(existing: g, candidateRange: candidateRange)
            }
            for dg in activeDailyGoals {
                if targetSeconds < dg.targetSeconds {
                    return lang == "tr"
                        ? "Haftalık hedef, bu haftadaki günlük hedeflerden düşük olamaz."
                        : "Weekly goal cannot be lower than daily goals in that week."
                }
            }
        } else if period == .monthly {
            // Monthly goal target cannot be lower than any active Weekly goal for same scope & workArea
            let activeWeeklyGoals = goals.filter { g in
                g.isEnabled && g.scope == scope && g.period == .weekly &&
                (scope == .total || g.workAreaName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedWorkArea) &&
                goalsAreComparable(existing: g, candidateRange: candidateRange)
            }
            for wg in activeWeeklyGoals {
                if targetSeconds < wg.targetSeconds {
                    return lang == "tr"
                        ? "Aylık hedef, bu aydaki haftalık hedeflerden düşük olamaz."
                        : "Monthly goal cannot be lower than weekly goals in that month."
                }
            }
        } else if period == .daily {
            // Daily goal target cannot exceed active Weekly goal
            let activeWeeklyGoals = goals.filter { g in
                g.isEnabled && g.scope == scope && g.period == .weekly &&
                (scope == .total || g.workAreaName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedWorkArea) &&
                goalsAreComparable(existing: g, candidateRange: candidateRange)
            }
            for wg in activeWeeklyGoals {
                if targetSeconds > wg.targetSeconds {
                    return lang == "tr"
                        ? "Haftalık hedef (\(formatShort(wg.targetSeconds, lang: lang))), günlük hedeften düşük kalıyor."
                        : "Weekly goal (\(formatShort(wg.targetSeconds, lang: lang))) cannot be lower than daily goal."
                }
            }
        }

        return nil
    }

    private func comparableDateRange(period: WorkGoalPeriod, mode: WorkGoalMode, referenceDate: Date = Date()) -> DateInterval? {
        guard mode == .periodSpecific else { return nil }
        let range = WorkGoalStore.periodSpecificDateRange(for: period, referenceDate: referenceDate)
        return DateInterval(start: range.start, end: range.end)
    }

    private func goalsAreComparable(existing goal: WorkGoal, candidateRange: DateInterval?) -> Bool {
        guard let candidateRange else { return true }
        guard goal.mode == .periodSpecific else { return true }
        guard let start = goal.startDate, let end = goal.endDate else { return false }
        return DateInterval(start: start, end: end).intersects(candidateRange)
    }

    // MARK: - Firestore Sync Helper

    /// Returns the UID of the currently linked (non-anonymous) Google user — or nil.
    private var linkedUID: String? {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return nil }
        return user.uid
    }

    // MARK: - Summaries

    func totalGoalsSummary(lang: String) -> String {
        var parts: [String] = []
        if let d = totalGoal(for: .daily) {
            let label = d.mode.label(period: .daily, lang: lang)
            parts.append("\(label) \(formatShort(d.targetSeconds, lang: lang))")
        } else {
            parts.append(lang == "tr" ? "Günlük hedef yok" : "No daily goal")
        }
        if let w = totalGoal(for: .weekly) {
            let label = w.mode.label(period: .weekly, lang: lang)
            parts.append("\(label) \(formatShort(w.targetSeconds, lang: lang))")
        } else {
            parts.append(lang == "tr" ? "Haftalık hedef yok" : "No weekly goal")
        }
        if let m = totalGoal(for: .monthly) {
            let label = m.mode.label(period: .monthly, lang: lang)
            parts.append("\(label) \(formatShort(m.targetSeconds, lang: lang))")
        } else {
            parts.append(lang == "tr" ? "Aylık hedef yok" : "No monthly goal")
        }
        return parts.joined(separator: " · ")
    }

    func workAreaGoalsSummary(lang: String) -> String {
        let active = goals.filter { $0.scope == .workArea && $0.isEnabled }
        if active.isEmpty {
            return lang == "tr" ? "Çalışma hedefi yok" : "No work area goals"
        }
        let formatted = active.prefix(2).compactMap { g -> String? in
            guard let name = g.workAreaName else { return nil }
            let pStr = g.mode.label(period: g.period, lang: lang)
            return "\(name) \(formatShort(g.targetSeconds, lang: lang)) (\(pStr))"
        }
        return formatted.joined(separator: " · ")
    }

    func cleanupOrphanGoals(validNames: Set<String>) {
        let normalizedValid = Set(validNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let filtered = goals.filter { goal in
            if goal.scope == .total { return true }
            guard let name = goal.workAreaName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
            return normalizedValid.contains(name)
        }
        if filtered.count != goals.count {
            goals = filtered
        }
    }

    private func formatShort(_ seconds: Int, lang: String) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        if lang == "tr" {
            if hrs > 0 && mins > 0 { return "\(hrs) sa \(mins) dk" }
            if hrs > 0 { return "\(hrs) sa" }
            return "\(mins) dk"
        } else {
            if hrs > 0 && mins > 0 { return "\(hrs)h \(mins)m" }
            if hrs > 0 { return "\(hrs)h" }
            return "\(mins)m"
        }
    }
}
