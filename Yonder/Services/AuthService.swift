//
//  AuthService.swift
//  Yonder
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import Security

/// Manages Firebase Authentication — anonymous by default, optional Google/Apple linking.
@Observable
final class AuthService {

    static let shared = AuthService()

    // MARK: - State

    /// Current authenticated user ID (if signed in).
    private(set) var currentUserId: String?

    /// Whether authentication is complete (anonymous OR Google).
    private(set) var isSignedIn: Bool = false

    /// Whether the current user has linked a Google account.
    private(set) var isGoogleLinked: Bool = false

    /// Whether the current user has linked an Apple account.
    private(set) var isAppleLinked: Bool = false

    /// Whether the current user has linked any cloud account.
    var isCloudAccountLinked: Bool {
        isGoogleLinked || isAppleLinked
    }

    /// E-mail of the linked Google account (nil if anonymous).
    private(set) var googleEmail: String?

    /// E-mail of the linked Apple account (nil if anonymous).
    private(set) var appleEmail: String?

    /// E-mail of the currently linked cloud account.
    var linkedAccountEmail: String? {
        googleEmail ?? appleEmail
    }

    /// Short display name for the connected provider.
    var linkedProviderName: String {
        if isGoogleLinked { return "Google" }
        if isAppleLinked { return "Apple" }
        return "Yonder"
    }

    /// Display name of the linked Google account (internal storage).
    private(set) var googleDisplayName: String? = UserDefaults.standard.string(forKey: "google_user_display_name") {
        didSet {
            if let name = googleDisplayName {
                UserDefaults.standard.set(name, forKey: "google_user_display_name")
            } else {
                UserDefaults.standard.removeObject(forKey: "google_user_display_name")
            }
        }
    }

    /// Custom display name entered by the user (overrides Google display name if present).
    private(set) var customDisplayName: String? = UserDefaults.standard.string(forKey: "custom_user_display_name") {
        didSet {
            if let name = customDisplayName, !name.isEmpty {
                UserDefaults.standard.set(name, forKey: "custom_user_display_name")
            } else {
                UserDefaults.standard.removeObject(forKey: "custom_user_display_name")
            }
        }
    }

    /// Effective display name for the user (custom name if available, otherwise Google display name).
    var displayName: String? {
        if let custom = customDisplayName, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom
        }
        return googleDisplayName
    }

    /// First name of the user (used for personalized greetings).
    var userFirstName: String? {
        if let name = displayName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").first
        }
        return nil
    }

    /// Custom avatar image data (uploaded by user) stored locally.
    private(set) var avatarImageData: Data? = loadStoredAvatarData()

    /// Google account profile picture URL.
    private(set) var googlePhotoURL: URL?

    // MARK: - Avatar Storage Helpers

    private static var avatarFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("custom_avatar.jpg")
    }

    private static func loadStoredAvatarData() -> Data? {
        try? Data(contentsOf: avatarFileURL)
    }

    /// Updates the local user display name.
    func updateDisplayName(_ newName: String?) {
        let trimmed = newName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed = trimmed, !trimmed.isEmpty {
            customDisplayName = trimmed
        } else {
            customDisplayName = nil
        }
    }

    /// Updates the custom avatar image data and saves it locally to disk.
    func updateAvatarImageData(_ data: Data?) {
        avatarImageData = data
        if let data = data {
            try? data.write(to: Self.avatarFileURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: Self.avatarFileURL)
        }
    }

    // MARK: - Init

    private init() {
        listenToAuthChanges()
        restoreGoogleSignIn()
    }

    // MARK: - Anonymous Auth

    /// Ensures a Firebase user exists (anonymous fallback).
    func ensureSignedIn() {
        if let user = Auth.auth().currentUser {
            currentUserId = user.uid
            isSignedIn = true
            refreshGoogleState(user: user)
            return
        }
        signInAnonymously()
    }

    /// Async variant used by SplashView (waits up to 4 s).
    @MainActor
    func ensureSignedInAsync() async {
        ensureSignedIn()
        if isSignedIn { return }

        let startTime = Date()
        while !isSignedIn && Date().timeIntervalSince(startTime) < 4.0 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - Google Sign-In

    /// Links the current anonymous user to a Google credential.
    /// If the credential is already in use by another account, falls back to full sign-in.
    @MainActor
    func signInWithGoogle(presentingVC: UIViewController) async throws {
        // 1. Trigger Google OAuth flow
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingIDToken
        }

        let gFullName = result.user.profile?.name
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        var finalUser: User?

        // 2. Try to link anonymous account → Google
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            do {
                let linkResult = try await currentUser.link(with: credential)
                finalUser = linkResult.user
                print("[AuthService] Anonymous → Google linked successfully. uid=\(linkResult.user.uid)")
            } catch let linkError as NSError where linkError.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                // Credential belongs to an existing account → sign in directly
                let signInResult = try await Auth.auth().signIn(with: credential)
                finalUser = signInResult.user
                print("[AuthService] Signed in to existing Google account. uid=\(signInResult.user.uid)")
            }
        } else {
            // No anonymous user — plain sign-in
            let signInResult = try await Auth.auth().signIn(with: credential)
            finalUser = signInResult.user
        }

        if let user = finalUser {
            // Update Firebase User profile display name if missing
            if (user.displayName == nil || user.displayName?.isEmpty == true), let fullName = gFullName {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = fullName
                try? await changeRequest.commitChanges()
            }

            let resolvedName = gFullName ?? user.displayName ?? user.providerData.first?.displayName
            let resolvedPhotoURL = user.photoURL ?? GIDSignIn.sharedInstance.currentUser?.profile?.imageURL(withDimension: 300)

            self.currentUserId = user.uid
            self.isSignedIn = true
            self.isGoogleLinked = true
            self.isAppleLinked = user.providerData.contains { $0.providerID == "apple.com" }
            self.googleEmail = user.email
            self.appleEmail = self.isAppleLinked ? user.email : nil
            self.googleDisplayName = resolvedName
            self.googlePhotoURL = resolvedPhotoURL
        }
    }

    // MARK: - Sign in with Apple

    static func makeAppleNonce() -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = 32

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate Apple sign-in nonce.")
            }

            for random in randoms where remainingLength > 0 {
                if Int(random) < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    /// Links the current anonymous user to Apple, or signs into an existing Apple-linked Firebase user.
    @MainActor
    func signInWithApple(authorization: ASAuthorization, currentNonce: String?) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidAppleCredential
        }
        guard let nonce = currentNonce else {
            throw AuthError.missingNonce
        }
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.missingAppleIDToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        var finalUser: User?

        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            do {
                let linkResult = try await currentUser.link(with: credential)
                finalUser = linkResult.user
                print("[AuthService] Anonymous → Apple linked successfully. uid=\(linkResult.user.uid)")
            } catch {
                let nsError = error as NSError
                print("[AuthService] Apple link failed: code=\(nsError.code), message=\(error.localizedDescription)")

                if shouldFallbackToAppleSignIn(after: nsError) {
                    let signInCredential = updatedCredential(from: nsError) ?? credential
                    let signInResult = try await Auth.auth().signIn(with: signInCredential)
                    finalUser = signInResult.user
                    print("[AuthService] Signed in to existing Apple account. uid=\(signInResult.user.uid)")
                } else {
                    throw error
                }
            }
        } else {
            do {
                let signInResult = try await Auth.auth().signIn(with: credential)
                finalUser = signInResult.user
            } catch {
                print("[AuthService] Apple sign-in failed: \(error.localizedDescription)")
                throw error
            }
        }

        if let user = finalUser {
            let formatter = PersonNameComponentsFormatter()
            let appleFullName = appleIDCredential.fullName.flatMap { components -> String? in
                let name = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : name
            }

            if (user.displayName == nil || user.displayName?.isEmpty == true), let appleFullName {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = appleFullName
                try? await changeRequest.commitChanges()
            }

            let resolvedName = appleFullName ?? user.displayName ?? user.providerData.first?.displayName
            let resolvedEmail = user.email ?? appleIDCredential.email

            self.currentUserId = user.uid
            self.isSignedIn = true
            self.isGoogleLinked = user.providerData.contains { $0.providerID == GoogleAuthProvider.id }
            self.isAppleLinked = true
            self.googleEmail = self.isGoogleLinked ? user.email : nil
            self.appleEmail = resolvedEmail
            self.googleDisplayName = resolvedName
            self.googlePhotoURL = user.photoURL
        }
    }

    private func shouldFallbackToAppleSignIn(after error: NSError) -> Bool {
        error.code == AuthErrorCode.credentialAlreadyInUse.rawValue ||
        error.code == AuthErrorCode.providerAlreadyLinked.rawValue ||
        error.localizedDescription.localizedCaseInsensitiveContains("duplicate credential")
    }

    private func updatedCredential(from error: NSError) -> AuthCredential? {
        error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
    }

    // MARK: - Sign Out

    /// Signs out and returns to anonymous authentication.
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
            currentUserId = nil
            isSignedIn = false
            isGoogleLinked = false
            isAppleLinked = false
            googleEmail = nil
            appleEmail = nil
            googleDisplayName = nil
            customDisplayName = nil
            googlePhotoURL = nil
            updateAvatarImageData(nil)
            Task { @MainActor in
                SubjectRealtimeSyncService.shared.stop()
            }
            ensureSignedIn()
        } catch {
            print("[AuthService] Error signing out: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func restoreGoogleSignIn() {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                if let profile = user?.profile {
                    Task { @MainActor [weak self] in
                        let name = profile.name
                        if !name.isEmpty {
                            self?.googleDisplayName = name
                        }
                        let photoURL = profile.imageURL(withDimension: 300)
                        if let photoURL = photoURL {
                            self?.googlePhotoURL = photoURL
                        }
                    }
                }
            }
        }
    }

    private func listenToAuthChanges() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                if let user = user {
                    self?.currentUserId = user.uid
                    self?.isSignedIn = true
                    self?.refreshGoogleState(user: user)
                } else {
                    self?.currentUserId = nil
                    self?.isSignedIn = false
                    self?.isGoogleLinked = false
                    self?.isAppleLinked = false
                    self?.googleEmail = nil
                    self?.appleEmail = nil
                    self?.googleDisplayName = nil
                    self?.customDisplayName = nil
                    self?.googlePhotoURL = nil
                    self?.updateAvatarImageData(nil)
                }
            }
        }
    }

    private func refreshGoogleState(user: User) {
        let googleProvider = user.providerData.first(where: { $0.providerID == GoogleAuthProvider.id })
        let appleProvider = user.providerData.first(where: { $0.providerID == "apple.com" })
        isGoogleLinked = googleProvider != nil
        isAppleLinked = appleProvider != nil
        googleEmail = isGoogleLinked ? (googleProvider?.email ?? user.email) : nil
        appleEmail = isAppleLinked ? (appleProvider?.email ?? user.email) : nil

        if isCloudAccountLinked {
            let name = googleProvider?.displayName ?? appleProvider?.displayName ?? user.displayName ?? GIDSignIn.sharedInstance.currentUser?.profile?.name
            if let name = name, !name.isEmpty {
                self.googleDisplayName = name
            }
            let photo = user.photoURL ?? googleProvider?.photoURL ?? GIDSignIn.sharedInstance.currentUser?.profile?.imageURL(withDimension: 300)
            self.googlePhotoURL = photo
        } else {
            self.googleDisplayName = nil
            self.googlePhotoURL = nil
        }
    }

    private func signInAnonymously() {
        Auth.auth().signInAnonymously { [weak self] authResult, error in
            Task { @MainActor in
                if let error = error {
                    print("[AuthService] Error signing in anonymously: \(error.localizedDescription)")
                    return
                }
                if let user = authResult?.user {
                    self?.currentUserId = user.uid
                    self?.isSignedIn = true
                    self?.isGoogleLinked = false
                    self?.isAppleLinked = false
                    self?.googleEmail = nil
                    self?.appleEmail = nil
                    print("[AuthService] Signed in anonymously with UID: \(user.uid)")
                }
            }
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case missingIDToken
    case missingAppleIDToken
    case missingNonce
    case invalidAppleCredential

    var errorDescription: String? {
        switch self {
        case .missingIDToken: return "Google ID token could not be retrieved."
        case .missingAppleIDToken: return "Apple ID token could not be retrieved."
        case .missingNonce: return "Apple sign-in nonce is missing."
        case .invalidAppleCredential: return "Apple credential could not be read."
        }
    }
}
