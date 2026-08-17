//
//  SubjectBreakdownView.swift
//  Yonder
//

import SwiftUI

enum SubjectPeriodFilter: String, CaseIterable, Identifiable {
    case week  = "subject_period_week"
    case month = "subject_period_month"
    case all   = "subject_period_all"

    var id: String { rawValue }

    func title(appLanguage: String) -> String {
        String.localized(rawValue, lang: appLanguage)
    }
}

struct SubjectItem: Identifiable {
    let id = UUID()
    let name: String
    let durationSeconds: Int
    let sessionCount: Int
    let totalSeconds: Int

    func formattedDuration(appLanguage: String) -> String {
        let hrs  = durationSeconds / 3600
        let mins = (durationSeconds % 3600) / 60

        if appLanguage == "tr" {
            if hrs > 0 { return "\(hrs) sa \(mins) dk" }
            return "\(mins) dk"
        } else {
            if hrs > 0 { return "\(hrs)h \(mins)m" }
            return "\(mins)m"
        }
    }

    var percentage: Int {
        guard totalSeconds > 0 else { return 0 }
        return Int((Double(durationSeconds) / Double(totalSeconds) * 100).rounded())
    }

    func formattedSessionCount(appLanguage: String) -> String {
        if appLanguage == "tr" {
            return "\(sessionCount) oturum"
        }
        return sessionCount == 1 ? "1 session" : "\(sessionCount) sessions"
    }
}

struct SubjectBreakdownView: View {

    let sessions: [FocusSession]

    @AppStorage("app_language") private var appLanguage: String = "en"
    @State private var filter: SubjectPeriodFilter = .week
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var isIPad: Bool { hSizeClass == .regular }

    private var unnamedLabel: String {
        appLanguage == "tr" ? "Adlandırılmamış çalışma" : "Unnamed work"
    }

    private func workAccentColor(for name: String) -> Color {
        WorkItemColorPalette.color(for: name, unnamedLabel: unnamedLabel)
    }

    private var filteredSessions: [FocusSession] {
        let calendar = Calendar.current
        let now = Date()

        switch filter {
        case .week:
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return sessions }
            return sessions.filter { $0.date >= weekStart && $0.date <= now }
        case .month:
            guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else { return sessions }
            return sessions.filter { $0.date >= monthStart && $0.date <= now }
        case .all:
            return sessions
        }
    }

    private var subjectItems: [SubjectItem] {
        var groups: [String: (displayName: String, durationSeconds: Int, sessionCount: Int)] = [:]

        for session in filteredSessions {
            let displayName: String
            if let subj = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines), !subj.isEmpty {
                displayName = subj
            } else if let note = session.intentionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                displayName = note
            } else {
                displayName = unnamedLabel
            }

            let key = displayName.lowercased()
            let existing = groups[key]
            groups[key] = (
                displayName: existing?.displayName ?? displayName,
                durationSeconds: (existing?.durationSeconds ?? 0) + session.durationSeconds,
                sessionCount: (existing?.sessionCount ?? 0) + 1
            )
        }

        let totalSeconds = groups.values.reduce(0) { $0 + $1.durationSeconds }
        return groups.values.map {
            SubjectItem(
                name: $0.displayName,
                durationSeconds: $0.durationSeconds,
                sessionCount: $0.sessionCount,
                totalSeconds: totalSeconds
            )
        }
        .sorted { $0.durationSeconds > $1.durationSeconds }
    }

    private var visibleSubjectItems: [SubjectItem] {
        Array(subjectItems.prefix(5))
    }

    private var overflowCount: Int {
        max(0, subjectItems.count - 5)
    }

    private var maxSeconds: Int {
        subjectItems.map { $0.durationSeconds }.max() ?? 1
    }

    private var shortHeadline: String {
        if filteredSessions.isEmpty {
            return appLanguage == "tr"
                ? "İlk çalışmalarından sonra dengen burada belirecek."
                : "Your work balance will appear after your first work."
        }

        let namedItems = subjectItems.filter { $0.name != unnamedLabel }
        if namedItems.isEmpty {
            return appLanguage == "tr"
                ? "Çalışmalarını adlandırdıkça dengen belirginleşecek."
                : "Your balance will become clearer as you name your work."
        }

        if namedItems.count == 1 {
            return appLanguage == "tr"
                ? "Tek bir çalışma bu haftaya yön vermiş."
                : "A single work area shaped this week."
        }

        if let top = namedItems.first {
            if top.percentage >= 50 {
                return appLanguage == "tr"
                    ? "Bu hafta odağın en çok \(top.name) üzerinde."
                    : "Your focus this week is mostly on \(top.name)."
            } else {
                return appLanguage == "tr"
                    ? "Çalışmaların dengeli dağılmış."
                    : "Your work is evenly balanced."
            }
        }

        return appLanguage == "tr" ? "Dengen oluşuyor." : "Balance forming."
    }

    private var unappearedPlannedSubjectThisWeek: String? {
        guard filter == .week else { return nil }
        let intentions = WeeklySubjectIntentionStore.shared.load()
        guard !intentions.isEmpty else { return nil }

        let activeKeys = Set(subjectItems.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        for (key, sec) in intentions where sec > 0 {
            if !activeKeys.contains(key) {
                return key.capitalized
            }
        }
        return nil
    }

    private var unappearedSubjectThisWeek: String? {
        guard filter == .week else { return nil }
        let metrics = ReportMetrics(sessions: sessions)
        return metrics.unappearedSubjectName
    }

    private var periodSegmentControl: some View {
        HStack(spacing: 4) {
            ForEach(SubjectPeriodFilter.allCases) { f in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filter = f
                    }
                } label: {
                    Text(f.title(appLanguage: appLanguage))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(filter == f ? Color.black : Color(white: 0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(filter == f ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color(white: 0.10))
        )
    }

    private var headerView: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center) {
                Text(appLanguage == "tr" ? "ÇALIŞMA DENGEN" : "WORK BALANCE")
                    .font(.system(size: isIPad ? 13 : 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .tracking(2.0)

                Spacer()

                periodSegmentControl
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(appLanguage == "tr" ? "ÇALIŞMA DENGEN" : "WORK BALANCE")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .tracking(2.0)

                    Spacer()
                }

                periodSegmentControl
            }
        }
    }

    private var emptyPlaceholdersView: some View {
        VStack(spacing: 10) {
            ForEach(0..<3) { idx in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: CGFloat(60 + idx * 25), height: 12)

                        Spacer()

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 40, height: 10)
                    }

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 5)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Title & Responsive Period Filter Segment Control
            headerView

            // Short Headline Subtitle
            Text(shortHeadline)
                .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.70))
                .fixedSize(horizontal: false, vertical: true)

            // Optional Planned or Inactive Subject Note
            if let plannedSubject = unappearedPlannedSubjectThisWeek {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.45))

                    Text(appLanguage == "tr"
                         ? "\(plannedSubject) bu hafta hedeflenmiş ama henüz görünmüyor."
                         : "\(plannedSubject) is planned this week but has not appeared yet.")
                        .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.035))
                )
            } else if let inactiveSubject = unappearedSubjectThisWeek {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.45))

                    Text(appLanguage == "tr" ? "\(inactiveSubject) bu hafta henüz görünmüyor." : "\(inactiveSubject) has not appeared this week yet.")
                        .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.035))
                )
            }

            // Work Items List (Top 5 visible)
            if !subjectItems.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(visibleSubjectItems.enumerated()), id: \.element.id) { idx, item in
                        let ratio = CGFloat(item.durationSeconds) / CGFloat(max(maxSeconds, 1))
                        let accentColor = workAccentColor(for: item.name)
                        let percentStr = appLanguage == "tr" ? "%\(item.percentage)" : "\(item.percentage)%"
                        let detailText = "\(item.formattedDuration(appLanguage: appLanguage)) · \(percentStr) · \(item.formattedSessionCount(appLanguage: appLanguage))"
                        let isTop = idx == 0

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: isIPad ? 15 : 13, weight: isTop ? .semibold : .medium, design: .rounded))
                                    .foregroundStyle(isTop ? Color(white: 0.95) : Color(white: 0.85))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)

                                Spacer()

                                Text(detailText)
                                    .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color(white: 0.45))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }

                            // Slim Progress bar indicator
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 5)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(accentColor.opacity(isTop ? 0.85 : 0.65))
                                        .frame(width: max(6, geo.size.width * ratio), height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                    }

                    if overflowCount > 0 {
                        HStack {
                            Spacer()
                            Text(appLanguage == "tr" ? "+\(overflowCount) diğer çalışma" : "+\(overflowCount) other work areas")
                                .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(white: 0.40))
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.top, 2)
            } else {
                emptyPlaceholdersView
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
    SubjectBreakdownView(sessions: [])
}
