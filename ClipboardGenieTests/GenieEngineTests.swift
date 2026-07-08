import XCTest
@testable import Clipboard_Mage

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
