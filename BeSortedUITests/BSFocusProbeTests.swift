import XCTest

final class BSFocusProbeTests: XCTestCase {
    func testOpenTaskFocusAndCapture() throws {
        print("PROBE_EVIDENCE_ID \(Self.evidenceID)")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2.0)
        let app = XCUIApplication()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 8)

        dismissSheetIfPresent(app)
        Thread.sleep(forTimeInterval: 1.0)
        attach("tree_launch", app.debugDescription)

        // 1) Open a project from home.
        let projectTile = app.buttons.allElementsBoundByIndex
            .first { $0.frame.width > 300 && $0.frame.height > 100 && $0.frame.origin.x < 60 }
        guard let projectTile else {
            XCTFail("brak kafelka projektu na home")
            return
        }
        projectTile.tap()
        Thread.sleep(forTimeInterval: 1.2)
        dismissSheetIfPresent(app)
        attach("tree_detail", app.debugDescription)

        // 2) Tap a task tile inside the project detail.
        let taskText: XCUIElement? =
            app.staticTexts["Poprawka"].firstMatch.exists
                ? app.staticTexts["Poprawka"].firstMatch
                : app.staticTexts.allElementsBoundByIndex.first { isTaskNameText($0) }
        guard let taskText, taskText.exists else {
            attach("tree_no_task", app.debugDescription)
            XCTFail("brak wiersza zadania w detalu")
            return
        }
        taskText.tap()
        Thread.sleep(forTimeInterval: 1.3)

        let focusButtons = ["Edytuj", "Usuń", "Priorytet", "Zadanie jest zrobione"]
        guard focusButtons.contains(where: { app.buttons[$0].exists }) else {
            attach("tree_no_focus", app.debugDescription)
            XCTFail("nie otwarto podglądu zadania")
            return
        }

        Thread.sleep(forTimeInterval: 0.8)
        attach("tree_focus_overlay", app.debugDescription)

        let shot = app.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = "png_focus_overlay"
        a.lifetime = .keepAlways
        add(a)
        saveToDisk("png_focus_overlay", shot.pngRepresentation)

        // 3) Repeat in landscape.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 3.0)

        let taskText2 = app.staticTexts["Poprawka"].firstMatch
        if taskText2.exists {
            taskText2.tap()
            Thread.sleep(forTimeInterval: 1.3)
            if focusButtons.contains(where: { app.buttons[$0].exists }) {
                Thread.sleep(forTimeInterval: 0.6)
                attach("tree_focus_overlay_land", app.debugDescription)
                let shot2 = app.screenshot()
                let a2 = XCTAttachment(screenshot: shot2)
                a2.name = "png_focus_overlay_land"
                a2.lifetime = .keepAlways
                add(a2)
                saveToDisk("png_focus_overlay_land", shot2.pngRepresentation)
            }
        }
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.0)
    }

    private func isTaskNameText(_ el: XCUIElement) -> Bool {
        let label = el.label
        guard label.count > 0, label.count < 60 else { return false }
        if label == "Z" || label == "Dodaj zadanie" || label == "Moje projekty" { return false }
        let banned = ["Poprawka", "W aktualnym planie", "Kluczowe zadanie", "Sheet Grabber"]
        if banned.contains(label) { return false }
        let frame = el.frame
        return frame.width > 30 && frame.width < 120 && frame.height > 12 && frame.height < 40
            && frame.minX > 25 && frame.minX < 60 && frame.minY > 300
    }

    private func dismissSheetIfPresent(_ app: XCUIApplication) {
        if app.buttons["Sheet Grabber"].exists {
            app.buttons["Sheet Grabber"].swipeDown(velocity: .fast)
            Thread.sleep(forTimeInterval: 0.8)
        }
        if app.buttons["cancel"].exists || app.staticTexts["Anuluj"].exists {
            app.buttons.firstMatch.tap()
        }
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func attach(_ name: String, _ string: String) {
        let a = XCTAttachment(string: string)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        saveToDisk(name, Data(string.utf8))
    }

    private static let evidenceID = String(Int(Date().timeIntervalSince1970))

    private func saveToDisk(_ name: String, _ data: Data) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let sub = dir.appendingPathComponent("bs_evidence", isDirectory: true)
        try? FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let fname = "\(Self.evidenceID)_\(name)"
        try? data.write(to: sub.appendingPathComponent(fname))
        print("PROBE_SAVED \(fname)")
    }
}