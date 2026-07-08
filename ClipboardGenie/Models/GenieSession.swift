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
    private var generation = 0

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
        generation += 1
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

        let gen = generation
        streamTask = Task {
            do {
                for try await delta in engine.transform(text: source, instruction: instruction, apiKey: apiKey) {
                    guard gen == generation else { return }
                    previewText += delta
                }
                guard gen == generation else { return }
                hasResult = true
                self.instruction = ""
            } catch is CancellationError {
                guard gen == generation else { return }
                previewText = source
            } catch {
                guard gen == generation else { return }
                previewText = source
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            guard gen == generation else { return }
            isStreaming = false
        }
    }
}
