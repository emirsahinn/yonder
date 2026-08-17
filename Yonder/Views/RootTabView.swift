//
//  RootTabView.swift
//  Yonder
//

import SwiftUI

/// Root tab navigation containing:
/// 1. HomeView (Dial & Focus Timer)
/// 2. ReportView (Focus Summary & 7-Day Chart)
/// 3. SettingsView (Preferences & About)
struct RootTabView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Binding var selectedTab: Int

    @State private var isLanguageLoading: Bool = false

    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab

        // Customize UITabBar appearance for pitch-black Fliqlo aesthetic
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1.0) // #0A0A0A

        // Subtle top border line
        appearance.shadowColor = UIColor(white: 0.15, alpha: 1.0)

        // Colors
        let normalColor = UIColor(white: 0.4, alpha: 1.0)
        let selectedColor = UIColor.white

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        appearance.inlineLayoutAppearance.normal.iconColor = normalColor
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        appearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        appearance.compactInlineLayoutAppearance.normal.iconColor = normalColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                // Tab 1: Home
                HomeView(
                    onNavigateToReport: { selectedTab = 1 },
                    onNavigateToSettings: { selectedTab = 2 }
                )
                    .tabItem {
                        Label(
                            title: { Text("home") },
                            icon: { Image(systemName: "hourglass") }
                        )
                    }
                    .tag(0)

                // Tab 2: Report
                ReportView()
                    .tabItem {
                        Label(
                            title: { Text("report") },
                            icon: { Image(systemName: "chart.bar") }
                        )
                    }
                    .tag(1)

                // Tab 3: Settings
                SettingsView()
                    .tabItem {
                        Label(
                            title: { Text("settings") },
                            icon: { Image(systemName: "gearshape") }
                        )
                    }
                    .tag(2)
            }
            .environment(\.locale, Locale(identifier: appLanguage))
            .tint(.white)

            // ── Loading indicator overlay on language change ───────────
            if isLanguageLoading {
                LoadingIndicatorView()
                    .transition(.opacity)
                    .zIndex(99)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: appLanguage) { oldValue, newValue in
            guard oldValue != newValue else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isLanguageLoading = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLanguageLoading = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootTabView()
}
