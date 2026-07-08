import SwiftUI

@main
struct ClipboardGenieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipboard Mage", systemImage: "wand.and.stars") {
            Button("Open Mage") {
                appDelegate.showPanel()
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
