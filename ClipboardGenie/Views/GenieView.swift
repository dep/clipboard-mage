import SwiftUI

struct GenieView: View {
    @ObservedObject var session: GenieSession
    var onClose: () -> Void
    var onOpenSettings: () -> Void

    @FocusState private var instructionFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            previewPane
            Divider()
            instructionField
        }
        .frame(width: 640, height: 420)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        )
        .onAppear { instructionFocused = true }
        .onExitCommand { onClose() }
    }

    @ViewBuilder
    private var previewPane: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                Text(session.previewText.isEmpty && !session.isStreaming
                     ? placeholderText
                     : session.previewText)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(session.hasClipboardText ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .textSelection(.enabled)
            }
            if session.isStreaming && session.previewText.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("The mage is casting…").foregroundStyle(.secondary)
                }
                .padding(16)
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let error = session.errorMessage {
                errorBar(error)
            } else if session.hasResult && !session.isStreaming {
                hintBar("↩ to copy to clipboard — or type another instruction")
            }
        }
    }

    private var placeholderText: String {
        session.hasClipboardText ? "" : "Nothing to transform — copy some text first."
    }

    private func errorBar(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message).font(.callout).lineLimit(2)
            Spacer()
            if message.contains("Settings") {
                Button("Open Settings") { onOpenSettings() }
            }
        }
        .padding(10)
        .background(.regularMaterial)
    }

    private func hintBar(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
    }

    private var instructionField: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.tint)
            TextField(
                session.hasResult ? "Press ↩ to accept, or ask for another change…"
                                  : "How should I transform this?",
                text: $session.instruction,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(.body, design: .rounded))
            .lineLimit(1...4)
            .focused($instructionFocused)
            .onSubmit { session.submit() }
            .disabled(session.isStreaming)
            if session.isStreaming {
                Button("Stop") { session.cancelStreaming() }
                    .controlSize(.small)
            }
        }
        .padding(14)
    }
}
