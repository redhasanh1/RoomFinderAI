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

    /// Waits out the splash and the first page load.
    private func waitForFirstPage() {
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 45),
                      "The home page never rendered")
    }

    func testAllFiveTabsLoadContent() {
        waitForFirstPage()

        // Listings is native and is covered by its own test below; the rest
        // render the site.
        for name in ["Negotiate", "RoomPal", "Profile", "Home"] {
            let tab = app.tabBars.buttons[name]
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "\(name) tab is missing")
            tab.tap()

            let webView = app.webViews.firstMatch
            XCTAssertTrue(webView.waitForExistence(timeout: 45),
                          "\(name) never produced a web view")

            // A web view that exists but has no size is a blank tab.
            XCTAssertGreaterThan(webView.frame.height, 200,
                                 "\(name) rendered a web view with no usable height")
        }
    }

    /// The native Listings tab must fetch real rooms from the API and let one
    /// be opened. This is the app's primary task and the part that is not a
    /// web page, so it gets checked end to end.
    func testNativeListingsLoadAndOpen() {
        waitForFirstPage()

        app.tabBars.buttons["Listings"].tap()

        // Matched on the price rather than taken as `cells.firstMatch`: the
        // section header ("9 rooms") is itself exposed as a cell, and tapping
        // that does nothing. Requiring "/mo" also proves the API response was
        // decoded, since the price only exists if it was.
        // `containing` matches on descendants, which holds whether or not the
        // row's children are merged into a single accessibility element.
        let pricedRow = app.cells
            .containing(NSPredicate(format: "label CONTAINS[c] '/mo'"))
            .firstMatch

        if !pricedRow.waitForExistence(timeout: 60) {
            // Say which failure this was. "No rows" with the error screen up is
            // the API not answering; "no rows" without it is the screen never
            // finishing its load; rows without prices is a decoding problem.
            let sawError = app.staticTexts["Couldn't load rooms"].exists
            let cellCount = app.cells.count
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
        app.tabBars.buttons["Listings"].tap()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 45))
        let unfilteredCount = app.cells.count
        XCTAssertGreaterThan(unfilteredCount, 0)

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

        // Home rather than Listings: Listings is native now, and this test is
        // specifically about the web view's content inset.
        app.tabBars.buttons["Home"].tap()
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

        let negotiate = app.tabBars.buttons["Negotiate"]
        negotiate.tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 45))

        Thread.sleep(forTimeInterval: 8)
        app.webViews.firstMatch.swipeUp(velocity: .fast)
        app.webViews.firstMatch.swipeUp(velocity: .fast)

        negotiate.tap()
        Thread.sleep(forTimeInterval: 3)

        // Back at the root, the navigation bar shows the tab's own name rather
        // than a page title.
        XCTAssertTrue(app.navigationBars["Negotiate"].exists,
                      "Re-tapping the tab did not return to the section root")
    }

    /// The overflow menu is where every page that is not a tab lives — legal,
    /// pricing, support, sublease. If it does not open, those pages are
    /// unreachable and the app fails review for missing a privacy policy.
    func testMoreMenuReachesSecondaryPages() {
        waitForFirstPage()

        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 10), "The More button is missing")
        more.tap()

        for label in ["Share", "Refresh", "Sublease", "Privacy Policy", "Terms of Service"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5),
                          "\(label) is missing from the More menu")
        }

        app.buttons["Sublease"].tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 45),
                      "Sublease did not open")
    }

    /// A deep link from email or a push notification has to land on the tab
    /// that owns the page, not wherever the user happened to be.
    func testDeepLinkSelectsOwningTab() {
        waitForFirstPage()

        // Start somewhere other than the destination so the assertion means
        // something.
        app.tabBars.buttons["Profile"].tap()
        Thread.sleep(forTimeInterval: 3)

        app.open(URL(string: "roomfinderai://roommate-matching.html")!)

        let roompal = app.tabBars.buttons["RoomPal"]
        XCTAssertTrue(roompal.waitForExistence(timeout: 15))
        // isSelected is the honest check — the tab exists either way.
        let selected = NSPredicate(format: "isSelected == true")
        expectation(for: selected, evaluatedWith: roompal)
        waitForExpectations(timeout: 20)
    }
}
