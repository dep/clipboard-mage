import AppKit

@MainActor
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
