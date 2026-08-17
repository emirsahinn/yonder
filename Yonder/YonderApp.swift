//
//  YonderApp.swift
//  Yonder
//
//  Created by Emir Şahin on 22.07.2026.
//

import SwiftUI
import FirebaseCore
import SwiftData
import UIKit
import GoogleSignIn

// MARK: - App Delegate & Scene Delegate for Quick Actions

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.shared.supportedInterfaceOrientations
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            QuickActionService.shared.handleShortcutItem(shortcutItem)
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let handled = QuickActionService.shared.handleShortcutItem(shortcutItem)
        completionHandler(handled)
    }
}

// MARK: - Extension for FullScreenCover Item Binding

extension TimerViewModel: Identifiable {
    public var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}

// MARK: - Main App Entry

@main
struct YonderApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var quickActionService = QuickActionService.shared

    /// Controls whether the animated splash is shown.
    @State private var showSplash = true

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("app_language") private var appLanguage: String = "en"
    @State private var authService: AuthService
    @State private var pendingQuickActionDuration: Int? = nil
    @State private var quickActionTimerVM: TimerViewModel? = nil
    @State private var showRecapFromNotification: Bool = false
    @State private var workGoalStore: WorkGoalStore = WorkGoalStore.shared
    @State private var pendingSyncAfterSplash: Bool = false
    @StateObject private var proStore = ProStore.shared

    init() {
        FirebaseApp.configure()
        // Relay Firebase's already-parsed CLIENT_ID to the GoogleSignIn SDK.
        // Must happen before any GIDSignIn.sharedInstance.signIn() call.
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        _authService = State(initialValue: AuthService.shared)
        _ = NotificationService.shared
        _ = LanguageService.shared
        // Schedule the weekly recap reminder (no-op if permission not granted yet)
        NotificationService.shared.scheduleWeeklyRecapNotification()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // ── Main content (always in the hierarchy so it's ready) ──
                ContentView(triggerSyncOnAppear: $pendingSyncAfterSplash)
                    .opacity(showSplash ? 0 : 1)

                // ── Animated splash overlay ───────────────────────────────
                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            showSplash = false
                        }
                        // Signal ContentView to run full sync once it appears
                        pendingSyncAfterSplash = true
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }

                // ── Onboarding overlay (first launch only, after splash) ──
                if !showSplash && !hasSeenOnboarding {
                    OnboardingView {
                        hasSeenOnboarding = true
                    }
                    .transition(.opacity)
                    .zIndex(3)
                }

                // ── Quick Action Confirmation Modal ──────────────────────
                if let duration = pendingQuickActionDuration {
                    QuickActionConfirmationView(
                        durationSeconds: duration,
                        onConfirm: {
                            pendingQuickActionDuration = nil
                            let vm = TimerViewModel()
                            vm.setDuration(duration)
                            vm.start()
                            quickActionTimerVM = vm
                        },
                        onCancel: {
                            pendingQuickActionDuration = nil
                            quickActionService.selectedDurationSeconds = nil
                        }
                    )
                    .zIndex(2)
                }
            }
            .ignoresSafeArea()
            .onChange(of: quickActionService.selectedDurationSeconds) { _, duration in
                if let duration = duration, duration > 0 {
                    // Bypass Splash animation immediately and show confirmation
                    showSplash = false
                    pendingQuickActionDuration = duration
                }
            }
            .fullScreenCover(item: $quickActionTimerVM) { timerVM in
                TimerView(timerVM: timerVM, onFinishAll: {
                    quickActionTimerVM = nil
                    quickActionService.selectedDurationSeconds = nil
                })
            }
            .onOpenURL { url in
                // Handle Google Sign-In OAuth redirect
                if GIDSignIn.sharedInstance.handle(url) { return }

                // Handle Yonder deep links (quick actions / Siri intents)
                if url.scheme == "yonder" && url.host == "start" {
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let item = components.queryItems?.first(where: { $0.name == "duration" }),
                       let durationVal = Int(item.value ?? "") {
                        quickActionService.triggerIntentDuration(durationVal)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didTapWeeklyRecapNotification)) { _ in
                showSplash = false
                showRecapFromNotification = true
            }
            .fullScreenCover(isPresented: $showRecapFromNotification) {
                RecapCardView(sessions: [])
            }
            .environment(authService)
            .environment(\.locale, Locale(identifier: appLanguage))
            .environmentObject(workGoalStore)
            .environmentObject(proStore)
            .task {
                await proStore.start()
            }
        }
        .modelContainer(for: [FocusSession.self, FocusReminder.self, Subject.self])
    }
}
