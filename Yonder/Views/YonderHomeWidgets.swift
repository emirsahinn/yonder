//
//  YonderHomeWidgets.swift
//  Yonder
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Entries

struct TodaySummaryEntry: TimelineEntry {
    let date: Date
    let todayTotalSeconds: Int
}

struct QuickStartEntry: TimelineEntry {
    let date: Date
    let mostUsedDurationSeconds: Int
}

// MARK: - Timeline Providers

struct TodaySummaryTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaySummaryEntry {
        TodaySummaryEntry(date: Date(), todayTotalSeconds: 4800)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaySummaryEntry) -> Void) {
        let entry = TodaySummaryEntry(
            date: Date(),
            todayTotalSeconds: WidgetDataService.shared.todayTotalSeconds
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaySummaryEntry>) -> Void) {
        let entry = TodaySummaryEntry(
            date: Date(),
            todayTotalSeconds: WidgetDataService.shared.todayTotalSeconds
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct QuickStartTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickStartEntry {
        QuickStartEntry(date: Date(), mostUsedDurationSeconds: 1500)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickStartEntry) -> Void) {
        let entry = QuickStartEntry(
            date: Date(),
            mostUsedDurationSeconds: WidgetDataService.shared.mostUsedDurationSeconds
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickStartEntry>) -> Void) {
        let entry = QuickStartEntry(
            date: Date(),
            mostUsedDurationSeconds: WidgetDataService.shared.mostUsedDurationSeconds
        )
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Widget 1: Bugünkü Özet (Today's Summary)

struct YonderTodaySummaryWidget: Widget {
    let kind: String = "YonderTodaySummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaySummaryTimelineProvider()) { entry in
            TodaySummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("Bugünkü Özet")
        .description("Bugünkü toplam odaklanma süreni gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct TodaySummaryWidgetView: View {
    let entry: TodaySummaryEntry

    @Environment(\.widgetFamily) private var family

    private var formattedDuration: String {
        let hours = entry.todayTotalSeconds / 3600
        let minutes = (entry.todayTotalSeconds % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours) sa \(minutes) dk"
        } else if hours > 0 {
            return "\(hours) sa"
        } else if minutes > 0 {
            return "\(minutes) dk"
        } else {
            return "0 dk"
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 11, weight: .bold))
                    Text(formattedDuration)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                }
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                    Text("YONDER")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Color(white: 0.6))
                }

                Text(formattedDuration)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Text(String(localized: "today_focused_sub", defaultValue: "Bugün odaklandın"))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color(white: 0.5))
            }

        case .systemMedium:
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image("SplashLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text("YONDER")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(Color(white: 0.6))
                    }

                    Spacer()

                    Text(formattedDuration)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    Text(String(localized: "today_focused_sub", defaultValue: "Bugün odaklandın"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.5))
                }

                Spacer()

                // Minimal Ring Graphic
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 68, height: 68)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Color(white: 0.8))
                }
            }
            .padding(16)
            .containerBackground(Color.black, for: .widget)

        default: // .systemSmall
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text("YONDER")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Color(white: 0.6))
                }

                Spacer()

                Text(formattedDuration)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)

                Text(String(localized: "today_focused_sub", defaultValue: "Bugün odaklandın"))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.5))
            }
            .padding(14)
            .containerBackground(Color.black, for: .widget)
        }
    }
}

// MARK: - Widget 2: Hızlı Başlat (Quick Start)

struct YonderQuickStartWidget: Widget {
    let kind: String = "YonderQuickStartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartTimelineProvider()) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("Hızlı Başlat")
        .description("En sık kullandığın odaklanma süresiyle onaylı sayaç başlatır.")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickStartWidgetView: View {
    let entry: QuickStartEntry

    private var durationMins: Int {
        entry.mostUsedDurationSeconds / 60
    }

    private var deepLinkURL: URL {
        URL(string: "yonder://start?duration=\(entry.mostUsedDurationSeconds)")!
    }

    var body: some View {
        Link(destination: deepLinkURL) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 44, height: 44)

                    Image(systemName: "hourglass")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color(white: 0.85))
                }

                Text("\(durationMins) dk")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(String(localized: "quick_start_sub", defaultValue: "Hızlı Başlat"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
        }
        .containerBackground(Color.black, for: .widget)
    }
}
