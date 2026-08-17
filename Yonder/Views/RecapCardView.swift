//
//  RecapCardView.swift
//  Yonder
//
//  Shareable focus recap card rendered in a 9:16 portrait frame.
//  Supports Daily, Weekly, and Monthly focus recap modes with goal progress and work area metrics.
//  Refined with Yonder's calm focus rhythm design language.
//

import SwiftUI
import FirebaseAuth

// MARK: - Recap Stats Model

struct RecapStats {
    let period: WorkGoalPeriod
    let periodLabel: String
    let totalSeconds: Int
    let activeDays: Int
    let totalSessionCount: Int
    let averageSessionSeconds: Int
    let roomTotalSeconds: Int
    let topWorkAreaName: String?
    let topWorkAreaSeconds: Int
    let strongestTimeBlock: ReportTimeBlock?
    let dayDots: [Bool]
    let goalTargetSeconds: Int

    var hasSufficientData: Bool {
        totalSessionCount >= 3
    }

    func formattedTotal(appLanguage: String) -> String {
        ReportMetrics.formattedTime(seconds: totalSeconds, lang: appLanguage)
    }

    func formattedAverage(appLanguage: String) -> String {
        ReportMetrics.formattedTime(seconds: averageSessionSeconds, lang: appLanguage)
    }

    func formattedTopWorkAreaDuration(appLanguage: String) -> String {
        ReportMetrics.formattedTime(seconds: topWorkAreaSeconds, lang: appLanguage)
    }

    func formattedActiveDays(appLanguage: String) -> String {
        if appLanguage == "tr" {
            return "\(activeDays) aktif gün"
        } else {
            return "\(activeDays) \(activeDays == 1 ? "active day" : "active days")"
        }
    }

    func formattedStrongestTime(appLanguage: String) -> String {
        guard hasSufficientData, let peak = strongestTimeBlock else {
            return appLanguage == "tr" ? "Henüz net değil" : "Not clear yet"
        }
        let name = peak.capitalizedName(lang: appLanguage)
        return appLanguage == "tr" ? "\(name) ritmi" : "\(name) rhythm"
    }

    /// Calm narrative insight sentence for the recap card.
    func insightNarrativeSentence(appLanguage: String) -> String {
        if totalSessionCount == 0 {
            switch period {
            case .daily:
                return appLanguage == "tr" ? "Bugün henüz çalışma kaydı oluşmadı." : "No focus records today yet."
            case .weekly:
                return appLanguage == "tr" ? "Bu hafta henüz çalışma kaydı oluşmadı." : "No focus records this week yet."
            case .monthly:
                return appLanguage == "tr" ? "Bu ay henüz çalışma kaydı oluşmadı." : "No focus records this month yet."
            }
        }
        if totalSessionCount <= 2 {
            return appLanguage == "tr"
                ? "İlk çalışma izlerin oluşmaya başladı."
                : "The first focus traces are starting to form."
        }
        if let top = topWorkAreaName {
            return appLanguage == "tr"
                ? "Odağın en çok \(top) üzerinde toplandı."
                : "Most of your focus gathered around \(top)."
        } else if let peak = strongestTimeBlock {
            let blockName = peak.localizedName(lang: appLanguage)
            return appLanguage == "tr"
                ? "Çalışma ritmin daha çok \(blockName) saatlerinde oluştu."
                : "Your rhythm formed mostly in the \(blockName)."
        } else {
            return appLanguage == "tr"
                ? "Çalışma ritmin dengeli şekilde ilerledi."
                : "Your focus rhythm progressed steadily."
        }
    }
}

// MARK: - RecapCardView (main sheet)

struct RecapCardView: View {

    let sessions: [FocusSession]
    var initialPeriod: WorkGoalPeriod = .weekly

    @AppStorage("app_language") private var appLanguage: String = "en"
    @State private var period: WorkGoalPeriod = .weekly
    @State private var showShareSheet: Bool = false
    @State private var renderedImage: UIImage? = nil
    @State private var isRendering: Bool = false
    @Environment(AuthService.self) private var authService

    @Environment(\.dismiss) private var dismiss

    init(sessions: [FocusSession], initialPeriod: WorkGoalPeriod = .weekly) {
        self.sessions = sessions
        self.initialPeriod = initialPeriod
        _period = State(initialValue: initialPeriod)
    }

    private var currentLocale: Locale {
        Locale(identifier: appLanguage)
    }

    private var firstName: String? {
        guard authService.isCloudAccountLinked else { return nil }
        return authService.userFirstName
    }

    private var shareButtonTitle: String {
        switch period {
        case .daily:
            return appLanguage == "tr" ? "Bugünü Paylaş" : "Share Today"
        case .weekly:
            return appLanguage == "tr" ? "Bu Haftanı Paylaş" : "Share This Week"
        case .monthly:
            return appLanguage == "tr" ? "Bu Ayını Paylaş" : "Share This Month"
        }
    }

    private var stats: RecapStats {
        var s = computeRecapStats(for: period, from: sessions, appLanguage: appLanguage)
        if let name = firstName {
            let format = String.localized("recap_period_named", lang: appLanguage)
            let customLabel = String(format: format, name, s.periodLabel)
            s = RecapStats(
                period: s.period,
                periodLabel: customLabel,
                totalSeconds: s.totalSeconds,
                activeDays: s.activeDays,
                totalSessionCount: s.totalSessionCount,
                averageSessionSeconds: s.averageSessionSeconds,
                roomTotalSeconds: s.roomTotalSeconds,
                topWorkAreaName: s.topWorkAreaName,
                topWorkAreaSeconds: s.topWorkAreaSeconds,
                strongestTimeBlock: s.strongestTimeBlock,
                dayDots: s.dayDots,
                goalTargetSeconds: s.goalTargetSeconds
            )
        }
        return s
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top Action Bar ─────────────────────────────────────────
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(white: 0.45))
                            .padding(10)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Period Segment Selector
                    HStack(spacing: 2) {
                        ForEach(WorkGoalPeriod.allCases) { p in
                            let isSelected = period == p
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    period = p
                                }
                            } label: {
                                Text(p.title(lang: appLanguage))
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.black : Color(white: 0.50))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(isSelected ? Color.white : Color.clear))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.08))
                            .overlay(Capsule().strokeBorder(Color(white: 0.14), lineWidth: 0.5))
                    )

                    Spacer()

                    // Share button
                    Button {
                        renderAndShare()
                    } label: {
                        HStack(spacing: 5) {
                            if isRendering {
                                ProgressView()
                                    .tint(Color(white: 0.6))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            Text(shareButtonTitle)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Color(white: 0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color(white: 0.10))
                                .overlay(Capsule().strokeBorder(Color(white: 0.18), lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRendering || stats.totalSessionCount == 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // ── Card Preview (Responsive Container) ───────────────────────
                GeometryReader { geo in
                    let availW = geo.size.width
                    let availH = geo.size.height

                    let maxCardH = max(300, availH - 24)
                    let maxCardW = max(240, availW - 32)
                    let targetRatio: CGFloat = 9.0 / 16.0

                    let (computedW, computedH): (CGFloat, CGFloat) = {
                        let wFromH = maxCardH * targetRatio
                        if wFromH <= maxCardW {
                            return (min(wFromH, 440), min(maxCardH, 440 / targetRatio))
                        } else {
                            let hFromW = maxCardW / targetRatio
                            return (min(maxCardW, 440), min(hFromW, 440 / targetRatio))
                        }
                    }()

                    ScrollView(showsIndicators: false) {
                        VStack {
                            RecapCard(stats: stats, appLanguage: appLanguage)
                                .frame(width: max(220, computedW), height: max(390, computedH))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color(white: 0.12), lineWidth: 0.5)
                                )
                                .shadow(color: .white.opacity(0.03), radius: 20, y: 6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }

            if isRendering {
                YonderTransitionOverlay(
                    message: appLanguage == "tr" ? "Paylaşım kartı hazırlanıyor" : "Preparing recap card",
                    onCancel: { isRendering = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isRendering)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShareSheet) {
            if let img = renderedImage {
                ShareSheet(items: [img])
            }
        }
    }

    // MARK: - Render & Share

    @MainActor
    private func renderAndShare() {
        isRendering = true
        let cardSize = CGSize(width: 1080, height: 1920) // 9:16 portrait
        let currentStats = stats
        let lang = appLanguage

        Task { @MainActor in
            let renderer = ImageRenderer(
                content: RecapCard(stats: currentStats, appLanguage: lang)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .environment(\.locale, Locale(identifier: lang))
            )
            renderer.scale = 1.0
            renderer.proposedSize = ProposedViewSize(cardSize)

            let img = renderer.uiImage
            renderedImage = img
            isRendering = false
            showShareSheet = true
        }
    }
}

// MARK: - RecapCard (the actual card preview & render source)

struct RecapCard: View {

    let stats: RecapStats
    let appLanguage: String

    private var currentLocale: Locale {
        Locale(identifier: appLanguage)
    }

    private var heroTitle: String {
        switch stats.period {
        case .daily:
            return appLanguage == "tr" ? "Bugünkü Çalışmalarım" : "Today's Focus"
        case .weekly:
            return appLanguage == "tr" ? "Bu Haftaki Çalışmalarım" : "This Week's Focus"
        case .monthly:
            return appLanguage == "tr" ? "Bu Ayki Çalışmalarım" : "This Month's Focus"
        }
    }

    private var heroNarrativeSentence: String {
        if stats.totalSessionCount == 0 {
            switch stats.period {
            case .daily:
                return appLanguage == "tr" ? "Bugün henüz çalışma kaydı oluşmadı." : "No focus records today yet."
            case .weekly:
                return appLanguage == "tr" ? "Bu hafta henüz çalışma kaydı oluşmadı." : "No focus records this week yet."
            case .monthly:
                return appLanguage == "tr" ? "Bu ay henüz çalışma kaydı oluşmadı." : "No focus records this month yet."
            }
        }
        let durationStr = stats.formattedTotal(appLanguage: appLanguage)
        switch stats.period {
        case .daily:
            return appLanguage == "tr" ? "Bugün \(durationStr) odaklandım." : "I focused for \(durationStr) today."
        case .weekly:
            return appLanguage == "tr" ? "Bu hafta \(durationStr) odaklandım." : "I focused for \(durationStr) this week."
        case .monthly:
            return appLanguage == "tr" ? "Bu ay \(durationStr) odaklandım." : "I focused for \(durationStr) this month."
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad = w * 0.085

            ZStack {
                // Background: Quiet dark gradient
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(white: 0.08),
                        Color(white: 0.03),
                        Color.black
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: max(w, h) * 0.75
                )

                VStack(alignment: .leading, spacing: 0) {

                    // ── Header: Yonder Wordmark ─────────────────────────
                    VStack(alignment: .leading, spacing: h * 0.016) {
                        HStack(spacing: w * 0.03) {
                            Image("SplashLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: w * 0.10, height: w * 0.10)

                            Text("YONDER")
                                .font(.system(size: w * 0.042, weight: .light, design: .rounded))
                                .foregroundStyle(Color(white: 0.65))
                                .tracking(w * 0.024)
                        }

                        Rectangle()
                            .fill(Color(white: 0.12))
                            .frame(height: 0.5)
                    }
                    .padding(.top, h * 0.05)

                    Spacer().frame(height: h * 0.035)

                    // ── Section Title ──────────────────────────────────
                    Text(heroTitle)
                        .font(.system(size: w * 0.036, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                        .tracking(2.2)
                        .textCase(.uppercase)

                    Spacer().frame(height: h * 0.016)

                    // ── Hero Narrative Sentence ────────────────────────
                    Text(heroNarrativeSentence)
                        .font(.system(size: w * 0.068, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.95))
                        .lineSpacing(4)
                        .minimumScaleFactor(0.7)
                        .lineLimit(3)

                    // ── Goal Progress Line (If target exists) ──────────
                    if stats.goalTargetSeconds > 0 {
                        Spacer().frame(height: h * 0.018)

                        let target = stats.goalTargetSeconds
                        let completed = stats.totalSeconds
                        let pct = min(100, Int((Double(completed) / Double(target) * 100).rounded()))
                        let ratio = min(1.0, CGFloat(completed) / CGFloat(target))
                        let compStr = ReportMetrics.formattedTime(seconds: completed, lang: appLanguage)
                        let targStr = ReportMetrics.formattedTime(seconds: target, lang: appLanguage)

                        VStack(alignment: .leading, spacing: h * 0.008) {
                            HStack {
                                Text(pct >= 100
                                     ? (appLanguage == "tr" ? "Hedef Tamamlandı (%100)" : "Goal Completed (100%)")
                                     : (appLanguage == "tr" ? "Hedef: \(compStr) / \(targStr)" : "Goal: \(compStr) / \(targStr)"))
                                    .font(.system(size: w * 0.032, weight: .medium, design: .rounded))
                                    .foregroundStyle(pct >= 100 ? Color(red: 0.45, green: 0.85, blue: 0.65) : Color(white: 0.65))

                                Spacer()

                                Text("%\(pct)")
                                    .font(.system(size: w * 0.032, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(white: 0.80))
                            }

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(white: 0.12))
                                    .frame(height: h * 0.006)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(pct >= 100 ? Color(red: 0.45, green: 0.85, blue: 0.65) : Color.white)
                                    .frame(width: max(pct > 0 ? 4 : 0, (w - pad * 2) * ratio), height: h * 0.006)
                            }
                        }
                    }

                    // ── Supporting Insight Sentence ────────────────────
                    if stats.totalSessionCount > 0 {
                        Spacer().frame(height: h * 0.012)

                        Text(stats.insightNarrativeSentence(appLanguage: appLanguage))
                            .font(.system(size: w * 0.034, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.60))
                            .lineSpacing(2)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer().frame(height: h * 0.035)

                    // ── Divider ────────────────────────────────────────
                    Rectangle()
                        .fill(Color(white: 0.12))
                        .frame(height: 0.5)

                    Spacer().frame(height: h * 0.035)

                    if stats.totalSessionCount > 0 {
                        // ── 2x2 Supporting Details Grid ───────────────────
                        VStack(spacing: h * 0.025) {
                            HStack(alignment: .top, spacing: w * 0.04) {
                                // Top Work Area
                                detailTile(
                                    title: appLanguage == "tr" ? "Baskın Çalışma" : "Top Work Area",
                                    value: stats.topWorkAreaName ?? (appLanguage == "tr" ? "Genel Odak" : "General Focus"),
                                    subtitle: stats.topWorkAreaName != nil ? stats.formattedTopWorkAreaDuration(appLanguage: appLanguage) : nil,
                                    width: w
                                )

                                // Active Days
                                detailTile(
                                    title: appLanguage == "tr" ? "Aktif Günler" : "Active Days",
                                    value: stats.formattedActiveDays(appLanguage: appLanguage),
                                    subtitle: stats.roomTotalSeconds > 0
                                        ? (appLanguage == "tr" ? "Sessiz odalarda \(ReportMetrics.formattedTime(seconds: stats.roomTotalSeconds, lang: appLanguage))" : "\(ReportMetrics.formattedTime(seconds: stats.roomTotalSeconds, lang: appLanguage)) in quiet rooms")
                                        : nil,
                                    width: w
                                )
                            }

                            HStack(alignment: .top, spacing: w * 0.04) {
                                // Average Session
                                detailTile(
                                    title: appLanguage == "tr" ? "Ortalama Oturum" : "Average Session",
                                    value: stats.formattedAverage(appLanguage: appLanguage),
                                    subtitle: nil,
                                    width: w
                                )

                                // Strongest Rhythm
                                detailTile(
                                    title: appLanguage == "tr" ? "En Güçlü Zaman" : "Strongest Rhythm",
                                    value: stats.formattedStrongestTime(appLanguage: appLanguage),
                                    subtitle: nil,
                                    width: w
                                )
                            }
                        }

                        Spacer().frame(height: h * 0.035)

                        // ── Week Day Track Dots ───────────────────────────
                        VStack(alignment: .leading, spacing: w * 0.022) {
                            HStack(spacing: w * 0.035) {
                                ForEach(stats.dayDots.indices, id: \.self) { i in
                                    Circle()
                                        .fill(stats.dayDots[i] ? Color.white.opacity(0.9) : Color(white: 0.08))
                                        .frame(width: w * 0.065, height: w * 0.065)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color(white: 0.18), lineWidth: 0.5)
                                                .opacity(stats.dayDots[i] ? 0 : 1)
                                        )
                                }
                            }
                        }
                    }

                    Spacer()

                    // ── Footer: yonder.app Signature ───────────────────
                    VStack(spacing: h * 0.016) {
                        Rectangle()
                            .fill(Color(white: 0.10))
                            .frame(height: 0.5)

                        Text("yonder.app")
                            .font(.system(size: w * 0.028, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.32))
                            .tracking(2.0)
                    }
                    .padding(.bottom, h * 0.04)
                }
                .padding(.horizontal, pad)
            }
        }
        .environment(\.locale, currentLocale)
    }

    private func detailTile(title: String, value: String, subtitle: String?, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: width * 0.026, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.40))
                .textCase(.uppercase)
                .tracking(1.2)

            Text(value)
                .font(.system(size: width * 0.040, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: width * 0.030, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.50))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(width * 0.035)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(white: 0.08), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Stats Calculator

private func computeRecapStats(for period: WorkGoalPeriod, from sessions: [FocusSession], appLanguage: String) -> RecapStats {
    let calendar = Calendar.current
    let now = Date()

    let periodSessions: [FocusSession]
    let periodLabel: String
    let dayDots: [Bool]

    switch period {
    case .daily:
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        periodSessions = sessions.filter { $0.date >= start && $0.date < end }
        periodLabel = String.localized("recap_today", lang: appLanguage)

        dayDots = (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return false }
            return sessions.contains { calendar.isDate($0.date, inSameDayAs: day) }
        }

    case .weekly:
        var cal = calendar
        cal.firstWeekday = 2
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else {
            periodSessions = []
            periodLabel = String.localized("recap_this_week", lang: appLanguage)
            dayDots = Array(repeating: false, count: 7)
            break
        }
        periodSessions = sessions.filter { $0.date >= weekStart && $0.date <= now }
        periodLabel = String.localized("recap_this_week", lang: appLanguage)

        dayDots = (0..<7).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart) else { return false }
            return periodSessions.contains { cal.isDate($0.date, inSameDayAs: day) }
        }

    case .monthly:
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            periodSessions = []
            periodLabel = String.localized("recap_this_month", lang: appLanguage)
            dayDots = Array(repeating: false, count: 7)
            break
        }
        periodSessions = sessions.filter { $0.date >= monthStart && $0.date <= now }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.dateFormat = "MMMM yyyy"
        periodLabel = formatter.string(from: now).capitalized

        dayDots = (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return false }
            return periodSessions.contains { calendar.isDate($0.date, inSameDayAs: day) }
        }
    }

    let metrics = ReportMetrics(sessions: periodSessions)
    let goal = WorkGoalStore.shared.totalGoal(for: period)
    let goalTargetSecs = goal?.targetSeconds ?? 0

    return RecapStats(
        period: period,
        periodLabel: periodLabel,
        totalSeconds: metrics.totalFocusSeconds,
        activeDays: Set(periodSessions.map { calendar.startOfDay(for: $0.date) }).count,
        totalSessionCount: metrics.totalSessionCount,
        averageSessionSeconds: metrics.averageSessionSeconds,
        roomTotalSeconds: metrics.currentWeekRoomTotalSeconds,
        topWorkAreaName: metrics.topSubjectName,
        topWorkAreaSeconds: metrics.topSubjectSeconds,
        strongestTimeBlock: metrics.strongestTimeBlock,
        dayDots: dayDots,
        goalTargetSeconds: goalTargetSecs
    )
}

// MARK: - System ShareSheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    RecapCardView(sessions: [])
}
