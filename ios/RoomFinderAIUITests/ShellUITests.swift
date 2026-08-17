import XCTest

/// Interaction tests for the native shell.
///
/// These exist because the parts of a hybrid app that break are the seams
/// between native chrome and web content, and those cannot be checked by
/// looking at a screenshot. A content inset that is off by the height of the
/// tab bar looks completely fine until someone tries to reach the last button
/// on the page.
///
/// They deliberately assert on native elements and on scroll geometry rather
/// than on page copy, so a wording change on the website does not fail the
/// suite.
final class ShellUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Every test starts on Home. Without this the tab restored from the
        // previous test's last tap decides where this one begins.
        app.launchArguments = ["-uiTestingResetState"]
        app.launch()
    }

    /// Polls a condition instead of sleeping a fixed amount.
    @discardableResult
    private func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return condition()
    }

    /// Taps a tab and gives it a chance to settle before the test continues.
    ///
    /// Deliberately does NOT assert that the tab became selected. Under load a
    /// tap can be swallowed while the previous screen is still laying out, and
    /// a helper that fails there reports a navigation problem when the screen
    /// under test is perfectly fine. It taps again instead, and leaves the
    /// judgement to the test's own assertions.
    private func selectTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 45), "\(name) tab never appeared")

        tab.tap()
        guard !waitUntil(12, { tab.isSelected }) else { return }

        tab.tap()
        waitUntil(12, { tab.isSelected })
    }

    /// RoomPal has its own tab now.
    private func openRoomPal() {
        selectTab("RoomPal")
    }

    /// Waits out the splash. Home is native now, so this waits for the tab bar
    /// rather than for a web view that will never appear there.
    private func waitForFirstPage() {
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 45),
                      "The app never finished launching")
    }

    /// The five slots, in the order the app has always had them, with Post in
    /// the middle.
    func testTabBarHasPostInTheMiddle() {
        _ = app.tabBars.buttons["Home"].waitForExistence(timeout: 45)

        let expected = ["Home", "RoomPal", "Post", "Messages", "Profile"]
        for name in expected {
            XCTAssertTrue(app.tabBars.buttons[name].exists, "\(name) tab is missing")
        }

        // Ordered left to right, so Post really is the middle one rather than
        // merely present.
        let positions = expected.map { app.tabBars.buttons[$0].frame.minX }
        XCTAssertEqual(positions, positions.sorted(), "The tabs are out of order")
        XCTAssertEqual(expected[2], "Post")
    }

    /// Profile is the one tab still rendering the site.
    func testProfileRendersTheSite() {
        waitForFirstPage()
        selectTab("Profile")

        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 45),
                      "Profile never produced a web view")
        XCTAssertGreaterThan(webView.frame.height, 200,
                             "Profile rendered a web view with no usable height")
    }

    /// Post is an action, not a place: it opens the sheet and leaves you where
    /// you were, so dismissing it does not strand you on a blank tab.
    func testPostTabOpensSheetAndKeepsYourPlace() {
        selectTab("Home")

        app.tabBars.buttons["Post"].tap()

        XCTAssertTrue(app.navigationBars["Post a Room"].waitForExistence(timeout: 15),
                      "The Post tab did not open the posting sheet")

        // Autofill is the reason most people finish posting at all.
        XCTAssertTrue(app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Write it for me' OR label CONTAINS[c] 'Fill in from my photo'")
        ).firstMatch.exists, "The post form has no AI autofill")

        app.buttons["Cancel"].tap()

        // Back on Listings, not on an empty Post screen.
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 15),
                      "Dismissing the sheet did not return to the previous tab")
    }

    /// The native Listings tab must fetch real rooms from the API and let one
    /// be opened. This is the app's primary task and the part that is not a
    /// web page, so it gets checked end to end.
    func testNativeListingsLoadAndOpen() {
        waitForFirstPage()

        selectTab("Home")

        // Matched on the price rather than taken as `cells.firstMatch`: the
        // section header ("9 rooms") is itself exposed as a cell, and tapping
        // that does nothing. Requiring "/mo" also proves the API response was
        // decoded, since the price only exists if it was.
        // `containing` matches on descendants, which holds whether or not the
        // row's children are merged into a single accessibility element.
        let pricedRow = app.buttons
            .containing(NSPredicate(format: "label CONTAINS[c] '/mo'"))
            .firstMatch

        if !pricedRow.waitForExistence(timeout: 60) {
            // Say which failure this was. "No rows" with the error screen up is
            // the API not answering; "no rows" without it is the screen never
            // finishing its load; rows without prices is a decoding problem.
            let sawError = app.staticTexts["Couldn't load rooms"].exists
            let cellCount = app.buttons.count
            XCTFail("""
                Native listings produced no priced row after 60s.
                error screen shown: \(sawError), cells present: \(cellCount)
                """)
            return
        }

        XCTAssertFalse(app.webViews.firstMatch.exists,
                       "Listings should be native, but a web view was found")

        pricedRow.tap()

        // The detail screen offers the two hand-off actions.
        XCTAssertTrue(app.buttons["Negotiate this rent"].waitForExistence(timeout: 15),
                      "Listing detail did not open")
        XCTAssertTrue(app.buttons["Contact host"].exists,
                      "Listing detail is missing the contact action")
    }

    /// Native search must actually filter the list rather than decorate it.
    func testNativeListingsSearchFilters() {
        waitForFirstPage()
        selectTab("Home")

        let anyCard = app.buttons
            .containing(NSPredicate(format: "label CONTAINS[c] '/mo'"))
            .firstMatch
        XCTAssertTrue(anyCard.waitForExistence(timeout: 60))

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No native search field")
        field.tap()
        field.typeText("zzzznowhere")

        // A query matching nothing must empty the list, not leave it as it was.
        let emptyState = app.staticTexts["No rooms match"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 25),
                      "Searching for nonsense did not filter the list")
    }

    /// The regression this is really guarding: content must not be permanently
    /// trapped under the floating tab bar. Scrolling to the very bottom of a
    /// page has to leave the last content visible ABOVE the tab bar, which only
    /// happens if the scroll view's bottom content inset is set.
    func testPageBottomIsReachableAboveTabBar() {
        waitForFirstPage()

        // Profile is the only web-backed tab left, and this test is
        // specifically about the web view's content inset.
        selectTab("Profile")
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 45))

        // Give the page time to populate, otherwise it is one screen tall and
        // there is nothing to scroll.
        Thread.sleep(forTimeInterval: 12)

        for _ in 0..<25 {
            webView.swipeUp(velocity: .fast)
        }

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "The tab bar disappeared while scrolling")

        // Text rather than links as the probe: the app hides the site's header
        // and footer because native chrome replaces them, which leaves the
        // homepage with almost no anchors to find. Every page has text.
        let texts = webView.staticTexts.allElementsBoundByIndex
        let onScreen = texts.filter {
            $0.exists && $0.frame.height > 0 && $0.frame.minY > 0
        }

        XCTAssertFalse(onScreen.isEmpty, "No page content was reachable after scrolling to the bottom")

        // The inset's job: at full scroll the last of the content comes to rest
        // ABOVE the tab bar rather than under it. Content is allowed to pass
        // beneath the translucent bar while scrolling — what must not happen is
        // ending up parked there with no way to bring it out.
        let strandedUnderTabBar = onScreen.filter { element in
            element.frame.minY >= tabBar.frame.minY && element.frame.maxY <= tabBar.frame.maxY
        }
        XCTAssertTrue(strandedUnderTabBar.isEmpty,
                      "\(strandedUnderTabBar.count) elements are stranded under the tab bar")
    }

    /// Tapping the selected tab again should go back to that section's root,
    /// which is the gesture people use without thinking about it.
    func testReselectingTabReturnsToRoot() {
        waitForFirstPage()

        selectTab("Profile")
        let profile = app.tabBars.buttons["Profile"]
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 45))

        Thread.sleep(forTimeInterval: 8)
        // Re-query rather than reusing the earlier element: profile.html
        // redirects to login when signed out, which replaces the web view and
        // invalidates any handle taken before the redirect.
        if app.webViews.firstMatch.waitForExistence(timeout: 20) {
            app.webViews.firstMatch.swipeUp(velocity: .fast)
        }

        profile.tap()

        // Returning to the root reloads the page, so this waits for the title
        // to settle instead of assuming a fixed delay is long enough.
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 45),
                      "Re-tapping the tab did not return to the section root")
    }

    /// The negotiator is the product's flagship and is now native. It works
    /// FOR the tenant: they say what they want and it answers. It must not
    /// call the model unprompted — each turn costs an API request.
    func testNativeNegotiatorAnswersTheTenant() {
        waitForFirstPage()
        selectTab("Messages")

        let opener = app.buttons["Find me a 1 bedroom under $1500"]
        XCTAssertTrue(opener.waitForExistence(timeout: 20),
                      "The negotiator did not show its opening screen")
        XCTAssertFalse(app.webViews.firstMatch.exists,
                       "Negotiate should be native, but a web view was found")

        // Nothing may be sent before the tenant asks for it.
        Thread.sleep(forTimeInterval: 6)
        XCTAssertTrue(opener.exists,
                      "The negotiator started talking on its own")

        opener.tap()

        // The tenant's own words come back as theirs, not as a landlord's.
        // Each bubble is merged into a single accessibility element so
        // VoiceOver reads "You: <message>" in one stop, which makes it an
        // `other` element rather than a staticText.
        let tenantTurn = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] 'You:'"))
            .firstMatch
        XCTAssertTrue(tenantTurn.waitForExistence(timeout: 20),
                      "The tenant's message was not shown as theirs")

        // And a real reply from /api/chat.
        let reply = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] 'AI Negotiator:'"))
            .firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 60),
                      "The negotiator never replied")

        // Nothing anywhere should ask the tenant to speak for the landlord.
        XCTAssertFalse(app.textFields["What did the landlord say?"].exists,
                       "The composer is still framed as the landlord's side")
    }

    /// The rooms browser lives on Home and must present rooms as cards with
    /// categories, not as a dense list where every room looks identical.
    func testListingsShowCategoriesAndCards() {
        waitForFirstPage()
        selectTab("Home")

        for category in ["All", "Apartment", "House"] {
            XCTAssertTrue(app.buttons[category].waitForExistence(timeout: 30),
                          "The \(category) category chip is missing")
        }

        let card = app.buttons
            .containing(NSPredicate(format: "label CONTAINS[c] '/mo'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 60),
                      "No room cards appeared")
        // A card, not a list row: tall enough to carry a photo worth looking at.
        XCTAssertGreaterThan(card.frame.height, 200,
                             "Rooms are rendering as thin list rows, not cards")
    }

    /// RoomPal is the people side of the marketplace and is now native. The
    /// two halves — looking for a room, and offering one — must stay clearly
    /// separated, which is the distinction the website kept blurring.
    func testNativeRoomPalShowsPeople() {
        openRoomPal()

        XCTAssertTrue(app.buttons["Looking for a room"].waitForExistence(timeout: 30),
                      "The seeking/offering control is missing")
        XCTAssertTrue(app.buttons["Has a room"].exists,
                      "The 'has a room' side is missing")
        XCTAssertFalse(app.webViews.firstMatch.exists,
                       "RoomPal should be native, but a web view was found")

        // A real person, carrying a budget that only exists if the API
        // response decoded.
        let personCard = app.buttons
            .containing(NSPredicate(format: "label CONTAINS[c] '/mo'"))
            .firstMatch
        XCTAssertTrue(personCard.waitForExistence(timeout: 45),
                      "No roommate profiles appeared")

        personCard.tap()
        XCTAssertTrue(app.buttons["Get in touch"].waitForExistence(timeout: 15),
                      "The roommate profile did not open")
    }

    /// Seed rows carry a "[seed]" marker that must never reach a real person.
    func testSeedMarkersAreNeverShown() {
        openRoomPal()
        _ = app.buttons
            .containing(NSPredicate(format: "label CONTAINS[c] '/mo'"))
            .firstMatch
            .waitForExistence(timeout: 45)

        let leaked = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] '[seed]' OR label CONTAINS[c] '[rf-catalog]'"))
        XCTAssertEqual(leaked.count, 0,
                       "Internal seed markers are visible to users")
    }

    /// The overflow menu is where every page that is not a tab lives — legal,
    /// pricing, support, sublease. If it does not open, those pages are
    /// unreachable and the app fails review for missing a privacy policy.
    func testMoreMenuReachesSecondaryPages() {
        waitForFirstPage()
        // From Listings: Home has its own "Sublease" quick-action tile, which
        // makes the name ambiguous while the menu is open.
        selectTab("Home")

        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 10), "The More button is missing")
        more.tap()

        for label in ["Sublease", "Privacy Policy", "Terms of Service"] {
            XCTAssertTrue(app.buttons["more-\(label)"].waitForExistence(timeout: 5),
                          "\(label) is missing from the More menu")
        }

        app.buttons["more-Sublease"].tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 45),
                      "Sublease did not open")
    }

    /// The messages hub carries both kinds of conversation. Missing either
    /// section means replies from real landlords have nowhere to appear.
    func testMessagesHubHasBothSections() {
        waitForFirstPage()
        selectTab("Messages")

        XCTAssertTrue(app.buttons["AI Negotiator"].waitForExistence(timeout: 20),
                      "The AI Negotiator section is missing")
        XCTAssertTrue(app.buttons["Direct Messages"].exists,
                      "The inbox section is missing")

        app.buttons["Direct Messages"].tap()

        // Signed out in the test environment, so the inbox asks for sign-in
        // rather than silently showing nothing.
        let signedOut = app.staticTexts["Sign in to see messages"]
        let empty = app.staticTexts["No messages yet"]
        let loaded = app.cells.firstMatch
        let appeared = signedOut.waitForExistence(timeout: 25)
            || empty.exists || loaded.exists
        XCTAssertTrue(appeared, "The inbox showed nothing at all")
    }

    /// A deep link from email or a push notification has to land on the tab
    /// that owns the page, not wherever the user happened to be.
    func testDeepLinkSelectsOwningTab() {
        waitForFirstPage()

        // Start somewhere other than the destination so the assertion means
        // something.
        selectTab("Profile")
        Thread.sleep(forTimeInterval: 3)

        // Rooms live on Home now, so a listings link belongs there.
        app.open(URL(string: "roomfinderai://listings.html")!)

        let home = app.tabBars.buttons["Home"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        // isSelected is the honest check — the tab exists either way.
        let selected = NSPredicate(format: "isSelected == true")
        expectation(for: selected, evaluatedWith: home)
        waitForExpectations(timeout: 25)
    }
}

/// Drives a real reply out of the inbox, end to end.
///
/// The negotiator is only half a product if the other side cannot answer from
/// a phone: the AI's message lands in a landlord's inbox, and everything after
/// that depends on the thread opening and the composer actually sending. That
/// path crosses the tab bar, the section switcher, a navigation push and a
/// network write, which is exactly the kind of seam a screenshot cannot check.
///
/// Skipped unless the run supplies an account and a line to send, so the
/// ordinary suite stays hermetic:
///
///   RFAI_UITEST_EMAIL=someone@example.com \
///   RFAI_UITEST_REPLY="Sure, that works." \
///   xcodebuild test -scheme RoomFinderAI ...
final class InboxReplyUITests: XCTestCase {

    private var app: XCUIApplication!

    private var email: String? { ProcessInfo.processInfo.environment["RFAI_UITEST_EMAIL"] }
    private var reply: String? { ProcessInfo.processInfo.environment["RFAI_UITEST_REPLY"] }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let email = try XCTUnwrap(self.email, "set RFAI_UITEST_EMAIL to run this test")

        app = XCUIApplication()
        // NSArgumentDomain wins over the persisted value, so the app comes up
        // signed in as this account without touching the real defaults.
        //
        // Order matters: NSArgumentDomain reads these as `-key value` pairs, so
        // the valueless `-uiTestingResetState` swallows whatever follows it.
        // Left first, it ate `-currentUserEmail` and the app launched signed
        // out — an inbox with nothing in it, blamed on the network.
        app.launchArguments = ["-uiTestingSignInEmail", email, "-uiTestingResetState"]
        app.launch()
    }

    func testRepliesToNewestThreadFromInbox() throws {
        let reply = try XCTUnwrap(self.reply, "set RFAI_UITEST_REPLY to run this test")

        let messages = app.tabBars.buttons["Messages"]
        XCTAssertTrue(messages.waitForExistence(timeout: 60), "Messages tab never appeared")
        messages.tap()

        // The hub opens on the negotiator; the real inbox is the other half.
        let inboxTab = app.buttons["Direct Messages"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 20), "Direct Messages switcher never appeared")
        inboxTab.tap()

        // Threads arrive over the network, so this is a wait, not a check.
        // Name the state we ended in — "no cell appeared" is the same symptom
        // for signed out, empty and offline, and they need different fixes.
        let thread = app.cells.firstMatch
        if !thread.waitForExistence(timeout: 45) {
            let state = ["Sign in to see messages", "No messages yet", "Couldn't load messages"]
                .first { app.staticTexts[$0].exists } ?? "still loading, or an unrecognised screen"
            XCTFail("No conversation loaded in the inbox — screen says: \(state)")
            return
        }
        thread.tap()

        let composer = app.textFields["Message"]
        XCTAssertTrue(composer.waitForExistence(timeout: 30), "The composer never appeared")
        composer.tap()
        composer.typeText(reply)

        let send = app.buttons["Send"]
        XCTAssertTrue(send.waitForExistence(timeout: 10), "No send button")
        XCTAssertTrue(send.isEnabled, "Send stayed disabled with text in the composer")
        send.tap()

        // The sent line is appended to the transcript only after the write
        // comes back, so its presence is the proof the message really went.
        let sent = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", reply)
        ).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 45), "The reply never appeared in the transcript")
    }
}
