import XCTest
@testable import Clipboard_Mage

final class KeychainStoreTests: XCTestCase {
    // Unique service per run so tests never collide with the real app entry.
    private let store = KeychainStore(service: "com.clipboardgenie.tests.\(UUID().uuidString)")
    private let account = "anthropic-api-key"

    override func tearDown() {
        store.delete(account: account)
        super.tearDown()
    }

    func testReadMissingReturnsNil() {
        XCTAssertNil(store.read(account: account))
    }

    func testSaveThenReadRoundTrips() throws {
        try store.save("sk-ant-test-123", account: account)
        XCTAssertEqual(store.read(account: account), "sk-ant-test-123")
    }

    func testSaveOverwritesExistingValue() throws {
        try store.save("first", account: account)
        try store.save("second", account: account)
        XCTAssertEqual(store.read(account: account), "second")
    }

    func testDeleteRemovesValue() throws {
        try store.save("bye", account: account)
        store.delete(account: account)
        XCTAssertNil(store.read(account: account))
    }
}
