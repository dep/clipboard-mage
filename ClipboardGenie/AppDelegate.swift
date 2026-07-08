import AppKit
import Foundation
import KeyboardShortcuts
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) lazy var clipboard = ClipboardService()
    private(set) lazy var session = GenieSession(
        engine: GenieEngine(),
        apiKeyProvider: { KeychainStore().read(account: "anthropic-api-key") }
    )
    private(set) lazy var panelController = PanelController(session: session, clipboard: clipboard)
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

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

    func showPanel() {
        panelController.show()
    }
}
