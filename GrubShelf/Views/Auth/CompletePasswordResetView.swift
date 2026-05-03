import SwiftUI

/// Shown after the user opens the password-reset link from email (Supabase establishes a recovery session via the deep link).
struct CompletePasswordResetView: View {
    @Bindable var authService: AuthenticationService
    @State private var newPassword = ""
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: AppSpacing.compactGap) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 36))
                            .foregroundStyle(.gsBrandPrimary)
                        Text("Choose a new password")
                            .font(BrandFont.semiBold(20))
                            .foregroundStyle(.gsTextPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.smallSpacing)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    Text(
                        "Your email link was verified. Enter a strong password to finish resetting your account."
                    )
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("New password") {
                    HStack {
                        if showPassword {
                            TextField("New password", text: $newPassword)
                                .textContentType(.newPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("New password", text: $newPassword)
                                .textContentType(.newPassword)
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

                if !newPassword.isEmpty {
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
                        Task { await authService.submitNewPasswordAfterReset(password: newPassword) }
                    } label: {
                        if authService.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Update password")
                                .font(BrandFont.semiBold(17))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(authService.isLoading || !isPasswordStrong)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Task { await authService.abandonPasswordResetAfterLinkFlow() }
                    }
                }
            }
        }
    }

    private var hasSpecialCharacter: Bool {
        let specialCharacters = CharacterSet.alphanumerics.inverted
        return newPassword.unicodeScalars.contains(where: { specialCharacters.contains($0) })
    }

    private var isPasswordStrong: Bool {
        newPassword.count >= 8 &&
            newPassword.contains(where: \.isUppercase) &&
            newPassword.contains(where: \.isLowercase) &&
            newPassword.contains(where: \.isNumber) &&
            hasSpecialCharacter
    }

    private var passwordStrengthLevel: Int {
        var level = 0
        if newPassword.count >= 8 { level += 1 }
        if newPassword.count >= 8 && newPassword.contains(where: \.isUppercase) && newPassword.contains(where: \.isLowercase) {
            level += 1
        }
        if isPasswordStrong { level += 1 }
        return level
    }

    private var passwordStrengthLabel: String {
        switch passwordStrengthLevel {
        case 0, 1: return "Weak"
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
        if newPassword.count < 8 { reqs.append("At least 8 characters") }
        if !newPassword.contains(where: \.isUppercase) { reqs.append("At least 1 uppercase letter") }
        if !newPassword.contains(where: \.isLowercase) { reqs.append("At least 1 lowercase letter") }
        if !newPassword.contains(where: \.isNumber) { reqs.append("At least 1 number") }
        if !hasSpecialCharacter { reqs.append("At least 1 special character (!@#$%...)") }
        return reqs
    }
}
