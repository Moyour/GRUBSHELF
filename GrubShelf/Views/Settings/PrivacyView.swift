import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                Text("Privacy Policy")
                    .font(BrandFont.semiBold(18))
                    .foregroundStyle(.gsTextPrimary)

                Text("Last updated: March 2025")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)

                Text("""
                \(BrandCopy.displayName) respects your privacy. This policy describes how we collect, use, and protect your information.

                Data we collect
                • Name and email (for account creation)
                • Pantry items, shopping lists, and household data you create
                • Transaction and spending data for summaries

                Data usage
                Your data is used to provide the app's features, including pantry tracking, household sharing, and spending summaries. We do not sell your data to third parties.

                Data storage
                Data is stored securely using industry-standard encryption. We use Supabase for data storage and authentication.

                Data sharing
                We do not share your personal data with third parties for marketing. Data may be shared with service providers necessary to operate the app (e.g., cloud hosting).

                Your rights
                You can request deletion of your account and data at any time from the Profile screen. This will permanently remove all your data.

                Contact
                For privacy-related questions, please contact us at contactgrubshelf@gmail.com.
                """)
                .font(BrandFont.regular(17))
                .foregroundStyle(.gsTextPrimary)
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(.gsBackground)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
