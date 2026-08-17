//
//  FocusHeatmapView.swift
//  Yonder
//

import SwiftUI
import SwiftData

/// Represents a single day's heatmap item.
struct HeatmapDay: Identifiable, Equatable {
    let id: Date
    let date: Date
    let totalSeconds: Int
    let isToday: Bool
    let isFuture: Bool

    static func == (lhs: HeatmapDay, rhs: HeatmapDay) -> Bool {
        lhs.id == rhs.id && lhs.totalSeconds == rhs.totalSeconds && lhs.isToday == rhs.isToday
    }
}

/// A GitHub-contribution style 12-month focus trail grid component.
struct FocusHeatmapView: View {

    let sessions: [FocusSession]

    @AppStorage("app_language") private var appLanguage: String = "en"
    @State private var selectedDay: HeatmapDay?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }

    private var currentLocale: Locale {
        Locale(identifier: appLanguage)
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = currentLocale
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private var totalWeeks: Int {
        sessions.isEmpty ? 16 : 53
    }

    // MARK: - Heatmap Data Calculation

    private var weeksData: [[HeatmapDay]] {
        let today = calendar.startOfDay(for: Date())
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
        let currentMonday = weekInterval.start
        let weeksBack = totalWeeks - 1

        guard let startMonday = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: currentMonday) else { return [] }

        var totalsByDate: [Date: Int] = [:]
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.date)
            totalsByDate[dayStart, default: 0] += session.durationSeconds
        }

        var result: [[HeatmapDay]] = []

        for weekOffset in 0..<totalWeeks {
            var weekDays: [HeatmapDay] = []
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: weekOffset * 7 + dayOffset, to: startMonday) else { continue }

                let isToday = calendar.isDate(date, inSameDayAs: today)
                let isFuture = date > today
                let totalSecs = totalsByDate[date] ?? 0

                weekDays.append(
                    HeatmapDay(
                        id: date,
                        date: date,
                        totalSeconds: totalSecs,
                        isToday: isToday,
                        isFuture: isFuture
                    )
                )
            }
            result.append(weekDays)
        }

        return result
    }

    // MARK: - Color Gradient Scale

    private func cellColor(for seconds: Int, isFuture: Bool) -> Color {
        if isFuture { return Color.white.opacity(0.02) }
        if seconds == 0 { return Color.white.opacity(0.05) }
        if seconds < 1800 {
            return Color(red: 0.30, green: 0.55, blue: 0.65).opacity(0.40)
        } else if seconds < 3600 {
            return Color(red: 0.35, green: 0.70, blue: 0.60).opacity(0.65)
        } else if seconds < 7200 {
            return Color(red: 0.90, green: 0.70, blue: 0.40).opacity(0.80)
        } else {
            return Color(red: 0.98, green: 0.90, blue: 0.75).opacity(0.95)
        }
    }

    private var activeDaysThisWeekCount: Int {
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return 0 }
        let weekSessions = sessions.filter { $0.date >= weekStart && $0.date <= Date() }
        return Set(weekSessions.map { calendar.startOfDay(for: $0.date) }).count
    }

    private var subtitleText: String {
        if sessions.isEmpty {
            return appLanguage == "tr"
                ? "İlk çalışmalarından sonra izlerin burada belirecek."
                : "Your traces will appear here after your first work."
        }
        return appLanguage == "tr"
            ? "Son haftalardaki çalışma izlerin."
            : "Your work traces over recent weeks."
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        if seconds == 0 { return appLanguage == "tr" ? "Odaklanılmadı" : "No focus recorded" }
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        if appLanguage == "tr" {
            if hrs > 0 { return "\(hrs) sa \(mins) dk" }
            return "\(mins) dk"
        } else {
            if hrs > 0 { return "\(hrs)h \(mins)m" }
            return "\(mins)m"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Title & Legend
            HStack {
                Text(appLanguage == "tr" ? "ODAK İZLERİN" : "FOCUS TRAIL")
                    .font(.system(size: isIPad ? 13 : 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .tracking(2.0)

                Spacer()

                if !sessions.isEmpty {
                    HStack(spacing: 4) {
                        Text(appLanguage == "tr" ? "Az" : "Less")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Color(white: 0.35))

                        ForEach([0, 1200, 2400, 5400, 9000], id: \.self) { sampleSecs in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(cellColor(for: sampleSecs, isFuture: false))
                                .frame(width: 7, height: 7)
                        }

                        Text(appLanguage == "tr" ? "Çok" : "More")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Color(white: 0.35))
                    }
                }
            }

            // Subtitle
            Text(subtitleText)
                .font(.system(size: isIPad ? 13 : 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.50))

            // Grid
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: isIPad ? 4 : 3) {
                        ForEach(Array(weeksData.enumerated()), id: \.offset) { weekIdx, weekDays in
                            VStack(spacing: isIPad ? 4 : 3) {
                                ForEach(weekDays) { day in
                                    let isSelected = selectedDay?.id == day.id

                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            if selectedDay?.id == day.id {
                                                selectedDay = nil
                                            } else {
                                                selectedDay = day
                                            }
                                        }
                                    } label: {
                                        RoundedRectangle(cornerRadius: isIPad ? 3 : 2.5)
                                            .fill(cellColor(for: day.totalSeconds, isFuture: day.isFuture))
                                            .frame(width: isIPad ? 13 : 10, height: isIPad ? 13 : 10)
                                            .overlay(
                                                Group {
                                                    if day.isToday {
                                                        RoundedRectangle(cornerRadius: isIPad ? 3 : 2.5)
                                                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.2)
                                                    } else if isSelected {
                                                        RoundedRectangle(cornerRadius: isIPad ? 3 : 2.5)
                                                            .strokeBorder(Color(white: 0.7), lineWidth: 1.0)
                                                    }
                                                }
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(day.isFuture)
                                }
                            }
                            .id(weekIdx)
                        }
                    }
                    .padding(.vertical, 2)
                    .onAppear {
                        if let lastIdx = weeksData.indices.last {
                            proxy.scrollTo(lastIdx, anchor: .trailing)
                        }
                    }
                }
            }

            // Summary line (if active days in current week > 0)
            if activeDaysThisWeekCount > 0 {
                HStack {
                    Spacer()
                    Text(appLanguage == "tr"
                         ? "Bu hafta \(activeDaysThisWeekCount) gün çalıştın"
                         : "Worked \(activeDaysThisWeekCount) days this week")
                        .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.40))
                }
                .padding(.top, 2)
            }

            // Selected Day Tooltip / Info Banner
            if let selected = selectedDay {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.6))

                    Text(formattedDate(selected.date))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.8))

                    Text("•")
                        .foregroundStyle(Color(white: 0.3))

                    Text(formattedDuration(selected.totalSeconds))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected.totalSeconds > 0 ? Color.white : Color(white: 0.45))

                    Spacer()

                    Button {
                        withAnimation { selectedDay = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(white: 0.15), lineWidth: 0.5)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(isIPad ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.038))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(white: 0.08), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    FocusHeatmapView(sessions: [])
}
