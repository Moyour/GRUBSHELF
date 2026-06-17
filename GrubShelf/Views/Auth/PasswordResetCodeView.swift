import SwiftUI

/// Enter the 6-digit code from the password reset email before choosing a new password.
struct PasswordResetCodeView: View {
    private static let codeLength = 6

    @Bindable var authService: AuthenticationService

    @State private var code = ""
    @State private var resendCooldown = 0
    @FocusState private var isCodeFocused: Bool

    private var email: String { authService.pendingPasswordResetEmail ?? "" }

    var body: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()

            VStack(spacing: AppSpacing.compactGap) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.gsBrandPrimary)

                Text("Enter reset code")
                    .font(BrandFont.semiBold(24))
                    .foregroundStyle(.gsTextPrimary)

                Text("We sent a 6-digit code to")
                    .font(BrandFont.regular(15))
                    .foregroundStyle(.gsTextSecondary)

                Text(email)
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(.gsTextPrimary)
            }

            TextField(String(repeating: "0", count: Self.codeLength), text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(BrandFont.semiBold(28))
                .tracking(8)
                .padding(.vertical, 14)
                .padding(.horizontal, AppSpacing.sectionSpacing)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gsSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCodeFocused ? Color.gsBrandPrimary : Color.gsBorder, lineWidth: isCodeFocused ? 2 : 1)
                )
                .padding(.horizontal, AppSpacing.sectionSpacing)
                .focused($isCodeFocused)
                .onChange(of: code) { _, newValue in
                    let filtered = newValue.filter { $0.isWholeNumber }
                    if filtered.count > Self.codeLength {
                        code = String(filtered.prefix(Self.codeLength))
                    } else if filtered != newValue {
                        code = filtered
                    }
                }

            if let error = authService.errorMessage {
                Text(error)
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task { await authService.verifyPasswordResetCode(code: code) }
            } label: {
                if authService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("Verify")
                        .font(BrandFont.semiBold(17))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.gsBrandPrimary)
            .disabled(authService.isLoading || code.count != Self.codeLength)
            .padding(.horizontal, AppSpacing.sectionSpacing)

            Button {
                Task {
                    await authService.resendPasswordResetCode()
                    if authService.errorMessage == nil {
                        startResendCooldown()
                    }
                }
            } label: {
                if resendCooldown > 0 {
                    Text("Resend code (\(resendCooldown)s)")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                } else {
                    Text("Resend code")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsBrandPrimary)
                }
            }
            .disabled(resendCooldown > 0 || authService.isLoading)

            Button {
                authService.cancelPendingPasswordReset()
            } label: {
                Text("Cancel")
                    .font(BrandFont.regular(15))
                    .foregroundStyle(.gsTextSecondary)
            }
            .padding(.top, AppSpacing.compactGap)

            Spacer()
            Spacer()
        }
        .padding()
        .background(.gsBackground)
        .onAppear { isCodeFocused = true }
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
