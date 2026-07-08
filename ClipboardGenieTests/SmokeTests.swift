import XCTest
@testable import Clipboard_Mage

final class SmokeTests: XCTestCase {
    func testAppBundleLoads() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.clipboardgenie.app")
    }
}
