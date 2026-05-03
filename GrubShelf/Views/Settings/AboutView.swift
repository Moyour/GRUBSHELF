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
            ?? BrandCopy.displayName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                BrandLogoMark(size: 72)

                Text(appName)
                    .font(BrandFont.bold(26))
                    .foregroundStyle(.gsTextPrimary)

                Text("Track food, reduce waste, save money")
                    .font(BrandFont.regular(17))
                    .foregroundStyle(.gsTextSecondary)
                    .multilineTextAlignment(.center)

                Text("Version \(appVersion)")
                    .font(BrandFont.regular(14))
                    .foregroundStyle(.gsTextSecondary)
                    .padding(.top, AppSpacing.rowSpacing)

                Text(BrandCopy.aboutDescription)
                    .font(BrandFont.regular(17))
                    .foregroundStyle(.gsTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.sectionSpacing)

                if let mailURL = URL(string: "mailto:contactgrubshelf@gmail.com") {
                    Link("contactgrubshelf@gmail.com", destination: mailURL)
                        .font(BrandFont.regular(17))
                        .foregroundStyle(.gsBrandPrimary)
                        .padding(.top, AppSpacing.rowSpacing)
                }
            }
            .padding(AppSpacing.screenPadding)
        }
        .background(.gsBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
