import Testing
@testable import GrubShelf

struct FeatureOnboardingViewTests {
    @Test func featureTourHasExpectedShape() {
        let tour = OnboardingPage.featureTour
        #expect(tour.count == 6)
        #expect(tour.enumerated().allSatisfy { $0.offset == $0.element.id })
        let lastFlags = tour.map(\.isLast)
        #expect(lastFlags.filter { $0 }.count == 1)
        #expect(lastFlags.last == true)
    }

    @Test func interactionKindsMatchTourPages() {
        #expect(FeatureOnboardingInteraction.forPageId(0) == .heroChips)
        #expect(FeatureOnboardingInteraction.forPageId(1) == .priorityPick)
        #expect(FeatureOnboardingInteraction.forPageId(2) == .budgetMeter)
        #expect(FeatureOnboardingInteraction.forPageId(3) == .checklistDemo)
        #expect(FeatureOnboardingInteraction.forPageId(4) == .householdPins)
        #expect(FeatureOnboardingInteraction.forPageId(5) == .none)
        #expect(FeatureOnboardingInteraction.forPageId(99) == .none)
    }

    @Test func onboardingPageInteractionMirrorsId() {
        let tour = OnboardingPage.featureTour
        for page in tour {
            #expect(page.interaction == FeatureOnboardingInteraction.forPageId(page.id))
        }
    }
}
