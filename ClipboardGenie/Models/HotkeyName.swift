import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleGenie = Self(
        "toggleGenie",
        default: .init(.c, modifiers: [.control, .option, .command])
    )
}
