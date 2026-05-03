import SwiftUI

struct EmailAuthView: View {
    @Bindable var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: AppSpacing.compactGap) {
                        BrandLogoMark(size: 48, cornerRadius: BrandLogoMark.iconCornerRadius(forSide: 48))
                        Text(BrandCopy.wordmark)
                            .font(BrandFont.semiBold(15))
                            .foregroundStyle(Color.gsBrandPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.smallSpacing)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if isSignUp {
                    Section("Name") {
                        TextField("Your name", text: $name)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }
                }

                Section("Credentials") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(BrandSymbolFont.symbol(17, weight: .regular))
                                .foregroundStyle(.gsTextSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isSignUp && !password.isEmpty {
                    Section {
                        PasswordStrengthBar(
                            level: passwordStrengthLevel,
                            label: passwordStrengthLabel,
                            color: passwordStrengthColor,
                            unmetRequirements: unmetPasswordRequirements
                        )
                    }
                }

                if let error = authService.errorMessage {
                    Section {
                        Text(error)
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsDanger)
                    }
                }

                Section {
                    Button {
                        Task {
                            if isSignUp {
                                await authService.signUp(email: email, password: password, name: name)
                            } else {
                                await authService.signIn(email: email, password: password)
                            }
                            if authService.isAuthenticated || authService.pendingVerificationEmail != nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if authService.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Create account" : "Sign in")
                                .font(BrandFont.semiBold(17))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(authService.isLoading || !isFormValid)
                }

                if !isSignUp {
                    Section {
                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Forgot password?")
                                .font(BrandFont.regular(14))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                Section {
                    Button {
                        isSignUp.toggle()
                        authService.errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                            .font(BrandFont.regular(14))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle(isSignUp ? "Create account" : "Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(authService: authService)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let emailValid = email.range(of: emailPattern, options: .regularExpression) != nil
        let passwordValid = isSignUp ? isPasswordStrong : password.count >= 6
        let nameValid = !isSignUp || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return emailValid && passwordValid && nameValid
    }

    private var hasSpecialCharacter: Bool {
        let specialCharacters = CharacterSet.alphanumerics.inverted
        return password.unicodeScalars.contains(where: { specialCharacters.contains($0) })
    }

    private var isPasswordStrong: Bool {
        password.count >= 8 &&
        password.contains(where: \.isUppercase) &&
        password.contains(where: \.isLowercase) &&
        password.contains(where: \.isNumber) &&
        hasSpecialCharacter
    }

    private var passwordStrengthLevel: Int {
        var level = 0
        if password.count >= 8 { level += 1 }
        if password.count >= 8 && password.contains(where: \.isUppercase) && password.contains(where: \.isLowercase) { level += 1 }
        if isPasswordStrong { level += 1 }
        return level
    }

    private var passwordStrengthLabel: String {
        switch passwordStrengthLevel {
        case 0: return "Weak"
        case 1: return "Weak"
        case 2: return "Medium"
        default: return "Strong"
        }
    }

    private var passwordStrengthColor: Color {
        switch passwordStrengthLevel {
        case 0, 1: return .gsTextSecondary
        case 2: return .gsTextSecondary
        default: return .gsBrandPrimary
        }
    }

    private var unmetPasswordRequirements: [String] {
        var reqs: [String] = []
        if password.count < 8 { reqs.append("At least 8 characters") }
        if !password.contains(where: \.isUppercase) { reqs.append("At least 1 uppercase letter") }
        if !password.contains(where: \.isLowercase) { reqs.append("At least 1 lowercase letter") }
        if !password.contains(where: \.isNumber) { reqs.append("At least 1 number") }
        if !hasSpecialCharacter { reqs.append("At least 1 special character (!@#$%...)") }
        return reqs
    }
}
