import XCTest

final class SaathiFlowUITests: XCTestCase {
    private var framesOutputDir: String? {
        ProcessInfo.processInfo.environment["SAATHI_FRAMES_OUT"]
    }

    func testWalkFlowAndCaptureKeyFrames() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MockMode"]
        app.launch()

        // 1. Onboarding / permissions screen
        XCTAssertTrue(app.buttons["startWalkButton"].waitForExistence(timeout: 5))
        saveFrame(app: app, filename: "01_onboarding_permissions.png")

        // Open Language Picker frame
        app.buttons["openLanguagePickerButton"].tap()
        XCTAssertTrue(app.navigationBars["Languages"].waitForExistence(timeout: 3))
        saveFrame(app: app, filename: "08_language_picker.png")
        app.buttons["Done"].tap()

        // Start session
        app.buttons["startWalkButton"].tap()

        // 2. Live voice mode session + narration card appears; open-ended clock, live walk stats
        XCTAssertTrue(narrationCard(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(element(in: app, id: "elapsedLabel").exists)
        XCTAssertTrue(element(in: app, id: "liveWalkStats").exists)
        saveFrame(app: app, filename: "02_live_voice_session.png")

        // 3. Toggle Touch Mode for citations card stream.
        // In an iOS 26 toolbar a Toggle is exposed as a button, not a switch.
        element(in: app, id: "liveTouchModeToggle").tap()
        saveFrame(app: app, filename: "03_touch_mode_citations.png")

        // 4. Nearby places map (no path trail)
        app.buttons["toggleMapButton"].tap()
        XCTAssertTrue(element(in: app, id: "nearbyPlacesMap").waitForExistence(timeout: 5))
        saveFrame(app: app, filename: "04_nearby_map.png")
        app.buttons["toggleMapButton"].tap()

        // Skip -> Quiet
        app.buttons["skipButton"].tap()
        app.buttons["quietButton"].tap()
        XCTAssertTrue(element(in: app, id: "quietBanner").waitForExistence(timeout: 5))
        saveFrame(app: app, filename: "05_quiet_mode.png")

        // End -> Privacy Receipt shows 0 coordinates
        app.buttons["endSessionButton"].tap()
        let coordValue = app.staticTexts["coordinatesStoredValue"]
        XCTAssertTrue(coordValue.waitForExistence(timeout: 5))
        XCTAssertEqual(coordValue.label, "0")
        saveFrame(app: app, filename: "06_privacy_receipt.png")

        // Continue to Memory Episode -> Discard
        app.buttons["continueToEpisodeButton"].tap()
        XCTAssertTrue(app.buttons["discardEpisodeButton"].waitForExistence(timeout: 5))
        // The episode carries the walk totals (distance, time, steps).
        XCTAssertTrue(element(in: app, id: "walkSummaryCard").waitForExistence(timeout: 3))
        saveFrame(app: app, filename: "07_episode_player.png")
        app.buttons["discardEpisodeButton"].tap()
        XCTAssertTrue(app.buttons["startWalkButton"].waitForExistence(timeout: 5))
    }

    /// Real-time companion: the simulated walk moves along the Hampi GPX route; after the
    /// landmarks, Saathi keeps talking about the wider area instead of going silent.
    func testCompanionKeepsTalkingBetweenLandmarks() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MockMode", "-AutoStart"]
        app.launch()
        XCTAssertTrue(narrationCard(in: app).waitForExistence(timeout: 10))

        let areaIDs = ["narrationCard_hampi_tungabhadra", "narrationCard_hampi_matanga_hill", "narrationCard_hampi_virupaksha"]
        let areaCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@", areaIDs))
            .firstMatch
        XCTAssertTrue(areaCard.waitForExistence(timeout: 60))
        saveFrame(app: app, filename: "12_companion_around_you.png")
    }

    func testHindiLiveSessionSnapshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MockMode", "-Language", "hi-IN", "-AutoStart"]
        app.launch()
        XCTAssertTrue(narrationCard(in: app).waitForExistence(timeout: 10))
        saveFrame(app: app, filename: "09_hindi_live_session.png")
    }

    func testTamilTouchModeSnapshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MockMode", "-Language", "ta-IN", "-AutoStart"]
        app.launch()
        XCTAssertTrue(narrationCard(in: app).waitForExistence(timeout: 10))
        element(in: app, id: "liveTouchModeToggle").tap()
        saveFrame(app: app, filename: "10_tamil_touch_mode.png")
    }

    func testUrduRTLLayoutSnapshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MockMode", "-Language", "ur-IN", "-AutoStart"]
        app.launch()
        XCTAssertTrue(narrationCard(in: app).waitForExistence(timeout: 10))
        saveFrame(app: app, filename: "11_urdu_rtl_screen.png")
    }

    func testPseudoLocalizationOverflowCheck() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-MockMode", "-NSDoubleLocalizedStrings", "YES"]
        app.launch()
        let start = app.buttons["startWalkButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        // The button sits below the fold on small screens; doubled strings must not make it unreachable.
        var swipes = 0
        while !start.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(start.isHittable)
    }

    /// Narration cards combine their children for VoiceOver, so match by identifier on any element type.
    private func narrationCard(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'narrationCard_'"))
            .firstMatch
    }

    private func element(in app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func saveFrame(app: XCUIApplication, filename: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)

        if let dir = framesOutputDir {
            let url = URL(fileURLWithPath: dir).appendingPathComponent(filename)
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}
