//
//  OnboardingView.swift
//  Yonder
//
//  Main Onboarding flow manager.
//  Orchestrates OnboardingLanguageView -> OnboardingIntroPagerView transition.
//

import SwiftUI

struct OnboardingView: View {

    var onFinished: () -> Void

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("hasSelectedLanguage") private var hasSelectedLanguage: Bool = false

    var body: some View {
        ZStack {
            if hasSelectedLanguage {
                OnboardingIntroPagerView {
                    finish()
                }
                .transition(.opacity)
            } else {
                OnboardingLanguageView { code in
                    appLanguage = code
                    LanguageService.shared.applyLanguage(code)
                    withAnimation(.easeInOut(duration: 0.45)) {
                        hasSelectedLanguage = true
                    }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation(.easeInOut(duration: 0.45)) {
            onFinished()
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
