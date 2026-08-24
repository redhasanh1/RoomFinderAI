import XCTest

/// The camera path, on a device that actually has one.
///
/// This cannot run on a simulator: `isSourceTypeAvailable(.camera)` is false
/// there, so the app deliberately sends it to the photo library instead and the
/// capture screen under test never appears. It exists because the bug it covers
/// — the sheet wedging after "Use Photo" — was reported from a real phone and
/// was invisible to every simulator run.
final class CameraCaptureUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetState"]
    }

    /// Take a photo, keep it, and land on the details form rather than a screen
    /// that no longer responds.
    func testTakingAPhotoReachesTheDetailsForm() throws {
        // The camera permission alert belongs to the system, not the app.
        addUIInterruptionMonitor(withDescription: "camera permission") { alert in
            for title in ["OK", "Allow", "Allow While Using App"] {
                if alert.buttons[title].exists { alert.buttons[title].tap(); return true }
            }
            return false
        }

        app.launch()
        XCTAssertTrue(app.tabBars.buttons.firstMatch.waitForExistence(timeout: 60),
                      "the app never launched")

        // Post is "+ Post" on iPad, where the bar draws words and no icons.
        let post = app.tabBars.buttons["+ Post"].exists
            ? app.tabBars.buttons["+ Post"]
            : app.tabBars.buttons["Post"]
        XCTAssertTrue(post.waitForExistence(timeout: 30), "no Post tab")
        post.tap()

        XCTAssertTrue(app.navigationBars["Add Photos"].waitForExistence(timeout: 20),
                      "the posting sheet did not open")

        app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Add photos of the room'"))
           .firstMatch.tap()

        let takePhoto = app.buttons["Take Photo"]
        guard takePhoto.waitForExistence(timeout: 8) else {
            throw XCTSkip("No camera on this device — the app offers the library only.")
        }
        takePhoto.tap()

        // Nudge the interruption monitor, which only fires on an interaction.
        app.tap()

        let shutter = app.buttons["PhotoCapture"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 30), "the camera never opened")
        shutter.tap()

        let use = app.buttons["Use Photo"]
        XCTAssertTrue(use.waitForExistence(timeout: 20), "no Use Photo after capturing")
        use.tap()

        // The bug: everything below this line was unreachable, because the
        // sheet was left with a capture screen over it that never dismissed.
        //
        // Either the camera comes back for the next shot, or the details form
        // appears. What must NOT happen is neither.
        let cameraAgain = app.buttons["PhotoCapture"]
        let details = app.navigationBars["Check the Details"]

        let progressed = waitFor(20) { cameraAgain.exists || details.exists }
        XCTAssertTrue(progressed, "stuck after Use Photo — nothing came back")

        // If it reopened for another shot, leaving should reach the form.
        if cameraAgain.exists {
            let cancel = app.buttons["Cancel"].firstMatch
            if cancel.waitForExistence(timeout: 8) { cancel.tap() }
            XCTAssertTrue(details.waitForExistence(timeout: 60),
                          "closing the camera did not reach the details form")
        }

        XCTAssertTrue(details.waitForExistence(timeout: 60),
                      "the photo never produced a listing draft")
    }

    private func waitFor(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return condition()
    }
}
