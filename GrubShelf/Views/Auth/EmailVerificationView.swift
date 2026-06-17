import SwiftUI

struct EmailVerificationView: View {
    @Bindable var authService: AuthenticationService

    @State private var code = ""
    @State private var resendCooldown = 0
    @State private var lastSubmittedCode = ""
    @FocusState private var isCodeFocused: Bool

    private var email: String { authService.pendingVerificationEmail ?? "" }

    var body: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()

            VStack(spacing: AppSpacing.compactGap) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 48))
                    .foregroundStyle(.gsBrandPrimary)

                Text("Check your email")
                    .font(BrandFont.semiBold(24))
                    .foregroundStyle(.gsTextPrimary)

                Text("We sent a 6-digit code to")
                    .font(BrandFont.regular(15))
                    .foregroundStyle(.gsTextSecondary)

                Text(email)
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(.gsTextPrimary)

                Button("Wrong email?") {
                    authService.pendingVerificationEmail = nil
                }
                .font(BrandFont.regular(14))
                .foregroundStyle(.gsBrandPrimary)
            }

            // OTP Code field
            TextField("000000", text: $code)
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
                    let normalized: String
                    if filtered.count > 6 {
                        normalized = String(filtered.prefix(6))
                        code = normalized
                    } else if filtered != newValue {
                        normalized = filtered
                        code = normalized
                    } else {
                        normalized = filtered
                    }

                    if normalized.count == 6,
                       !authService.isLoading,
                       normalized != lastSubmittedCode {
                        lastSubmittedCode = normalized
                        Task { await authService.verifyEmail(code: normalized) }
                    }
                }
                .onChange(of: authService.errorMessage) { _, newValue in
                    if newValue != nil {
                        lastSubmittedCode = ""
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
                Task { await authService.verifyEmail(code: code) }
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
            .disabled(authService.isLoading || code.count != 6)
            .padding(.horizontal, AppSpacing.sectionSpacing)

            Button {
                Task {
                    await authService.resendVerificationEmail()
                    startResendCooldown()
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
