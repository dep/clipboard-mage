import SwiftUI

@main
struct ClipboardGenieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipboard Genie", systemImage: "wand.and.stars") {
            Button("Open Genie") {
                appDelegate.showPanel()
            }
            Divider()
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Quit Clipboard Genie") {
                NSApp.terminate(nil)
            }
        }
        Settings {
            Text("Settings coming soon")
                .padding(40)
        }
    }
}
