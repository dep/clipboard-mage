import AppKit
import SwiftUI

/// Borderless panels refuse key status unless we say otherwise.
final class GeniePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: GeniePanel?
    private let session: GenieSession
    private let clipboard: ClipboardService

    init(session: GenieSession, clipboard: ClipboardService) {
        self.session = session
        self.clipboard = clipboard
        super.init()
        session.onAccept = { [weak self] text in
            self?.clipboard.write(text)
            self?.hide()
        }
    }

    func show() {
        session.begin(with: clipboard.currentText())

        if panel == nil {
            let content = GenieView(
                session: session,
                onClose: { [weak self] in self?.hide() },
                onOpenSettings: { [weak self] in
                    self?.hide()
                    NSApp.activate(ignoringOtherApps: true)
                    // Programmatic Settings open (SettingsLink can't be triggered from AppKit)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            )
            let hosting = NSHostingController(rootView: content)
            let newPanel = GeniePanel(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.contentViewController = hosting
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.hidesOnDeactivate = false
            newPanel.isReleasedWhenClosed = false
            newPanel.delegate = self
            panel = newPanel
        }

        centerPanel()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        session.cancelStreaming()
        panel?.orderOut(nil)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? hide() : show()
    }

    private func centerPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.midY - panel.frame.height / 2 + frame.height * 0.08
        )
        panel.setFrameOrigin(origin)
    }

    // Click-outside dismissal: the panel resigns key when another window is clicked.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
