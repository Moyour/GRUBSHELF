import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                Text("Privacy Policy")
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.primaryText)

                Text("Last updated: March 2025")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)

                Text("""
                FoodPan respects your privacy. This policy describes how we collect, use, and protect your information.

                Data We Collect
                • Name and email (for account creation)
                • Pantry items, shopping lists, and household data you create
                • Transaction and spending data for insights

                Data Usage
                Your data is used to provide the app's features, including pantry tracking, household sharing, and spending insights. We do not sell your data to third parties.

                Data Storage
                Data is stored securely using industry-standard encryption. We use Supabase for data storage and authentication.

                Data Sharing
                We do not share your personal data with third parties for marketing. Data may be shared with service providers necessary to operate the app (e.g., cloud hosting).

                Your Rights
                You can request deletion of your account and data at any time from the Profile screen. This will permanently remove all your data.

                Contact
                For privacy-related questions, please contact us at contactfoodpan@gmail.com.
                """)
                .font(AppFont.body)
                .foregroundStyle(Color.primaryText)
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(Color.appBackground)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
