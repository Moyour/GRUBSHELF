import SwiftUI

/// One-time mandatory screen shown after OAuth sign-in (Google / Apple) so the
/// user can confirm or edit the name pulled from the provider before proceeding.
struct NameGateView: View {
    var authService: AuthenticationService
    @Binding var hasCompletedNameGate: Bool

    @State private var name: String
    @State private var isSaving = false
    @FocusState private var isNameFieldFocused: Bool

    init(authService: AuthenticationService, hasCompletedNameGate: Binding<Bool>) {
        self.authService = authService
        self._hasCompletedNameGate = hasCompletedNameGate
        // Pre-fill with the name from the OAuth provider (if valid).
        let current = authService.currentUser?.name ?? ""
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUsable = !trimmed.isEmpty && trimmed != "User" && !trimmed.contains("@")
        self._name = State(initialValue: isUsable ? trimmed : "")
    }

    var body: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Spacer()

            VStack(spacing: AppSpacing.compactGap) {
                BrandLogoMark(size: 48, cornerRadius: BrandLogoMark.iconCornerRadius(forSide: 48))
                Text(BrandCopy.wordmark)
                    .font(BrandFont.semiBold(15))
                    .foregroundStyle(Color.gsBrandPrimary)
            }

            VStack(spacing: AppSpacing.smallSpacing) {
                Text("What should we call you?")
                    .font(BrandFont.semiBold(22))
                    .multilineTextAlignment(.center)

                Text("This is how you'll appear to your household.")
                    .font(BrandFont.regular(15))
                    .foregroundStyle(.gsTextSecondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Your name", text: $name)
                .textContentType(.name)
                .autocorrectionDisabled()
                .font(BrandFont.regular(17))
                .padding(AppSpacing.rowSpacing)
                .background(Color.gsSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
                .focused($isNameFieldFocused)
                .submitLabel(.done)
                .onSubmit { save() }

            Button {
                save()
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .font(BrandFont.semiBold(17))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .background(.gsBackground)
        .onAppear {
            isNameFieldFocused = true
        }
        .interactiveDismissDisabled()
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSaving else { return }
        isSaving = true
        Task {
            try? await authService.updateUserName(trimmed)
            hasCompletedNameGate = true
            isSaving = false
        }
    }
}
