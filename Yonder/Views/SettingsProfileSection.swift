//
//  SettingsProfileSection.swift
//  Yonder
//

import SwiftUI

/// Profile section row inside SettingsView displaying user avatar, name, email/status, and edit button.
struct SettingsProfileSection: View {

    let authService: AuthService
    let selectedLanguage: String
    let isIPad: Bool
    let onEditProfile: () -> Void

    var body: some View {
        Button(action: onEditProfile) {
            HStack(spacing: 16) {
                ProfileAvatarView(
                    imageData: authService.avatarImageData,
                    googlePhotoURL: authService.googlePhotoURL,
                    name: authService.displayName,
                    size: isIPad ? 64 : 54,
                    showEditBadge: false
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(authService.displayName ?? (selectedLanguage == "tr" ? "Yonder kullanıcısı" : "Yonder user"))
                        .font(.system(size: isIPad ? 17 : 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.9))

                    if let email = authService.linkedAccountEmail, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                    } else {
                        Text(selectedLanguage == "tr" ? "Yerel kullanım" : "Local use")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(white: 0.45))
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(white: 0.14))
                        .frame(width: 36, height: 36)

                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(white: 0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
