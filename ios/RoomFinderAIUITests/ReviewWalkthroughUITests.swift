import XCTest

/// A hands-off walkthrough of the app, for the screen recording App Review
/// asked for under guideline 2.1.
///
/// It is not a test in the usual sense: it asserts very little, because its job
/// is to *drive* the app at a pace a person can follow rather than to catch
/// regressions. Every step pauses long enough for the screen to be read, which
/// is why the deliberate sleeps below are not the mistake they normally would
/// be in a UI test.
///
/// Run it with the device already recording. Nothing here signs in, signs up or
/// deletes anything: those flows live in a web view and are demonstrated by
/// hand, so an automated mis-tap can never destroy the reviewer's demo account.
final class ReviewWalkthroughUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Long enough to read a screen, short enough that the finished video is
    /// not padding.
    private let beat: TimeInterval = 1.8

    override func setUpWithError() throws {
        continueAfterFailure = true          // a missing screen should not end the tour
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetState"]
    }

    private func pause(_ multiplier: Double = 1) {
        Thread.sleep(forTimeInterval: beat * multiplier)
    }

    /// The Post tab is labelled "+ Post" on iPad, where the bar draws words and
    /// no icons, and "Post" on iPhone.
    private func tabButton(_ name: String) -> XCUIElement {
        let bar = app.tabBars.firstMatch
        if name == "Post" {
            let padded = bar.buttons["+ Post"]
            if padded.exists { return padded }
        }
        return bar.buttons[name]
    }

    @discardableResult
    private func go(_ name: String) -> Bool {
        let tab = tabButton(name)
        guard tab.waitForExistence(timeout: 30) else {
            XCTFail("\(name) tab never appeared"); return false
        }
        tab.tap()
        pause()
        return true
    }

    /// Taps the "..." toolbar menu, whatever it is called on this screen.
    private func openOverflow() -> Bool {
        for candidate in ["More options", "More"] {
            let button = app.buttons[candidate]
            if button.waitForExistence(timeout: 4) { button.tap(); pause(); return true }
        }
        return false
    }

    func testGuidedWalkthroughForAppReview() {
        // Permission prompts are system alerts, so they have to be answered
        // through an interruption monitor rather than by tapping the app.
        addUIInterruptionMonitor(withDescription: "system permission") { alert in
            for title in ["Allow While Using App", "Allow", "OK", "Continue"] {
                let button = alert.buttons[title]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        app.launch()
        XCTAssertTrue(tabButton("Home").waitForExistence(timeout: 60), "app never launched")
        pause(2)

        section1Home()
        section2ReportAListing()
        section3BlockAndUnblockAPerson()
        section4PostAndMessages()
        section5LegalPages()

        // Land somewhere calm so the video does not end mid-scroll.
        go("Home")
        pause(2)
    }

    // MARK: - 1. Browsing

    private func section1Home() {
        go("Home")
        app.swipeUp(); pause()
        app.swipeUp(); pause()
        app.swipeDown(); pause()
        app.swipeDown(); pause()
    }

    // MARK: - 2. Reporting user content (guideline 1.2)

    private func section2ReportAListing() {
        go("Home")

        // The first room card on the page, whatever it is called today.
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '$'")).firstMatch
        guard card.waitForExistence(timeout: 25) else {
            XCTFail("no room card to open"); return
        }
        card.tap()
        pause(2)
        app.swipeUp(); pause()

        guard openOverflow() else { XCTFail("no overflow menu on the listing"); return }

        let report = app.buttons["Report this listing"]
        guard report.waitForExistence(timeout: 6) else {
            XCTFail("Report is not in the listing menu"); return
        }
        report.tap()
        pause(2)

        // Show the reasons, then leave without filing a real report — the point
        // is that the mechanism is reachable and complete, not to put noise in
        // the moderation queue.
        app.staticTexts["Offensive or abusive"].firstMatch.tap()
        pause()
        app.buttons["Cancel"].firstMatch.tap()
        pause()

        app.navigationBars.buttons.element(boundBy: 0).tap()   // back to the list
        pause()
    }

    // MARK: - 3. Blocking, and undoing it (guideline 1.2)

    private func section3BlockAndUnblockAPerson() {
        go("People")
        pause()

        let person = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Looking for a room' OR label CONTAINS[c] 'Has a room'")).firstMatch
        guard person.waitForExistence(timeout: 25) else {
            XCTFail("no roommate card to open"); return
        }
        person.tap()
        pause(2)

        guard openOverflow() else { XCTFail("no overflow menu on the profile"); return }

        let block = app.buttons["Block this person"]
        guard block.waitForExistence(timeout: 6) else {
            XCTFail("Block is not in the profile menu"); return
        }
        block.tap()
        pause()

        // The confirmation, so the recording shows blocking is deliberate.
        let confirm = app.buttons["Block"].firstMatch
        if confirm.waitForExistence(timeout: 6) { confirm.tap() }
        pause(2)

        // Now prove it is reversible, which is the half that did not exist.
        go("Profile")
        let blocked = app.buttons["Blocked people"]
        if blocked.waitForExistence(timeout: 20) {
            blocked.tap()
            pause(2)
            let unblock = app.buttons["Unblock"].firstMatch
            if unblock.waitForExistence(timeout: 10) {
                unblock.tap()
                pause(2)
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            pause()
        }
    }

    // MARK: - 4. Posting, and the messages hub

    private func section4PostAndMessages() {
        go("Post")
        pause(2)
        app.swipeUp(); pause()
        app.swipeDown(); pause()
        let close = app.buttons["Cancel"].firstMatch
        if close.waitForExistence(timeout: 6) { close.tap() }
        pause()

        go("Messages")
        pause(2)
        let inbox = app.buttons["Direct Messages"]
        if inbox.waitForExistence(timeout: 10) { inbox.tap(); pause(2) }
        let negotiator = app.buttons["AI Negotiator"]
        if negotiator.waitForExistence(timeout: 10) { negotiator.tap(); pause(2) }
    }

    // MARK: - 5. The pages Apple expects to reach without an account

    private func section5LegalPages() {
        go("Messages")
        guard openOverflow() else { return }
        let privacy = app.buttons["Privacy Policy"]
        if privacy.waitForExistence(timeout: 6) {
            privacy.tap()
            pause(3)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            pause()
        } else {
            // The menu differs per tab; closing it is enough for the tour.
            app.tap()
        }
    }
}
