//
//  RoomTimerView.swift
//  Yonder
//
//  Synchronized Fliqlo-style timer screen for group focus rooms.
//  Displays live countdown, minimal participant avatars,
//  and shared controls to pause/toggle study state.
//

import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import UIKit

/// Synchronized Fliqlo-style timer screen for group focus rooms.
struct RoomTimerView: View {

    let roomId: String

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("active_room_id") private var activeRoomId: String = ""
    @AppStorage("timer_clock_style") private var timerClockStyleRaw: String = "flip"
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false

    private var selectedStyle: TimerClockStyle {
        TimerClockStyle.resolved(rawValue: timerClockStyleRaw, isPremiumUser: isPremiumUser)
    }
    @State private var room: RoomModel? = nil
    @State private var participants: [ParticipantModel] = []
    @State private var lastKnownParticipants: [ParticipantModel] = []
    @State private var remainingSeconds: Int = 0
    @State private var nowTickDate: Date = Date()
    @State private var controlsVisible: Bool = false
    @State private var hideControlsTask: Task<Void, Never>? = nil
    @State private var loadingTimeoutTask: Task<Void, Never>? = nil
    @State private var isRoomNotFoundOrTimedOut: Bool = false
    @State private var isCompleted: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var roomListener: ListenerRegistration? = nil
    @State private var participantListener: ListenerRegistration? = nil
    @State private var myStatus: String = "studying"
    @State private var selectedWorkItem: String? = nil
    @State private var showWorkItemPicker: Bool = false
    @State private var didSendEndedStatus: Bool = false
    @State private var didSaveLocalSession: Bool = false
    @State private var inlineErrorMessage: String? = nil
    @State private var showStartBreakConfirmation: Bool = false
    @State private var showResumeWorkConfirmation: Bool = false
    @State private var showLeaveConfirmation: Bool = false
    @State private var showEndRoomConfirmation: Bool = false
    @State private var isActionLoading: Bool = false
    @State private var showParticipantsSheet: Bool = false
    @State private var didLeaveRoomExplicitly: Bool = false
    @State private var roomCodeCopied: Bool = false
    @State private var showPortraitTransitionMask: Bool = false
    @State private var portraitTransitionTask: Task<Void, Never>? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [FocusSession]
    @Query(sort: \Subject.lastUsedDate, order: .reverse) private var savedSubjects: [Subject]
    private var isIPad: Bool { hSizeClass == .regular }
    private var isLandscapePhone: Bool { vSizeClass == .compact }

    private var hours: Int { remainingSeconds / 3600 }
    private var minutes: Int { (remainingSeconds % 3600) / 60 }
    private var seconds: Int { remainingSeconds % 60 }
    private var studyingCount: Int { participants.filter(\.isStudying).count }
    private var breakCount: Int { max(0, participants.count - studyingCount) }
    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    private var isHost: Bool { room?.hostId == currentUserId }
    private var isHostPresent: Bool {
        guard let hostId = room?.hostId, !hostId.isEmpty else { return true }
        return participants.contains(where: { $0.id == hostId })
    }
    private var myParticipant: ParticipantModel? { participants.first { $0.id == currentUserId } }
    private var isReady: Bool { myParticipant?.isReady ?? false }
    private var readyCount: Int { participants.filter(\.isReady).count }
    private var allReady: Bool { !participants.isEmpty && participants.allSatisfy(\.isReady) }
    private var canStartRoom: Bool { isHost && allReady }
    private var isOnlyParticipant: Bool { participants.count <= 1 }
    private var visibleHeaderParticipants: [ParticipantModel] { Array(participants.prefix(4)) }
    private var todayTotalSeconds: Int {
        let calendar = Calendar.current
        return allSessions
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isCompleted {
                completedView
            } else if room?.isWaiting == true {
                lobbyView
            } else {
                timerContentView
            }

            // Syncing Loading Overlay (until initial Firestore snapshot arrives)
            if room == nil {
                if isRoomNotFoundOrTimedOut {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(Color(white: 0.60))

                        Text(appLanguage == "tr"
                             ? "Oda bulunamadı veya bağlantı kurulamadı."
                             : "The room could not be found or reached.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button {
                            activeRoomId = ""
                            dismissRoomTimerAfterPortraitSettles()
                        } label: {
                            Text(appLanguage == "tr" ? "Kapat" : "Close")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(width: 140, height: 44)
                                .background(Capsule().fill(.white))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    LoadingIndicatorView(
                        messageKey: "syncing_room_loading",
                        onCancel: {
                            activeRoomId = ""
                            dismissRoomTimerAfterPortraitSettles()
                        }
                    )
                }
            }

            if showPortraitTransitionMask {
                YonderTransitionOverlay(message: appLanguage == "tr" ? "Ekran hazırlanıyor" : "Preparing screen")
                    .transition(.opacity)
                    .zIndex(40)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: controlsVisible)
        .animation(.easeInOut(duration: 0.5), value: isCompleted)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .sheet(isPresented: $showWorkItemPicker) {
            WorkItemPickerSheet(selectedWorkItem: $selectedWorkItem)
        }
        .onChange(of: selectedWorkItem) { _, newItem in
            Task {
                try? await RoomService.shared.updateMyWorkItem(roomId: roomId, workItemName: newItem)
            }
        }
        .onAppear {
            setupListeners()
            startLocalTimer()
            updateOrientationPermission()
        }
        .onDisappear {
            portraitTransitionTask?.cancel()
            showPortraitTransitionMask = false
            OrientationLock.shared.lockPhonePortrait(roomOrientationReason)
            cleanUp()
        }
        .onChange(of: room?.isWaiting) { _, _ in
            updateOrientationPermission()
        }
        .onChange(of: isCompleted) { _, _ in
            updateOrientationPermission()
        }
        // Start Break Confirmation Dialog
        .confirmationDialog(
            appLanguage == "tr" ? "Molaya çıkılsın mı?" : "Start break?",
            isPresented: $showStartBreakConfirmation,
            titleVisibility: .visible
        ) {
            Button(appLanguage == "tr" ? "Molaya Çık" : "Start Break") {
                executeToggleMyStatus()
            }
            Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {}
        } message: {
            Text(appLanguage == "tr" ? "Mola süresi çalışma sürene eklenmez." : "Break time will not count as active work time.")
        }
        // Resume Work Confirmation Dialog
        .confirmationDialog(
            appLanguage == "tr" ? "Çalışmaya dönülsün mü?" : "Resume work?",
            isPresented: $showResumeWorkConfirmation,
            titleVisibility: .visible
        ) {
            Button(appLanguage == "tr" ? "Çalışmaya Dön" : "Resume Work") {
                executeToggleMyStatus()
            }
            Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {}
        } message: {
            Text(appLanguage == "tr" ? "Aktif çalışma süren tekrar işlemeye başlayacak." : "Your active work time will start counting again.")
        }
        // Leave Room Confirmation Dialog
        .confirmationDialog(
            appLanguage == "tr" ? "Odadan ayrıl?" : "Leave room?",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            if isOnlyParticipant {
                Button(appLanguage == "tr" ? "Ayrıl ve Odayı Bitir" : "Leave and End Room", role: .destructive) {
                    executeLeaveRoom()
                }
                Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {}
            } else if isHost {
                Button(appLanguage == "tr" ? "Sadece Ayrıl" : "Leave Only") {
                    executeLeaveRoom()
                }
                Button(appLanguage == "tr" ? "Odayı Bitir" : "End Room", role: .destructive) {
                    executeEndRoom()
                }
                Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {}
            } else {
                Button(appLanguage == "tr" ? "Ayrıl" : "Leave", role: .destructive) {
                    executeLeaveRoom()
                }
                Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {}
            }
        } message: {
            Text(appLanguage == "tr"
                 ? "Bu oturumdaki aktif çalışma süren kaydedilmeden önce sonlandırılacak."
                 : "Your active time in this room will be finalized before leaving.")
        }
        // End Room Confirmation Dialog
        .confirmationDialog(
            appLanguage == "tr" ? "Oda bitirilsin mi?" : "End room?",
            isPresented: $showEndRoomConfirmation,
            titleVisibility: .visible
        ) {
            Button(appLanguage == "tr" ? "Odayı Bitir" : "End Room", role: .destructive) {
                executeEndRoom()
            }
            Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {}
        } message: {
            Text(appLanguage == "tr"
                 ? "Odadaki oturum sona erecek. Katılımcıların süreleri mevcut durumlarına göre tamamlanacak."
                 : "The room session will end. Participant times will be finalized from their current state.")
        }
        .sheet(isPresented: $showParticipantsSheet) {
            RoomParticipantsSheet(
                roomId: roomId,
                room: room,
                participants: participants,
                currentUserId: currentUserId,
                remainingSeconds: remainingSeconds,
                appLanguage: appLanguage
            )
        }
    }

    private var roomOrientationReason: String {
        "room-timer-\(roomId)"
    }

    private func updateOrientationPermission() {
        if room?.isWaiting == false && !isCompleted {
            OrientationLock.shared.allowPhoneLandscape(roomOrientationReason)
        } else {
            OrientationLock.shared.lockPhonePortrait(roomOrientationReason)
        }
    }

    // MARK: - Timer Layout

    private var timerContentView: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let shortEdge = min(geometry.size.width, geometry.size.height)
            let clockHeight = shortEdge * 0.80

            ZStack {
                Color.black
                    .ignoresSafeArea()

                // Center Clock Display
                TimerClockDisplayView(
                    style: selectedStyle,
                    hours: hours,
                    minutes: minutes,
                    seconds: seconds,
                    showHours: hours > 0,
                    showSeconds: true,
                    isRunning: true,
                    remainingSeconds: remainingSeconds,
                    totalSeconds: room?.duration
                )
                .frame(width: geometry.size.width * 0.96, height: clockHeight)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Overlaid Controls (Header badge at top + Control bar at bottom/side)
                VStack(spacing: 0) {
                    roomHeader
                        .padding(.top, isIPad ? (isLandscape ? 16 : 32) : (isLandscape ? 12 : 20))
                        .opacity(controlsVisible ? 1.0 : 0.0)
                        .disabled(!controlsVisible)

                    Spacer()

                    if let err = inlineErrorMessage {
                        Text(err)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(white: 0.10))
                            )
                            .padding(.bottom, 12)
                    }

                    if !isLandscape {
                        controlBar
                            .opacity(controlsVisible ? 1.0 : 0.0)
                            .disabled(!controlsVisible)
                            .padding(.bottom, isIPad ? 44 : 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .trailing) {
                    if isLandscape {
                        controlBarVertical
                            .frame(width: isIPad ? 92 : 76)
                            .opacity(controlsVisible ? 1.0 : 0.0)
                            .disabled(!controlsVisible)
                            .padding(.trailing, isIPad ? 24 : 14)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleControls()
            }
            .rotatesForPhoneUpsideDown()
        }
    }

    // MARK: - Lobby Layout

    private var lobbyView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    handleCloseTap()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(white: 0.55))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, isIPad ? 24 : 14)
            .padding(.horizontal, isIPad ? 44 : 20)

            if isLandscapePhone {
                ScrollView(showsIndicators: false) {
                    lobbyMainContent
                        .padding(.vertical, 12)
                }
            } else {
                Spacer(minLength: 0)
                lobbyMainContent
                Spacer(minLength: 0)
            }
        }
    }

    private var lobbyMainContent: some View {
        VStack(spacing: isIPad ? 24 : (isLandscapePhone ? 14 : 18)) {
            VStack(spacing: 8) {
                Text(appLanguage == "tr" ? "ONLİNE ODA" : "ONLINE ROOM")
                    .font(.system(size: isIPad ? 16 : 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .textCase(.uppercase)
                    .tracking(3)

                Text(roomId)
                    .font(.system(size: isIPad ? 58 : (isLandscapePhone ? 34 : 42), weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                // Copy room code chip
                Button {
                    UIPasteboard.general.string = roomId
                    HapticService.light()
                    withAnimation(.easeInOut(duration: 0.2)) { roomCodeCopied = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.2)) { roomCodeCopied = false }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: roomCodeCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                        Text(roomCodeCopied
                             ? (appLanguage == "tr" ? "Kopyalandı" : "Copied!")
                             : (appLanguage == "tr" ? "Kodu Kopyala" : "Copy Code"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color(white: roomCodeCopied ? 0.85 : 0.55))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.10))
                            .overlay(Capsule().strokeBorder(Color(white: roomCodeCopied ? 0.32 : 0.18), lineWidth: 0.5))
                    )
                }
                .buttonStyle(.plain)

                if let subject = room?.subject, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subject)
                        .font(.system(size: isIPad ? 17 : 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Text(appLanguage == "tr" ? "Birlikte odaklan · \(formattedDuration(room?.duration ?? 0)) · \(readyCount)/\(max(participants.count, 1)) hazır" : "Focus together · \(formattedDuration(room?.duration ?? 0)) · \(readyCount)/\(max(participants.count, 1)) ready")
                    .font(.system(size: isIPad ? 14 : 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.40))
                    .monospacedDigit()

                if !isHostPresent {
                    Text(appLanguage == "tr" ? "Host odadan ayrıldı." : "The host left the room.")
                        .font(.system(size: isIPad ? 13 : 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.50))
                        .padding(.top, 2)
                }
            }

            // My Selected Work Area setup pill
            myWorkSetupField

            participantListView
                .frame(maxWidth: isIPad ? 520 : (isLandscapePhone ? 480 : .infinity))

            VStack(spacing: 12) {
                // Ready Button
                Button {
                    toggleReady()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17, weight: .semibold))
                        Text(isReady ? (appLanguage == "tr" ? "Hazırsın" : "Ready") : (appLanguage == "tr" ? "Hazırım" : "I’m ready"))
                            .font(.system(size: isIPad ? 17 : 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(isReady ? .black : Color(white: 0.9))
                    .frame(maxWidth: isIPad ? 520 : (isLandscapePhone ? 480 : .infinity))
                    .frame(height: isIPad ? 54 : 48)
                    .background(
                        Capsule()
                            .fill(isReady ? Color.white : Color(white: 0.12))
                            .overlay(Capsule().strokeBorder(Color(white: isReady ? 1 : 0.22), lineWidth: 0.5))
                    )
                }
                .buttonStyle(.plain)

                // Host Start Room Button or Explanatory Text
                if isHost {
                    VStack(spacing: 6) {
                        Button {
                            startRoom()
                        } label: {
                            Text(appLanguage == "tr" ? "Odayı Başlat" : "Start Room")
                                .font(.system(size: isIPad ? 17 : 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: isIPad ? 520 : (isLandscapePhone ? 480 : .infinity))
                                .frame(height: isIPad ? 54 : 48)
                                .background(Capsule().fill(.white))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canStartRoom || isActionLoading)
                        .opacity(canStartRoom ? 1.0 : 0.35)

                        if !canStartRoom {
                            Text(appLanguage == "tr" ? "Herkes hazır olduğunda host odayı başlatabilir." : "The host can start when everyone is ready.")
                                .font(.system(size: isIPad ? 12 : 11, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(white: 0.40))
                                .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    Text(appLanguage == "tr" ? "Host odayı başlatınca sayaç aynı anda başlayacak." : "The timer will start when the host begins.")
                        .font(.system(size: isIPad ? 13 : 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.40))
                        .multilineTextAlignment(.center)
                }

                if let err = inlineErrorMessage {
                    Text(err)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.6))
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, isIPad ? 80 : (isLandscapePhone ? 20 : 28))
        }
    }

    private var myWorkSetupField: some View {
        Button {
            showWorkItemPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.45))

                VStack(alignment: .leading, spacing: 2) {
                    let currentWork = myParticipant?.workItemName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(currentWork?.isEmpty == false ? currentWork! : (appLanguage == "tr" ? "Çalışma seç" : "Choose work"))
                        .font(.system(size: isIPad ? 15 : 13, weight: currentWork?.isEmpty == false ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(Color(white: currentWork?.isEmpty == false ? 0.90 : 0.45))
                        .lineLimit(1)

                    if currentWork?.isEmpty == true || currentWork == nil {
                        Text(appLanguage == "tr" ? "Odadaki çalışma alanını belirle" : "Set your focus work area in this room")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.38))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.35))
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: isIPad ? 520 : (isLandscapePhone ? 480 : .infinity))
            .frame(height: isIPad ? 48 : 42)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isActionLoading)
        .padding(.horizontal, isIPad ? 80 : (isLandscapePhone ? 20 : 28))
    }

    private var participantListView: some View {
        VStack(spacing: 8) {
            ForEach(participants) { participant in
                HStack(spacing: 12) {
                    Text(initials(for: participant.displayName))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.86))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(white: 0.13)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(participant.displayName)
                            .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.84))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if participant.id == room?.hostId {
                                Text("Host")
                                    .font(.system(size: isIPad ? 11 : 10, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color(white: 0.45))
                            }

                            if let work = participant.workItemName, !work.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(work)
                                    .font(.system(size: isIPad ? 11 : 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(white: 0.70))
                            } else {
                                Text(appLanguage == "tr" ? "Çalışma seçilmedi" : "No work selected")
                                    .font(.system(size: isIPad ? 11 : 10, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color(white: 0.40))
                            }

                            Text("·")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(white: 0.30))

                            Text(participant.isStudying ? (appLanguage == "tr" ? "çalışıyor" : "studying") : (appLanguage == "tr" ? "molada" : "on break"))
                                .font(.system(size: isIPad ? 11 : 10, weight: .regular, design: .rounded))
                                .foregroundStyle(participant.isStudying ? Color(white: 0.55) : Color(white: 0.35))
                        }

                        // Per-participant timing summary
                        let activeSec = participant.currentActiveSeconds(now: nowTickDate)
                        let breakSec = participant.currentBreakSeconds(now: nowTickDate)
                        let timeSummaryText: String = {
                            if activeSec == 0 && breakSec == 0 {
                                return appLanguage == "tr" ? "Henüz süre yok" : "No time yet"
                            }
                            let actStr = formattedTimeBadge(seconds: activeSec)
                            let brkStr = formattedTimeBadge(seconds: breakSec)
                            return appLanguage == "tr" ? "\(actStr) aktif · \(brkStr) mola" : "\(actStr) active · \(brkStr) break"
                        }()

                        Text(timeSummaryText)
                            .font(.system(size: isIPad ? 11 : 10, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                            .monospacedDigit()
                    }

                    Spacer()

                    Image(systemName: participant.isReady ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(participant.isReady ? Color.white : Color(white: 0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.055))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(white: 0.10), lineWidth: 0.5)
                        )
                )
            }
        }
        .padding(.horizontal, isIPad ? 80 : 28)
        .contentShape(Rectangle())
        .onTapGesture {
            showParticipantsSheet = true
        }
    }

    private var roomHeader: some View {
        Button {
            showParticipantsSheet = true
        } label: {
            HStack(spacing: 10) {
                participantAvatarStack

                Text(statusSummaryText)
                    .font(.system(size: isIPad ? 12 : 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Circle()
                    .fill(Color(white: 0.24))
                    .frame(width: 3, height: 3)

                Text(roomId)
                    .font(.system(size: isIPad ? 11 : 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.38))
                    .tracking(1.4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color(white: 0.07))
                    .overlay(Capsule().strokeBorder(Color(white: 0.16), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private var participantAvatarStack: some View {
        HStack(spacing: -7) {
            if visibleHeaderParticipants.isEmpty {
                headerAvatar(initials: "Y", isStudying: true)
            } else {
                ForEach(visibleHeaderParticipants) { participant in
                    headerAvatar(
                        initials: initials(for: participant.displayName),
                        isStudying: participant.isStudying
                    )
                    .animation(.easeInOut(duration: 0.3), value: participant.status)
                }

                if participants.count > visibleHeaderParticipants.count {
                    overflowAvatar(count: participants.count - visibleHeaderParticipants.count)
                }
            }
        }
    }

    private func headerAvatar(initials: String, isStudying: Bool) -> some View {
        Text(initials)
            .font(.system(size: isIPad ? 9 : 8, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(white: isStudying ? 0.88 : 0.45))
            .frame(width: isIPad ? 27 : 23, height: isIPad ? 27 : 23)
            .background(
                Circle()
                    .fill(Color(white: isStudying ? 0.13 : 0.09))
                    .overlay(
                        Circle()
                            .strokeBorder(Color(white: isStudying ? 0.38 : 0.16), lineWidth: 0.8)
                    )
            )
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(isStudying ? Color.white : Color(white: 0.28))
                    .frame(width: isIPad ? 6 : 5, height: isIPad ? 6 : 5)
                    .overlay(Circle().strokeBorder(Color.black, lineWidth: 1))
            }
    }

    private func overflowAvatar(count: Int) -> some View {
        Text("+\(count)")
            .font(.system(size: isIPad ? 9 : 8, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(white: 0.62))
            .frame(width: isIPad ? 27 : 23, height: isIPad ? 27 : 23)
            .background(
                Circle()
                    .fill(Color(white: 0.10))
                    .overlay(Circle().strokeBorder(Color(white: 0.18), lineWidth: 0.8))
            )
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            controlsVisible.toggle()
        }
        if controlsVisible {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
        }
    }

    private var statusSummaryText: String {
        if room?.isWaiting == true {
            return appLanguage == "tr"
                ? "\(readyCount)/\(max(participants.count, 1)) hazır"
                : "\(readyCount)/\(max(participants.count, 1)) ready"
        }

        if let me = myParticipant {
            if me.isStudying {
                let activeFormatted = formattedTimeBadge(seconds: me.currentActiveSeconds(now: nowTickDate))
                return appLanguage == "tr" ? "Çalışıyorsun: \(activeFormatted)" : "Working: \(activeFormatted)"
            } else if me.isBreak {
                let breakFormatted = formattedTimeBadge(seconds: me.currentBreakSeconds(now: nowTickDate))
                return appLanguage == "tr" ? "Moladasın: \(breakFormatted)" : "On break: \(breakFormatted)"
            }
        }

        if participants.isEmpty {
            return appLanguage == "tr" ? "1 kişi çalışıyor" : "1 studying"
        }

        if breakCount == 0 {
            return appLanguage == "tr" ? "\(studyingCount) kişi çalışıyor" : "\(studyingCount) studying"
        }

        return appLanguage == "tr"
            ? "\(studyingCount) çalışıyor · \(breakCount) molada"
            : "\(studyingCount) studying · \(breakCount) on break"
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: isIPad ? 24 : 14) {
            // Work Area Picker Button
            controlButton(icon: "square.and.pencil", label: appLanguage == "tr" ? "Çalışma" : "Work Area") {
                showWorkItemPicker = true
                scheduleHideControls()
            }
            .disabled(isActionLoading)

            // Participants Button
            controlButton(icon: "person.2.fill", label: appLanguage == "tr" ? "Katılımcılar" : "Participants") {
                showParticipantsSheet = true
                scheduleHideControls()
            }

            // Toggle Study / Break Button (Prompts for confirmation)
            controlButton(
                icon: myStatus == "studying" ? "cup.and.saucer.fill" : "play.fill",
                label: myStatus == "studying" ? (appLanguage == "tr" ? "Mola" : "Break") : (appLanguage == "tr" ? "Çalışıyorum" : "Resume"),
                isPrimary: true
            ) {
                if myStatus == "studying" {
                    showStartBreakConfirmation = true
                } else {
                    showResumeWorkConfirmation = true
                }
                scheduleHideControls()
            }
            .disabled(isActionLoading)

            // Leave Room Button (always shows confirmation)
            controlButton(icon: "arrow.left.circle", label: appLanguage == "tr" ? "Ayrıl" : "Leave") {
                showLeaveConfirmation = true
                scheduleHideControls()
            }
            .disabled(isActionLoading)

            // Host End Room Button
            if isHost && room?.isRunning == true {
                controlButton(
                    icon: "stop.circle.fill",
                    label: appLanguage == "tr" ? "Odayı Bitir" : "End Room"
                ) {
                    showEndRoomConfirmation = true
                    scheduleHideControls()
                }
                .disabled(isActionLoading)
            }
        }
    }

    private var controlBarVertical: some View {
        VStack(spacing: isIPad ? 18 : 12) {
            Spacer(minLength: 0)

            controlButton(icon: "square.and.pencil", label: appLanguage == "tr" ? "Çalışma" : "Work", compact: true) {
                showWorkItemPicker = true
                scheduleHideControls()
            }
            .disabled(isActionLoading)

            controlButton(icon: "person.2.fill", label: appLanguage == "tr" ? "Katılımcılar" : "People", compact: true) {
                showParticipantsSheet = true
                scheduleHideControls()
            }

            controlButton(
                icon: myStatus == "studying" ? "cup.and.saucer.fill" : "play.fill",
                label: myStatus == "studying" ? (appLanguage == "tr" ? "Mola" : "Break") : (appLanguage == "tr" ? "Çalışıyorum" : "Resume"),
                isPrimary: true,
                compact: true
            ) {
                if myStatus == "studying" {
                    showStartBreakConfirmation = true
                } else {
                    showResumeWorkConfirmation = true
                }
                scheduleHideControls()
            }
            .disabled(isActionLoading)

            controlButton(icon: "arrow.left.circle", label: appLanguage == "tr" ? "Ayrıl" : "Leave", compact: true) {
                showLeaveConfirmation = true
                scheduleHideControls()
            }
            .disabled(isActionLoading)

            if isHost && room?.isRunning == true {
                controlButton(
                    icon: "stop.circle.fill",
                    label: appLanguage == "tr" ? "Odayı Bitir" : "End Room",
                    compact: true
                ) {
                    showEndRoomConfirmation = true
                    scheduleHideControls()
                }
                .disabled(isActionLoading)
            }

            Spacer(minLength: 0)
        }
    }

    private func controlButton(
        icon: String,
        label: String,
        isPrimary: Bool = false,
        compact: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let size: CGFloat = compact ? (isIPad ? 54 : 44) : (isIPad ? 60 : 48)
        let iconSize: CGFloat = compact ? (isIPad ? 19 : 15) : (isIPad ? 20 : 17)

        return Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isPrimary ? Color.white : Color(white: 0.15))
                        .frame(width: size, height: size)

                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(isPrimary ? .black : Color(white: 0.6))
                }

                Text(label)
                    .font(.system(size: compact ? (isIPad ? 10 : 8) : (isIPad ? 11 : 9), weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.4))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: compact ? (isIPad ? 80 : 64) : nil)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completed Screen Subview

    private var completedView: some View {
        RoomSummaryView(
            room: room,
            participants: lastKnownParticipants,
            currentUserId: currentUserId,
            appLanguage: appLanguage,
            onDone: {
                activeRoomId = ""
                dismissRoomTimerAfterPortraitSettles()
            }
        )
    }

    // MARK: - Firebase & Action Logic

    private func setupListeners() {
        startLoadingTimeout()
        roomListener = RoomService.shared.listenToRoom(roomId: roomId) { updatedRoom in
            Task { @MainActor in
                self.loadingTimeoutTask?.cancel()
                self.room = updatedRoom
                if let room = updatedRoom {
                    if room.status == "ended" {
                        self.activeRoomId = ""
                        self.saveLocalRoomSessionIfNeeded(room: room)
                        self.presentCompletedRoomAfterPortraitSettles()
                    } else if room.isWaiting {
                        self.isCompleted = false
                        self.remainingSeconds = room.duration
                    } else {
                        self.didSendEndedStatus = false
                        self.syncRemainingSeconds(with: room)
                    }
                } else {
                    self.activeRoomId = ""
                    self.isRoomNotFoundOrTimedOut = true
                }
            }
        }

        participantListener = RoomService.shared.listenToParticipants(roomId: roomId) { updatedParticipants in
            Task { @MainActor in
                let sorted = updatedParticipants.sorted { $0.joinedAt < $1.joinedAt }
                self.participants = sorted
                if !sorted.isEmpty {
                    self.lastKnownParticipants = sorted
                }
                if let me = sorted.first(where: { $0.id == self.currentUserId }) {
                    self.myStatus = me.status
                    if let workName = me.workItemName, !workName.isEmpty {
                        self.selectedWorkItem = workName
                    }
                }
            }
        }
    }

    private func startLocalTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    self.nowTickDate = Date()
                    guard let room, room.isRunning else { return }
                    syncRemainingSeconds(with: room)
                }
            }
        }
    }

    private func syncRemainingSeconds(with room: RoomModel) {
        guard let endTimestamp = room.endTimestamp else {
            remainingSeconds = room.duration
            return
        }

        let secondsLeft = max(0, Int(ceil(endTimestamp.timeIntervalSinceNow)))
        remainingSeconds = secondsLeft

        if secondsLeft == 0 {
            saveLocalRoomSessionIfNeeded(room: room)
            timerTask?.cancel()
            endRoomIfNeeded()
            presentCompletedRoomAfterPortraitSettles()
        }
    }

    private func endRoomIfNeeded() {
        guard !didSendEndedStatus else { return }
        didSendEndedStatus = true

        Task {
            try? await RoomService.shared.endRoom(roomId: roomId)
        }
    }

    private func saveLocalRoomSessionIfNeeded(room: RoomModel) {
        guard !didSaveLocalSession else { return }
        didSaveLocalSession = true
        guard !allSessions.contains(where: { $0.roomId == room.id && $0.modeRawValue == FocusSessionMode.room.rawValue }) else {
            return
        }

        let activeSec = myParticipant?.currentActiveSeconds() ?? 0
        guard activeSec > 0 else { return }

        let trimmedSubject = (myParticipant?.workItemName ?? room.subject ?? "").normalizedWorkItemName()
        guard !trimmedSubject.isEmpty else {
            return
        }

        let endedAt = room.endedAt ?? room.endTimestamp ?? Date()
        let sharedStartedAt = room.endTimestamp?.addingTimeInterval(-TimeInterval(room.duration)) ?? room.createdAt
        let joinedAt = myParticipant?.joinedAt ?? sharedStartedAt
        let startedAt = joinedAt > sharedStartedAt ? joinedAt : sharedStartedAt

        let wasEarlyEnd = room.endedAt != nil && (room.endTimestamp == nil || room.endedAt! < room.endTimestamp!.addingTimeInterval(-10))
        let isCompletedNaturally = !wasEarlyEnd && activeSec >= max(1, room.duration - 10)
        let widgetTotal = todayTotalSeconds + activeSec

        if let existing = savedSubjects.first(where: { $0.name.normalizedWorkItemName().localizedCaseInsensitiveCompare(trimmedSubject) == .orderedSame }) {
            existing.name = trimmedSubject
            existing.lastUsedDate = Date()
            existing.updatedAt = Date()
            SyncService.shared.syncSubject(existing)
        }

        let session = FocusSession(
            durationSeconds: activeSec,
            completed: isCompletedNaturally,
            intentionNote: trimmedSubject,
            subject: trimmedSubject,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedDurationSeconds: room.duration,
            modeRawValue: FocusSessionMode.room.rawValue,
            roomId: room.id
        )

        modelContext.insert(session)
        try? modelContext.save()
        SyncService.shared.syncSession(session)

        WidgetDataService.shared.updateWidgetData(todayTotalSeconds: widgetTotal, mostUsedDurationSeconds: room.duration)
    }

    private func executeToggleMyStatus() {
        guard !isActionLoading else { return }
        isActionLoading = true
        HapticService.light()
        let nextStatus = (myStatus == "studying") ? "break" : "studying"
        myStatus = nextStatus

        Task {
            do {
                try await RoomService.shared.updateMyStatus(roomId: roomId, status: nextStatus)
                await MainActor.run {
                    self.inlineErrorMessage = nil
                    self.isActionLoading = false
                }
            } catch {
                await MainActor.run {
                    HapticService.error()
                    self.isActionLoading = false
                    self.inlineErrorMessage = appLanguage == "tr"
                        ? "Oda güncellenemedi. Bağlantını kontrol et."
                        : "The room could not be updated. Check your connection."
                }
            }
        }
    }

    private func executeLeaveRoom() {
        guard !isActionLoading else { return }
        isActionLoading = true

        Task {
            do {
                try await RoomService.shared.leaveRoom(roomId: roomId)
                await MainActor.run {
                    self.isActionLoading = false
                    self.didLeaveRoomExplicitly = true
                    self.activeRoomId = ""
                    self.dismissRoomTimerAfterPortraitSettles()
                }
            } catch {
                await MainActor.run {
                    HapticService.error()
                    self.isActionLoading = false
                    self.inlineErrorMessage = appLanguage == "tr"
                        ? "Odadan ayrılamadı. Bağlantını kontrol et."
                        : "Could not leave room. Check your connection."
                }
            }
        }
    }

    private func executeEndRoom() {
        guard !isActionLoading else { return }
        isActionLoading = true

        Task {
            do {
                try await RoomService.shared.endRoom(roomId: roomId)
                await MainActor.run {
                    self.isActionLoading = false
                    self.inlineErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    HapticService.error()
                    self.isActionLoading = false
                    self.inlineErrorMessage = appLanguage == "tr"
                        ? "Oda bitirilemedi. Bağlantını kontrol et."
                        : "The room could not be ended. Check your connection."
                }
            }
        }
    }

    private func toggleReady() {
        guard !isActionLoading else { return }
        isActionLoading = true
        HapticService.light()
        let nextReady = !isReady
        Task {
            do {
                try await RoomService.shared.updateMyReadyState(roomId: roomId, isReady: nextReady)
                await MainActor.run {
                    self.inlineErrorMessage = nil
                    self.isActionLoading = false
                }
            } catch {
                await MainActor.run {
                    HapticService.error()
                    self.isActionLoading = false
                    self.inlineErrorMessage = appLanguage == "tr"
                        ? "Oda güncellenemedi. Bağlantını kontrol et."
                        : "The room could not be updated. Check your connection."
                }
            }
        }
    }

    private func startRoom() {
        guard canStartRoom && !isActionLoading else { return }
        isActionLoading = true
        HapticService.success()
        Task {
            do {
                try await RoomService.shared.startRoom(roomId: roomId)
                await MainActor.run {
                    self.inlineErrorMessage = nil
                    self.isActionLoading = false
                }
            } catch {
                await MainActor.run {
                    HapticService.error()
                    self.isActionLoading = false
                    self.inlineErrorMessage = appLanguage == "tr"
                        ? "Oda güncellenemedi. Bağlantını kontrol et."
                        : "The room could not be updated. Check your connection."
                }
            }
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        ReportMetrics.formattedTime(seconds: seconds, lang: appLanguage)
    }

    private func formattedTimeBadge(seconds: Int) -> String {
        guard seconds > 0 else {
            return appLanguage == "tr" ? "0 dk" : "0m"
        }
        let mins = seconds / 60
        let secs = seconds % 60
        if mins == 0 {
            return appLanguage == "tr" ? "\(secs) sn" : "\(secs)s"
        } else {
            return appLanguage == "tr" ? "\(mins) dk" : "\(mins)m"
        }
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Y" }

        let parts = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(2)
            .compactMap { $0.first }

        let value = String(parts).uppercased()
        return value.isEmpty ? "Y" : value
    }

    private func handleCloseTap() {
        if isCompleted {
            activeRoomId = ""
            dismissRoomTimerAfterPortraitSettles()
        } else {
            showLeaveConfirmation = true
        }
    }

    private func presentCompletedRoomAfterPortraitSettles() {
        guard !isCompleted else { return }
        portraitTransitionTask?.cancel()
        OrientationLock.shared.lockPhonePortrait(roomOrientationReason)

        let shouldDelayForRotation = YonderPortraitTransition.shouldMask(verticalSizeClass: vSizeClass)
        withAnimation(.easeInOut(duration: 0.16)) {
            controlsVisible = false
            showPortraitTransitionMask = shouldDelayForRotation
        }

        portraitTransitionTask = Task {
            let delay = YonderPortraitTransition.delayNanoseconds(needsMask: shouldDelayForRotation)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                remainingSeconds = 0
                isCompleted = true
                withAnimation(.easeInOut(duration: 0.18)) {
                    showPortraitTransitionMask = false
                }
            }
        }
    }

    private func dismissRoomTimerAfterPortraitSettles() {
        portraitTransitionTask?.cancel()
        hideControlsTask?.cancel()
        OrientationLock.shared.lockPhonePortrait(roomOrientationReason)

        let shouldDelayForRotation = YonderPortraitTransition.shouldMask(verticalSizeClass: vSizeClass)
        withAnimation(.easeInOut(duration: 0.16)) {
            controlsVisible = false
            showPortraitTransitionMask = shouldDelayForRotation
        }

        portraitTransitionTask = Task {
            let delay = YonderPortraitTransition.delayNanoseconds(needsMask: shouldDelayForRotation)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                cleanUp()
                dismiss()
            }
        }
    }

    private func startLoadingTimeout() {
        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self.room == nil {
                    self.isRoomNotFoundOrTimedOut = true
                }
            }
        }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    controlsVisible = false
                }
            }
        }
    }

    private func cleanUp() {
        timerTask?.cancel()
        loadingTimeoutTask?.cancel()
        roomListener?.remove()
        participantListener?.remove()
        if !isCompleted && !didLeaveRoomExplicitly {
            Task {
                try? await RoomService.shared.leaveRoom(roomId: roomId)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RoomTimerView(roomId: "ABC123")
}
