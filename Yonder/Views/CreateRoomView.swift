//
//  CreateRoomView.swift
//  Yonder
//
//  Online room setup, room code sharing, and entry to RoomTimerView.
//

import SwiftUI

struct CreateRoomView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("active_room_id") private var activeRoomId: String = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var selectedHours: Int
    @State private var selectedMinutes: Int
    @State private var selectedSeconds: Int
    @State private var selectedWorkItem: String?
    @State private var showWorkItemPicker: Bool = false
    @State private var roomCode: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showRoomTimer: Bool = false
    @State private var isCopied: Bool = false

    init(durationInSeconds: Int, subject: String?) {
        let clampedDuration = max(0, min(12 * 60 * 60 + 59 * 60 + 59, durationInSeconds))
        _selectedHours = State(initialValue: clampedDuration / 3600)
        _selectedMinutes = State(initialValue: (clampedDuration % 3600) / 60)
        _selectedSeconds = State(initialValue: clampedDuration % 60)
        _selectedWorkItem = State(initialValue: subject?.normalizedWorkItemNameOrNil)
    }

    private var isIPad: Bool { horizontalSizeClass == .regular }
    private var isLandscapePhone: Bool { verticalSizeClass == .compact }
    private var hasCreatedRoom: Bool { !roomCode.isEmpty }

    private func makeLayout(_ width: CGFloat) -> YonderLayout { YonderLayout(screenWidth: width) }

    private var selectedDurationSeconds: Int {
        selectedHours * 3600 + selectedMinutes * 60 + selectedSeconds
    }

    private var canCreateRoom: Bool {
        selectedDurationSeconds > 0
    }

    private var fallbackRoomSubject: String {
        appLanguage == "tr" ? "Odak" : "Focus"
    }

    private var formattedDurationStr: String {
        ReportMetrics.formattedTime(seconds: selectedDurationSeconds, lang: appLanguage)
    }

    private var shareMessageText: String {
        let trimmedWork = selectedWorkItem?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if appLanguage == "tr" {
            if !trimmedWork.isEmpty {
                return "Yonder’da \(trimmedWork) için \(formattedDurationStr) online odama katıl: \(roomCode)"
            } else {
                return "Yonder’da \(formattedDurationStr) online odama katıl: \(roomCode)"
            }
        } else {
            if !trimmedWork.isEmpty {
                return "Join my \(formattedDurationStr) online room for \(trimmedWork) on Yonder: \(roomCode)"
            } else {
                return "Join my \(formattedDurationStr) online room on Yonder: \(roomCode)"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                LoadingIndicatorView(
                    message: appLanguage == "tr" ? "Online oda hazırlanıyor" : "Preparing online room",
                    onCancel: { isLoading = false }
                )
            } else if let error = errorMessage {
                errorView(error)
            } else if hasCreatedRoom {
                roomCodeView
            } else {
                setupView
            }
        }
        .sheet(isPresented: $showWorkItemPicker) {
            WorkItemPickerSheet(selectedWorkItem: $selectedWorkItem)
        }
        .fullScreenCover(isPresented: $showRoomTimer) {
            RoomTimerView(roomId: roomCode)
        }
        .preferredColorScheme(.dark)
    }

    private var setupView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                topDismissHeader

                if isLandscapePhone {
                    setupLandscapeLayout(availableWidth: geo.size.width)
                } else if makeLayout(geo.size.width).isWide {
                    setupWideLayout(availableWidth: geo.size.width)
                } else {
                    setupPortraitLayout(availableWidth: geo.size.width)
                }
            }
        }
    }

    private var topDismissHeader: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(Color(white: 0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)
            Spacer()
        }
    }

    private func setupWideLayout(availableWidth: CGFloat) -> some View {
        let layout = makeLayout(availableWidth)
        let hPad = layout.hPad
        let contentWidth = layout.contentWidth

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 12)

                setupHeader(layout: layout)
                    .padding(.bottom, 22)
                    .padding(.horizontal, hPad)

                HStack(alignment: .top, spacing: 32) {
                    durationComposerView(availableWidth: contentWidth * 0.52)
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)

                    Rectangle()
                        .fill(Color(white: 0.12))
                        .frame(width: 0.5)
                        .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 16) {
                        Spacer(minLength: 10)
                        workSetupField(availableWidth: contentWidth * 0.44)
                        createRoomButton(availableWidth: contentWidth * 0.44)
                    }
                    .frame(maxWidth: contentWidth * 0.42)
                }
                .padding(.horizontal, hPad)
                .padding(.bottom, 34)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func setupPortraitLayout(availableWidth: CGFloat) -> some View {
        let layout = makeLayout(availableWidth)
        let hPad = layout.hPad

        return VStack(spacing: 0) {
            Spacer(minLength: 8)

            setupHeader(layout: layout)
                .padding(.bottom, 8)

            Spacer(minLength: 0)

            durationComposerView(availableWidth: layout.contentWidth)
                .padding(.horizontal, hPad)
                .layoutPriority(1)

            Spacer(minLength: 0)

            VStack(spacing: layout.isMedium ? 14 : 10) {
                workSetupField(availableWidth: layout.contentWidth)
                createRoomButton(availableWidth: layout.contentWidth)
            }
            .padding(.horizontal, hPad)
            .padding(.bottom, layout.isMedium ? 28 : 20)
        }
    }

    private func setupLandscapeLayout(availableWidth: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            HStack(spacing: 20) {
                durationComposerView(availableWidth: availableWidth * 0.48)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("yonder")
                            .font(.system(size: 20, weight: .light, design: .rounded))
                            .foregroundStyle(Color(white: 0.6))
                            .tracking(6)
                            .textCase(.uppercase)

                        Text(appLanguage == "tr" ? "Online oda" : "Online room")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.35))
                    }

                    workSetupField(availableWidth: 300, isCompact: true)
                    createRoomButton(availableWidth: 300, isCompact: true)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func setupHeader(layout: YonderLayout) -> some View {
        VStack(spacing: 4) {
            Text("yonder")
                .font(.system(size: layout.isMedium ? 30 : 24, weight: .light, design: .rounded))
                .foregroundStyle(Color(white: 0.6))
                .tracking(6)
                .textCase(.uppercase)

            Text(appLanguage == "tr" ? "Online oda için süre ve çalışma seç" : "Choose duration and work area")
                .font(.system(size: layout.isMedium ? 14 : 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.35))
                .multilineTextAlignment(.center)
        }
    }

    private func workSetupField(availableWidth: CGFloat, isCompact: Bool = false) -> some View {
        Button {
            showWorkItemPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: isCompact ? 12 : 14, weight: .regular))
                    .foregroundStyle(Color(white: 0.45))

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedWorkItem?.nilIfEmpty ?? (appLanguage == "tr" ? "Ne çalışacaksın?" : "What will you focus on?"))
                        .font(.system(size: isCompact ? 12 : (isIPad ? 15 : 13), weight: selectedWorkItem?.nilIfEmpty == nil ? .regular : .semibold, design: .rounded))
                        .foregroundStyle(Color(white: selectedWorkItem?.nilIfEmpty == nil ? 0.45 : 0.88))
                        .lineLimit(1)

                    if !isCompact {
                        Text(appLanguage == "tr"
                             ? "Çalışma eklemek için Çalışmalarım’a git."
                             : "Go to My Work Areas to add a new one.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.38))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: isCompact ? 10 : 12))
                    .foregroundStyle(Color(white: 0.35))
            }
            .padding(.horizontal, isCompact ? 10 : 14)
            .frame(maxWidth: isCompact ? 300 : .infinity)
            .frame(height: isCompact ? 38 : (isIPad ? 48 : 44))
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 10 : 12)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 10 : 12)
                            .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func createRoomButton(availableWidth: CGFloat, isCompact: Bool = false) -> some View {
        let maxWidth = isCompact ? min(availableWidth, 300) : YonderLayout(screenWidth: availableWidth).ctaMaxWidth

        return Button {
            Task { await createRoom() }
        } label: {
            Text(appLanguage == "tr" ? "Online Oda Oluştur" : "Create Online Room")
                .font(.system(size: isCompact ? 14 : (isIPad ? 18 : 16), weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: maxWidth)
                .frame(height: isCompact ? 42 : (isIPad ? 54 : 48))
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: .white.opacity(0.15), radius: 8)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canCreateRoom)
        .opacity(canCreateRoom ? 1.0 : 0.35)
    }

    private var roomCodeView: some View {
        VStack(spacing: isIPad ? 34 : 24) {
            topCloseBar

            Spacer()

            VStack(spacing: 12) {
                Text(appLanguage == "tr" ? "ONLINE ODA HAZIR" : "ONLINE ROOM READY")
                    .font(.system(size: isIPad ? 18 : 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .textCase(.uppercase)
                    .tracking(3)

                Text(roomCode)
                    .font(.system(size: isIPad ? 60 : 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(8)
                    .padding(.vertical, isIPad ? 18 : 14)
                    .padding(.horizontal, isIPad ? 36 : 24)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color(white: 0.18), lineWidth: 0.5)
                            )
                    )

                setupSummaryPills

                Text(appLanguage == "tr"
                     ? "Arkadaşların bu kodla online odaya katılabilir."
                     : "Friends can join this online room with the code.")
                    .font(.system(size: isIPad ? 14 : 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.40))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }

            Spacer()

            HStack(spacing: 14) {
                ShareLink(
                    item: shareMessageText,
                    subject: Text(appLanguage == "tr" ? "Yonder Online Oda Kodu" : "Yonder Online Room Code"),
                    message: Text(shareMessageText)
                ) {
                    actionButtonLabel(icon: "square.and.arrow.up", title: appLanguage == "tr" ? "Kodu Paylaş" : "Share Code")
                }
                .buttonStyle(.plain)

                Button {
                    UIPasteboard.general.string = roomCode
                    HapticService.success()
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isCopied = false
                    }
                } label: {
                    actionButtonLabel(
                        icon: isCopied ? "checkmark" : "doc.on.doc",
                        title: isCopied ? (appLanguage == "tr" ? "Kopyalandı" : "Copied") : (appLanguage == "tr" ? "Kopyala" : "Copy"),
                        color: isCopied ? .green : Color(white: 0.85)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isIPad ? 80 : 32)

            Button {
                HapticService.light()
                showRoomTimer = true
            } label: {
                Text(appLanguage == "tr" ? "Odaya Gir" : "Enter Room")
                    .font(.system(size: isIPad ? 18 : 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: isIPad ? 54 : 48)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, isIPad ? 80 : 32)

            Spacer()
                .frame(height: 20)
        }
    }

    private var setupSummaryPills: some View {
        HStack(spacing: 8) {
            summaryPill(icon: "clock", text: formattedDurationStr)

            if let selectedWorkItem {
                summaryPill(icon: "square.and.pencil", text: selectedWorkItem)
            }

            summaryPill(
                icon: "checkmark.circle",
                text: appLanguage == "tr" ? "Herkes hazır olunca başlar" : "Starts when everyone is ready",
                subdued: true
            )
        }
        .padding(.top, 4)
    }

    private var topCloseBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
                    .padding(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
        .padding(.trailing, 16)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(white: 0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(white: 0.11), lineWidth: 0.6)
            )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: isIPad ? 12 : 10, weight: .medium, design: .rounded))
            .foregroundStyle(Color(white: 0.42))
            .tracking(2.4)
    }

    private func durationComposerView(availableWidth: CGFloat) -> some View {
        let clockHeight: CGFloat = isIPad ? 170 : 128

        return VStack(spacing: isIPad ? 17 : 14) {
            FlipClockView(
                hours: selectedHours,
                minutes: selectedMinutes,
                seconds: selectedSeconds,
                showHours: true,
                isRunning: false,
                animatesDigitChanges: false
            )
            .frame(maxWidth: .infinity)
            .frame(height: clockHeight)

            durationWheelView(availableWidth: availableWidth)
        }
    }

    private func durationWheelView(availableWidth: CGFloat) -> some View {
        let wheelHeight: CGFloat = isIPad ? 104 : 92
        let containerHeight: CGFloat = isIPad ? 134 : 118
        let spacing: CGFloat = isIPad ? 12 : 9

        return HStack(spacing: spacing) {
            durationWheelColumn(
                title: unitTitle(.hours),
                selection: $selectedHours,
                values: 0...12,
                wheelHeight: wheelHeight
            )

            durationWheelColumn(
                title: unitTitle(.minutes),
                selection: $selectedMinutes,
                values: 0...59,
                wheelHeight: wheelHeight
            )

            durationWheelColumn(
                title: unitTitle(.seconds),
                selection: $selectedSeconds,
                values: 0...59,
                wheelHeight: wheelHeight
            )
        }
        .frame(height: containerHeight)
    }

    private func durationWheelColumn(
        title: String,
        selection: Binding<Int>,
        values: ClosedRange<Int>,
        wheelHeight: CGFloat
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: isIPad ? 11 : 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.42))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Picker(title, selection: selection) {
                ForEach(Array(values), id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .font(.system(size: isIPad ? 23 : 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: wheelHeight)
            .clipped()
            .compositingGroup()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.075))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                    )
            )
        }
    }

    private func unitTitle(_ unit: TimeUnit) -> String {
        switch unit {
        case .hours:
            return appLanguage == "tr" ? "Saat" : "Hour"
        case .minutes:
            return appLanguage == "tr" ? "Dakika" : "Minute"
        case .seconds:
            return appLanguage == "tr" ? "Saniye" : "Second"
        }
    }

    private func summaryPill(icon: String, text: String, subdued: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: subdued ? 11 : 10))
            Text(text)
                .font(.system(size: subdued ? 11 : 12, weight: subdued ? .regular : .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(Color(white: subdued ? 0.50 : 0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(white: subdued ? 0.06 : 0.10))
                .overlay(Capsule().strokeBorder(Color(white: subdued ? 0.12 : 0.18), lineWidth: 0.5))
        )
    }

    private func actionButtonLabel(icon: String, title: String, color: Color = Color(white: 0.85)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
            Text(title)
        }
        .font(.system(size: isIPad ? 15 : 13, weight: .medium, design: .rounded))
        .foregroundStyle(color)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.10))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(white: 0.16), lineWidth: 0.5))
        )
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Text(error)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                errorMessage = nil
            } label: {
                Text(appLanguage == "tr" ? "Tekrar Dene" : "Try Again")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.15)))
            }
            .buttonStyle(.plain)
        }
    }

    private func createRoom() async {
        guard !isLoading, canCreateRoom else { return }
        let normalizedWorkItem = selectedWorkItem?.normalizedWorkItemNameOrNil
        let roomSubject = normalizedWorkItem ?? fallbackRoomSubject

        isLoading = true
        errorMessage = nil

        do {
            let (_, code) = try await RoomService.shared.createRoom(
                durationInSeconds: selectedDurationSeconds,
                subject: roomSubject,
                workItemName: normalizedWorkItem
            )
            roomCode = code
            activeRoomId = code
            isLoading = false
            HapticService.success()
        } catch {
            HapticService.error()
            errorMessage = appLanguage == "tr"
                ? "Online oda oluşturulamadı. Lütfen tekrar dene."
                : "Could not create online room. Please try again."
            isLoading = false
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    CreateRoomView(durationInSeconds: 1500, subject: "Matematik")
}
