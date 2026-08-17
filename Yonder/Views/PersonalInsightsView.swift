//
//  PersonalInsightsView.swift
//  Yonder
//

import SwiftUI
import SwiftData

/// Renders calm, awareness-focused personal narrative insights about the user's focus habit.
struct PersonalInsightsView: View {

    let sessions: [FocusSession]

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool { horizontalSizeClass == .regular }

    private var currentLocale: Locale {
        Locale(identifier: appLanguage)
    }

    private var metrics: ReportMetrics {
        ReportMetrics(sessions: sessions)
    }

    // MARK: - Single Smart Note Generation

    private var singleSmartNote: String {
        if sessions.count <= 3 {
            return appLanguage == "tr"
                ? "Dengen zamanla netleşecek."
                : "Your balance will form over time."
        }

        // 1. Time Window Momentum Note
        if let peak = metrics.strongestTimeBlock {
            switch peak {
            case .evening:
                return appLanguage == "tr"
                    ? "Akşam oturumların daha uzun."
                    : "Your evening sessions last longer."
            case .morning:
                return appLanguage == "tr"
                    ? "Sabah oturumlarında daha rahat ivme yakalıyorsun."
                    : "Morning sessions suit you best."
            case .afternoon:
                return appLanguage == "tr"
                    ? "Öğleden sonra oturumlarında düzenli ilerliyorsun."
                    : "Afternoon sessions maintain steady progress."
            case .night:
                return appLanguage == "tr"
                    ? "Gece saatlerinde sakince çalışmayı tercih ediyorsun."
                    : "Night hours suit your quiet focus."
            }
        }

        // 2. Recommended Focus Duration Note
        if let recMins = metrics.recommendedFocusDurationMinutes {
            return appLanguage == "tr"
                ? "\(recMins) dk civarı sana iyi gidiyor."
                : "Around \(recMins)m seems to suit you."
        }

        // 3. Best Completed Duration Bucket Note
        if let bestBucket = metrics.bestCompletedDurationBucketMinutes {
            return appLanguage == "tr"
                ? "\(bestBucket) dakikalık oturumları daha sık tamamlıyorsun."
                : "You complete \(bestBucket)-minute sessions more often."
        }

        // Fallback
        return appLanguage == "tr"
            ? "İlk ritim izlerin oluşuyor."
            : "Your first rhythm traces are forming."
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appLanguage == "tr" ? "İÇGÖRÜ" : "INSIGHT")
                .font(.system(size: isIPad ? 13 : 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.45))
                .tracking(2.0)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: isIPad ? 13 : 11, weight: .medium))
                    .foregroundStyle(Color(white: 0.50))

                Text(singleSmartNote)
                    .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.80))
                    .lineLimit(2)
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
    PersonalInsightsView(sessions: [])
}
