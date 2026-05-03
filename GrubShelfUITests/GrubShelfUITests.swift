import XCTest

/// Smoke tests for launch and first paint. Run on Simulator or device; no sign-in required.
/// Covers: feature onboarding, welcome, create household, or signed-in tabs.
final class GrubShelfUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesToForeground() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testLaunchShowsRecognizableScreenWithinTimeout() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline {
            if app.buttons["Skip"].exists { return }
            if app.staticTexts["Grub Shelf"].exists { return }
            if app.tabBars.buttons["Home"].exists { return }
            if app.staticTexts["Create your household"].exists { return }
            if app.staticTexts["You've been invited"].exists { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail(
            "Timed out waiting for a recognizable screen (onboarding Skip, welcome, household setup, or Home tab)."
        )
    }
}
