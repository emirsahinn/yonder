//
//  SessionCompleteView.swift
//  Yonder
//
//  Full-screen completion view presented when a focus session ends (or is stopped early),
//  requiring explicit user confirmation to save the session to SwiftData, with optional break proposal.
//  Work area selection uses canonical subjects only via WorkItemPickerSheet (no ad-hoc creation).
//

import SwiftUI

struct SessionCompleteView: View {

    let durationSeconds: Int
    let completed: Bool
    let intentionNote: String?
    let onSave: (_ workArea: String?) -> Void
    let onStartBreak: () -> Void
    let onFinish: () -> Void
    let onDiscard: () -> Void

    @AppStorage("app_language") private var appLanguage: String = "en"
    @State private var showBreakProposal: Bool = false
    @State private var hasSaved: Bool = false
    @State private var isSaving: Bool = false
    @State private var transitionMessage: String?
    @State private var selectedWorkArea: String?
    @State private var showWorkItemPickerSheet: Bool = false

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    private var isIPad: Bool { hSizeClass == .regular }
    private var isLandscape: Bool { vSizeClass == .compact }

    init(
        durationSeconds: Int,
        completed: Bool,
        intentionNote: String?,
        onSave: @escaping (_ workArea: String?) -> Void,
        onStartBreak: @escaping () -> Void = {},
        onFinish: @escaping () -> Void,
        onDiscard: @escaping () -> Void
    ) {
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.intentionNote = intentionNote
        self.onSave = onSave
        self.onStartBreak = onStartBreak
        self.onFinish = onFinish
        self.onDiscard = onDiscard
        let initialWorkArea = intentionNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        self._selectedWorkArea = State(initialValue: (initialWorkArea?.isEmpty == false) ? initialWorkArea : nil)
    }

    private var formattedTimeStr: String {
        let hrs = durationSeconds / 3600
        let mins = (durationSeconds % 3600) / 60
        let secs = durationSeconds % 60
        var parts: [String] = []

        if appLanguage == "tr" {
            if hrs > 0 { parts.append("\(hrs) saat") }
            if mins > 0 { parts.append("\(mins) dakika") }
            if secs > 0 || parts.isEmpty { parts.append("\(secs) saniye") }
        } else {
            if hrs > 0 { parts.append("\(hrs) \(hrs == 1 ? "hour" : "hours")") }
            if mins > 0 { parts.append("\(mins) \(mins == 1 ? "minute" : "minutes")") }
            if secs > 0 || parts.isEmpty { parts.append("\(secs) \(secs == 1 ? "second" : "seconds")") }
        }

        return parts.joined(separator: " ")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showBreakProposal {
                breakProposalView
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                saveConfirmationView
                    .transition(.opacity)
            }

            if isSaving {
                YonderTransitionOverlay(message: transitionMessage ?? (appLanguage == "tr" ? "Ekran hazırlanıyor" : "Preparing screen"))
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showWorkItemPickerSheet) {
            WorkItemPickerSheet(selectedWorkItem: $selectedWorkArea)
        }
        .animation(.easeInOut(duration: 0.25), value: isSaving)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
    }

    // MARK: - Save Confirmation View

    private var saveConfirmationView: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: isLandscape ? 12 : (isIPad ? 32 : 20)) {
                    Spacer(minLength: isLandscape ? 12 : 24)

                    // Checkmark / Icon
                    Image(systemName: completed ? "checkmark.circle" : "clock.badge.checkmark")
                        .font(.system(size: isLandscape ? 38 : (isIPad ? 72 : 54), weight: .thin))
                        .foregroundStyle(Color(white: 0.8))

                    // Status Header
                    Text(completed ? "session_completed" : "session_ended")
                        .font(.system(size: isLandscape ? 14 : (isIPad ? 22 : 16), weight: .light, design: .rounded))
                        .foregroundStyle(Color(white: 0.5))
                        .tracking(4)
                        .textCase(.uppercase)

                    // Large Completed Duration Display
                    Text(formattedTimeStr)
                        .font(.system(size: isLandscape ? 38 : (isIPad ? 64 : 48), weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .padding(.vertical, 2)

                    // Work Area Selector Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appLanguage == "tr" ? "ÇALIŞMA ALANI" : "WORK AREA")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                            .tracking(1)

                        Button {
                            showWorkItemPickerSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 12))
                                    .foregroundStyle(selectedWorkArea != nil ? Color.black : Color(white: 0.5))

                                Text(selectedWorkArea ?? (appLanguage == "tr" ? "Çalışma seç" : "Select work area"))
                                    .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(selectedWorkArea != nil ? Color.black : Color(white: 0.5))
                                    .lineLimit(1)

                                Spacer()

                                if selectedWorkArea != nil {
                                    Button {
                                        selectedWorkArea = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color(white: 0.4))
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(white: 0.4))
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: isIPad ? 46 : 42)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedWorkArea != nil ? Color.white : Color(white: 0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedWorkArea != nil ? Color.white : Color(white: 0.18), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, isLandscape ? 40 : (isIPad ? 60 : 32))

                    Spacer(minLength: isLandscape ? 12 : 24)

                    // Actions Section
                    VStack(spacing: 12) {
                        // Primary CTA: "Kaydet"
                        Button {
                            guard selectedWorkArea?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                                HapticService.warning()
                                showWorkItemPickerSheet = true
                                return
                            }
                            guard !hasSaved else { return }
                            hasSaved = true
                            isSaving = true
                            transitionMessage = appLanguage == "tr" ? "Oturum kaydediliyor" : "Saving session"
                            HapticService.success()

                            Task {
                                await YonderTransitionHelper.withMinimumDuration(seconds: 0.45) {
                                    onSave(selectedWorkArea)
                                }
                                await MainActor.run {
                                    onFinish()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("save_session_button")
                                    .font(.system(size: isIPad ? 19 : 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: isLandscape ? 380 : (isIPad ? 440 : .infinity))
                            .frame(height: isIPad ? 56 : 50)
                            .background(
                                Capsule()
                                    .fill(.white)
                                    .shadow(color: .white.opacity(0.18), radius: 10)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(hasSaved || selectedWorkArea?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false)
                        .opacity(selectedWorkArea?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? 1.0 : 0.35)

                        // Secondary CTA: "Kaydetmeden Çık"
                        Button {
                            guard !isSaving else { return }
                            isSaving = true
                            transitionMessage = appLanguage == "tr" ? "Ana ekran hazırlanıyor" : "Preparing home"
                            HapticService.warning()
                            Task {
                                try? await Task.sleep(nanoseconds: 450_000_000)
                                await MainActor.run {
                                    onDiscard()
                                }
                            }
                        } label: {
                            Text("discard_session_button")
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.45))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, isLandscape ? 40 : (isIPad ? 80 : 32))
                    .padding(.bottom, isLandscape ? 20 : (isIPad ? 40 : 28))
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Break Proposal Subview

    private var breakProposalView: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: isLandscape ? 12 : (isIPad ? 32 : 24)) {
                    Spacer(minLength: isLandscape ? 12 : 24)

                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: isLandscape ? 42 : (isIPad ? 72 : 54), weight: .thin))
                        .foregroundStyle(Color(white: 0.8))

                    VStack(spacing: 8) {
                        Text("break_proposal_title")
                            .font(.system(size: isIPad ? 22 : 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("break_proposal_subtitle")
                            .font(.system(size: isIPad ? 16 : 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                    }

                    Spacer(minLength: isLandscape ? 12 : 24)

                    VStack(spacing: 14) {
                        Button {
                            HapticService.light()
                            onStartBreak()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
                                Text("take_break_button")
                                    .font(.system(size: isIPad ? 19 : 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: isLandscape ? 380 : (isIPad ? 440 : .infinity))
                            .frame(height: isIPad ? 56 : 50)
                            .background(
                                Capsule()
                                    .fill(.white)
                                    .shadow(color: .white.opacity(0.18), radius: 10)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            onFinish()
                        } label: {
                            Text("no_finish_button")
                                .font(.system(size: isIPad ? 16 : 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.45))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, isLandscape ? 40 : (isIPad ? 80 : 32))
                    .padding(.bottom, isLandscape ? 20 : (isIPad ? 40 : 28))
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Preview

#Preview {
    SessionCompleteView(
        durationSeconds: 1500,
        completed: true,
        intentionNote: "Matematik Ödevi",
        onSave: { _ in },
        onStartBreak: {},
        onFinish: {},
        onDiscard: {}
    )
}
