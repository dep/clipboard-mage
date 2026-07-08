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
