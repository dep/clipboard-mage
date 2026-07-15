import SwiftUI

struct GenieView: View {
    @ObservedObject var session: GenieSession
    var onClose: () -> Void
    var onOpenSettings: () -> Void

    @FocusState private var instructionFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            previewPane
            divider
            instructionField
        }
        .frame(width: 640, height: 420)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: MageTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MageTheme.cornerRadius, style: .continuous)
                .strokeBorder(MageTheme.borderBright, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .onAppear { instructionFocused = true }
        .onExitCommand { onClose() }
    }

    private var divider: some View {
        Rectangle()
            .fill(MageTheme.border)
            .frame(height: 1)
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MageTheme.cornerRadius, style: .continuous)
                .fill(MageTheme.bg.opacity(0.94))
            RadialGradient(
                colors: [MageTheme.violetGlow.opacity(0.10), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
        }
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: MageTheme.cornerRadius, style: .continuous)
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("🪄").font(.system(size: 16))
            Text("Clipboard Mage")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(MageTheme.ink.opacity(0.85))
            Spacer()
            statusPill
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statusPill: some View {
        if session.isStreaming {
            pill("STREAMING…", color: MageTheme.gold)
        } else if session.hasResult {
            pill("↩ TO ACCEPT", color: MageTheme.violet)
        }
    }

    private func pill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.08)))
            .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
    }

    // MARK: Preview

    @ViewBuilder
    private var previewPane: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $session.previewText)
                .font(.system(size: 13, design: .monospaced))
                .lineSpacing(4)
                .foregroundStyle(MageTheme.ink)
                .tint(MageTheme.violet)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.automatic)
                .padding(13) // TextEditor has ~5pt intrinsic inset; total ≈ old 18pt padding
                .disabled(session.isStreaming)
            if session.previewText.isEmpty && !session.isStreaming {
                Text(placeholderText)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(4)
                    .foregroundStyle(MageTheme.inkFaint)
                    .padding(18)
                    .allowsHitTesting(false)
            }
            if session.isStreaming && session.previewText.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(MageTheme.gold)
                    Text("The mage is casting…")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(MageTheme.gold.opacity(0.9))
                }
                .padding(18)
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let error = session.errorMessage {
                errorBar(error)
            }
        }
    }

    private var placeholderText: String {
        "Copy some text, or type it here…"
    }

    private func errorBar(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MageTheme.gold)
            Text(message)
                .font(.callout)
                .lineLimit(2)
                .foregroundStyle(MageTheme.ink)
            Spacer()
            if message.contains("Settings") {
                Button("Open Settings") { onOpenSettings() }
                    .buttonStyle(.plain)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(MageTheme.violet)
            }
        }
        .padding(12)
        .background(MageTheme.bgDeep.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle().fill(MageTheme.border).frame(height: 1)
        }
    }

    // MARK: Input

    private var instructionField: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MageTheme.gold)
            TextField(
                "",
                text: $session.instruction,
                prompt: Text(promptText).foregroundColor(MageTheme.inkFaint),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(MageTheme.ink)
            .tint(MageTheme.violet)
            .lineLimit(1...4)
            .focused($instructionFocused)
            .onSubmit { session.submit() }
            .disabled(session.isStreaming)
            .onChange(of: session.isStreaming) { _, streaming in
                if !streaming { instructionFocused = true }
            }
            trailingControl
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var promptText: String {
        session.hasResult
            ? "Press ↩ to accept, or ask for another change…"
            : "How should I transform this?"
    }

    @ViewBuilder
    private var trailingControl: some View {
        if session.isStreaming {
            Button("Stop") { session.cancelStreaming() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MageTheme.gold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(MageTheme.gold.opacity(0.5), lineWidth: 1))
        } else {
            Button { session.submit() } label: {
                Image(systemName: "return")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MageTheme.inkDim)
                    .frame(width: 40, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(MageTheme.borderBright, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
