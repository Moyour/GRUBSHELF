import SwiftUI

struct ForgotPasswordView: View {
    @Bindable var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var didSendInstructions = false
    @State private var resendCooldown = 0

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

                if !didSendInstructions {
                    Section {
                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("We will email you a reset link. Open it on this device to choose a new password.")
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
                                let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                                await authService.requestPasswordReset(email: trimmed)
                                if authService.errorMessage == nil {
                                    didSendInstructions = true
                                    startResendCooldown()
                                }
                            }
                        } label: {
                            if authService.isLoading {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Send reset link")
                                    .font(BrandFont.semiBold(17))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(authService.isLoading || !isEmailValid)
                    }
                } else {
                    Section {
                        Text(
                            "Check your inbox for an email from us. Tap the reset link—it opens GrubShelf so you can set a new password."
                        )
                        .font(BrandFont.regular(15))
                        .foregroundStyle(.gsTextSecondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    Section {
                        Button {
                            Task {
                                let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                                await authService.requestPasswordReset(email: trimmed)
                                if authService.errorMessage == nil {
                                    startResendCooldown()
                                    ToastManager.shared.show("Another reset email is on its way.", style: .success)
                                }
                            }
                        } label: {
                            if resendCooldown > 0 {
                                Text("Resend link (\(resendCooldown)s)")
                                    .font(BrandFont.regular(14))
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Resend link")
                                    .font(BrandFont.regular(14))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(resendCooldown > 0 || authService.isLoading)
                    }

                    if let error = authService.errorMessage {
                        Section {
                            Text(error)
                                .font(BrandFont.regular(14))
                                .foregroundStyle(.gsDanger)
                        }
                    }

                    Section {
                        Button("Done") {
                            authService.errorMessage = nil
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                    }
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
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func startResendCooldown() {
        resendCooldown = 60
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendCooldown -= 1
            }
        }
    }
}
