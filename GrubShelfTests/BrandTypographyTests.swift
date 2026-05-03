import SwiftUI
import XCTest

@testable import GrubShelf

final class BrandTypographyTests: XCTestCase {
    func testUiKitWeightMapsStandardSwiftUIWeights() {
        XCTAssertEqual(BrandFont.uiKitWeight(.regular), .regular)
        XCTAssertEqual(BrandFont.uiKitWeight(.medium), .medium)
        XCTAssertEqual(BrandFont.uiKitWeight(.semibold), .semibold)
        XCTAssertEqual(BrandFont.uiKitWeight(.bold), .bold)
    }
}
