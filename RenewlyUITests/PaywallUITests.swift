import StoreKitTest
import XCTest

/// Drives the free-plan limit → paywall → purchase flow against the local Renewly.storekit configuration.
final class PaywallUITests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        continueAfterFailure = false
        session = try SKTestSession(configurationFileNamed: "Renewly")
        session.disableDialogs = true
        session.clearTransactions()
    }

    @MainActor
    func testLimitShowsPaywallAndPurchaseUnlocksPro() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSampleData", "-selectedTab", "0"]
        app.launch()

        // Sample data puts the free plan over its limit, so adding opens the paywall instead of the editor.
        app.buttons["Add subscription"].firstMatch.tap()
        let purchase = app.buttons["paywall.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Renewly Pro"].exists)
        XCTAssertTrue(app.buttons["Restore Purchases"].exists)

        let priced = NSPredicate(format: "label BEGINSWITH 'Unlock for'")
        expectation(for: priced, evaluatedWith: purchase)
        waitForExpectations(timeout: 10)
        attach(app, "1-paywall-limit")

        purchase.tap()
        XCTAssertTrue(app.staticTexts["You're Pro!"].waitForExistence(timeout: 10))
        attach(app, "2-purchased")

        // Pro lifts the limit: the + button now opens the editor.
        purchase.tap()
        app.buttons["Add subscription"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New subscription"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Unlocked. Thanks for your support!"].waitForExistence(timeout: 5))
        attach(app, "3-settings-pro")
    }

    @MainActor
    func testFreePlanLocksInsightsAndOffersUpgradeInSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSampleData", "-selectedTab", "1"]
        app.launch()

        let unlock = app.buttons["Unlock Insights"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        attach(app, "4-insights-locked")

        app.tabBars.buttons["Settings"].tap()
        let upgrade = app.buttons["settings.upgrade"]
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
        attach(app, "5-settings-free")
        upgrade.tap()
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
