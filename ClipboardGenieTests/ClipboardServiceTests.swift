import XCTest
import AppKit
@testable import Clipboard_Genie

final class ClipboardServiceTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var service: ClipboardService!

    override func setUp() {
        super.setUp()
        // Unique named pasteboard so tests never touch the user's real clipboard.
        pasteboard = NSPasteboard(name: NSPasteboard.Name("test-\(UUID().uuidString)"))
        service = ClipboardService(pasteboard: pasteboard)
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        super.tearDown()
    }

    func testWriteThenCurrentTextRoundTrips() {
        service.write("genie output")
        XCTAssertEqual(service.currentText(), "genie output")
    }

    func testCurrentTextNilWhenEmpty() {
        pasteboard.clearContents()
        XCTAssertNil(service.currentText())
    }

    func testExternalCopyTriggersCallback() {
        var received: String?
        service.onExternalCopy = { received = $0 }
        service.checkForChanges() // baseline snapshot

        pasteboard.clearContents()
        pasteboard.setString("copied elsewhere", forType: .string)
        service.checkForChanges()

        XCTAssertEqual(received, "copied elsewhere")
    }

    func testOwnWriteDoesNotTriggerCallback() {
        var received: String?
        service.onExternalCopy = { received = $0 }
        service.checkForChanges() // baseline

        service.write("self write")
        service.checkForChanges()

        XCTAssertNil(received)
    }

    func testNoChangeDoesNotTriggerCallback() {
        pasteboard.clearContents()
        pasteboard.setString("stable", forType: .string)
        service.checkForChanges() // baseline picks this up as the starting state

        var received: String?
        service.onExternalCopy = { received = $0 }
        service.checkForChanges()

        XCTAssertNil(received)
    }
}
