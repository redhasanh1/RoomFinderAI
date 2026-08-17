import SwiftUI

/// The website's palette, so native chrome and web content read as one app.
enum Theme {

    /// #667eea — the start of the site's primary gradient and its most-used
    /// colour by a wide margin.
    static let brand = Color(red: 0x66 / 255, green: 0x7e / 255, blue: 0xea / 255)

    /// #764ba2 — the end of that gradient.
    static let brandDeep = Color(red: 0x76 / 255, green: 0x4b / 255, blue: 0xa2 / 255)

    static let gradient = LinearGradient(
        colors: [brand, brandDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
