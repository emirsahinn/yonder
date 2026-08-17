//
//  DayDetailSheet.swift
//  Yonder
//
//  Dedicated day detail sheet showing focus metrics, goal progress,
//  work area distribution, and session breakdown for a specific selected date.
//

import SwiftUI
import SwiftData

struct DayDetailSheet: View {

    let date: Date
    let sessions: [FocusSession]

    @AppStorage("app_language") private var appLanguage: String = "en"
    @ObservedObject private var goalStore = WorkGoalStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var isIPad: Bool { hSizeClass == .regular }
    private var calendar: Calendar { Calendar.current }

    private var dayStart: Date { calendar.startOfDay(for: date) }
    private var dayEnd: Date { calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date }

    private var daySessions: [FocusSession] {
        sessions.filter { $0.date >= dayStart && $0.date < dayEnd }
    }

    private var formattedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.dateFormat = "d MMMM EEEE" // 31 Temmuz Cuma
        return formatter.string(from: date).capitalized
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        if hrs > 0 {
            if mins > 0 {
                return appLanguage == "tr" ? "\(hrs) sa \(mins) dk" : "\(hrs)h \(mins)m"
            } else {
                return appLanguage == "tr" ? "\(hrs) sa" : "\(hrs)h"
            }
        } else {
            return appLanguage == "tr" ? "\(mins) dk" : "\(mins)m"
        }
    }

    // MARK: - Work Area Distribution Item

    private struct WorkDistributionItem: Identifiable {
        let id = UUID()
        let name: String
        let durationSeconds: Int
        let sessionCount: Int
        let percentage: Double
    }

    private var workAreaDistribution: [WorkDistributionItem] {
        let totalSecs = daySessions.reduce(0) { $0 + $1.durationSeconds }
        guard totalSecs > 0 else { return [] }

        var map: [String: (seconds: Int, count: Int)] = [:]
        for session in daySessions {
            let name = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = (name?.isEmpty == false) ? name! : (appLanguage == "tr" ? "Çalışma seçilmedi" : "No work area selected")
            var current = map[displayName, default: (0, 0)]
            current.seconds += session.durationSeconds
            current.count += 1
            map[displayName] = current
        }

        return map.map { (key, val) in
            let pct = Double(val.seconds) / Double(totalSecs) * 100.0
            return WorkDistributionItem(
                name: key,
                durationSeconds: val.seconds,
                sessionCount: val.count,
                percentage: pct
            )
        }.sorted(by: { $0.durationSeconds > $1.durationSeconds })
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top Navigation Bar ────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedDateTitle)
                            .font(.system(size: isIPad ? 22 : 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(appLanguage == "tr" ? "Günlük Çalışma Detayı" : "Daily Focus Detail")
                            .font(.system(size: isIPad ? 13 : 11, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                    }

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(white: 0.50))
                            .padding(10)
                            .background(Circle().fill(Color(white: 0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, isIPad ? 24 : 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isIPad ? 20 : 16) {

                        // ── 1. DAILY OVERVIEW & GOAL PROGRESS ─────────────────────
                        dailyOverviewCard

                        if daySessions.isEmpty {
                            // ── EMPTY STATE ───────────────────────────────────────
                            emptyDayView
                        } else {
                            // ── 2. WORK AREA DISTRIBUTION ─────────────────────────
                            workDistributionCard

                            // ── 3. SESSION CHRONOLOGY LIST ────────────────────────
                            sessionListCard
                        }
                    }
                    .padding(.horizontal, isIPad ? 24 : 18)
                    .padding(.bottom, isIPad ? 32 : 24)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var dailyOverviewCard: some View {
        let totalCompletedSecs = daySessions.reduce(0) { $0 + $1.durationSeconds }
        let dailyGoal = goalStore.totalGoal(for: .daily)
        let targetSecs = dailyGoal?.targetSeconds ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appLanguage == "tr" ? "Toplam Odaklanma" : "Total Focus")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .textCase(.uppercase)
                        .tracking(1.0)

                    Text(formatDuration(totalCompletedSecs))
                        .font(.system(size: isIPad ? 32 : 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(appLanguage == "tr" ? "Oturum Sayısı" : "Total Sessions")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .textCase(.uppercase)
                        .tracking(1.0)

                    Text("\(daySessions.count)")
                        .font(.system(size: isIPad ? 26 : 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: 0.85))
                        .monospacedDigit()
                }
            }

            // Daily Goal Line (if daily goal set)
            if targetSecs > 0 {
                let remainingSecs = max(0, targetSecs - totalCompletedSecs)
                let pct = min(100, Int((Double(totalCompletedSecs) / Double(targetSecs) * 100).rounded()))
                let ratio = min(1.0, CGFloat(totalCompletedSecs) / CGFloat(targetSecs))

                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(Color(white: 0.08))
                        .frame(height: 0.5)

                    HStack {
                        Text(pct >= 100
                             ? (appLanguage == "tr" ? "Günlük Hedef Tamamlandı (%100)" : "Daily Goal Completed (100%)")
                             : (appLanguage == "tr" ? "Günlük Hedef: \(formatDuration(totalCompletedSecs)) / \(formatDuration(targetSecs))" : "Daily Goal: \(formatDuration(totalCompletedSecs)) / \(formatDuration(targetSecs))"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(pct >= 100 ? Color(red: 0.45, green: 0.85, blue: 0.65) : Color(white: 0.60))
                            .monospacedDigit()

                        Spacer()

                        Text("%\(pct)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(white: 0.80))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(white: 0.10))
                                .frame(height: 5)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(pct >= 100 ? Color(red: 0.45, green: 0.85, blue: 0.65) : Color.white)
                                .frame(width: max(pct > 0 ? 5 : 0, geo.size.width * ratio), height: 5)
                        }
                    }
                    .frame(height: 5)

                    if totalCompletedSecs < targetSecs {
                        Text(appLanguage == "tr" ? "\(formatDuration(remainingSecs)) kaldı" : "\(formatDuration(remainingSecs)) remaining")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color(white: 0.40))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(white: 0.10), lineWidth: 0.5)
                )
        )
    }

    private var emptyDayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 28))
                .foregroundStyle(Color(white: 0.30))
                .padding(.bottom, 4)

            Text(appLanguage == "tr" ? "Bu gün çalışma kaydı bulunmuyor." : "No work records for this day.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.60))

            Text(appLanguage == "tr" ? "Odaklanma oturumu tamamladığında verilerin burada görünecek." : "Your data will appear here once you complete a focus session.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color(white: 0.40))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(white: 0.08), lineWidth: 0.5)
                )
        )
    }

    private var workDistributionCard: some View {
        let distribution = workAreaDistribution

        return VStack(alignment: .leading, spacing: 14) {
            Text(appLanguage == "tr" ? "Çalışma Dağılımı" : "Work Area Distribution")
                .font(.system(size: isIPad ? 16 : 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.90))

            VStack(spacing: 10) {
                ForEach(distribution) { item in
                    let ratio = min(1.0, CGFloat(item.percentage) / 100.0)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(white: 0.45))

                                Text(item.name)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(white: 0.90))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(formatDuration(item.durationSeconds))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(white: 0.90))
                                .monospacedDigit()
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(white: 0.10))
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(white: 0.70))
                                    .frame(width: max(4, geo.size.width * ratio), height: 4)
                            }
                        }
                        .frame(height: 4)

                        HStack {
                            Text("\(item.sessionCount) \(appLanguage == "tr" ? "oturum" : (item.sessionCount == 1 ? "session" : "sessions"))")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color(white: 0.40))

                            Spacer()

                            Text(String(format: "%%%.0f", item.percentage))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.45))
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.025))
                    )
                }
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(white: 0.10), lineWidth: 0.5)
                )
        )
    }

    private var sessionListCard: some View {
        let sorted = daySessions.sorted(by: { $0.date > $1.date })

        return VStack(alignment: .leading, spacing: 14) {
            Text(appLanguage == "tr" ? "Oturum Listesi" : "Session List")
                .font(.system(size: isIPad ? 16 : 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.90))

            VStack(spacing: 8) {
                ForEach(sorted) { session in
                    let name = (session.subject?.isEmpty == false) ? session.subject! : (appLanguage == "tr" ? "Çalışma seçilmedi" : "No work area selected")
                    let timeStr = DateFormatter.localizedString(from: session.date, dateStyle: .none, timeStyle: .short)

                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(white: 0.45))

                            Text(name)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.85))
                        }

                        Spacer()

                        Text("\(formatDuration(session.durationSeconds)) · \(timeStr)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                            .monospacedDigit()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.025)))
                }
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(white: 0.10), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    DayDetailSheet(date: Date(), sessions: [])
}
