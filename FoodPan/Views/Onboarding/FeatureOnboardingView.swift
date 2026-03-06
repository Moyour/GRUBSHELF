import SwiftUI

struct FeatureOnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            illustration: "onboarding-foodwaste",
            headline: "Food goes to waste before you use it.",
            subtext: "Track what you have and get alerts before things expire.",
            isLast: false
        ),
        OnboardingPage(
            id: 1,
            illustration: "onboarding-budget",
            headline: "Grocery spending slips out of control.",
            subtext: "See where your money goes and set budgets that stick.",
            isLast: false
        ),
        OnboardingPage(
            id: 2,
            illustration: "onboarding-shopping",
            headline: "Shopping lists get messy and forgotten.",
            subtext: "One list, check off as you shop, move to pantry in one tap.",
            isLast: false
        ),
        OnboardingPage(
            id: 3,
            illustration: "onboarding-family",
            headline: "Everyone buys the same thing.",
            subtext: "Share your pantry with the family. One place everyone can see.",
            isLast: false
        ),
        OnboardingPage(
            id: 4,
            illustration: "onboarding-pantry",
            headline: "You never know what's at home.",
            subtext: "One place to see everything. No more guessing.",
            isLast: false
        ),
        OnboardingPage(
            id: 5,
            illustration: "onboarding-getstarted",
            headline: "Ready to waste less?",
            subtext: "Get started in seconds.",
            isLast: true
        ),
    ]

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(pages) { page in
                onboardingPageView(page)
                    .tag(page.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color.appBackground)
    }

    private func onboardingPageView(_ page: OnboardingPage) -> some View {
        VStack(alignment: .center, spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    onComplete()
                }
                .font(AppFont.caption)
                .foregroundStyle(Color.secondaryText)
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.sectionSpacing)
            }

            Spacer(minLength: 24)

            // Illustration
            Image(page.illustration)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280, maxHeight: 240)
                .padding(.horizontal, AppSpacing.screenPadding)

            Spacer(minLength: 24)

            // Headline
            Text(page.headline)
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.screenPadding)

            // Subtext
            Text(page.subtext)
                .font(AppFont.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.rowSpacing)
                .padding(.horizontal, AppSpacing.screenPadding)

            Spacer(minLength: 40)

            // Button
            Button {
                if page.isLast {
                    onComplete()
                } else {
                    withAnimation {
                        currentPage += 1
                    }
                }
            } label: {
                Text(page.isLast ? "Get Started" : "Next")
                    .font(AppFont.button)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.minTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primaryGreen)
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.bottom, AppSpacing.sectionSpacing)
        }
    }
}

struct OnboardingPage: Identifiable {
    let id: Int
    let illustration: String
    let headline: String
    let subtext: String
    let isLast: Bool
}
