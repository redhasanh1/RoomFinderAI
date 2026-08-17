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

        for name in ["Listings", "Negotiate", "RoomPal", "Profile", "Home"] {
            let tab = app.tabBars.buttons[name]
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "\(name) tab is missing")
            tab.tap()

            // Each tab owns its own web view and loads it on first appearance.
            let webView = app.webViews.firstMatch
            XCTAssertTrue(webView.waitForExistence(timeout: 45),
                          "\(name) never produced a web view")

            // A web view that exists but has no size is a blank tab.
            XCTAssertGreaterThan(webView.frame.height, 200,
                                 "\(name) rendered a web view with no usable height")
        }
    }

    /// The regression this is really guarding: content must not be permanently
    /// trapped under the floating tab bar. Scrolling to the very bottom of a
    /// page has to leave the last content visible ABOVE the tab bar, which only
    /// happens if the scroll view's bottom content inset is set.
    func testPageBottomIsReachableAboveTabBar() {
        waitForFirstPage()

        app.tabBars.buttons["Listings"].tap()
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 45))

        // Give the listings time to populate, otherwise the page is one screen
        // tall and there is nothing to scroll.
        Thread.sleep(forTimeInterval: 12)

        for _ in 0..<25 {
            webView.swipeUp(velocity: .fast)
        }

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "The tab bar disappeared while scrolling")

        // Any element the page still shows must not be sitting underneath the
        // tab bar's frame. Links are used as the probe because every page has
        // several and they are the things people need to tap.
        let links = webView.links.allElementsBoundByIndex
        let visibleLinks = links.filter { $0.exists && $0.frame.height > 0 && $0.frame.minY > 0 }

        XCTAssertFalse(visibleLinks.isEmpty, "No links were reachable after scrolling to the bottom")

        let hiddenUnderTabBar = visibleLinks.filter { link in
            // Fully swallowed by the tab bar, not merely overlapping its glass.
            link.frame.minY >= tabBar.frame.minY && link.frame.maxY <= tabBar.frame.maxY
        }
        XCTAssertTrue(hiddenUnderTabBar.isEmpty,
                      "\(hiddenUnderTabBar.count) tappable elements are stranded under the tab bar")
    }

    /// Tapping the selected tab again should go back to that section's root,
    /// which is the gesture people use without thinking about it.
    func testReselectingTabReturnsToRoot() {
        waitForFirstPage()

        let listings = app.tabBars.buttons["Listings"]
        listings.tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 45))

        Thread.sleep(forTimeInterval: 8)
        app.webViews.firstMatch.swipeUp(velocity: .fast)
        app.webViews.firstMatch.swipeUp(velocity: .fast)

        listings.tap()
        Thread.sleep(forTimeInterval: 3)

        // Back at the root, the navigation bar shows the tab's own name rather
        // than a page title, and no back button is offered.
        XCTAssertTrue(app.navigationBars["Listings"].exists,
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
