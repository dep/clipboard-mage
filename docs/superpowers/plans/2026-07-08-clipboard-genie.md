# Clipboard Genie Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu bar app: global hotkey opens a centered floating panel showing clipboard text; the user types an instruction, the Anthropic API (Sonnet) streams a transformed version into the preview; Enter accepts it into the clipboard.

**Architecture:** SwiftUI app shell (`MenuBarExtra`, no Dock icon) + a borderless floating `NSPanel` hosting a SwiftUI view. A `GenieSession` view model owns the state machine; `GenieEngine` streams SSE from the Anthropic Messages API via `URLSession`; `ClipboardService` reads/writes/watches `NSPasteboard`; API key lives in the Keychain. XcodeGen project mirroring Synapse Meetings; Sparkle 2 for updates.

**Tech Stack:** Swift 5.10, SwiftUI, macOS 14.0+, XcodeGen, `KeyboardShortcuts` (sindresorhus) 2.x, Sparkle 2.6.x, XCTest.

## Global Constraints

- Working directory: `/Users/dep/Sites/magic-clipboard` (repo already `git init`-ed on `main`; remote will be `https://github.com/dep/clipboard-genie`)
- App name: **Clipboard Genie**; bundle id `com.clipboardgenie.app`; test bundle `com.clipboardgenie.tests`
- Deployment target: macOS **14.0**; Swift **5.10**
- Local dev builds use ad-hoc signing (`CODE_SIGN_IDENTITY: "-"`, `CODE_SIGNING_ALLOWED: NO`, `ENABLE_HARDENED_RUNTIME: NO`) — release signing is overridden on the `xcodebuild` command line (see Task 9)
- Anthropic model id: exactly `claude-sonnet-5` (no date suffix). Streaming (`"stream": true`), `"max_tokens": 64000`, and `thinking: {"type": "disabled"}` — on Sonnet 5, *omitting* `thinking` silently enables adaptive thinking; we disable it for latency. Never send `temperature`/`top_p`/`top_k` (rejected with 400 on Sonnet 5).
- API auth headers: `x-api-key: <key>`, `anthropic-version: 2023-06-01`, `content-type: application/json`
- API key storage: macOS Keychain only (generic password, service `com.clipboardgenie`, account `anthropic-api-key`). Never UserDefaults, never plaintext on disk, never logged.
- Build after every task: `xcodegen generate` (only when project.yml changed) then
  `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie -configuration Debug build`
- Run tests with: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie -configuration Debug test`
- Prerequisites assumed installed: Xcode 15+, `xcodegen` (`brew install xcodegen`)

---

### Task 1: Project scaffold — XcodeGen + menu bar shell

**Files:**
- Create: `project.yml`
- Create: `ClipboardGenie/ClipboardGenieApp.swift`
- Create: `ClipboardGenie/AppDelegate.swift`
- Create: `ClipboardGenieTests/SmokeTests.swift`
- Modify: `.gitignore`

**Interfaces:**
- Produces: an app target `ClipboardGenie` and test target `ClipboardGenieTests` that build and run. `AppDelegate` is the wiring point later tasks extend.

- [ ] **Step 1: Write `project.yml`**

```yaml
name: ClipboardGenie
options:
  bundleIdPrefix: com.clipboardgenie
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
  developmentLanguage: en
settings:
  base:
    SWIFT_VERSION: "5.10"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    ENABLE_HARDENED_RUNTIME: NO
    DEAD_CODE_STRIPPING: YES
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGNING_REQUIRED: NO
    CODE_SIGNING_ALLOWED: NO
packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: "2.0.0"
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.6.4"
schemes:
  ClipboardGenie:
    build:
      targets:
        ClipboardGenie: all
        ClipboardGenieTests: [test]
    test:
      targets:
        - ClipboardGenieTests

targets:
  ClipboardGenie:
    type: application
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - path: ClipboardGenie
    resources:
      - path: ClipboardGenie/Resources
        optional: true
    info:
      path: ClipboardGenie/Info.plist
      properties:
        CFBundleName: Clipboard Genie
        CFBundleDisplayName: Clipboard Genie
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
        LSMinimumSystemVersion: "14.0"
        LSUIElement: true
        NSHumanReadableCopyright: "© 2026 Clipboard Genie"
        SUFeedURL: "https://raw.githubusercontent.com/dep/clipboard-genie/main/appcast.xml"
        SUPublicEDKey: "SPARKLE_PUBLIC_KEY_PLACEHOLDER"
        SUEnableAutomaticChecks: true
        SUScheduledCheckInterval: 86400
    entitlements:
      path: ClipboardGenie/ClipboardGenie.entitlements
      properties:
        com.apple.security.app-sandbox: false
        com.apple.security.network.client: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.clipboardgenie.app
        PRODUCT_NAME: "Clipboard Genie"
        GENERATE_INFOPLIST_FILE: NO
        COMBINE_HIDPI_IMAGES: YES
        ENABLE_PREVIEWS: YES
        ENABLE_TESTABILITY: YES
    dependencies:
      - package: KeyboardShortcuts
        product: KeyboardShortcuts
      - package: Sparkle
        product: Sparkle

  ClipboardGenieTests:
    type: bundle.unit-test
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - path: ClipboardGenieTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.clipboardgenie.tests
        SWIFT_VERSION: "5.10"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Clipboard Genie.app/Contents/MacOS/Clipboard Genie"
        BUNDLE_LOADER: "$(TEST_HOST)"
    dependencies:
      - target: ClipboardGenie
        embed: false
```

`SUPublicEDKey` is a placeholder until Task 8 (Sparkle keys).

- [ ] **Step 2: Write the app entry point**

`ClipboardGenie/ClipboardGenieApp.swift`:

```swift
import SwiftUI

@main
struct ClipboardGenieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipboard Genie", systemImage: "wand.and.stars") {
            Button("Open Genie") {
                appDelegate.showPanel()
            }
            Divider()
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Quit Clipboard Genie") {
                NSApp.terminate(nil)
            }
        }
        Settings {
            Text("Settings coming soon")
                .padding(40)
        }
    }
}
```

`ClipboardGenie/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wiring added in later tasks (panel, hotkey, clipboard watcher, Sparkle).
    }

    func showPanel() {
        // Replaced in Task 6 with real panel presentation.
        NSSound.beep()
    }
}
```

- [ ] **Step 3: Write a smoke test**

`ClipboardGenieTests/SmokeTests.swift`:

```swift
import XCTest
@testable import Clipboard_Genie

final class SmokeTests: XCTestCase {
    func testAppBundleLoads() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.clipboardgenie.app")
    }
}
```

Note the module name: `PRODUCT_NAME` is "Clipboard Genie", so the testable import is `Clipboard_Genie`.

- [ ] **Step 4: Update `.gitignore`**

Append to the existing `.gitignore` (which currently contains only `.env`):

```
.env
build/
*.xcodeproj
DerivedData/
.DS_Store
```

The `.xcodeproj` is generated by XcodeGen and never committed (same as Synapse Meetings commits `project.yml` only — verify: synapse *does* commit its xcodeproj; for this project we regenerate, so ignoring is fine and keeps diffs clean).

- [ ] **Step 5: Generate and build**

Run:
```bash
cd /Users/dep/Sites/magic-clipboard && xcodegen generate && \
xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **` (first run resolves SPM packages; may take a couple of minutes).

- [ ] **Step 6: Run tests**

```bash
xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie -configuration Debug test
```
Expected: `** TEST SUCCEEDED **`, 1 test passing.

- [ ] **Step 7: Commit**

```bash
git add project.yml ClipboardGenie ClipboardGenieTests .gitignore
git commit -m "feat: scaffold XcodeGen project with menu bar shell"
```

---

### Task 2: KeychainStore

**Files:**
- Create: `ClipboardGenie/Services/KeychainStore.swift`
- Test: `ClipboardGenieTests/KeychainStoreTests.swift`

**Interfaces:**
- Produces: `struct KeychainStore` with `init(service: String = "com.clipboardgenie")`, `func save(_ value: String, account: String) throws`, `func read(account: String) -> String?`, `func delete(account: String)`. Later tasks use account `"anthropic-api-key"`.

- [ ] **Step 1: Write the failing tests**

`ClipboardGenieTests/KeychainStoreTests.swift`:

```swift
import XCTest
@testable import Clipboard_Genie

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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test`
Expected: build FAILS with "cannot find 'KeychainStore' in scope".

- [ ] **Step 3: Implement KeychainStore**

`ClipboardGenie/Services/KeychainStore.swift`:

```swift
import Foundation
import Security

struct KeychainStore {
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    let service: String

    init(service: String = "com.clipboardgenie") {
        self.service = service
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(
                baseQuery(account: account) as CFDictionary,
                update as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test`
Expected: `** TEST SUCCEEDED **` (5 tests).

- [ ] **Step 5: Commit**

```bash
git add ClipboardGenie/Services/KeychainStore.swift ClipboardGenieTests/KeychainStoreTests.swift
git commit -m "feat: Keychain-backed API key storage"
```

---

### Task 3: GenieEngine — Anthropic Messages API SSE client

**Files:**
- Create: `ClipboardGenie/Services/GenieEngine.swift`
- Test: `ClipboardGenieTests/GenieEngineTests.swift`

**Interfaces:**
- Produces:
  - `protocol TransformEngine { func transform(text: String, instruction: String, apiKey: String) -> AsyncThrowingStream<String, Error> }` — yields text deltas.
  - `struct GenieEngine: TransformEngine` with `init(session: URLSession = .shared)`.
  - `enum GenieError: LocalizedError` cases: `.missingAPIKey`, `.http(status: Int, message: String)`, `.malformedStream`.
  - Internal (tested) statics: `GenieEngine.makeRequest(apiKey:text:instruction:) -> URLRequest` and `GenieEngine.textDelta(fromSSEDataLine:) -> String?`.

- [ ] **Step 1: Write the failing tests**

`ClipboardGenieTests/GenieEngineTests.swift`:

```swift
import XCTest
@testable import Clipboard_Genie

final class GenieEngineTests: XCTestCase {

    // MARK: Request construction

    func testMakeRequestShape() throws {
        let request = GenieEngine.makeRequest(
            apiKey: "sk-ant-test",
            text: "hello world",
            instruction: "make it uppercase"
        )
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")

        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
        XCTAssertEqual(body?["model"] as? String, "claude-sonnet-5")
        XCTAssertEqual(body?["stream"] as? Bool, true)
        XCTAssertEqual(body?["max_tokens"] as? Int, 64000)
        let thinking = body?["thinking"] as? [String: Any]
        XCTAssertEqual(thinking?["type"] as? String, "disabled")
        XCTAssertNil(body?["temperature"])

        let system = body?["system"] as? String
        XCTAssertTrue(system?.contains("ONLY the transformed text") ?? false)

        let messages = body?["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 1)
        XCTAssertEqual(messages?.first?["role"] as? String, "user")
        let content = messages?.first?["content"] as? String
        XCTAssertTrue(content?.contains("make it uppercase") ?? false)
        XCTAssertTrue(content?.contains("hello world") ?? false)
    }

    // MARK: SSE line parsing

    func testTextDeltaParsedFromContentBlockDelta() {
        let line = #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}"#
        XCTAssertEqual(GenieEngine.textDelta(fromSSEDataLine: line), "Hi")
    }

    func testNonDeltaEventsReturnNil() {
        XCTAssertNil(GenieEngine.textDelta(fromSSEDataLine: #"data: {"type":"message_start","message":{}}"#))
        XCTAssertNil(GenieEngine.textDelta(fromSSEDataLine: "event: content_block_delta"))
        XCTAssertNil(GenieEngine.textDelta(fromSSEDataLine: ""))
        XCTAssertNil(GenieEngine.textDelta(fromSSEDataLine: #"data: {"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"{}"}}"#))
    }

    // MARK: Full stream via stubbed URLProtocol

    func testTransformStreamsDeltasInOrder() async throws {
        let sse = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_1"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        StubURLProtocol.stub = (status: 200, data: Data(sse.utf8))
        let engine = GenieEngine(session: Self.stubbedSession())

        var collected = ""
        for try await delta in engine.transform(text: "x", instruction: "y", apiKey: "k") {
            collected += delta
        }
        XCTAssertEqual(collected, "Hello world")
    }

    func testTransformThrowsOnHTTPError() async {
        let errorBody = #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#
        StubURLProtocol.stub = (status: 401, data: Data(errorBody.utf8))
        let engine = GenieEngine(session: Self.stubbedSession())

        do {
            for try await _ in engine.transform(text: "x", instruction: "y", apiKey: "bad") {}
            XCTFail("expected error")
        } catch let GenieError.http(status, message) {
            XCTAssertEqual(status, 401)
            XCTAssertTrue(message.contains("invalid x-api-key"))
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    private static func stubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}

final class StubURLProtocol: URLProtocol {
    static var stub: (status: Int, data: Data) = (200, Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub = Self.stub
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": stub.status == 200 ? "text/event-stream" : "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test`
Expected: build FAILS with "cannot find 'GenieEngine' in scope".

- [ ] **Step 3: Implement GenieEngine**

`ClipboardGenie/Services/GenieEngine.swift`:

```swift
import Foundation

enum GenieError: LocalizedError {
    case missingAPIKey
    case http(status: Int, message: String)
    case malformedStream

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key set. Add your Anthropic API key in Settings."
        case .http(let status, let message):
            return "API error (\(status)): \(message)"
        case .malformedStream:
            return "The response stream was malformed."
        }
    }
}

protocol TransformEngine {
    func transform(text: String, instruction: String, apiKey: String) -> AsyncThrowingStream<String, Error>
}

struct GenieEngine: TransformEngine {
    var session: URLSession = .shared

    static let systemPrompt = """
    You are a text transformation engine. The user gives you a piece of text and an \
    instruction describing how to change it. Respond with ONLY the transformed text — \
    no commentary, no preamble, no code fences unless the instruction asks for them.
    """

    static func makeRequest(apiKey: String, text: String, instruction: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let userContent = """
        <instruction>
        \(instruction)
        </instruction>
        <text>
        \(text)
        </text>
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-5",
            "max_tokens": 64000,
            "stream": true,
            "thinking": ["type": "disabled"],
            "system": systemPrompt,
            "messages": [["role": "user", "content": userContent]],
        ]
        request.httpBody = try! JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func textDelta(fromSSEDataLine line: String) -> String? {
        guard line.hasPrefix("data: ") else { return nil }
        let json = line.dropFirst("data: ".count)
        guard
            let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
            object["type"] as? String == "content_block_delta",
            let delta = object["delta"] as? [String: Any],
            delta["type"] as? String == "text_delta",
            let text = delta["text"] as? String
        else { return nil }
        return text
    }

    func transform(text: String, instruction: String, apiKey: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = Self.makeRequest(apiKey: apiKey, text: text, instruction: instruction)
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw GenieError.malformedStream
                    }
                    guard http.statusCode == 200 else {
                        var bodyData = Data()
                        for try await byte in bytes { bodyData.append(byte) }
                        let message = Self.errorMessage(fromBody: bodyData)
                        throw GenieError.http(status: http.statusCode, message: message)
                    }

                    for try await line in bytes.lines {
                        if let delta = Self.textDelta(fromSSEDataLine: line) {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func errorMessage(fromBody data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? [String: Any],
            let message = error["message"] as? String
        else {
            return String(data: data, encoding: .utf8) ?? "unknown error"
        }
        return message
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test`
Expected: `** TEST SUCCEEDED **` (all tests, including Tasks 1–2).

- [ ] **Step 5: Commit**

```bash
git add ClipboardGenie/Services/GenieEngine.swift ClipboardGenieTests/GenieEngineTests.swift
git commit -m "feat: Anthropic Messages API SSE streaming engine"
```

---

### Task 4: ClipboardService

**Files:**
- Create: `ClipboardGenie/Services/ClipboardService.swift`
- Test: `ClipboardGenieTests/ClipboardServiceTests.swift`

**Interfaces:**
- Produces: `final class ClipboardService` with:
  - `init(pasteboard: NSPasteboard = .general)`
  - `func currentText() -> String?`
  - `func write(_ text: String)` — records its own `changeCount` so the watcher ignores it
  - `var onExternalCopy: ((String) -> Void)?`
  - `func startWatching()` / `func stopWatching()` (0.5s `Timer`)
  - `func checkForChanges()` — one poll tick, exposed for tests

- [ ] **Step 1: Write the failing tests**

`ClipboardGenieTests/ClipboardServiceTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test`
Expected: build FAILS with "cannot find 'ClipboardService' in scope".

- [ ] **Step 3: Implement ClipboardService**

`ClipboardGenie/Services/ClipboardService.swift`:

```swift
import AppKit

final class ClipboardService {
    private let pasteboard: NSPasteboard
    private var lastSeenChangeCount: Int
    private var lastOwnWriteChangeCount: Int = -1
    private var timer: Timer?

    var onExternalCopy: ((String) -> Void)?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastSeenChangeCount = pasteboard.changeCount
    }

    func currentText() -> String? {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return nil }
        return text
    }

    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastOwnWriteChangeCount = pasteboard.changeCount
    }

    func startWatching() {
        stopWatching()
        lastSeenChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    func checkForChanges() {
        let count = pasteboard.changeCount
        defer { lastSeenChangeCount = count }
        guard count != lastSeenChangeCount else { return }
        guard count != lastOwnWriteChangeCount else { return }
        guard let text = currentText() else { return }
        onExternalCopy?(text)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ClipboardGenie/Services/ClipboardService.swift ClipboardGenieTests/ClipboardServiceTests.swift
git commit -m "feat: clipboard read/write and change watching with self-copy suppression"
```

---

### Task 5: GenieSession — the state machine

**Files:**
- Create: `ClipboardGenie/Models/GenieSession.swift`
- Test: `ClipboardGenieTests/GenieSessionTests.swift`

**Interfaces:**
- Consumes: `TransformEngine` (Task 3).
- Produces: `@MainActor final class GenieSession: ObservableObject` with:
  - `init(engine: TransformEngine, apiKeyProvider: @escaping () -> String?)`
  - `@Published var previewText: String`, `@Published var instruction: String`, `@Published var isStreaming: Bool`, `@Published var hasResult: Bool`, `@Published var errorMessage: String?`, `var hasClipboardText: Bool`
  - `var onAccept: ((String) -> Void)?` — called with the final text when the user accepts
  - `func begin(with clipboardText: String?)` — resets state for a fresh panel-open
  - `func submit()` — Enter pressed: empty instruction + result → accept; non-empty → transform
  - `func cancelStreaming()`

Semantics (from the spec): a transform failure restores the pre-transform preview; each transform operates on the **current preview text** (iteration); accepting calls `onAccept` with the preview text.

- [ ] **Step 1: Write the failing tests**

`ClipboardGenieTests/GenieSessionTests.swift`:

```swift
import XCTest
@testable import Clipboard_Genie

/// Engine stub that yields scripted deltas or throws.
struct MockEngine: TransformEngine {
    var deltas: [String] = []
    var error: Error?
    // Records what it was asked to transform.
    var spy: ((String, String) -> Void)?

    func transform(text: String, instruction: String, apiKey: String) -> AsyncThrowingStream<String, Error> {
        spy?(text, instruction)
        return AsyncThrowingStream { continuation in
            for delta in deltas { continuation.yield(delta) }
            continuation.finish(throwing: error)
        }
    }
}

@MainActor
final class GenieSessionTests: XCTestCase {

    private func makeSession(
        engine: TransformEngine = MockEngine(deltas: ["OK"]),
        apiKey: String? = "sk-test"
    ) -> GenieSession {
        GenieSession(engine: engine, apiKeyProvider: { apiKey })
    }

    private func waitForStreamingToEnd(_ session: GenieSession) async {
        for _ in 0..<200 where session.isStreaming {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testBeginPopulatesPreviewFromClipboard() {
        let session = makeSession()
        session.begin(with: "copied text")
        XCTAssertEqual(session.previewText, "copied text")
        XCTAssertTrue(session.hasClipboardText)
        XCTAssertFalse(session.hasResult)
    }

    func testBeginWithNilClipboardSetsEmptyState() {
        let session = makeSession()
        session.begin(with: nil)
        XCTAssertFalse(session.hasClipboardText)
    }

    func testSubmitStreamsResultIntoPreviewAndClearsInstruction() async {
        let session = makeSession(engine: MockEngine(deltas: ["Hello", " world"]))
        session.begin(with: "source")
        session.instruction = "greet"
        session.submit()
        await waitForStreamingToEnd(session)

        XCTAssertEqual(session.previewText, "Hello world")
        XCTAssertEqual(session.instruction, "")
        XCTAssertTrue(session.hasResult)
        XCTAssertNil(session.errorMessage)
    }

    func testSecondSubmitTransformsCurrentPreviewNotOriginal() async {
        var transformedInputs: [String] = []
        var engine = MockEngine(deltas: ["step-output"])
        engine.spy = { text, _ in transformedInputs.append(text) }

        let session = makeSession(engine: engine)
        session.begin(with: "original")
        session.instruction = "first"
        session.submit()
        await waitForStreamingToEnd(session)

        session.instruction = "second"
        session.submit()
        await waitForStreamingToEnd(session)

        XCTAssertEqual(transformedInputs, ["original", "step-output"])
    }

    func testSubmitWithEmptyInstructionAndResultAccepts() async {
        let session = makeSession(engine: MockEngine(deltas: ["final"]))
        var accepted: String?
        session.onAccept = { accepted = $0 }

        session.begin(with: "source")
        session.instruction = "go"
        session.submit()
        await waitForStreamingToEnd(session)

        session.instruction = "   " // whitespace-only counts as empty
        session.submit()
        XCTAssertEqual(accepted, "final")
    }

    func testSubmitWithEmptyInstructionAndNoResultDoesNothing() {
        let session = makeSession()
        var accepted: String?
        session.onAccept = { accepted = $0 }

        session.begin(with: "source")
        session.submit()
        XCTAssertNil(accepted)
    }

    func testErrorRestoresPreviewAndSetsMessage() async {
        let engine = MockEngine(deltas: ["partial"], error: GenieError.http(status: 500, message: "boom"))
        let session = makeSession(engine: engine)
        session.begin(with: "precious source")
        session.instruction = "transform"
        session.submit()
        await waitForStreamingToEnd(session)

        XCTAssertEqual(session.previewText, "precious source")
        XCTAssertNotNil(session.errorMessage)
        XCTAssertFalse(session.hasResult)
    }

    func testMissingAPIKeySetsErrorWithoutStreaming() {
        let session = makeSession(apiKey: nil)
        session.begin(with: "source")
        session.instruction = "transform"
        session.submit()

        XCTAssertEqual(session.errorMessage, GenieError.missingAPIKey.errorDescription)
        XCTAssertFalse(session.isStreaming)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test`
Expected: build FAILS with "cannot find 'GenieSession' in scope".

- [ ] **Step 3: Implement GenieSession**

`ClipboardGenie/Models/GenieSession.swift`:

```swift
import Foundation

@MainActor
final class GenieSession: ObservableObject {
    @Published var previewText: String = ""
    @Published var instruction: String = ""
    @Published var isStreaming: Bool = false
    @Published var hasResult: Bool = false
    @Published var errorMessage: String?
    private(set) var hasClipboardText: Bool = false

    var onAccept: ((String) -> Void)?

    private let engine: TransformEngine
    private let apiKeyProvider: () -> String?
    private var streamTask: Task<Void, Never>?

    init(engine: TransformEngine, apiKeyProvider: @escaping () -> String?) {
        self.engine = engine
        self.apiKeyProvider = apiKeyProvider
    }

    func begin(with clipboardText: String?) {
        cancelStreaming()
        previewText = clipboardText ?? ""
        hasClipboardText = clipboardText != nil
        instruction = ""
        hasResult = false
        errorMessage = nil
    }

    func submit() {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if hasResult, !isStreaming {
                onAccept?(previewText)
            }
            return
        }
        guard !isStreaming, hasClipboardText else { return }
        runTransform(instruction: trimmed)
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    private func runTransform(instruction: String) {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            errorMessage = GenieError.missingAPIKey.errorDescription
            return
        }

        let source = previewText
        errorMessage = nil
        isStreaming = true
        previewText = ""

        streamTask = Task {
            do {
                for try await delta in engine.transform(text: source, instruction: instruction, apiKey: apiKey) {
                    previewText += delta
                }
                hasResult = true
                self.instruction = ""
            } catch is CancellationError {
                previewText = source
            } catch {
                previewText = source
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isStreaming = false
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ClipboardGenie/Models/GenieSession.swift ClipboardGenieTests/GenieSessionTests.swift
git commit -m "feat: GenieSession state machine (transform, iterate, accept, error restore)"
```

---

### Task 6: GeniePanel + GenieView — the pretty modal

**Files:**
- Create: `ClipboardGenie/Views/GenieView.swift`
- Create: `ClipboardGenie/PanelController.swift`
- Modify: `ClipboardGenie/AppDelegate.swift`

**Interfaces:**
- Consumes: `GenieSession` (Task 5), `GenieEngine` (Task 3), `KeychainStore` (Task 2), `ClipboardService` (Task 4).
- Produces: `final class PanelController` with `func show()` and `func hide()`. `AppDelegate.showPanel()` now presents the real panel.

No unit tests for this task (pure AppKit/SwiftUI presentation); verification is manual (Step 4).

- [ ] **Step 1: Write GenieView**

`ClipboardGenie/Views/GenieView.swift`:

```swift
import SwiftUI

struct GenieView: View {
    @ObservedObject var session: GenieSession
    var onClose: () -> Void
    var onOpenSettings: () -> Void

    @FocusState private var instructionFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            previewPane
            Divider()
            instructionField
        }
        .frame(width: 640, height: 420)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        )
        .onAppear { instructionFocused = true }
        .onExitCommand { onClose() }
    }

    @ViewBuilder
    private var previewPane: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                Text(session.previewText.isEmpty && !session.isStreaming
                     ? placeholderText
                     : session.previewText)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(session.hasClipboardText ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .textSelection(.enabled)
            }
            if session.isStreaming && session.previewText.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("The genie is thinking…").foregroundStyle(.secondary)
                }
                .padding(16)
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let error = session.errorMessage {
                errorBar(error)
            } else if session.hasResult && !session.isStreaming {
                hintBar("↩ to copy to clipboard — or type another instruction")
            }
        }
    }

    private var placeholderText: String {
        session.hasClipboardText ? "" : "Nothing to transform — copy some text first."
    }

    private func errorBar(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message).font(.callout).lineLimit(2)
            Spacer()
            if message.contains("Settings") {
                Button("Open Settings") { onOpenSettings() }
            }
        }
        .padding(10)
        .background(.regularMaterial)
    }

    private func hintBar(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
    }

    private var instructionField: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.tint)
            TextField(
                session.hasResult ? "Press ↩ to accept, or ask for another change…"
                                  : "How should I transform this?",
                text: $session.instruction,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(.body, design: .rounded))
            .lineLimit(1...4)
            .focused($instructionFocused)
            .onSubmit { session.submit() }
            .disabled(session.isStreaming)
            if session.isStreaming {
                Button("Stop") { session.cancelStreaming() }
                    .controlSize(.small)
            }
        }
        .padding(14)
    }
}
```

Notes: `TextField(axis: .vertical)` gives multi-line input where **Option+Enter** inserts a newline and plain **Enter** triggers `.onSubmit` — this satisfies the "Enter submits / modifier for newline" requirement without a custom NSTextView.

- [ ] **Step 2: Write PanelController**

`ClipboardGenie/PanelController.swift`:

```swift
import AppKit
import SwiftUI

/// Borderless panels refuse key status unless we say otherwise.
final class GeniePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: GeniePanel?
    private let session: GenieSession
    private let clipboard: ClipboardService

    init(session: GenieSession, clipboard: ClipboardService) {
        self.session = session
        self.clipboard = clipboard
        super.init()
        session.onAccept = { [weak self] text in
            self?.clipboard.write(text)
            self?.hide()
        }
    }

    func show() {
        session.begin(with: clipboard.currentText())

        if panel == nil {
            let content = GenieView(
                session: session,
                onClose: { [weak self] in self?.hide() },
                onOpenSettings: { [weak self] in
                    self?.hide()
                    NSApp.activate(ignoringOtherApps: true)
                    // Programmatic Settings open (SettingsLink can't be triggered from AppKit)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            )
            let hosting = NSHostingController(rootView: content)
            let newPanel = GeniePanel(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.contentViewController = hosting
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.hidesOnDeactivate = false
            newPanel.isReleasedWhenClosed = false
            newPanel.delegate = self
            panel = newPanel
        }

        centerPanel()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        session.cancelStreaming()
        panel?.orderOut(nil)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? hide() : show()
    }

    private func centerPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.midY - panel.frame.height / 2 + frame.height * 0.08
        )
        panel.setFrameOrigin(origin)
    }

    // Click-outside dismissal: the panel resigns key when another window is clicked.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
```

- [ ] **Step 3: Wire into AppDelegate**

Replace `ClipboardGenie/AppDelegate.swift` with:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) lazy var clipboard = ClipboardService()
    private(set) lazy var session = GenieSession(
        engine: GenieEngine(),
        apiKeyProvider: { KeychainStore().read(account: "anthropic-api-key") }
    )
    private(set) lazy var panelController = PanelController(session: session, clipboard: clipboard)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hotkey + auto-appear wiring added in Task 7; Sparkle in Task 8.
    }

    func showPanel() {
        panelController.show()
    }
}
```

- [ ] **Step 4: Build and manually verify**

```bash
xcodegen generate 2>/dev/null; xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/ClipboardGenie-*/Build/Products/Debug/Clipboard\ Genie.app
```

Manual checks:
1. Menu bar icon appears (wand); no Dock icon.
2. Copy some text anywhere, click **Open Genie** → centered blurred panel appears showing the copied text, cursor in the instruction field.
3. **Esc** closes it. Clicking another app's window closes it.
4. With no API key set, typing an instruction + Enter shows the "No API key set" error bar.

- [ ] **Step 5: Run tests (regression) and commit**

```bash
xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test
git add ClipboardGenie/Views/GenieView.swift ClipboardGenie/PanelController.swift ClipboardGenie/AppDelegate.swift
git commit -m "feat: floating genie panel with streaming preview UI"
```

---

### Task 7: Hotkey, Settings, and auto-appear-on-copy

**Files:**
- Create: `ClipboardGenie/Views/SettingsView.swift`
- Create: `ClipboardGenie/Models/HotkeyName.swift`
- Modify: `ClipboardGenie/AppDelegate.swift`
- Modify: `ClipboardGenie/ClipboardGenieApp.swift`

**Interfaces:**
- Consumes: `KeyboardShortcuts` package, `KeychainStore`, `ClipboardService`, `PanelController`.
- Produces: `KeyboardShortcuts.Name.toggleGenie` (default **⌃⌥⌘C**); `SettingsView`; UserDefaults key `"autoAppearOnCopy"` (Bool, default false).

- [ ] **Step 1: Define the shortcut name**

`ClipboardGenie/Models/HotkeyName.swift`:

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleGenie = Self(
        "toggleGenie",
        default: .init(.c, modifiers: [.control, .option, .command])
    )
}
```

- [ ] **Step 2: Write SettingsView**

`ClipboardGenie/Views/SettingsView.swift`:

```swift
import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @AppStorage("autoAppearOnCopy") private var autoAppearOnCopy = false
    @State private var apiKeyField = ""
    @State private var keyIsSaved = false

    private let keychain = KeychainStore()
    private let account = "anthropic-api-key"

    var body: some View {
        Form {
            Section("Shortcut") {
                KeyboardShortcuts.Recorder("Summon the genie:", name: .toggleGenie)
            }

            Section("Anthropic API Key") {
                HStack {
                    SecureField(
                        keyIsSaved ? "••••••••••••••••••••  (saved)" : "sk-ant-…",
                        text: $apiKeyField
                    )
                    .textContentType(.password)
                    Button("Save") { saveKey() }
                        .disabled(apiKeyField.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if keyIsSaved {
                    Button("Remove key", role: .destructive) {
                        keychain.delete(account: account)
                        keyIsSaved = false
                        apiKeyField = ""
                    }
                }
                Text("Stored securely in your macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Auto-appear when I copy text", isOn: $autoAppearOnCopy)
                Text("Opens the genie every time you copy text. Press Esc to dismiss.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { keyIsSaved = keychain.read(account: account) != nil }
    }

    private func saveKey() {
        let key = apiKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        try? keychain.save(key, account: account)
        keyIsSaved = true
        apiKeyField = ""
    }
}
```

- [ ] **Step 3: Wire hotkey and auto-appear into AppDelegate**

In `ClipboardGenie/AppDelegate.swift`, add `import KeyboardShortcuts` and `import Foundation`, and replace `applicationDidFinishLaunching` with:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyboardShortcuts.onKeyUp(for: .toggleGenie) { [weak self] in
            self?.panelController.toggle()
        }

        clipboard.onExternalCopy = { [weak self] _ in
            guard UserDefaults.standard.bool(forKey: "autoAppearOnCopy") else { return }
            self?.panelController.show()
        }
        clipboard.startWatching()
    }
```

The watcher always runs; the toggle is checked per-event so flipping the setting takes effect immediately without restart.

- [ ] **Step 4: Use SettingsView in the app scene**

In `ClipboardGenie/ClipboardGenieApp.swift`, replace the `Settings { ... }` scene body:

```swift
        Settings {
            SettingsView()
        }
```

- [ ] **Step 5: Build and manually verify**

```bash
xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/ClipboardGenie-*/Build/Products/Debug/Clipboard\ Genie.app
```

Manual checks:
1. **⌃⌥⌘C** toggles the panel from any app.
2. Settings… opens: recorder shows the shortcut and can rebind it; rebound shortcut works immediately.
3. Paste your real API key, Save → copy some text → hotkey → type "translate to French" → Enter → tokens stream into the preview → Enter again → panel closes → paste somewhere: it's the French text. 🎉
4. Type a follow-up instruction instead of accepting → it transforms the *result* again.
5. Toggle "Auto-appear when I copy text" on → copy text in another app → panel pops up focused. Accepting a result does NOT re-trigger the panel (self-copy suppression).
6. Toggle off → copying no longer triggers.

- [ ] **Step 6: Run tests and commit**

```bash
xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test
git add ClipboardGenie ClipboardGenieTests
git commit -m "feat: global hotkey, settings window, auto-appear-on-copy"
```

---

### Task 8: Sparkle auto-updates

**Files:**
- Modify: `ClipboardGenie/AppDelegate.swift`
- Modify: `ClipboardGenie/ClipboardGenieApp.swift`
- Modify: `project.yml` (real `SUPublicEDKey`)
- Create: `appcast.xml`

- [ ] **Step 1: Generate Sparkle signing keys (one-time, machine-local)**

```bash
mkdir -p /tmp/sparkle-bin && cd /tmp/sparkle-bin && \
curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz" -o sparkle.tar.xz && \
tar -xf sparkle.tar.xz && \
./bin/generate_keys
```

Expected output includes a public key line like `Tnoq0NNr…Zh4=`. (If a key already exists in the keychain, `generate_keys -p` prints it.) The private key is stored in the login keychain automatically.

- [ ] **Step 2: Put the real public key in `project.yml`**

Replace `SPARKLE_PUBLIC_KEY_PLACEHOLDER` in `project.yml` with the printed public key, then `xcodegen generate`.

- [ ] **Step 3: Add the updater**

In `ClipboardGenie/AppDelegate.swift`, add `import Sparkle` and this property:

```swift
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
```

In `ClipboardGenie/ClipboardGenieApp.swift`, add a menu item between "Open Genie" and Settings:

```swift
            Button("Check for Updates…") {
                appDelegate.updaterController.checkForUpdates(nil)
            }
```

- [ ] **Step 4: Create the initial appcast**

`appcast.xml` at repo root:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Clipboard Mage</title>
    <link>https://raw.githubusercontent.com/dep/clipboard-mage/main/appcast.xml</link>
    <description>Most recent changes with links to updates.</description>
    <language>en</language>
    <!-- items go here, newest first -->
  </channel>
</rss>
```

- [ ] **Step 5: Build, verify, commit**

```bash
xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie -configuration Debug build
```

Manual check: launch the app, click "Check for Updates…" — Sparkle's dialog appears (it will report "up to date" or a fetch error against the not-yet-populated appcast; either proves the wiring).

```bash
git add project.yml ClipboardGenie appcast.xml
git commit -m "feat: Sparkle auto-update wiring with appcast"
```

---

### Task 9: Release docs, README, and GitHub push

**Files:**
- Create: `.agents/commands/EXPORT-SIGNED-APP.md`
- Create: `README.md`

- [ ] **Step 1: Write the release runbook**

`.agents/commands/EXPORT-SIGNED-APP.md` — adapt the Synapse Meetings runbook (`/Users/dep/Sites/synapse-meetings/.agents/commands/EXPORT-SIGNED-APP.md`) with these substitutions, keeping the same 8-step structure (bump version → archive with Developer ID overrides → export → codesign verify → notarize + staple → create-dmg → sign_update → appcast + GitHub release):

- Project: `ClipboardGenie.xcodeproj`, scheme `ClipboardGenie`, archive `build/ClipboardGenie.xcarchive`
- App: `build/export/Clipboard Mage.app` (PRODUCT_NAME is now "Clipboard Mage")
- Identity/team unchanged: `Developer ID Application: Danny Peck (299R8V27FZ)` / `299R8V27FZ`
- Notarize zip: `/tmp/ClipboardMage-notarize.zip`; keychain profile `notarytool` (already stored — reuse; the one-time `store-credentials` step reads `source .env`)
- DMG: `~/Desktop/ClipboardMage-<version>.dmg`, volname `Clipboard Mage`
- Entitlements path for any re-sign fallback: `ClipboardGenie/ClipboardGenie.entitlements`
- Appcast enclosure URL: `https://github.com/dep/clipboard-mage/releases/download/<version>/ClipboardMage-<version>.dmg`
- `SUFeedURL` already set to `https://raw.githubusercontent.com/dep/clipboard-mage/main/appcast.xml`
- First-release checklist: verify `/tmp/sparkle-bin/bin/generate_keys -p` prints the same public key committed in `project.yml`

- [ ] **Step 2: Write README.md**

```markdown
# Clipboard Mage 🧙

A macOS menu bar app. Hit a hotkey (default **⌃⌥⌘C**), see your clipboard in a
pretty floating panel, tell the mage how to transform it ("clean this up into
markdown"), watch the result stream in, press **Enter** to accept it into your
clipboard — or keep iterating with more instructions.

## Features
- Global hotkey summons a Spotlight-style panel with your current clipboard text
- Transformations powered by Claude (Anthropic API, Sonnet) with live streaming
- Iterate: each new instruction transforms the current result
- Optional "auto-appear on copy" mode
- API key stored in the macOS Keychain
- Auto-updates via Sparkle

## Setup
1. Download the latest DMG from Releases and drag to Applications.
2. Open Settings from the menu bar icon and paste your Anthropic API key
   (get one at https://platform.claude.com).
3. Copy some text, press ⌃⌥⌘C, and make a wish.

## Development
```sh
brew install xcodegen
xcodegen generate
open ClipboardGenie.xcodeproj
```

Releases: see `.agents/commands/EXPORT-SIGNED-APP.md`.
```

- [ ] **Step 3: Push to the existing GitHub repo**

The remote `origin` already exists and points to `https://github.com/dep/clipboard-mage.git` (created by a separate marketing-site session; the repo is public and its `main` may already contain marketing-site content). Do NOT create a new repo.

```bash
cd /Users/dep/Sites/magic-clipboard
git add README.md .agents
git commit -m "docs: README and release runbook"
git fetch origin
git push -u origin feature/clipboard-genie-v0.1
```

Expected: the feature branch is on https://github.com/dep/clipboard-mage. Merging to `main` happens after the final whole-branch review (finishing-a-development-branch), reconciling with whatever the marketing-site session put on `origin/main` — merge, don't force-push.

- [ ] **Step 4: Full manual QA pass**

Run through the complete checklist:
1. Fresh launch: menu bar icon, no Dock icon
2. Hotkey opens panel with clipboard text; Esc / click-outside dismisses
3. Empty clipboard → "Nothing to transform" state
4. No API key → error bar with Open Settings button; button opens Settings
5. Transform streams live; Stop button cancels and restores source text
6. Enter with empty field accepts → clipboard updated, panel closes
7. Iteration: instruction → result → another instruction transforms the result
8. API error (e.g. temporarily save a bogus key) → inline error, source text preserved
9. Shortcut rebinding works immediately
10. Auto-appear toggle: on = panel pops on external copy, never on self-write; off = silent
11. Check for Updates… shows the Sparkle dialog
12. Full test suite green: `xcodebuild -project ClipboardGenie.xcodeproj -scheme ClipboardGenie test`

- [ ] **Step 5: Final commit if QA produced fixes**

```bash
git add -A && git commit -m "fix: QA pass fixes" && git push
```

---

## Out of Scope (v1) — do not build

Auto-paste after accept, clipboard history, image/file clipboard support, prompt presets, model picker.
