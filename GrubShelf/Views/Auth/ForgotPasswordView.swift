import SwiftUI

struct ForgotPasswordView: View {
    @Bindable var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: AppSpacing.compactGap) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.gsBrandPrimary)
                        Text("Reset password")
                            .font(BrandFont.semiBold(20))
                            .foregroundStyle(.gsTextPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.smallSpacing)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                        Text("We will email you a 6-digit code. Enter it in the app to choose a new password.")
                        
                        Text("Note: If you signed in with Apple or Google, please use that button instead. Password reset is only for email accounts.")
                            .font(BrandFont.regular(13))
                            .foregroundStyle(.gsTextSecondary)
                            .padding(.top, 4)
                    }
                }

                if let error = authService.errorMessage {
                    Section {
                        // Check if this is an OAuth provider message (Apple/Google)
                        if error.contains("Apple") || error.contains("Google") {
                            VStack(alignment: .leading, spacing: AppSpacing.compactGap) {
                                HStack(alignment: .top, spacing: AppSpacing.compactGap) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(BrandPalette.Status.info)
                                        .font(.system(size: 20))
                                    Text(error)
                                        .font(BrandFont.regular(14))
                                        .foregroundStyle(.gsTextPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(AppSpacing.mediumSpacing)
                                .background(BrandPalette.Status.info.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
                            }
                        } else {
                            Text(error)
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsDanger)
                        }
                    }
                }

                Section {
                    Button {
                        Task {
                            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            await authService.requestPasswordReset(email: trimmed)
                            if authService.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if authService.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Send reset code")
                                .font(BrandFont.semiBold(17))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(authService.isLoading || !isEmailValid)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.gsBackground)
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authService.errorMessage = nil
                        dismiss()
                    }
                }
            }
        }
    }

    private var isEmailValid: Bool {
        email.isValidEmail
    }
}
