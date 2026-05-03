import Foundation
import Testing
@testable import GrubShelf

struct GrubShelfTests {
    @Test func appLaunches() async throws {
        #expect(true)
    }
}

struct BrandCopyTests {
    @Test func displayNameMatchesProductBranding() {
        #expect(BrandCopy.displayName == "Grub Shelf")
        #expect(BrandCopy.wordmark == "GrubShelf")
        #expect(!BrandCopy.welcomeTagline.isEmpty)
        #expect(BrandCopy.aboutDescription.contains(BrandCopy.displayName))
    }
}

struct BrandLogoMarkTests {
    @Test func iconCornerRadiusMatchesIOSIconProportion() {
        let side: CGFloat = 88
        #expect(BrandLogoMark.iconCornerRadius(forSide: side) == side * 0.2237)
    }
}

struct FeatureOnboardingPageTests {
    @Test func featureTourEndsWithSingleCallToAction() {
        let pages = OnboardingPage.featureTour
        #expect(pages.count == 6)
        #expect(pages.last?.isLast == true)
        #expect(pages.filter(\.isLast).count == 1)
    }

    @Test func featureTourHeroUsesLogoNotIllustration() {
        let hero = OnboardingPage.featureTour.first
        #expect(hero?.illustration == nil)
        #expect(hero?.isLast == false)
    }
}

struct ProductRecognitionGroceryMapperTests {
    @Test func mapsTomatoToVegetables() {
        #expect(ProductRecognitionGroceryMapper.pantryCategory(forVisionIdentifier: "tomato") == "Vegetables")
    }

    @Test func mapsHotDogToMeat() {
        #expect(ProductRecognitionGroceryMapper.pantryCategory(forVisionIdentifier: "hot_dog") == "Meat")
    }

    @Test func pineappleNotClassifiedAsApple() {
        #expect(ProductRecognitionGroceryMapper.pantryCategory(forVisionIdentifier: "pineapple") == "Fruits")
    }

    @Test func humanizesIdentifier() {
        #expect(ProductRecognitionGroceryMapper.displayName(fromVisionIdentifier: "bell_pepper") == "Bell Pepper")
    }
}

struct OpenFoodFactsProductNameResolverTests {
    @Test func resolvesItalianProductName() {
        let product: [String: Any] = ["product_name_it": "  Olio d'oliva  "]
        #expect(OpenFoodFactsProductNameResolver.resolvedName(from: product) == "Olio d'oliva")
    }

    @Test func prefersProductNameOverGeneric() {
        let product: [String: Any] = [
            "generic_name": "Oil",
            "product_name": "Extra virgin olive oil",
        ]
        #expect(OpenFoodFactsProductNameResolver.resolvedName(from: product) == "Extra virgin olive oil")
    }

    @Test func resolvesBrandsTagsWhenNoTitle() {
        let product: [String: Any] = ["brands_tags": ["en:acme-foods", "fr:autre-marque"]]
        #expect(OpenFoodFactsProductNameResolver.resolvedName(from: product) == "acme foods, autre marque")
    }

    @Test func displayNameFallsBackToBarcodePlaceholder() {
        let product: [String: Any] = [:]
        let name = OpenFoodFactsProductNameResolver.displayName(from: product, barcode: "1234567890123")
        #expect(name.contains("1234567890123"))
    }
}

struct BarcodeCatalogMatchTests {
    private func catalogItem(name: String) -> GroceryCatalogItem {
        GroceryCatalogItem(
            catalogItemId: UUID(),
            name: name,
            defaultCategory: "Other",
            defaultUnit: .pcs,
            searchKeywords: nil,
            createdAt: .now
        )
    }

    @Test func picksSingleCatalogRowWhenOnlyOne() {
        let one = catalogItem(name: "Tomato")
        let r = BarcodeCatalogMatch.resolve(
            catalogSearchQuery: "tomato",
            openFoodFactsName: "Brand diced tomatoes",
            openFoodFactsCategory: "Vegetables",
            catalogResults: [one]
        )
        guard case let .single(item) = r else {
            Issue.record("Expected .single, got \(r)")
            return
        }
        #expect(item.name == "Tomato")
    }

    @Test func offersChoiceWhenTwoOrThreeResults() {
        let a = catalogItem(name: "Tomato")
        let b = catalogItem(name: "Tomato paste")
        let r = BarcodeCatalogMatch.resolve(
            catalogSearchQuery: "tomato",
            openFoodFactsName: "X",
            openFoodFactsCategory: "Other",
            catalogResults: [a, b]
        )
        guard case let .chooseAmong(items) = r else {
            Issue.record("Expected .chooseAmong, got \(r)")
            return
        }
        #expect(items.count == 2)
    }

    @Test func fallsBackToOpenFoodFactsWhenManyUnmatched() {
        let many = (0..<6).map { catalogItem(name: "Item \($0)") }
        let r = BarcodeCatalogMatch.resolve(
            catalogSearchQuery: "tomato",
            openFoodFactsName: "Heinz Ketchup",
            openFoodFactsCategory: "Condiments",
            catalogResults: many
        )
        guard case let .useOpenFoodFacts(name, category) = r else {
            Issue.record("Expected .useOpenFoodFacts, got \(r)")
            return
        }
        #expect(name == "Heinz Ketchup")
        #expect(category == "Condiments")
    }
}

struct EmptyStateMetricsTests {
    @Test func metricCapsAreOrderedForLayout() {
        #expect(EmptyStateMetrics.tabHeroImageMaxWidth > 0)
        #expect(EmptyStateMetrics.tabHeroImageMaxHeight > 0)
        #expect(EmptyStateMetrics.featureTourImageMaxWidth >= EmptyStateMetrics.tabHeroImageMaxWidth)
        #expect(EmptyStateMetrics.tabHeroSymbolSize > 0)
    }
}
