import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "FoodPan"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: AppFont.emptyStateIconSize))
                    .foregroundStyle(Color.primaryGreen)

                Text(appName)
                    .font(AppFont.largeTitle)
                    .foregroundStyle(Color.primaryText)

                Text("Track food, reduce waste, save money")
                    .font(AppFont.body)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)

                Text("Version \(appVersion)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.secondaryText)
                    .padding(.top, AppSpacing.rowSpacing)

                Text("FoodPan helps your household track pantry items, plan shopping trips, and reduce food waste — all in one simple app.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.sectionSpacing)

                if let mailURL = URL(string: "mailto:contactfoodpan@gmail.com") {
                    Link("contactfoodpan@gmail.com", destination: mailURL)
                        .font(AppFont.body)
                        .foregroundStyle(Color.primaryGreen)
                        .padding(.top, AppSpacing.rowSpacing)
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(Color.appBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
