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
