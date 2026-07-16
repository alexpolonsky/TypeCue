import ApplicationServices
import XCTest

@MainActor
final class TypeCueUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extraArgs: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST"] + extraArgs
        app.launch()
        return app
    }

    func testEditorScriptAndBlockCRUD() {
        let app = launch(["UITEST_OPEN_EDITOR"])

        let window = app.windows["TypeCue"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Main window should open")

        // Create a script.
        app.buttons["addScriptButton"].click()

        let nameField = app.textFields["scriptNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "New script should be selected and editable")

        // Rename it.
        nameField.click()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("Demo One")
        XCTAssertEqual(nameField.value as? String, "Demo One")

        // Add a second block (the new script starts with one).
        app.buttons["addBlockButton"].click()

        // Two "Block N" labels should now be visible.
        XCTAssertTrue(app.staticTexts["Block 1"].exists)
        XCTAssertTrue(app.staticTexts["Block 2"].waitForExistence(timeout: 3))
    }

    /// Automated accessibility audit of the editor window (contrast, labels, hit regions,
    /// clipping, etc.). Requires an interactive GUI runner.
    func testEditorAccessibilityAudit() throws {
        let app = launch(["UITEST_OPEN_EDITOR"])
        XCTAssertTrue(app.windows["TypeCue"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    /// Automated accessibility audit of the onboarding window. Requires an interactive GUI runner.
    func testOnboardingAccessibilityAudit() throws {
        let app = launch(["UITEST_OPEN_ONBOARDING"])
        XCTAssertTrue(app.windows["Welcome to TypeCue"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    func testOnboardingShowsPermissionAndTestPad() {
        let app = launch(["UITEST_OPEN_ONBOARDING"])

        let window = app.windows["Welcome to TypeCue"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Onboarding window should open")

        // The flow opens on the "What is TypeCue" step; advance to the permission step.
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3), "Continue should advance the flow")
        continueButton.click()

        XCTAssertTrue(app.staticTexts["permissionStatus"].waitForExistence(timeout: 3), "Permission status should be shown")
        XCTAssertTrue(app.textFields["testPadField"].exists, "Test Pad field should be present")
        XCTAssertTrue(app.buttons["testTypeButton"].exists, "Test Type button should be present")
    }

    /// End-to-end typing smoke test. Requires the test runner to have Accessibility
    /// permission (local machine only); skipped otherwise, per the testing strategy.
    func testEndToEndTypingIntoTestPad() throws {
        try XCTSkipUnless(AXIsProcessTrusted(), "Accessibility not granted to the test runner; skipping live typing test")

        let app = launch(["UITEST_OPEN_ONBOARDING"])
        let window = app.windows["Welcome to TypeCue"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        continueButton.click()

        let field = app.textFields["testPadField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.click()

        app.buttons["testTypeButton"].click()

        // The engine types "TypeCue works!" into the focused field.
        let verified = app.images["testVerified"]
        XCTAssertTrue(verified.waitForExistence(timeout: 5), "Typed text should match the expected string")
    }
}
