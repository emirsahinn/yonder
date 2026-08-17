//
//  SignInView.swift
//  Yonder
//
//  Optional Google & Apple Sign-In sheet, presented from SettingsView.
//  NOT shown as a mandatory launch screen.
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct SignInView: View {

    private enum LoadingProvider {
        case apple
        case google
    }

    var onSignedIn: () -> Void
    var onSkip: () -> Void

    @Environment(AuthService.self) private var authService
    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var loadingProvider: LoadingProvider? = nil
    @State private var errorMessage: String? = nil
    @State private var currentAppleNonce: String? = nil
    @State private var appleCoordinator = AppleSignInCoordinator()

    private var isIPad: Bool { hSizeClass == .regular }
    private var emblemScale: CGFloat { isIPad ? 1.4 : 1.0 }
    private var ctaMaxWidth: CGFloat? { isIPad ? 440 : nil }
    private var isLoading: Bool { loadingProvider != nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Skip button (top trailing) ─────────────────────────────
                HStack {
                    Spacer()
                    Button { onSkip() } label: {
                        Text(appLanguage == "tr" ? "Şimdilik geç" : "Skip for now")
                            .font(.system(size: isIPad ? 16 : 14, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(white: 0.38))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)

                Spacer()

                // ── Emblem + Brand ────────────────────────────────────────
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color(white: 0.15), lineWidth: 1)
                            .frame(width: 110, height: 110)

                        Image("SplashLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                    }
                    .frame(width: 110, height: 110)
                    .scaleEffect(emblemScale)
                    .frame(width: 110 * emblemScale, height: 110 * emblemScale)

                    Text("YONDER")
                        .font(.system(size: isIPad ? 16 : 14, weight: .light, design: .rounded))
                        .foregroundStyle(Color(white: 0.38))
                        .tracking(10)
                }

                Spacer().frame(height: isIPad ? 68 : 52)

                // ── Headline ──────────────────────────────────────────────
                VStack(spacing: 12) {
                    Text(appLanguage == "tr" ? "Ritmini koru" : "Keep your rhythm")
                        .font(.system(size: isIPad ? 30 : 24, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .tracking(0.5)

                    Text(appLanguage == "tr"
                         ? "Geçmişini saklamak ve sessiz odalara katılmak için hesabını bağlayabilirsin."
                         : "Connect your account to keep your history and join quiet rooms.")
                        .font(.system(size: isIPad ? 18 : 15, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.42))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, isIPad ? 100 : 44)
                        .lineSpacing(4)
                }
                .frame(maxWidth: isIPad ? 560 : .infinity)

                Spacer().frame(height: 48)

                // ── Error message ─────────────────────────────────────────
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: isIPad ? 15 : 13, design: .rounded))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 16)
                        .frame(maxWidth: isIPad ? 440 : .infinity)
                        .transition(.opacity)
                }

                VStack(spacing: 12) {
                    // ── Apple Button ──────────────────────────────────────────
                    Button {
                        triggerAppleSignIn()
                    } label: {
                        HStack(spacing: 12) {
                            if loadingProvider == .apple {
                                ProgressView()
                                    .tint(.black)
                                    .scaleEffect(0.85)
                                    .frame(width: 22, height: 22)
                            } else {
                                appleLogoIcon()
                            }

                            Text(appLanguage == "tr" ? "Apple ile devam et" : "Continue with Apple")
                                .font(.system(size: isIPad ? 17 : 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.13, green: 0.13, blue: 0.13))
                        }
                        .frame(maxWidth: ctaMaxWidth ?? .infinity)
                        .frame(height: isIPad ? 58 : 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                                .shadow(color: .white.opacity(0.08), radius: 8, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)

                    // ── Google Button ─────────────────────────────────────────
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            if loadingProvider == .google {
                                ProgressView()
                                    .tint(.black)
                                    .scaleEffect(0.85)
                                    .frame(width: 22, height: 22)
                            } else {
                                googleGIcon()
                            }

                            Text(appLanguage == "tr" ? "Google ile devam et" : "Continue with Google")
                                .font(.system(size: isIPad ? 17 : 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.13, green: 0.13, blue: 0.13))
                        }
                        .frame(maxWidth: ctaMaxWidth ?? .infinity)
                        .frame(height: isIPad ? 58 : 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                                .shadow(color: .white.opacity(0.08), radius: 8, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                .padding(.horizontal, 36)
                .animation(.easeInOut(duration: 0.2), value: isLoading)

                Spacer()

                // ── Privacy note ──────────────────────────────────────────
                Text(appLanguage == "tr"
                     ? "Dilersen hesabını bağlamadan yerel olarak devam edebilirsin."
                     : "You can continue locally without connecting an account.")
                    .font(.system(size: isIPad ? 13 : 11, design: .rounded))
                    .foregroundStyle(Color(white: 0.40))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                    .padding(.bottom, 32)
                    .padding(.bottom, 8) // extra buffer for home indicator safe area
            }
            .frame(maxWidth: .infinity)

            if isLoading {
                YonderTransitionOverlay(
                    message: appLanguage == "tr" ? "Ritmin hazırlanıyor" : "Preparing your rhythm",
                    onCancel: { loadingProvider = nil }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sign In Actions

    private func triggerAppleSignIn() {
        errorMessage = nil
        appleCoordinator.onCompletion = { result in
            signInWithApple(result)
        }
        appleCoordinator.performAppleSignIn { nonce in
            self.currentAppleNonce = nonce
        }
    }

    private func signInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            loadingProvider = .apple
            errorMessage = nil

            Task {
                do {
                    try await authService.signInWithApple(
                        authorization: authorization,
                        currentNonce: currentAppleNonce
                    )
                    await MainActor.run {
                        loadingProvider = nil
                        currentAppleNonce = nil
                        onSignedIn()
                    }
                } catch {
                    await MainActor.run {
                        loadingProvider = nil
                        currentAppleNonce = nil
                        print("[SignInView] Apple sign-in failed: \(error.localizedDescription)")
                        errorMessage = appleSignInErrorMessage(error)
                    }
                }
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                currentAppleNonce = nil
                return
            }
            currentAppleNonce = nil
            print("[SignInView] Apple authorization failed: \(error.localizedDescription)")
            errorMessage = appleSignInErrorMessage(error)
        }
    }

    private func appleSignInErrorMessage(_ error: Error) -> String {
        #if DEBUG
        return error.localizedDescription
        #else
        return appLanguage == "tr"
            ? "Apple ile giriş yapılamadı. Lütfen tekrar dene."
            : "Could not sign in with Apple. Please try again."
        #endif
    }

    private func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            errorMessage = String(localized: "signin_error_generic", defaultValue: "Bir hata oluştu. Lütfen tekrar dene.")
            return
        }

        loadingProvider = .google
        errorMessage = nil

        Task {
            do {
                try await authService.signInWithGoogle(presentingVC: rootVC)
                await MainActor.run {
                    loadingProvider = nil
                    onSignedIn()
                }
            } catch {
                await MainActor.run {
                    loadingProvider = nil
                    errorMessage = appLanguage == "tr"
                        ? "Google ile giriş yapılamadı. Lütfen tekrar dene."
                        : "Could not sign in with Google. Please try again."
                }
            }
        }
    }

    // MARK: - Icons

    @ViewBuilder
    private func appleLogoIcon() -> some View {
        Image(systemName: "applelogo")
            .font(.system(size: isIPad ? 19 : 17, weight: .semibold))
            .foregroundStyle(Color(red: 0.13, green: 0.13, blue: 0.13))
            .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private func googleGIcon() -> some View {
        ZStack {
            Text("G")
                .font(.system(size: isIPad ? 17 : 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Apple Sign-In Coordinator

@MainActor
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?

    func performAppleSignIn(currentNonce: @escaping (String) -> Void) {
        let nonce = AuthService.makeAppleNonce()
        currentNonce(nonce)

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AuthService.sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion?(.failure(error))
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Preview

#Preview {
    SignInView(onSignedIn: {}, onSkip: {})
}
