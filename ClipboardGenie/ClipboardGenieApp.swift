import SwiftUI

@main
struct ClipboardGenieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipboard Mage", image: "MenuBarIcon") {
            Button("Open Mage") {
                appDelegate.showPanel()
            }
            Button("Check for Updates…") {
                appDelegate.updaterController.checkForUpdates(nil)
            }
            Divider()
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Quit Clipboard Mage") {
                NSApp.terminate(nil)
            }
        }
        Settings {
            SettingsView()
        }
    }
}
