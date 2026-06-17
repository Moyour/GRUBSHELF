import SwiftUI

struct InviteMemberSheet: View {
    @State private var email = ""
    @State private var validationError: String?
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss

    let onInvite: (String) async -> Void

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isValid: Bool {
        trimmedEmail.isValidEmail
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.sectionSpacing) {
                VStack(spacing: AppSpacing.rowSpacing) {
                    Image(systemName: "person.badge.plus")
                        .font(BrandSymbolFont.symbol(34, weight: .bold))
                        .foregroundStyle(.gsBrandPrimary)

                    Text("Invite a family member")
                        .font(BrandFont.semiBold(18))
                        .foregroundStyle(.gsTextPrimary)

                    Text("Enter the email they'll use in GrubShelf. We'll email them an invitation, and they can accept it in the app after signing in with that address.")
                        .font(BrandFont.regular(14))
                        .foregroundStyle(.gsTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.screenPadding)
                }
                .padding(.top, AppSpacing.sectionSpacing)

                VStack(alignment: .leading, spacing: AppSpacing.denseSpacing) {
                    TextField("Email address", text: $email)
                        .font(BrandFont.regular(17))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(AppSpacing.cardPadding)
                        .background(.gsSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                .stroke(validationError != nil ? .gsDanger : .gsBorder, lineWidth: 1)
                        )
                        .disabled(isSending)

                    if let error = validationError {
                        Text(error)
                            .font(BrandFont.regular(14))
                            .foregroundStyle(.gsDanger)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                Button {
                    validate()
                } label: {
                    Group {
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send invite")
                        }
                    }
                    .font(BrandFont.semiBold(17))
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(.gsBrandPrimary)
                .disabled(trimmedEmail.isEmpty || isSending)
                .padding(.horizontal, AppSpacing.screenPadding)

                Spacer()
            }
            .navigationTitle("Invite member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSending)
                }
            }
            .interactiveDismissDisabled(isSending)
            .tint(.gsBrandPrimary)
        }
    }

    private func validate() {
        if !isValid {
            validationError = "Please enter a valid email address."
            return
        }
        validationError = nil
        isSending = true
        Task {
            await onInvite(trimmedEmail)
            isSending = false
        }
    }
}
