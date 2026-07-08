import XCTest
@testable import Clipboard_Mage

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

/// Engine whose stream is driven manually by the test.
final class ManualEngine: TransformEngine, @unchecked Sendable {
    var continuation: AsyncThrowingStream<String, Error>.Continuation?
    func transform(text: String, instruction: String, apiKey: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { self.continuation = $0 }
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

    func testStaleTransformCannotClobberStateAfterReBegin() async throws {
        let engine = ManualEngine()
        let session = GenieSession(engine: engine, apiKeyProvider: { "sk-test" })

        session.begin(with: "old source")
        session.instruction = "transform"
        session.submit()
        // Wait for the stream task to start and register its continuation.
        for _ in 0..<200 where engine.continuation == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        let staleContinuation = try XCTUnwrap(engine.continuation)

        // User closes and re-opens the panel with new clipboard content.
        session.begin(with: "new source")
        XCTAssertEqual(session.previewText, "new source")

        // The orphaned stream now emits — none of it may touch the session.
        staleContinuation.yield("STALE DELTA")
        staleContinuation.finish(throwing: GenieError.http(status: 500, message: "stale boom"))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(session.previewText, "new source")
        XCTAssertNil(session.errorMessage)
        XCTAssertFalse(session.hasResult)
        XCTAssertFalse(session.isStreaming)
    }
}
