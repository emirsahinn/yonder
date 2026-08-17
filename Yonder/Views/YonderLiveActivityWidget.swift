//
//  YonderLiveActivityWidget.swift
//  Yonder
//

import SwiftUI
import WidgetKit
import ActivityKit

struct YonderWidgetBundle: WidgetBundle {
    var body: some Widget {
        YonderLiveActivityWidget()
        YonderTodaySummaryWidget()
        YonderQuickStartWidget()
    }
}

/// ActivityKit Widget implementation rendering Yonder's live focus countdown on Lock Screen and Dynamic Island.
struct YonderLiveActivityWidget: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: YonderActivityAttributes.self) { context in
            // Lock Screen & Notification Center Banner View
            lockScreenBannerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island Layout
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image("SplashLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)

                        Text("YONDER")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(white: 0.7))
                            .tracking(2)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text(String(localized: "paused_tag", defaultValue: "Duraklatıldı"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.5))
                    } else {
                        Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        if let count = context.state.participantCount, count > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 11))
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color(red: 0.42, green: 0.82, blue: 0.88))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(white: 0.12)))
                        }

                        if let note = context.state.intentionNote, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("“\(note.trimmingCharacters(in: .whitespacesAndNewlines))”")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color(white: 0.75))
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            } compactTrailing: {
                if context.state.isPaused {
                    Text("II")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.5))
                } else {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 42)
                }
            } minimal: {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
        }
    }

    // MARK: - Lock Screen Banner View

    private func lockScreenBannerView(context: ActivityViewContext<YonderActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            // Left: Logo Emblem inside Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 42, height: 42)

                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }

            // Middle: Title & Intention Note
            VStack(alignment: .leading, spacing: 3) {
                Text("YONDER")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.5))
                    .tracking(3)

                if let note = context.state.intentionNote, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("“\(note.trimmingCharacters(in: .whitespacesAndNewlines))”")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.85))
                        .lineLimit(1)
                } else {
                    Text(String(localized: "focus_session_label", defaultValue: "Odaklanma Oturumu"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.85))
                }
            }

            Spacer()

            // Right: Monospaced Countdown Timer
            if context.state.isPaused {
                Text(String(localized: "paused_tag", defaultValue: "Duraklatıldı"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.5))
            } else {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black)
        .activityBackgroundTint(Color.black)
    }
}
