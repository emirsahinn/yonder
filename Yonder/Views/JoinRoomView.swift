//
//  JoinRoomView.swift
//  Yonder
//
//  Screen allowing the user to enter a 6-character room code to join an existing focus room.
//

import SwiftUI
import FirebaseAuth

/// Screen allowing the user to enter a 6-character room code to join an existing focus room.
struct JoinRoomView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("active_room_id") private var activeRoomId: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var codeInput: String = ""
    @State private var selectedWorkItem: String? = nil
    @State private var showWorkItemPicker: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var joinedRoomId: String? = nil
    @State private var showRoomTimer: Bool = false

    private var isIPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: isIPad ? 28 : 18) {
                    // Top close button
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

                    Spacer(minLength: isIPad ? 32 : 16)

                    // Header
                    VStack(spacing: 8) {
                        Text(appLanguage == "tr" ? "SESSİZ ODAYA KATIL" : "JOIN QUIET ROOM")
                            .font(.system(size: isIPad ? 22 : 16, weight: .light, design: .rounded))
                            .foregroundStyle(Color(white: 0.50))
                            .tracking(3)

                        Text(appLanguage == "tr" ? "Arkadaşının oda kodunu gir." : "Enter friend's room code.")
                            .font(.system(size: isIPad ? 16 : 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.40))
                    }

                    // Code Input Field
                    VStack(spacing: 12) {
                        TextField("", text: $codeInput, prompt: Text("XXXXXX").foregroundStyle(Color(white: 0.2)))
                            .font(.system(size: isIPad ? 40 : 32, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .frame(height: isIPad ? 72 : 60)
                            .frame(maxWidth: isIPad ? 360 : 280)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(white: 0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(
                                                codeInput.count == 6 ? Color.white : Color(white: 0.18),
                                                lineWidth: codeInput.count == 6 ? 1.0 : 0.5
                                            )
                                    )
                            )
                            .onChange(of: codeInput) { oldValue, newValue in
                                let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                                if filtered.count > 6 {
                                    codeInput = String(filtered.prefix(6))
                                } else {
                                    codeInput = filtered
                                }
                                if filtered.count == 6 && oldValue.count != 6 {
                                    HapticService.light()
                                }
                                if errorMessage != nil {
                                    errorMessage = nil
                                }
                            }

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .transition(.opacity)
                        } else if !codeInput.isEmpty && codeInput.count < 6 {
                            Text(appLanguage == "tr" ? "6 karakterli oda kodunu gir." : "Enter the 6-character room code.")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(white: 0.40))
                                .transition(.opacity)
                        } else {
                            Text(appLanguage == "tr" ? "Oda başladıysa kalan süreyle katılırsın." : "If the room has started, you’ll join with the remaining time.")
                                .font(.system(size: isIPad ? 13 : 11, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(white: 0.38))
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        }
                    }

                    // Work Area Selection Field
                    workSetupField

                    Spacer(minLength: isIPad ? 32 : 16)

                    // Join Button
                    Button {
                        joinRoom()
                    } label: {
                        HStack {
                            Text(appLanguage == "tr" ? "Odaya Katıl" : "Join Room")
                                .font(.system(size: isIPad ? 18 : 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 54 : 48)
                        .background(
                            Capsule()
                                .fill(.white)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(codeInput.count < 6 || isLoading)
                    .opacity(codeInput.count < 6 || isLoading ? 0.35 : 1.0)
                    .padding(.horizontal, isIPad ? 80 : 36)

                    Spacer(minLength: 24)
                }
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            if isLoading {
                LoadingIndicatorView(
                    message: appLanguage == "tr" ? "Odaya bağlanıyor" : "Joining room",
                    onCancel: { isLoading = false }
                )
            }
        }
        .sheet(isPresented: $showWorkItemPicker) {
            WorkItemPickerSheet(selectedWorkItem: $selectedWorkItem)
        }
        .fullScreenCover(isPresented: $showRoomTimer) {
            if let roomId = joinedRoomId {
                RoomTimerView(roomId: roomId)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var workSetupField: some View {
        Button {
            showWorkItemPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: isIPad ? 15 : 13))
                    .foregroundStyle(Color(white: 0.45))

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedWorkItem?.nilIfEmpty ?? (appLanguage == "tr" ? "Çalışma alanı seç (Opsiyonel)" : "Choose work area (Optional)"))
                        .font(.system(size: isIPad ? 15 : 13, weight: selectedWorkItem?.nilIfEmpty == nil ? .regular : .semibold, design: .rounded))
                        .foregroundStyle(Color(white: selectedWorkItem?.nilIfEmpty == nil ? 0.45 : 0.88))
                        .lineLimit(1)

                    Text(appLanguage == "tr"
                         ? "Oda içinde de çalışma değiştirebilirsin."
                         : "You can also change work inside the room.")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.38))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.35))
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: isIPad ? 360 : 280)
            .frame(height: isIPad ? 52 : 44)
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
    }

    private func joinRoom() {
        guard codeInput.count == 6 else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let roomId = try await RoomService.shared.joinRoom(
                    code: codeInput,
                    workItemName: selectedWorkItem?.normalizedWorkItemNameOrNil
                )
                await MainActor.run {
                    HapticService.success()
                    self.joinedRoomId = roomId
                    self.activeRoomId = roomId
                    self.isLoading = false
                    self.showRoomTimer = true
                }
            } catch {
                let nsError = error as NSError
                await MainActor.run {
                    HapticService.error()
                    if nsError.code == 401 {
                        self.errorMessage = appLanguage == "tr"
                            ? "Odaya katılmak için giriş yapman gerekiyor."
                            : "You need to sign in to join a room."
                    } else if nsError.code == 410 {
                        self.errorMessage = appLanguage == "tr"
                            ? "Bu oda sona ermiş."
                            : "This room has ended."
                    } else {
                        self.errorMessage = appLanguage == "tr"
                            ? "Bu oda bulunamadı veya sona ermiş."
                            : "This room was not found or has ended."
                    }
                    self.isLoading = false
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Preview

#Preview {
    JoinRoomView()
}
