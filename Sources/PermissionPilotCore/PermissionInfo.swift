import Foundation

/// Human-facing copy + icon for a ``Permission``.
///
/// Hosts override these to match their app's voice. Every field has a sensible
/// default from ``Permission/defaultInfo``.
public struct PermissionInfo: Hashable, Sendable {
    /// Short title shown as the row's bold name (e.g. "Screen Recording").
    public var title: String
    /// One-line "why we need this" shown under the title.
    public var reason: String
    /// SF Symbol name for the row's icon tile.
    public var systemImage: String

    public init(title: String, reason: String, systemImage: String) {
        self.title = title
        self.reason = reason
        self.systemImage = systemImage
    }
}
