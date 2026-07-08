import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @AppStorage("autoAppearOnCopy") private var autoAppearOnCopy = false
    @State private var apiKeyField = ""
    @State private var keyIsSaved = false

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
        .onAppear { keyIsSaved = keychain.read(account: account) != nil }
    }

    private func saveKey() {
        let key = apiKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        try? keychain.save(key, account: account)
        keyIsSaved = true
        apiKeyField = ""
    }
}
