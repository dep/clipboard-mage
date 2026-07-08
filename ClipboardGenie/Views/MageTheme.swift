import SwiftUI

/// Always-dark palette lifted from marketing-site/css/style.css — keep in sync.
enum MageTheme {
    static let bg = Color(red: 0x13 / 255, green: 0x0E / 255, blue: 0x26 / 255)        // #130e26
    static let bgDeep = Color(red: 0x0A / 255, green: 0x07 / 255, blue: 0x16 / 255)    // #0a0716
    static let ink = Color(red: 0xF2 / 255, green: 0xEE / 255, blue: 0xFC / 255)       // #f2eefc
    static let inkDim = Color(red: 0xB6 / 255, green: 0xAE / 255, blue: 0xD0 / 255)    // #b6aed0
    static let inkFaint = Color(red: 0x7E / 255, green: 0x74 / 255, blue: 0xA3 / 255)  // #7e74a3
    static let violet = Color(red: 0xA7 / 255, green: 0x8B / 255, blue: 0xFA / 255)    // #a78bfa
    static let violetGlow = Color(red: 0x7C / 255, green: 0x5C / 255, blue: 0xFF / 255) // #7c5cff
    static let gold = Color(red: 0xFF / 255, green: 0xD5 / 255, blue: 0x7A / 255)      // #ffd57a

    static let border = violet.opacity(0.18)
    static let borderBright = violet.opacity(0.38)
    static let cornerRadius: CGFloat = 18
}
