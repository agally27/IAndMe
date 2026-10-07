import XCTest

/// The primary journey: launch → onboarding → capture → journal → open moment → companion → memories → story.
/// Screenshots are written to the directory named by the SCREENSHOT_DIR environment variable when set.
final class PrimaryJourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
    }

    func testOnboardingCaptureAndExplore() {
        app.launch()
        snapshot("01-onboarding")

        // Onboarding
        let begin = app.buttons["onboarding.begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.tap()
        let nameField = app.textFields["onboarding.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Alex")
        app.buttons["onboarding.continue"].tap()
        let fresh = app.buttons["onboarding.fresh"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 5))
        fresh.tap()
        snapshot("02-onboarding-choice")
        app.buttons["onboarding.finish"].tap()

        // Today, first run
        XCTAssertTrue(app.otherElements["today.header"].waitForExistence(timeout: 8) || app.staticTexts["Capture your first moment"].waitForExistence(timeout: 8))
        snapshot("03-today-first-run")

        // Capture a moment via the accessory
        let captureButton = app.buttons["capture.accessory"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5))
        captureButton.tap()
        let editor = waitForEither(app.textViews["capture.text"].firstMatch, app.textFields["capture.text"].firstMatch)
        XCTAssertNotNil(editor)
        guard let editor else { return }
        editor.tap()
        editor.typeText("Walked the harbour with Hannah after a heavy day at work. The water did its gold thing.")
        let good = app.buttons["capture.feeling.good"]
        if good.exists { good.tap() }
        snapshot("04-capture")
        app.buttons["capture.save"].tap()

        // Journal shows the moment
        app.tabBars.buttons["Journal"].tap()
        let entry = app.buttons["journal.entry"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        snapshot("05-journal")
        entry.tap()
        XCTAssertTrue(app.staticTexts["entry.text"].waitForExistence(timeout: 5))
        snapshot("06-entry")

        // Companion from the moment
        let talk = app.buttons["entry.talk"]
        XCTAssertTrue(talk.waitForExistence(timeout: 5))
        talk.tap()
        let input = waitForEither(app.textFields["conversation.input"].firstMatch, app.textViews["conversation.input"].firstMatch, timeout: 10)
        XCTAssertNotNil(input)
        guard let input else { return }
        input.tap()
        input.typeText("Why did that walk help?")
        app.buttons["conversation.send"].tap()
        // Wait for a reply beyond the opening + the user's message.
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Companion:'")
        let replies = app.descendants(matching: .any).matching(predicate)
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count >= 2"), object: replies)
        wait(for: [expectation], timeout: 15)
        snapshot("07-companion")

        // Leave the conversation (which also dismisses the keyboard) before switching tabs.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.tabBars.buttons["Memories"].waitForExistence(timeout: 5))

        // Memories and Story
        app.tabBars.buttons["Memories"].tap()
        XCTAssertTrue(app.staticTexts["Memories"].waitForExistence(timeout: 5))
        snapshot("08-memories")
        app.tabBars.buttons["Story"].tap()
        XCTAssertTrue(app.staticTexts["My Story"].waitForExistence(timeout: 5))
        snapshot("09-story")
    }

    func testSampleLifeScreens() {
        app.launchArguments += ["-seed-sample"]
        app.launch()
        XCTAssertTrue(app.buttons["capture.accessory"].waitForExistence(timeout: 10))
        snapshot("10-sample-today")
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["journal.entry"].firstMatch.waitForExistence(timeout: 8))
        snapshot("11-sample-journal")
        app.buttons["journal.entry"].firstMatch.tap()
        XCTAssertTrue(app.buttons["entry.talk"].waitForExistence(timeout: 5))
        snapshot("12-sample-entry")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Companion"].tap()
        XCTAssertTrue(app.buttons["companion.starter"].firstMatch.waitForExistence(timeout: 5))
        snapshot("13-sample-companion")
        app.buttons["companion.starter"].firstMatch.tap()
        XCTAssertNotNil(waitForEither(app.textFields["conversation.input"].firstMatch, app.textViews["conversation.input"].firstMatch, timeout: 10))
        sleep(2)
        snapshot("14-sample-conversation")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Memories"].tap()
        XCTAssertTrue(app.staticTexts["Memories"].waitForExistence(timeout: 5))
        snapshot("15-sample-memories")
        app.tabBars.buttons["Story"].tap()
        XCTAssertTrue(app.staticTexts["My Story"].waitForExistence(timeout: 5))
        snapshot("16-sample-story")
        let chapter = app.staticTexts["A Different Kind of Year"].firstMatch
        if chapter.waitForExistence(timeout: 3) {
            chapter.tap()
            sleep(1)
            snapshot("17-sample-chapter")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.tabBars.buttons["Today"].tap()
        let all = app.buttons["All observations"].firstMatch
        if all.waitForExistence(timeout: 3) {
            all.tap()
            sleep(1)
            snapshot("18-sample-insights")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.buttons["today.profile"].tap()
        sleep(1)
        snapshot("19-sample-profile")
    }

    /// SwiftUI exposes a multi-line TextField as either a text field or a text view depending on state.
    private func waitForEither(_ a: XCUIElement, _ b: XCUIElement, timeout: TimeInterval = 6) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if a.exists { return a }
            if b.exists { return b }
            usleep(200_000)
        }
        return nil
    }

    private func snapshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}

/// Records a short voice moment and keeps it. Grant the microphone first:
/// `xcrun simctl privacy booted grant microphone com.iandme.prototype`.
final class VoiceMomentUITests: XCTestCase {
    func testRecordAndKeepVoiceMoment() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-seed-sample"]
        app.launch()
        addUIInterruptionMonitor(withDescription: "Microphone permission") { alert in
            for title in ["Allow", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        XCTAssertTrue(app.buttons["capture.accessory.voice"].waitForExistence(timeout: 10))
        app.buttons["capture.accessory.voice"].tap()
        let start = app.buttons["recorder.start"]
        let stop = app.buttons["recorder.stop"]
        let failed = app.staticTexts["recorder.failed"]
        if !stop.waitForExistence(timeout: 3) && !failed.exists {
            if start.waitForExistence(timeout: 5) {
                start.tap()
                app.tap()
            }
        }
        // The Simulator's microphone may never come up (a macOS prompt nobody can answer). In that
        // case the app must stay responsive and say so; on a device recording proceeds.
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline, !stop.exists, !failed.exists { usleep(300_000) }
        if failed.exists {
            save(app, "20-recorder-unavailable")
            XCTAssertTrue(app.buttons["Cancel"].firstMatch.exists)
            app.buttons["Cancel"].firstMatch.tap()
            XCTAssertTrue(app.buttons["capture.cancel"].waitForExistence(timeout: 5))
            app.buttons["capture.cancel"].tap()
            XCTAssertTrue(app.buttons["capture.accessory.voice"].waitForExistence(timeout: 5))
            return
        }
        XCTAssertTrue(stop.exists)
        sleep(2)
        save(app, "20-recording")
        stop.tap()
        let keep = app.buttons["recorder.keep"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        save(app, "21-recording-review")
        keep.tap()
        let saveButton = app.buttons["capture.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        save(app, "22-capture-with-voice")
        saveButton.tap()
        app.tabBars.buttons["Journal"].tap()
        let withVoice = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] '1 voice recording'")).firstMatch
        XCTAssertTrue(withVoice.waitForExistence(timeout: 8))
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}
