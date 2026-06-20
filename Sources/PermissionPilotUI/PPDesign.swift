import SwiftUI

/// Design tokens from the approved visual spec (`design/` spec sheet).
///
/// Colors are **semantic** so the UI adapts to dark mode, increase-contrast, and
/// the user's accent automatically — the hex values in the spec are only the
/// reference the system produces. Metrics are starting values; SwiftUI layout adapts.
public enum PPDesign {

    // MARK: Metrics (pt)

    public static let windowWidth: CGFloat = 700
    public static let windowHeight: CGFloat = 540
    public static let cardWidth: CGFloat = 640
    public static let rowHeight: CGFloat = 64
    public static let iconTileSize: CGFloat = 40

    // Corner radii
    public static let cardRadius: CGFloat = 12
    public static let appIconRadius: CGFloat = 22
    public static let iconTileRadius: CGFloat = 9

    // Spacing scale: 4 · 8 · 12 · 16 · 20 · 24 · 32
    public static let s4: CGFloat = 4
    public static let s8: CGFloat = 8
    public static let s12: CGFloat = 12
    public static let s16: CGFloat = 16
    public static let s20: CGFloat = 20
    public static let s24: CGFloat = 24
    public static let s32: CGFloat = 32

    public static let rowIconTextGap: CGFloat = 13
    public static let cardPadding: CGFloat = 22
    public static let stepDotSize: CGFloat = 7
    public static let stepDotGap: CGFloat = 7
    public static let appIconSlot: CGFloat = 88
}

/// Semantic color helpers. `Color.primary` / `.secondary` already map to
/// `labelColor` / `secondaryLabelColor`; these cover the rest.
public enum PPColor {
    /// Card / control surface (`NSColor.controlBackgroundColor`).
    public static let card = Color(nsColor: .controlBackgroundColor)
    /// Window background (`NSColor.windowBackgroundColor`).
    public static let window = Color(nsColor: .windowBackgroundColor)
    /// Hairline separators (`NSColor.separatorColor`).
    public static let separator = Color(nsColor: .separatorColor)
    /// Reserved for the *granted* state only (`NSColor.systemGreen`).
    public static let granted = Color(nsColor: .systemGreen)

    /// Subtle neutral fill behind row icons.
    /// Spec: black @ 5% (light) / white @ 10% (dark).
    public static func iconTile(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.05)
    }
}
