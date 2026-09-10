//
//  ReportView.swift
//  Yonder
//

import SwiftUI
import SwiftData

/// Selected time period for the focus report.
enum ReportPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    func title(lang: String) -> String {
        switch self {
        case .daily:
            return lang == "tr" ? "Günlük" : "Daily"
        case .weekly:
            return lang == "tr" ? "Haftalık" : "Weekly"
        case .monthly:
            return lang == "tr" ? "Aylık" : "Monthly"
        }
    }

    func shareButtonText(lang: String) -> String {
        switch self {
        case .daily:
            return lang == "tr" ? "Bugünümü Paylaş" : "Share Today"
        case .weekly:
            return lang == "tr" ? "Bu Haftamı Paylaş" : "Share This Week"
        case .monthly:
            return lang == "tr" ? "Bu Ayımı Paylaş" : "Share This Month"
        }
    }
}

/// Clean, data-oriented focus report view for Yonder.
struct ReportView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @ObservedObject private var goalStore = WorkGoalStore.shared

    @Query(sort: \FocusSession.date, order: .reverse) private var sessions: [FocusSession]
    @Query(sort: \Subject.lastUsedDate, order: .reverse) private var savedSubjects: [Subject]

    @State private var selectedPeriod: ReportPeriod = .daily
    @State private var referenceDate: Date = Date()
    @State private var showSessionLog: Bool = false
    @State private var showRecapCard: Bool = false
    @State private var showFocusGoals: Bool = false
    @State private var selectedDayForDetail: Date? = nil

    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isIPad: Bool { hSizeClass == .regular }

    private var calendar: Calendar { Calendar.current }
    private var now: Date { referenceDate }

    private var isViewingCurrentPeriod: Bool {
        switch selectedPeriod {
        case .daily:
            return calendar.isDateInToday(referenceDate)
        case .weekly:
            return calendar.isDate(referenceDate, equalTo: Date(), toGranularity: .weekOfYear)
        case .monthly:
            return calendar.isDate(referenceDate, equalTo: Date(), toGranularity: .month)
        }
    }

    private func shiftPeriod(by amount: Int) {
        let component: Calendar.Component
        switch selectedPeriod {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        }
        guard let shifted = calendar.date(byAdding: component, value: amount, to: referenceDate) else { return }
        // Never navigate into the future beyond today.
        referenceDate = min(shifted, Date())
    }

    private var periodRangeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)

        switch selectedPeriod {
        case .daily:
            if calendar.isDateInToday(referenceDate) {
                return appLanguage == "tr" ? "Bugün" : "Today"
            }
            if calendar.isDateInYesterday(referenceDate) {
                return appLanguage == "tr" ? "Dün" : "Yesterday"
            }
            formatter.dateFormat = "d MMMM"
            return formatter.string(from: referenceDate)

        case .weekly:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return "" }
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            formatter.dateFormat = "d MMM"
            return "\(formatter.string(from: interval.start)) – \(formatter.string(from: end))"

        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: referenceDate)
        }
    }

    // MARK: - Period Filtered Sessions & Metrics

    private var periodSessions: [FocusSession] {
        switch selectedPeriod {
        case .daily:
            return sessions.filter { calendar.isDate($0.date, inSameDayAs: now) }

        case .weekly:
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
            return sessions.filter { $0.date >= weekStart && $0.date <= now }

        case .monthly:
            guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
            return sessions.filter { $0.date >= monthStart && $0.date <= now }
        }
    }

    private var periodTotalSeconds: Int {
        periodSessions.reduce(0) { $0 + $1.durationSeconds }
    }

    private var periodSessionCount: Int {
        periodSessions.count
    }

    private var periodAverageSeconds: Int {
        guard periodSessionCount > 0 else { return 0 }
        return periodTotalSeconds / periodSessionCount
    }

    private var selectedWorkGoalPeriod: WorkGoalPeriod {
        switch selectedPeriod {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        }
    }

    private var periodGoal: WorkGoal? {
        goalStore.totalGoal(for: selectedWorkGoalPeriod, date: now)
    }

    private var periodGoalTargetSeconds: Int {
        periodGoal?.targetSeconds ?? 0
    }

    private func displaySubjectName(for session: FocusSession) -> String {
        if let sub = session.subject?.trimmingCharacters(in: .whitespacesAndNewlines), !sub.isEmpty {
            return sub.normalizedWorkItemName()
        }
        return appLanguage == "tr" ? "Adlandırılmamış çalışma" : "Unnamed work"
    }

    private var topWorkAreaName: String {
        var totals: [String: (displayName: String, seconds: Int)] = [:]
        for session in periodSessions {
            guard session.durationSeconds > 0 else { continue }
            let rawName = displaySubjectName(for: session)
            let key = rawName.normalizedWorkItemName()
            let existing = totals[key]
            totals[key] = (
                displayName: existing?.displayName ?? rawName,
                seconds: (existing?.seconds ?? 0) + session.durationSeconds
            )
        }

        guard let top = totals.values.max(by: { $0.seconds < $1.seconds }), top.seconds > 0 else {
            return appLanguage == "tr" ? "Yok" : "None"
        }
        return top.displayName
    }

    private var periodEyebrow: String {
        switch selectedPeriod {
        case .daily:
            return appLanguage == "tr" ? "BUGÜNÜN ODAĞI" : "TODAY'S FOCUS"
        case .weekly:
            return appLanguage == "tr" ? "HAFTALIK RİTİM" : "WEEKLY RHYTHM"
        case .monthly:
            return appLanguage == "tr" ? "AYLIK İZ" : "MONTHLY TRACE"
        }
    }

    private var periodInsightText: String {
        if periodTotalSeconds <= 0 {
            return appLanguage == "tr"
                ? "10 dakikalık kısa bir oturum iyi bir başlangıç olur."
                : "A quick 10-minute session is a clean way to start."
        }

        let countText = appLanguage == "tr"
            ? "\(periodSessionCount) oturum"
            : "\(periodSessionCount) \(periodSessionCount == 1 ? "session" : "sessions")"

        if topWorkAreaName != (appLanguage == "tr" ? "Yok" : "None") {
            return appLanguage == "tr"
                ? "\(topWorkAreaName) bu dönemin en baskın çalışma alanı."
                : "\(topWorkAreaName) is your strongest work area this period."
        }

        return appLanguage == "tr"
            ? "\(countText) tamamlandı."
            : "\(countText) completed."
    }

    // MARK: - Work Breakdown Data Model

    private struct WorkBreakdownItem: Identifiable {
        let id = UUID()
        let name: String
        let totalSeconds: Int
        let sessionCount: Int
        let percentage: Double
        let isSavedSubject: Bool
    }

    private var workBreakdownItems: [WorkBreakdownItem] {
        var sessionTotals: [String: (displayName: String, seconds: Int, count: Int)] = [:]
        for session in periodSessions {
            let rawName = displaySubjectName(for: session)
            let key = rawName.normalizedWorkItemName()
            let existing = sessionTotals[key]
            sessionTotals[key] = (
                displayName: existing?.displayName ?? rawName,
                seconds: (existing?.seconds ?? 0) + session.durationSeconds,
                count: (existing?.count ?? 0) + 1
            )
        }

        var combinedMap: [String: (displayName: String, seconds: Int, count: Int, isSaved: Bool)] = [:]

        // Add all saved subjects from Çalışmalarım
        for subject in savedSubjects {
            let norm = subject.name.normalizedWorkItemName()
            guard !norm.isEmpty else { continue }
            let sessionData = sessionTotals[norm]
            combinedMap[norm] = (
                displayName: subject.name,
                seconds: sessionData?.seconds ?? 0,
                count: sessionData?.count ?? 0,
                isSaved: true
            )
        }

        // Add sessions that are not in savedSubjects (e.g. deleted or older)
        for (key, sessionData) in sessionTotals {
            if combinedMap[key] == nil {
                combinedMap[key] = (
                    displayName: sessionData.displayName,
                    seconds: sessionData.seconds,
                    count: sessionData.count,
                    isSaved: false
                )
            }
        }

        let grandTotal = periodTotalSeconds

        let items = combinedMap.map { _, val in
            let pct = grandTotal > 0 ? (Double(val.seconds) / Double(grandTotal)) : 0.0
            return WorkBreakdownItem(
                name: val.displayName,
                totalSeconds: val.seconds,
                sessionCount: val.count,
                percentage: pct,
                isSavedSubject: val.isSaved
            )
        }

        return items.sorted { a, b in
            if a.totalSeconds != b.totalSeconds {
                return a.totalSeconds > b.totalSeconds
            }
            if a.isSavedSubject != b.isSavedSubject {
                return a.isSavedSubject && !b.isSavedSubject
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    // MARK: - Body

    private var recapPeriod: WorkGoalPeriod {
        switch selectedPeriod {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                headerView
                    .padding(.top, isIPad ? 24 : 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isIPad ? 24 : 18) {

                        // Period Segment Picker
                        periodPickerSection

                        // Previous / Next Period Navigation
                        periodNavigationRow

                        // 1. Focus Summary
                        focusSummaryCard

                        // 2. Work Area Breakdown
                        workBreakdownSection

                        // 3. Calendar / Date Activity
                        calendarDateSection

                        // 4. Past Sessions Button
                        pastSessionsButton
                    }
                    .frame(maxWidth: isIPad ? 680 : .infinity)
                    .padding(.horizontal, isIPad ? 32 : 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSessionLog) {
            SessionLogView()
        }
        .sheet(isPresented: $showRecapCard) {
            RecapCardView(sessions: sessions, initialPeriod: recapPeriod)
        }
        .sheet(isPresented: $showFocusGoals) {
            FocusGoalsView()
        }
        .sheet(item: Binding(
            get: { selectedDayForDetail.map { IdentifiableDate(date: $0) } },
            set: { selectedDayForDetail = $0?.date }
        )) { item in
            DayDetailSheet(date: item.date, sessions: sessions)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        Text(appLanguage == "tr" ? "RAPOR" : "REPORT")
            .font(.system(size: isIPad ? 22 : 16, weight: .light, design: .rounded))
            .foregroundStyle(Color(white: 0.6))
            .tracking(6)
            .textCase(.uppercase)
            .padding(.bottom, 12)
    }

    // MARK: - Period Picker

    private var periodPickerSection: some View {
        HStack(spacing: 4) {
            ForEach(ReportPeriod.allCases) { period in
                let isSelected = selectedPeriod == period
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                        referenceDate = Date()
                    }
                } label: {
                    Text(period.title(lang: appLanguage))
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.black : Color(white: 0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color(white: 0.08))
                .overlay(
                    Capsule()
                        .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                )
        )
    }

    private var periodNavigationRow: some View {
        HStack(spacing: 0) {
            Button {
                HapticService.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    shiftPeriod(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.75))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            Button {
                guard !isViewingCurrentPeriod else { return }
                HapticService.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    referenceDate = Date()
                }
            } label: {
                Text(periodRangeLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.85))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .disabled(isViewingCurrentPeriod)

            Spacer(minLength: 4)

            Button {
                HapticService.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    shiftPeriod(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isViewingCurrentPeriod ? Color(white: 0.25) : Color(white: 0.75))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isViewingCurrentPeriod)
        }
    }

    // MARK: - 1. Focus Summary

    private var focusSummaryCard: some View {
        let goal = periodGoal
        let targetSecs = periodGoalTargetSeconds
        let actualSecs = periodTotalSeconds
        let hasGoal = targetSecs > 0
        let progress = hasGoal ? min(Double(actualSecs) / Double(targetSecs), 1.0) : 0.0
        let percentageInt = Int((progress * 100).rounded())

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(periodEyebrow)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.55))
                        .tracking(1.8)

                    Text(formatDuration(actualSecs))
                        .font(.system(size: isIPad ? 48 : 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(periodInsightText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.55))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Button {
                    showRecapCard = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selectedPeriod.shareButtonText(lang: appLanguage))
            }

            if let goal, hasGoal {
                goalProgressStrip(
                    goal: goal,
                    actualSecs: actualSecs,
                    targetSecs: targetSecs,
                    progress: progress,
                    percentageInt: percentageInt
                )
            } else {
                noGoalStrip
            }

            if actualSecs <= 0 {
                firstSessionHintStrip
            }

            HStack(spacing: 0) {
                summaryStat(
                    title: appLanguage == "tr" ? "Oturum" : "Sessions",
                    value: "\(periodSessionCount)",
                    icon: "play.circle.fill"
                )

                summaryDivider

                summaryStat(
                    title: appLanguage == "tr" ? "Ortalama" : "Average",
                    value: formatDuration(periodAverageSeconds),
                    icon: "chart.bar.fill"
                )

                summaryDivider

                summaryStat(
                    title: appLanguage == "tr" ? "En yoğun" : "Strongest",
                    value: topWorkAreaName,
                    icon: "sparkline"
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.12),
                            Color(white: 0.075)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.7)
                )
                .shadow(color: Color.white.opacity(0.035), radius: 18, x: 0, y: 10)
        )
    }

    private func goalProgressStrip(
        goal: WorkGoal,
        actualSecs: Int,
        targetSecs: Int,
        progress: Double,
        percentageInt: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 7) {
                    Image(systemName: "target")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(percentageInt >= 100 ? Color.green : Color.white.opacity(0.75))

                    Text(goal.mode.label(period: goal.period, lang: appLanguage))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.72))
                }

                Spacer()

                Text("\(formatDuration(actualSecs)) / \(formatDuration(targetSecs))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.72))
                    .monospacedDigit()

                Text("%\(percentageInt)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(percentageInt >= 100 ? Color.green : Color.white)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: percentageInt >= 100
                                    ? [Color.green, Color(red: 0.45, green: 0.90, blue: 0.62)]
                                    : [Color.white, Color(white: 0.72)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * CGFloat(progress), 8), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
                )
        )
    }

    private var noGoalStrip: some View {
        Button {
            showFocusGoals = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "target")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.78))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.10)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(appLanguage == "tr" ? "Hedef belirle" : "Set a goal")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.88))

                    Text(appLanguage == "tr" ? "Günlük, haftalık veya aylık ilerlemeni takip et." : "Track daily, weekly, or monthly progress.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white))
            }
            .contentShape(Rectangle())
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appLanguage == "tr" ? "Hedef belirle" : "Set a goal")
    }

    private var firstSessionHintStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.92)))

            VStack(alignment: .leading, spacing: 2) {
                Text(appLanguage == "tr" ? "İlk oturuma hazır" : "Ready for the first session")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.84))

                Text(appLanguage == "tr" ? "Tamamladığında süre, ortalama ve en yoğun çalışma burada canlanır." : "Duration, average, and strongest work area come alive after you finish.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.46))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
                )
        )
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 38)
    }

    private func summaryStat(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.50))

                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.48))
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    // MARK: - 3. Work Breakdown Section

    private var workBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: appLanguage == "tr" ? "ÇALIŞMA DAĞILIMI" : "WORK BREAKDOWN",
                detail: "\(workBreakdownItems.filter { $0.totalSeconds > 0 }.count)"
            )

            if workBreakdownItems.isEmpty {
                emptyWorkBreakdownCard
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(workBreakdownItems.enumerated()), id: \.element.id) { index, item in
                        workBreakdownRow(item)
                            .padding(.vertical, 12)

                        if index != workBreakdownItems.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                                .padding(.leading, 38)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.065))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.6)
                        )
                )
            }
        }
    }

    private var emptyWorkBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.72))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.08)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(appLanguage == "tr" ? "Henüz dağılım oluşmadı" : "No breakdown yet")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.84))

                    Text(appLanguage == "tr" ? "İlk oturumdan sonra çalışmalarına göre yoğunluk burada görünür." : "After your first session, work-area intensity appears here.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.46))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 8) {
                emptyBreakdownPreviewRow(widthRatio: 0.72, opacity: 0.16)
                emptyBreakdownPreviewRow(widthRatio: 0.48, opacity: 0.12)
                emptyBreakdownPreviewRow(widthRatio: 0.30, opacity: 0.09)
            }
            .padding(.leading, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(white: 0.12), lineWidth: 0.5))
        )
    }

    private func emptyBreakdownPreviewRow(widthRatio: CGFloat, opacity: Double) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color.white.opacity(opacity + 0.06))
                .frame(width: 8, height: 8)

            GeometryReader { geo in
                Capsule()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: geo.size.width * widthRatio, height: 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 5)
        }
    }

    private func workBreakdownRow(_ item: WorkBreakdownItem) -> some View {
        let hasDuration = item.totalSeconds > 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill((hasDuration ? colorForSubject(item.name) : Color(white: 0.22)).opacity(hasDuration ? 0.22 : 0.16))
                            .frame(width: 30, height: 30)

                        Circle()
                            .fill(hasDuration ? colorForSubject(item.name) : Color(white: 0.28))
                            .frame(width: 9, height: 9)
                    }

                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(hasDuration ? Color(white: 0.9) : Color(white: 0.55))
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 6) {
                    Text(formatDurationShort(item.totalSeconds))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(hasDuration ? Color.white : Color(white: 0.45))
                        .monospacedDigit()

                    Text("(\(Int((item.percentage * 100).rounded()))%)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(hasDuration ? Color(white: 0.45) : Color(white: 0.30))
                        .monospacedDigit()
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)

                    if hasDuration {
                        Capsule()
                            .fill(colorForSubject(item.name))
                            .frame(width: max(geo.size.width * CGFloat(item.percentage), 6), height: 5)
                    }
                }
            }
            .frame(height: 5)
            .padding(.leading, 38)
        }
    }

    // MARK: - 4. Calendar / Date Activity Section

    private var calendarDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: appLanguage == "tr" ? "TAKVİM" : "CALENDAR",
                detail: appLanguage == "tr" ? "Gün detayı" : "Day detail"
            )

            switch selectedPeriod {
            case .daily:
                dailyActivityCard

            case .weekly:
                weeklyActivityGrid

            case .monthly:
                monthlyActivityGrid
            }
        }
    }

    private func sectionHeader(title: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.50))
                .tracking(1.8)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.38))
                    .lineLimit(1)
            }
        }
    }

    private var dailyActivityCard: some View {
        Button {
            selectedDayForDetail = now
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(periodSessionCount == 0
                         ? (appLanguage == "tr" ? "Bugün henüz oturum yok" : "No sessions today yet")
                         : (appLanguage == "tr" ? "Bugünün Detaylarını Gör" : "View Today's Details"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.95))

                    Text(periodSessionCount == 0
                         ? (appLanguage == "tr" ? "Başladığında gün detayın burada birikir." : "Your day detail builds here once you start.")
                         : (appLanguage == "tr" ? "\(periodSessionCount) oturum · \(formatDuration(periodTotalSeconds))" : "\(periodSessionCount) sessions · \(formatDuration(periodTotalSeconds))"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(white: 0.13), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private var currentWeekMondayToSundayDates: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let comp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStart = cal.date(from: comp) else { return [] }
        return (0..<7).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private var weeklyActivityGrid: some View {
        let weekDays = currentWeekMondayToSundayDates
        let maxSecs = max(weekDays.map { daySeconds(for: $0) }.max() ?? 1, 1)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekDays, id: \.self) { day in
                    CalendarDayCell(
                        date: day,
                        seconds: daySeconds(for: day),
                        maxSeconds: maxSecs,
                        showWeekdayHeader: true,
                        isToday: calendar.isDateInToday(day),
                        appLanguage: appLanguage,
                        action: { selectedDayForDetail = day }
                    )
                }
            }

            Text(appLanguage == "tr" ? "Detay görmek için bir güne dokun." : "Tap a day to view details.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color(white: 0.4))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(white: 0.13), lineWidth: 0.5))
        )
    }

    private var weekdayHeaderRow: some View {
        let trNames = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        let enNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let names = appLanguage == "tr" ? trNames : enNames

        return HStack(spacing: 6) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthlyActivityGrid: some View {
        let monthDays = currentMonthDays
        let maxSecs = max(monthDays.map { daySeconds(for: $0) }.max() ?? 1, 1)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return VStack(spacing: 10) {
            weekdayHeaderRow

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(monthDays, id: \.self) { day in
                    CalendarDayCell(
                        date: day,
                        seconds: daySeconds(for: day),
                        maxSeconds: maxSecs,
                        showWeekdayHeader: false,
                        isToday: calendar.isDateInToday(day),
                        appLanguage: appLanguage,
                        action: { selectedDayForDetail = day }
                    )
                }
            }

            Text(appLanguage == "tr" ? "Detay görmek için bir güne dokun." : "Tap a day to view details.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color(white: 0.4))
                .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(white: 0.13), lineWidth: 0.5))
        )
    }

    // MARK: - 5. Past Sessions Button

    private var pastSessionsButton: some View {
        Button {
            showSessionLog = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.8))

                Text(appLanguage == "tr" ? "Geçmiş Oturumlar" : "Past Sessions")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.9))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(white: 0.14), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Date Calculation Helpers

    private var last7DaysDates: [Date] {
        let now = Date()
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -(6 - offset), to: now)
        }
    }

    private var currentMonthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return [] }
        var dates: [Date] = []
        var d = monthInterval.start
        while d < monthInterval.end {
            dates.append(d)
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return dates
    }

    private func daySeconds(for date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return sessions
            .filter { $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    private func dayShortName(_ date: Date) -> String {
        let dayNamesTR = ["", "Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]
        let dayNamesEN = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let idx = calendar.component(.weekday, from: date)
        return appLanguage == "tr" ? dayNamesTR[idx] : dayNamesEN[idx]
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

    private func formatDurationShort(_ seconds: Int) -> String {
        if seconds > 0 && seconds < 60 {
            return appLanguage == "tr" ? "<1 dk" : "<1m"
        }
        return formatDuration(seconds)
    }

    private func colorForSubject(_ name: String) -> Color {
        let unnamedLabel = appLanguage == "tr" ? "Adlandırılmamış çalışma" : "Unnamed work"
        return WorkItemColorPalette.color(for: name, unnamedLabel: unnamedLabel)
    }
}

// MARK: - Identifiable Date Helper for Sheet Presentation

private struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - Reusable Calendar Day Cell

private struct CalendarDayCell: View {
    let date: Date
    let seconds: Int
    let maxSeconds: Int
    let showWeekdayHeader: Bool
    let isToday: Bool
    let appLanguage: String
    let action: () -> Void

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    private var weekdayName: String {
        let cal = Calendar.current
        let idx = cal.component(.weekday, from: date)
        if appLanguage == "tr" {
            let names = ["", "Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]
            return names[idx]
        } else {
            let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return names[idx]
        }
    }

    private var intensity: Double {
        guard maxSeconds > 0, seconds > 0 else { return 0 }
        return min(Double(seconds) / Double(maxSeconds), 1.0)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(seconds > 0 ? Color.white.opacity(0.18 + intensity * 0.72) : Color(white: 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isToday ? Color.white : (seconds > 0 ? Color.white.opacity(0.3) : Color(white: 0.14)),
                                lineWidth: isToday ? 1.2 : 0.5
                            )
                    )

                if showWeekdayHeader {
                    VStack(spacing: 2) {
                        Text(weekdayName)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(intensity > 0.5 ? Color.black.opacity(0.7) : (isToday ? Color.white : Color(white: 0.45)))

                        Text("\(dayNumber)")
                            .font(.system(size: 13, weight: isToday ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(intensity > 0.5 ? Color.black : (seconds > 0 ? Color.white : (isToday ? Color.white : Color(white: 0.85))))
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("\(dayNumber)")
                        .font(.system(size: 11, weight: isToday ? .bold : .regular, design: .rounded))
                        .foregroundStyle(intensity > 0.5 ? Color.black : (seconds > 0 ? Color.white : (isToday ? Color.white : Color(white: 0.45))))
                }
            }
            .frame(height: showWeekdayHeader ? 46 : 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
