//
//  ReportMetrics.swift
//  Yonder
//

import Foundation

/// Time window blocks for categorizing focus sessions.
enum ReportTimeBlock: String, CaseIterable, Identifiable {
    case morning   // 05:00 - 11:59
    case afternoon // 12:00 - 16:59
    case evening   // 17:00 - 23:59
    case night     // 00:00 - 04:59

    var id: String { rawValue }

    static func from(hour: Int) -> ReportTimeBlock {
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<24: return .evening
        default: return .night
        }
    }

    func localizedName(lang: String) -> String {
        switch self {
        case .morning: return lang == "tr" ? "sabah" : "morning"
        case .afternoon: return lang == "tr" ? "öğlen" : "afternoon"
        case .evening: return lang == "tr" ? "akşam" : "evening"
        case .night: return lang == "tr" ? "gece" : "night"
        }
    }

    func capitalizedName(lang: String) -> String {
        switch self {
        case .morning: return lang == "tr" ? "Sabah" : "Morning"
        case .afternoon: return lang == "tr" ? "Öğlen" : "Afternoon"
        case .evening: return lang == "tr" ? "Akşam" : "Evening"
        case .night: return lang == "tr" ? "Gece" : "Night"
        }
    }
}

/// Encapsulates calculated focus report metrics for Yonder.
struct ReportMetrics {
    let allSessions: [FocusSession]
    let todaySessions: [FocusSession]
    let currentWeekSessions: [FocusSession]
    let previousWeekSessions: [FocusSession]

    let todayTotalSeconds: Int
    let currentWeekTotalSeconds: Int
    let previousWeekTotalSeconds: Int
    let weeklyDeltaSeconds: Int
    let totalFocusSeconds: Int
    let averageSessionSeconds: Int

    let currentWeekSoloTotalSeconds: Int
    let currentWeekRoomTotalSeconds: Int
    let currentWeekRoomSessionCount: Int

    let bestCompletedDurationBucketMinutes: Int?
    let recommendedFocusDurationMinutes: Int?

    let unappearedSubjectName: String?
    let daysSinceUnappearedSubject: Int?

    let streakDays: Int
    let topSubjectName: String?
    let topSubjectSeconds: Int
    let previousWeekTopSubjectName: String?
    let strongestTimeBlock: ReportTimeBlock?
    let timeBlockTotals: [ReportTimeBlock: Int]

    let completionRate: Int
    let completedSessionCount: Int
    let totalSessionCount: Int

    /// Indicates whether there is enough session history (4+ sessions) to make confident assertions.
    var hasSufficientData: Bool {
        totalSessionCount >= 4
    }

    init(sessions: [FocusSession]) {
        let calendar = Calendar.current
        let now = Date()

        self.allSessions = sessions
        self.totalSessionCount = sessions.count

        // Today sessions & total
        self.todaySessions = sessions.filter { calendar.isDateInToday($0.date) }
        self.todayTotalSeconds = todaySessions.reduce(0) { $0 + $1.durationSeconds }

        // Current week sessions & total
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart

        self.currentWeekSessions = sessions.filter { $0.date >= weekStart && $0.date <= now }
        self.currentWeekTotalSeconds = currentWeekSessions.reduce(0) { $0 + $1.durationSeconds }

        // Previous week sessions & total
        self.previousWeekSessions = sessions.filter { $0.date >= previousWeekStart && $0.date < weekStart }
        self.previousWeekTotalSeconds = previousWeekSessions.reduce(0) { $0 + $1.durationSeconds }
        self.weeklyDeltaSeconds = currentWeekTotalSeconds - previousWeekTotalSeconds

        // Mode-based metrics (Solo vs Room) for current week
        let roomSessions = currentWeekSessions.filter { $0.modeRawValue == "room" }
        let soloSessions = currentWeekSessions.filter { $0.modeRawValue != "room" }
        self.currentWeekRoomSessionCount = roomSessions.count
        self.currentWeekRoomTotalSeconds = roomSessions.reduce(0) { $0 + $1.durationSeconds }
        self.currentWeekSoloTotalSeconds = soloSessions.reduce(0) { $0 + $1.durationSeconds }

        // Total focus & average session
        self.totalFocusSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        self.averageSessionSeconds = sessions.isEmpty ? 0 : totalFocusSeconds / sessions.count

        // Duration Buckets calculation (15, 25, 45, 60 minutes)
        var bucketStats: [Int: (total: Int, completed: Int)] = [
            15: (0, 0),
            25: (0, 0),
            45: (0, 0),
            60: (0, 0)
        ]

        for session in sessions {
            let targetSecs = (session.plannedDurationSeconds ?? 0) > 0 ? session.plannedDurationSeconds! : session.durationSeconds
            let targetMins = max(1, targetSecs / 60)

            let bucketKey: Int
            if targetMins <= 20 { bucketKey = 15 }
            else if targetMins <= 35 { bucketKey = 25 }
            else if targetMins <= 50 { bucketKey = 45 }
            else { bucketKey = 60 }

            let existing = bucketStats[bucketKey] ?? (0, 0)
            bucketStats[bucketKey] = (
                total: existing.total + 1,
                completed: existing.completed + (session.completed ? 1 : 0)
            )
        }

        if sessions.count >= 4 {
            let validBuckets = bucketStats.filter { $0.value.total >= 2 }
            if let best = validBuckets.max(by: {
                let r0 = Double($0.value.completed) / Double($0.value.total)
                let r1 = Double($1.value.completed) / Double($1.value.total)
                if r0 != r1 { return r0 < r1 }
                return $0.value.total < $1.value.total
            }), Double(best.value.completed) / Double(best.value.total) >= 0.5 {
                self.bestCompletedDurationBucketMinutes = best.key
            } else {
                self.bestCompletedDurationBucketMinutes = nil
            }
        } else {
            self.bestCompletedDurationBucketMinutes = nil
        }

        // Recommended Focus Duration (from last 10 completed sessions)
        let recentCompleted = sessions.prefix(10).filter(\.completed)
        if sessions.count >= 4 && recentCompleted.count >= 2 {
            var recentCounts: [Int: Int] = [:]
            for session in recentCompleted {
                let targetSecs = (session.plannedDurationSeconds ?? 0) > 0 ? session.plannedDurationSeconds! : session.durationSeconds
                let mins = max(1, targetSecs / 60)
                let roundedBucket: Int
                if mins <= 20 { roundedBucket = 15 }
                else if mins <= 27 { roundedBucket = 25 }
                else if mins <= 37 { roundedBucket = 30 }
                else if mins <= 52 { roundedBucket = 45 }
                else { roundedBucket = 60 }
                recentCounts[roundedBucket, default: 0] += 1
            }
            if let topBucket = recentCounts.max(by: { $0.value < $1.value }), topBucket.value >= 2 {
                self.recommendedFocusDurationMinutes = topBucket.key
            } else {
                self.recommendedFocusDurationMinutes = nil
            }
        } else {
            self.recommendedFocusDurationMinutes = nil
        }

        // Unappeared Subject Gap calculation
        if sessions.count >= 4 {
            let thisWeekSubjectKeys = Set(currentWeekSessions.compactMap { session -> String? in
                if let s = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s.lowercased() }
                if let n = session.intentionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty { return n.lowercased() }
                return nil
            })

            var pastSubjectTotals: [String: (displayName: String, seconds: Int, count: Int, maxDate: Date)] = [:]
            for session in sessions where session.date < weekStart {
                let name: String?
                if let s = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { name = s }
                else if let n = session.intentionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty { name = n }
                else { name = nil }

                guard let realName = name else { continue }
                let key = realName.lowercased()
                if !thisWeekSubjectKeys.contains(key) {
                    let existing = pastSubjectTotals[key]
                    pastSubjectTotals[key] = (
                        displayName: existing?.displayName ?? realName,
                        seconds: (existing?.seconds ?? 0) + session.durationSeconds,
                        count: (existing?.count ?? 0) + 1,
                        maxDate: max(existing?.maxDate ?? session.date, session.date)
                    )
                }
            }

            let qualified = pastSubjectTotals.values.filter { $0.count >= 2 && $0.seconds >= 1200 }
            if let topUnappeared = qualified.max(by: { $0.seconds < $1.seconds }) {
                self.unappearedSubjectName = topUnappeared.displayName
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: topUnappeared.maxDate), to: calendar.startOfDay(for: now)).day ?? 0
                self.daysSinceUnappearedSubject = max(1, days)
            } else {
                self.unappearedSubjectName = nil
                self.daysSinceUnappearedSubject = nil
            }
        } else {
            self.unappearedSubjectName = nil
            self.daysSinceUnappearedSubject = nil
        }

        // Completion metrics
        self.completedSessionCount = sessions.filter(\.completed).count
        if sessions.isEmpty {
            self.completionRate = 0
        } else {
            self.completionRate = Int((Double(completedSessionCount) / Double(sessions.count) * 100).rounded())
        }

        // Streak calculation (strictly starts from today if today has a session)
        let focusedDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var day = calendar.startOfDay(for: now)

        if focusedDays.contains(day) {
            while focusedDays.contains(day) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previousDay
            }
        }
        self.streakDays = streak

        // Current Week Top Subject calculation
        let targetSessionsForSubject = currentWeekSessions.isEmpty ? sessions : currentWeekSessions
        var subjectTotals: [String: (displayName: String, seconds: Int)] = [:]

        for session in targetSessionsForSubject {
            let subj: String?
            if let s = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                subj = s
            } else if let n = session.intentionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                subj = n
            } else {
                subj = nil
            }

            guard let realSubject = subj else { continue }
            let key = realSubject.lowercased()
            let existing = subjectTotals[key]
            subjectTotals[key] = (
                displayName: existing?.displayName ?? realSubject,
                seconds: (existing?.seconds ?? 0) + session.durationSeconds
            )
        }

        if let top = subjectTotals.values.max(by: { $0.seconds < $1.seconds }) {
            self.topSubjectName = top.displayName
            self.topSubjectSeconds = top.seconds
        } else {
            self.topSubjectName = nil
            self.topSubjectSeconds = 0
        }

        // Previous Week Top Subject calculation
        var prevSubjectTotals: [String: (displayName: String, seconds: Int)] = [:]
        for session in previousWeekSessions {
            let subj: String?
            if let s = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                subj = s
            } else if let n = session.intentionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                subj = n
            } else {
                subj = nil
            }

            guard let realSubject = subj else { continue }
            let key = realSubject.lowercased()
            let existing = prevSubjectTotals[key]
            prevSubjectTotals[key] = (
                displayName: existing?.displayName ?? realSubject,
                seconds: (existing?.seconds ?? 0) + session.durationSeconds
            )
        }
        self.previousWeekTopSubjectName = prevSubjectTotals.values.max(by: { $0.seconds < $1.seconds })?.displayName

        // Time block calculation
        let targetSessionsForTimeBlock = currentWeekSessions.isEmpty ? sessions : currentWeekSessions
        var totalsByBlock: [ReportTimeBlock: Int] = [
            .morning: 0,
            .afternoon: 0,
            .evening: 0,
            .night: 0
        ]

        for session in targetSessionsForTimeBlock where session.durationSeconds > 0 {
            let dateToUse = session.startedAt ?? session.date
            let hour = calendar.component(.hour, from: dateToUse)
            let block = ReportTimeBlock.from(hour: hour)
            totalsByBlock[block, default: 0] += session.durationSeconds
        }

        self.timeBlockTotals = totalsByBlock

        if let maxBlock = totalsByBlock.max(by: { $0.value < $1.value }), maxBlock.value > 0 {
            self.strongestTimeBlock = maxBlock.key
        } else {
            self.strongestTimeBlock = nil
        }
    }

    // MARK: - Formatters

    static func formattedTime(seconds: Int, lang: String) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        if lang == "tr" {
            if hrs > 0 { return "\(hrs) sa \(mins) dk" }
            return "\(mins) dk"
        } else {
            if hrs > 0 { return "\(hrs)h \(mins)m" }
            return "\(mins)m"
        }
    }

    func formattedStreak(lang: String) -> String {
        if lang == "tr" {
            return "\(streakDays) gün"
        } else {
            return "\(streakDays) \(streakDays == 1 ? "day" : "days")"
        }
    }
}
