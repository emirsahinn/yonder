//
//  HomeView.swift
//  Yonder
//

import SwiftUI

/// Home tab root view — delegates to TodayView ("Bugün" karşılama katmanı).
struct HomeView: View {

    var onNavigateToReport: (() -> Void)? = nil
    var onNavigateToSettings: (() -> Void)? = nil

    var body: some View {
        TodayView(
            onNavigateToReport: onNavigateToReport,
            onNavigateToSettings: onNavigateToSettings
        )
    }
}

// MARK: - Previews

#Preview {
    HomeView()
}
