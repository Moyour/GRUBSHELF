import SwiftUI

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                Text("Terms of Service")
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.primaryText)

                Text("Last updated: March 2025")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)

                Text("""
                By using FoodPan, you agree to these Terms of Service. Please read them carefully.

                1. Acceptance of Terms
                By downloading, installing, or using the FoodPan app, you agree to be bound by these terms and our Privacy Policy.

                2. Use of the Service
                FoodPan provides pantry management, shopping list, and household tracking features. You agree to use the service only for lawful purposes and in accordance with these terms.

                3. Account and Data
                You are responsible for maintaining the confidentiality of your account. Your data is stored securely and processed in accordance with our Privacy Policy.

                4. Changes
                We may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the updated terms.

                5. Contact
                For questions about these terms, please contact us at contactfoodpan@gmail.com.
                """)
                .font(AppFont.body)
                .foregroundStyle(Color.primaryText)
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(Color.appBackground)
        .navigationTitle("Terms & Conditions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
