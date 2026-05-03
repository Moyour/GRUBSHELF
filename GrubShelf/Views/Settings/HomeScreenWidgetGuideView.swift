import SwiftUI

/// Explains how to add the GrubShelf shopping list widget — iOS does not allow apps to place widgets programmatically.
struct HomeScreenWidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(BrandSymbolFont.symbol(44, weight: .semibold))
                    .foregroundStyle(.gsBrandPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.compactGap)

                Text("Shopping list on your Home Screen")
                    .font(BrandFont.bold(24))
                    .foregroundStyle(.gsTextPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text("See what’s left to buy without opening the app. Apple doesn’t let any app add a widget for you—you choose it once, then it stays updated when you use \(BrandCopy.displayName).")
                    .font(BrandFont.regular(17))
                    .foregroundStyle(.gsTextSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: AppSpacing.rowSpacing) {
                    stepRow(number: 1, text: "On your Home Screen, touch and hold an empty area until the apps jiggle.")
                    stepRow(number: 2, text: "Tap the + button in the top corner (or corner of the dock on iPad).")
                    stepRow(number: 3, text: "Search for \(BrandCopy.displayName), then choose Shop list (shown as “Shopping list” in the widget gallery).")
                    stepRow(number: 4, text: "Pick a size, tap Add Widget, then tap outside the sheet to finish.")
                }
                .padding(AppSpacing.cardPadding)
                .dashboardCardSurface()

                Label {
                    Text("Open Shop in \(BrandCopy.displayName) so lists sync to the widget. Medium and large sizes show item names from your newest list by default. In Settings → Widget shopping list you can choose a specific list, or pin one from a list’s menu.")
                        .font(BrandFont.regular(16))
                        .foregroundStyle(.gsTextSecondary)
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(BrandSymbolFont.symbol(18))
                        .foregroundStyle(.gsBrandPrimary)
                }
                .labelStyle(.titleAndIcon)
                .padding(AppSpacing.cardPadding)
                .background(Color.gsBrandPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.bottom, AppSpacing.sectionSpacing)
        }
        .background(.gsBackground)
        .navigationTitle("Home screen widget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .font(BrandFont.semiBold(17))
            }
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.rowSpacing) {
            Text("\(number)")
                .font(BrandFont.bold(16))
                .foregroundStyle(.gsTextInverse)
                .frame(width: 28, height: 28)
                .background(.gsBrandPrimary)
                .clipShape(Circle())

            Text(text)
                .font(BrandFont.regular(17))
                .foregroundStyle(.gsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        HomeScreenWidgetGuideView()
    }
}
