//
//  ProfileEditSheet.swift
//  Yonder
//

import SwiftUI
import PhotosUI

/// Modal sheet for editing user profile (display name & avatar photo).
/// All changes remain isolated in draft state until explicitly confirmed with "Kaydet".
struct ProfileEditSheet: View {

    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("app_language") private var appLanguage: String = "en"

    private var isIPad: Bool { hSizeClass == .regular }

    @State private var draftName: String = ""
    @State private var draftAvatarData: Data? = nil
    @State private var isPhotoRemoved: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showErrorAlert: Bool = false
    @State private var isSaving: Bool = false

    /// Evaluates the avatar data to preview based on draft changes.
    private var currentAvatarData: Data? {
        if isPhotoRemoved {
            return nil
        }
        return draftAvatarData
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // ── Subtitle ──────────────────────────────────
                        Text(appLanguage == "tr" ? "Sessiz odalarda bu ad görünür." : "This name appears in quiet rooms.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)

                        // ── Avatar preview + PhotosPicker ─────────────
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ProfileAvatarView(
                                    imageData: currentAvatarData,
                                    googlePhotoURL: authService.googlePhotoURL,
                                    name: draftName.isEmpty ? (appLanguage == "tr" ? "Yonder kullanıcısı" : "Yonder user") : draftName,
                                    size: isIPad ? 112 : 84,
                                    showEditBadge: true
                                )
                            }
                            .buttonStyle(.plain)
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data),
                                       let compressedData = ImageCompressor.compress(image: uiImage, maxDimension: 500) {
                                        await MainActor.run {
                                            draftAvatarData = compressedData
                                            isPhotoRemoved = false
                                        }
                                    }
                                }
                            }

                            HStack(spacing: 16) {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Text(appLanguage == "tr" ? "Fotoğrafı değiştir" : "Change photo")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color(white: 0.8))
                                }
                                .buttonStyle(.plain)

                                if currentAvatarData != nil || authService.googlePhotoURL != nil {
                                    Button {
                                        isPhotoRemoved = true
                                        draftAvatarData = nil
                                    } label: {
                                        Text(appLanguage == "tr" ? "Fotoğrafı kaldır" : "Remove photo")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.red.opacity(0.85))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // ── Display Name Field ─────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text(appLanguage == "tr" ? "Adın" : "Your name")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.45))
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .padding(.leading, 4)

                            HStack {
                                TextField(
                                    appLanguage == "tr" ? "Adın" : "Your name",
                                    text: $draftName
                                )
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.95))
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()

                                Image(systemName: "pencil")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(white: 0.35))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(white: 0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                                    )
                            )
                        }
                        .padding(.horizontal, isIPad ? 60 : 20)
                        .padding(.bottom, 32)
                    }
                    .frame(maxWidth: isIPad ? 520 : .infinity)
                }

                if isSaving {
                    YonderTransitionOverlay(message: appLanguage == "tr" ? "Profil kaydediliyor" : "Saving profile")
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isSaving)
            .navigationTitle(appLanguage == "tr" ? "Profil" : "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appLanguage == "tr" ? "Vazgeç" : "Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color(white: 0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appLanguage == "tr" ? "Kaydet" : "Save") {
                        saveChanges()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                }
            }
            .alert(
                appLanguage == "tr" ? "Profil güncellenemedi." : "Profile could not be updated.",
                isPresented: $showErrorAlert
            ) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                draftName = authService.displayName ?? ""
                draftAvatarData = authService.avatarImageData
                isPhotoRemoved = false
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveChanges() {
        isSaving = true
        Task {
            await YonderTransitionHelper.withMinimumDuration(seconds: 0.45) {
                authService.updateDisplayName(draftName)

                if isPhotoRemoved {
                    authService.updateAvatarImageData(nil)
                } else if let draftAvatarData, draftAvatarData != authService.avatarImageData {
                    authService.updateAvatarImageData(draftAvatarData)
                }
            }
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileEditSheet()
}
