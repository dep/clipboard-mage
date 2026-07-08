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
