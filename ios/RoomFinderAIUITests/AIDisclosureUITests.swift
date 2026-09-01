import XCTest

/// The disclosure that has to appear before anything is sent to a third-party
/// AI service.
///
/// App Review asked what personal data goes to third-party AI, and the answer
/// given was that a disclosure is shown before any of it is sent. These exist
/// so that claim is checked rather than assumed: a reviewer will look for this
/// screen, and if it were not there the answer would have been untrue.
final class AIDisclosureUITests: XCTestCase {

    private var app: XCUIApplication!
    private let starter = "Find me a 1 bedroom under $1500"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Also clears the remembered agreement, so every run starts having
        // agreed to nothing.
        app.launchArguments = ["-uiTestingResetState"]
        app.launch()
    }

    private func waitFor(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return condition()
    }

    /// Opens the negotiator and returns its first starter question.
    ///
    /// The waits are generous on purpose. The tab bar, the Messages hub and the
    /// negotiator each load in turn, and short timeouts made these fail on the
    /// screen before the one under test.
    @discardableResult
    private func openNegotiatorAndTapStarter() -> Bool {
        let messages = app.tabBars.buttons["Messages"]
        guard messages.waitForExistence(timeout: 60) else { XCTFail("no Messages tab"); return false }
        messages.tap()

        let negotiator = app.buttons["AI Negotiator"]
        if negotiator.waitForExistence(timeout: 30) { negotiator.tap() }

        let chip = app.buttons[starter]
        guard chip.waitForExistence(timeout: 30) else { XCTFail("negotiator never offered its starters"); return false }
        chip.tap()
        return true
    }

    /// Whether the transcript shows the starter as a sent message. The chip is
    /// a button; a sent message is static text, so this cannot match the chip
    /// itself.
    private func transcriptShowsStarter() -> Bool {
        app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "1 bedroom under")).firstMatch.exists
    }

    /// Nothing may be sent until the disclosure has been agreed to.
    func testDisclosureAppearsBeforeTheFirstMessage() {
        guard openNegotiatorAndTapStarter() else { return }
        XCTAssertTrue(app.navigationBars["Before you use AI"].waitForExistence(timeout: 20),
                      "the disclosure did not appear before the first message")
    }

    /// It has to name the data and the companies, not merely say "AI is used" —
    /// naming them is the whole point of the question App Review asked.
    func testDisclosureNamesTheDataAndTheCompanies() {
        guard openNegotiatorAndTapStarter() else { return }
        XCTAssertTrue(app.navigationBars["Before you use AI"].waitForExistence(timeout: 20))

        // Scrolling as it goes: the sheet is longer than a phone screen, and
        // what is below the fold is not in the tree until it has been reached.
        for phrase in ["OpenAI", "Cloudflare", "email address", "Photos you add"] {
            let found = app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS[c] %@", phrase)).firstMatch

            var seen = found.waitForExistence(timeout: 4)
            var scrolls = 0
            while !seen && scrolls < 6 {
                app.swipeUp()
                scrolls += 1
                seen = found.exists
            }
            XCTAssertTrue(seen, "the disclosure never mentions \(phrase)")
        }
    }

    /// Declining must leave the message unsent, rather than sending it anyway
    /// once the sheet is out of the way.
    func testDecliningSendsNothing() {
        guard openNegotiatorAndTapStarter() else { return }
        XCTAssertTrue(app.navigationBars["Before you use AI"].waitForExistence(timeout: 20))

        app.buttons["Not now"].tap()
        XCTAssertTrue(waitFor(15) { !app.navigationBars["Before you use AI"].exists },
                      "the sheet did not close")

        XCTAssertFalse(waitFor(10) { transcriptShowsStarter() },
                       "the message was sent despite the disclosure being declined")
    }

    /// Agreeing sends the message that was waiting, so it does not have to be
    /// entered a second time.
    func testAgreeingSendsTheMessageThatWasWaiting() {
        guard openNegotiatorAndTapStarter() else { return }
        XCTAssertTrue(app.navigationBars["Before you use AI"].waitForExistence(timeout: 20))

        app.buttons["Agree and continue"].tap()

        // The starters are only offered while the conversation is empty, so
        // their going is the proof the waiting message was sent. Asserting on
        // the reply instead made this depend on a live round trip to the AI
        // service, which is not what is being tested here.
        XCTAssertTrue(waitFor(45) { !app.buttons[starter].exists },
                      "agreeing did not send the message that was waiting")
    }
}
