import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @AppStorage("autoAppearOnCopy") private var autoAppearOnCopy = false
    @State private var apiKeyField = ""
    @State private var keyIsSaved = false
    @State private var saveErrorMessage: String?

    private let keychain = KeychainStore()
    private let account = "anthropic-api-key"

    var body: some View {
        Form {
            Section("Shortcut") {
                KeyboardShortcuts.Recorder("Summon the mage:", name: .toggleGenie)
            }

            Section("Anthropic API Key") {
                HStack {
                    SecureField(
                        keyIsSaved ? "••••••••••••••••••••  (saved)" : "sk-ant-…",
                        text: $apiKeyField
                    )
                    .textContentType(.password)
                    Button("Save") { saveKey() }
                        .disabled(apiKeyField.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if keyIsSaved {
                    Button("Remove key", role: .destructive) {
                        keychain.delete(account: account)
                        keyIsSaved = false
                        apiKeyField = ""
                    }
                }
                Text("Stored securely in your macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Behavior") {
                Toggle("Auto-appear when I copy text", isOn: $autoAppearOnCopy)
                Text("Opens the mage every time you copy text. Press Esc to dismiss.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .background(SettingsWindowElevator())
        .onAppear {
            keyIsSaved = keychain.read(account: account) != nil
            // LSUIElement apps don't activate when the Settings scene opens,
            // so the window can appear behind the frontmost app.
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    /// Grabs the hosting NSWindow and brings it to the front — needed because
    /// an LSUIElement app isn't activated when SwiftUI opens the Settings scene.
    private struct SettingsWindowElevator: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                guard let window = view.window else { return }
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {}
    }

    private func saveKey() {
        let key = apiKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try keychain.save(key, account: account)
            keyIsSaved = keychain.read(account: account) != nil
            saveErrorMessage = keyIsSaved ? nil : "The key could not be verified after saving."
            if keyIsSaved { apiKeyField = "" }
        } catch {
            keyIsSaved = false
            saveErrorMessage = "Couldn't save to the Keychain: \(error.localizedDescription)"
        }
    }
}
