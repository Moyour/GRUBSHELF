import SwiftUI
import UIKit

struct InviteMemberSheet: View {
    @State private var email = ""
    @State private var validationError: String?
    @Environment(\.dismiss) private var dismiss

    let onInvite: (String) -> Void

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isValid: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmedEmail.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.sectionSpacing) {
                VStack(spacing: AppSpacing.rowSpacing) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: AppFont.emptyStateIconSizeSecondary))
                        .foregroundStyle(Color.primaryGreen)

                    Text("Invite a Family Member")
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.primaryText)

                    Text("Enter their email address. They'll be able to join your household when they sign up or log in.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.screenPadding)
                }
                .padding(.top, AppSpacing.sectionSpacing)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Email address", text: $email)
                        .font(AppFont.body)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                                .stroke(validationError != nil ? Color.errorRed : Color.divider, lineWidth: 1)
                        )

                    if let error = validationError {
                        Text(error)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.errorRed)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                Button {
                    validate()
                } label: {
                    Text("Send Invite")
                        .font(AppFont.button)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSpacing.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.primaryGreen)
                .disabled(trimmedEmail.isEmpty)
                .padding(.horizontal, AppSpacing.screenPadding)

                Spacer()
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func validate() {
        if !isValid {
            validationError = "Please enter a valid email address."
            return
        }
        validationError = nil
        onInvite(trimmedEmail)
    }
}

// MARK: - Share Sheet (wraps UIActivityViewController)

struct InviteShareSheet: UIViewControllerRepresentable {
    let item: InviteShareItem

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let emailItem = InviteEmailItem(subject: item.subject, body: item.body)

        let controller = UIActivityViewController(
            activityItems: [emailItem],
            applicationActivities: nil
        )

        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .print,
            .openInIBooks,
        ]

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class InviteEmailItem: NSObject, UIActivityItemSource {
    let subject: String
    let body: String

    init(subject: String, body: String) {
        self.subject = subject
        self.body = body
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        body
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        body
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        subject
    }
}
