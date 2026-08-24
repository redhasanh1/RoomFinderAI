import XCTest

/// The photo screen's own behaviour: what it shows once photos exist, that one
/// can be taken back off, and that there is always a way forward.
///
/// Photos are seeded through a launch argument rather than picked from the
/// system library. The library picker runs in another process and its element
/// tree moves between OS versions, so driving it made the test about Apple's
/// picker instead of about this screen — which is where the bug was: after a
/// photo was added, nothing on screen moved the person on.
final class PhotoRemovalUITests: XCTestCase {

    private var app: XCUIApplication!

    private func launch(seedingPhotos count: Int) {
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetState", "-uiTestingSeedPhotos", "\(count)"]
        app.launch()
    }

    private func openPostSheet() {
        let post = app.tabBars.buttons["+ Post"].exists
            ? app.tabBars.buttons["+ Post"] : app.tabBars.buttons["Post"]
        XCTAssertTrue(post.waitForExistence(timeout: 60), "no Post tab")
        post.tap()
        XCTAssertTrue(app.navigationBars["Add Photos"].waitForExistence(timeout: 25),
                      "the posting sheet did not open")
    }

    private var removeBadges: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Remove photo'"))
    }

    private var continueButton: XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Continue with'")).firstMatch
    }

    private func waitFor(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return condition()
    }

    /// Photos present means a visible way on. This is the state Connor was
    /// stranded in: a photo taken, and nothing that continued.
    func testPhotosGiveAWayForward() {
        launch(seedingPhotos: 1)
        openPostSheet()

        XCTAssertTrue(removeBadges.firstMatch.waitForExistence(timeout: 20),
                      "the photo did not appear on the screen")
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10),
                      "no way to continue with a photo added — this was the stuck state")
    }

    /// The X takes off exactly the one that was tapped, and no more.
    func testTheXRemovesOnePhoto() {
        launch(seedingPhotos: 3)
        openPostSheet()

        XCTAssertTrue(waitFor(25) { removeBadges.count == 3 },
                      "expected 3 photos, found \(removeBadges.count)")

        removeBadges.element(boundBy: 0).tap()
        XCTAssertTrue(waitFor(15) { removeBadges.count == 2 },
                      "after one X, expected 2 photos, found \(removeBadges.count)")

        XCTAssertTrue(continueButton.exists,
                      "removing one photo took away the way forward while two remained")
    }

    /// Removing the last one puts the screen back to empty rather than leaving
    /// a Continue button with nothing behind it.
    func testRemovingEveryPhotoClearsTheWayForward() {
        launch(seedingPhotos: 2)
        openPostSheet()

        XCTAssertTrue(waitFor(25) { removeBadges.count == 2 }, "photos never appeared")
        removeBadges.element(boundBy: 0).tap()
        XCTAssertTrue(waitFor(15) { removeBadges.count == 1 }, "first X did nothing")
        removeBadges.element(boundBy: 0).tap()

        XCTAssertTrue(waitFor(15) { removeBadges.count == 0 }, "second X did nothing")
        XCTAssertTrue(waitFor(10) { !continueButton.exists },
                      "Continue was still offered with no photos left")
    }

    /// Cancel leaves the sheet and lands back where it was opened from.
    func testCancelClosesTheSheet() {
        launch(seedingPhotos: 1)
        openPostSheet()
        app.navigationBars["Add Photos"].buttons["Cancel"].tap()

        let home = app.tabBars.buttons["Home"]
        XCTAssertTrue(waitFor(20) { home.exists && home.isSelected },
                      "Cancel did not return to the previous tab")
    }
}
