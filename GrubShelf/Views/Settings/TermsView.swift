import SwiftUI

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                Text("Terms of Service")
                    .font(BrandFont.semiBold(18))
                    .foregroundStyle(.gsTextPrimary)

                Text("Last updated: March 2025")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)

                Text("""
                By using \(BrandCopy.displayName), you agree to these Terms of Service. Please read them carefully.

                1. Acceptance of Terms
                By downloading, installing, or using the \(BrandCopy.displayName) app, you agree to be bound by these terms and our Privacy Policy.

                2. Use of the Service
                \(BrandCopy.displayName) provides pantry management, shopping list, and household tracking features. You agree to use the service only for lawful purposes and in accordance with these terms.

                3. Account and Data
                You are responsible for maintaining the confidentiality of your account. Your data is stored securely and processed in accordance with our Privacy Policy.

                4. Changes
                We may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the updated terms.

                5. Contact
                For questions about these terms, please contact us at contactgrubshelf@gmail.com.
                """)
                .font(BrandFont.regular(17))
                .foregroundStyle(.gsTextPrimary)
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(.gsBackground)
        .navigationTitle("Terms & Conditions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
