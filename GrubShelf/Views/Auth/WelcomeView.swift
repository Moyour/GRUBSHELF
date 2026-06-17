import SwiftUI
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct WelcomeView: View {
    @Bindable var authService: AuthenticationService
    @State private var showEmailAuth = false
    @State private var showForgotPassword = false
    @State private var currentNonce: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()

            // Branding — rounded mark + product name (no tagline)
            VStack(spacing: AppSpacing.mediumSpacing) {
                BrandLogoMark(size: 88, cornerRadius: BrandLogoMark.iconCornerRadius(forSide: 88))
                Text(BrandCopy.wordmark)
                    .font(BrandFont.bold(30))
                    .foregroundStyle(Color.gsBrandPrimary)
            }

            Spacer()

            VStack(spacing: AppSpacing.smallSpacing) {
                EmptyStateTealCTAButton(title: "Continue with Google", systemImage: nil) {
                    Task { await handleGoogleSignIn() }
                }

                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    Task { @MainActor in
                        handleAppleSignIn(result)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: AppSpacing.minTouchTarget)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))

                Button {
                    showEmailAuth = true
                } label: {
                    Text("Continue with email")
                        .font(BrandFont.semiBold(17))
                        .foregroundStyle(Color.gsBrandPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                        .background(Color.gsBrandPrimaryBg.opacity(colorScheme == .dark ? 0.28 : 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous)
                                .strokeBorder(Color.gsBrandPrimary.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    showForgotPassword = true
                } label: {
                    Text("Forgot password?")
                        .font(BrandFont.regular(15))
                        .foregroundStyle(Color.gsBrandPrimary)
                }
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.compactGap)
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .frame(maxWidth: .infinity)

            HStack(spacing: AppSpacing.denseSpacing) {
                Image(systemName: "lock.shield.fill")
                    .font(BrandSymbolFont.symbol(13))
                    .foregroundStyle(.gsTextSecondary)
                Text("Your data stays private. We never sell it.")
                    .font(BrandFont.regular(13))
                    .foregroundStyle(.gsTextSecondary)
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            if let error = authService.errorMessage {
                Text(error)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsDanger)
                    .padding(.horizontal, AppSpacing.screenPadding)
            }

            Spacer().frame(height: AppSpacing.sectionSpacing)
        }
        .background(.gsBackground)
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView(authService: authService)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(authService: authService)
        }
    }

    // MARK: - Google Sign In

    @MainActor
    private func handleGoogleSignIn() async {
        if GIDSignIn.sharedInstance.configuration == nil {
            _ = GoogleSignInSupport.configureFromAppConfig()
        }
        guard GIDSignIn.sharedInstance.configuration != nil else {
            authService.errorMessage = GoogleSignInSupport.configurationErrorMessage
            return
        }

        guard let presentingViewController = GoogleSignInSupport.viewControllerForSignIn() else {
            authService.errorMessage = "Unable to present sign in"
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                authService.errorMessage = "Invalid Google credential"
                return
            }
            GoogleSignInTrace.logIDTokenClaims(idToken)
            let accessToken = result.user.accessToken.tokenString

            await authService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn", nsError.code == -5 {
                // User cancelled
                return
            }
            authService.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Apple Sign In Helpers

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                authService.errorMessage = "Invalid Apple credential"
                return
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                authService.errorMessage = "Invalid Apple identity token"
                return
            }
            guard let nonce = currentNonce else {
                authService.errorMessage = "Sign in failed. Please try again."
                return
            }

            let fullName = formatAppleFullName(credential.fullName)
            Task { await authService.signInWithApple(idToken: idToken, nonce: nonce, fullName: fullName) }

        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                // User cancelled — don't show error
                return
            }
            authService.errorMessage = error.localizedDescription
        }
    }

    private func formatAppleFullName(_ fullName: PersonNameComponents?) -> String? {
        guard let fullName else { return nil }
        var parts: [String] = []
        if let given = fullName.givenName { parts.append(given) }
        if let middle = fullName.middleName { parts.append(middle) }
        if let family = fullName.familyName { parts.append(family) }
        let name = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
