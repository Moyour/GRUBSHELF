import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase
import GoogleSignIn

struct WelcomeView: View {
    @Bindable var authService: AuthenticationService
    @State private var showEmailAuth = false
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()

            // Branding
            Image(systemName: "leaf.fill")
                .font(.system(size: AppFont.emptyStateIconSize))
                .foregroundStyle(Color.primaryGreen)
                .accessibilityHidden(true)

            Text("FoodPan")
                .font(AppFont.largeTitle)
                .foregroundStyle(Color.primaryText)

            Text("Reduce waste. Save money. Simplify meals.")
                .font(AppFont.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.screenPadding)

            Spacer()

            // Sign In with Google
            Button {
                Task { await handleGoogleSignIn() }
            } label: {
                HStack(spacing: AppSpacing.mediumSpacing) {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("Continue with Google")
                        .font(AppFont.button)
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppSpacing.minTouchTarget)
                .background(Color.white)
                .foregroundStyle(Color.primaryText)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                        .stroke(Color.divider, lineWidth: 1)
                )
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            // Sign In with Apple
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
            .signInWithAppleButtonStyle(.black)
            .frame(height: AppSpacing.minTouchTarget)
            .padding(.horizontal, AppSpacing.screenPadding)

            // Email option
            Button {
                showEmailAuth = true
            } label: {
                Text("Continue with Email")
                    .font(AppFont.button)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.minTouchTarget)
                    .background(Color.cardBackground)
                    .foregroundStyle(Color.primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                            .stroke(Color.divider, lineWidth: 1)
                    )
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            if let error = authService.errorMessage {
                Text(error)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.errorRed)
                    .padding(.horizontal, AppSpacing.screenPadding)
            }

            #if DEBUG
            Button {
                Task { await devSignIn() }
            } label: {
                Text("Skip Sign In (Dev)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.top, AppSpacing.rowSpacing)
            #endif

            Spacer().frame(height: AppSpacing.sectionSpacing)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView(authService: authService)
        }
    }

    // MARK: - Dev Bypass

    #if DEBUG
    private func devSignIn() async {
        let email = "dev@foodpan.test"
        let password = "devpassword123!"
        let client = SupabaseManager.shared.client
        authService.errorMessage = nil
        authService.isLoading = true
        defer { authService.isLoading = false }

        // Step 1: Try sign-in (works if user exists and email is confirmed)
        if let session = try? await client.auth.signIn(email: email, password: password) {
            print("🔑 [DEV] Auth succeeded. user_id = \(session.user.id)")
            do {
                try await ensureDevUserAndHousehold(userId: session.user.id, email: email, client: client)
                print("🔑 [DEV] ensureDevUserAndHousehold OK. currentUser.userId = \(authService.currentUser?.userId.uuidString ?? "nil")")
                authService.isAuthenticated = true
                return
            } catch {
                print("🔑 [DEV] ensureDevUserAndHousehold FAILED: \(error)")
                authService.errorMessage = "Auth OK but DB setup failed: \(error.localizedDescription)"
                return
            }
        }

        // Step 2: Sign-in failed — clean up any broken auth user created by raw SQL,
        // then sign up through the proper Supabase Auth API.
        _ = try? await client.rpc("delete_dev_user").execute()

        do {
            let response = try await client.auth.signUp(email: email, password: password)

            if let session = response.session {
                try await ensureDevUserAndHousehold(userId: session.user.id, email: email, client: client)
                authService.isAuthenticated = true
                return
            }

            // No session → email confirmation is blocking. Try sign-in anyway.
            if let session = try? await client.auth.signIn(email: email, password: password) {
                try await ensureDevUserAndHousehold(userId: session.user.id, email: email, client: client)
                authService.isAuthenticated = true
                return
            }

            authService.errorMessage = "Email confirmation required.\nIn Supabase Dashboard → Authentication → Providers → Email, disable \"Confirm email\", then try again."
        } catch {
            authService.errorMessage = "Dev sign-in failed: \(error.localizedDescription)"
        }
    }

    private func ensureDevUserAndHousehold(userId: UUID, email: String, client: SupabaseClient) async throws {
        let existingUser: AppUser? = try? await client.from("users")
            .select()
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value

        if let user = existingUser, user.householdId != nil {
            authService.currentUser = user
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            return
        }

        let household = Household(
            householdId: UUID(),
            name: "Dev Household",
            planType: nil,
            createdAt: .now
        )
        try await client.from("households").insert(household).execute()

        let rows: [AppUser] = try await client.rpc("ensure_user_profile", params: [
            "p_user_id": userId.uuidString,
            "p_name": "Dev User",
            "p_email": email,
            "p_household_id": household.householdId.uuidString,
            "p_role": "admin",
        ]).execute().value

        guard let user = rows.first else {
            throw NSError(domain: "FoodPan", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create user row in database"
            ])
        }

        authService.currentUser = user
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    #endif

    // MARK: - Google Sign In

    private func handleGoogleSignIn() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            authService.errorMessage = "Unable to present sign in"
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                authService.errorMessage = "Invalid Google credential"
                return
            }
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
