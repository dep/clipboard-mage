import XCTest
@testable import Clipboard_Genie

final class SmokeTests: XCTestCase {
    func testAppBundleLoads() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.clipboardgenie.app")
    }
}
