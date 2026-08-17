//
//  ProfileAvatarView.swift
//  Yonder
//

import SwiftUI

/// Circular avatar view implementing the 4-tier profile picture fallback hierarchy:
/// 1. Custom photo uploaded by user (`imageData`)
/// 2. Google account profile photo (`googlePhotoURL`)
/// 3. Initial letter monochrome circular placeholder (first letter of user's display name)
/// 4. Neutral monochrome circular placeholder (`person.fill` icon for anonymous users)
struct ProfileAvatarView: View {

    let imageData: Data?
    let googlePhotoURL: URL?
    let name: String?
    let size: CGFloat
    var showEditBadge: Bool = false

    /// Extracts the first letter of the display name for the letter placeholder.
    private var initialLetter: String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }
        return String(name.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color(white: 0.2), lineWidth: 0.8)
                )

            if showEditBadge {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.22))
                        .frame(width: max(18, size * 0.32), height: max(18, size * 0.32))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black, lineWidth: 1.5)
                        )

                    Image(systemName: "camera.fill")
                        .font(.system(size: max(9, size * 0.16)))
                        .foregroundStyle(Color(white: 0.9))
                }
                .offset(x: 2, y: 2)
            }
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let googlePhotoURL {
            AsyncImage(url: googlePhotoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.14))

            if let initialLetter {
                Text(initialLetter)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.85))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(Color(white: 0.45))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Initial letter placeholder
        ProfileAvatarView(imageData: nil, googlePhotoURL: nil, name: "Emir", size: 64, showEditBadge: true)

        // Anonymous placeholder
        ProfileAvatarView(imageData: nil, googlePhotoURL: nil, name: nil, size: 40)
    }
    .padding()
    .background(Color.black)
}
