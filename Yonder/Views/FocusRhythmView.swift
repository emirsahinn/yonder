//
//  FocusRhythmView.swift
//  Yonder
//

import SwiftUI
import SwiftData

private extension ReportTimeBlock {
    var accentColor: Color {
        switch self {
        case .morning:
            return Color(red: 0.95, green: 0.72, blue: 0.45) // Soft Amber
        case .afternoon:
            return Color(red: 0.42, green: 0.82, blue: 0.88) // Muted Cyan
        case .evening:
            return Color(white: 0.92)                        // Warm White
        case .night:
            return Color(red: 0.65, green: 0.72, blue: 0.95) // Muted Violet/Blue
        }
    }

    func peakSentence(lang: String) -> String {
        switch self {
        case .morning: return lang == "tr" ? "En güçlü zamanın sabah." : "Your strongest time is morning."
        case .afternoon: return lang == "tr" ? "En güçlü zamanın öğlen." : "Your strongest time is afternoon."
        case .evening: return lang == "tr" ? "En güçlü zamanın akşam." : "Your strongest time is evening."
        case .night: return lang == "tr" ? "En güçlü zamanın gece." : "Your strongest time is night."
        }
    }
}

/// Displays user's daily focus rhythm by time window with quiet horizontal progress bars.
struct FocusRhythmView: View {

    let sessions: [FocusSession]

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool { horizontalSizeClass == .regular }

    private var metrics: ReportMetrics {
        ReportMetrics(sessions: sessions)
    }

    private var maxBlockSeconds: Int {
        metrics.timeBlockTotals.values.max() ?? 1
    }

    private var shortStatusNote: String {
        if metrics.allSessions.isEmpty {
            return ""
        }
        if !metrics.hasSufficientData {
            return appLanguage == "tr" ? "İlk izler" : "First traces"
        }
        if let peak = metrics.strongestTimeBlock {
            switch peak {
            case .morning: return appLanguage == "tr" ? "Sabah ritmi" : "Morning rhythm"
            case .afternoon: return appLanguage == "tr" ? "Öğlen ritmi" : "Afternoon rhythm"
            case .evening: return appLanguage == "tr" ? "Akşam ritmi" : "Evening rhythm"
            case .night: return appLanguage == "tr" ? "Gece ritmi" : "Night rhythm"
            }
        }
        return appLanguage == "tr" ? "Ritmin oluşuyor" : "Rhythm forming"
    }

    private var summaryHeadline: String {
        if metrics.allSessions.isEmpty {
            return appLanguage == "tr"
                ? "İlk çalışmalarından sonra ritmin burada belirecek."
                : "Your rhythm will appear after your first work."
        }
        if let peak = metrics.strongestTimeBlock, metrics.hasSufficientData {
            return peak.peakSentence(lang: appLanguage)
        }
        return appLanguage == "tr"
            ? "Odağın gün içine yayılıyor."
            : "Your focus is forming throughout the day."
    }

    private var completionValueString: String {
        guard metrics.hasSufficientData else {
            return appLanguage == "tr" ? "Henüz net değil" : "Not clear yet"
        }
        return appLanguage == "tr" ? "%\(metrics.completionRate)" : "\(metrics.completionRate)%"
    }

    private var strongestValueString: String {
        guard metrics.hasSufficientData, let peak = metrics.strongestTimeBlock else {
            return appLanguage == "tr" ? "Henüz net değil" : "Not clear yet"
        }
        return peak.capitalizedName(lang: appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Title & Short Tag
            HStack {
                Text(appLanguage == "tr" ? "ÇALIŞMA RİTMİ" : "FOCUS RHYTHM")
                    .font(.system(size: isIPad ? 13 : 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .tracking(2.0)

                Spacer()

                if !shortStatusNote.isEmpty {
                    Text(shortStatusNote)
                        .font(.system(size: isIPad ? 13 : 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.65))
                }
            }

            // Summary Subtitle
            Text(summaryHeadline)
                .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.70))
                .fixedSize(horizontal: false, vertical: true)

            // Time Window Horizontal Bars (Rendered for active & empty placeholder states)
            VStack(spacing: 10) {
                ForEach([ReportTimeBlock.morning, .afternoon, .evening, .night]) { block in
                    timeBlockRow(block: block)
                }
            }
            .padding(.top, 2)

            if !metrics.allSessions.isEmpty {
                // Divider
                Rectangle()
                    .fill(Color(white: 0.06))
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                // 3 Quiet Rhythm Metrics
                HStack(spacing: 8) {
                    rhythmMetricTile(
                        title: appLanguage == "tr" ? "Ortalama" : "Average",
                        value: ReportMetrics.formattedTime(seconds: metrics.averageSessionSeconds, lang: appLanguage)
                    )
                    rhythmMetricTile(
                        title: appLanguage == "tr" ? "Tamamlama" : "Completion",
                        value: completionValueString
                    )
                    rhythmMetricTile(
                        title: appLanguage == "tr" ? "En Güçlü" : "Strongest",
                        value: strongestValueString
                    )
                }
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

    private func timeBlockRow(block: ReportTimeBlock) -> some View {
        let sec = metrics.timeBlockTotals[block] ?? 0
        let isPeak = block == metrics.strongestTimeBlock && sec > 0 && metrics.hasSufficientData
        let ratio = maxBlockSeconds > 0 ? CGFloat(sec) / CGFloat(maxBlockSeconds) : 0.0
        let accent = block.accentColor

        let fillOpacity: Double = {
            if sec == 0 { return 0.0 }
            if isPeak { return 0.90 }
            return 0.50
        }()

        let labelColor: Color = {
            if sec == 0 { return Color(white: 0.35) }
            if isPeak { return Color(white: 0.95) }
            return Color(white: 0.65)
        }()

        let valueColor: Color = {
            if sec == 0 { return Color(white: 0.30) }
            if isPeak { return Color(white: 0.90) }
            return Color(white: 0.50)
        }()

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(block.capitalizedName(lang: appLanguage))
                    .font(.system(size: isIPad ? 14 : 12, weight: isPeak ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(labelColor)

                Spacer()

                Text(ReportMetrics.formattedTime(seconds: sec, lang: appLanguage))
                    .font(.system(size: isIPad ? 13 : 11, weight: isPeak ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(sec > 0 ? 0.06 : 0.04))
                        .frame(height: 5)

                    if sec > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accent.opacity(fillOpacity))
                            .frame(width: max(6, geo.size.width * ratio), height: 5)
                    }
                }
            }
            .frame(height: 5)
        }
    }

    private func rhythmMetricTile(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: isIPad ? 10 : 9, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.38))
                .textCase(.uppercase)
                .tracking(1.0)

            Text(value)
                .font(.system(size: isIPad ? 14 : 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.85))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(white: 0.07), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    FocusRhythmView(sessions: [])
}
