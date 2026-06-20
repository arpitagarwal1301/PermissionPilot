import Foundation
import AppKit

/// Builds and opens `x-apple.systempreferences:` deep-links to the exact
/// Privacy & Security pane for a permission.
///
/// Anchors are verified per the design doc's table and may need maintenance as
/// macOS evolves — that maintenance is part of the project's value.
public enum SystemSettingsLink {
    /// The base Privacy & Security preference bundle.
    private static let base = "x-apple.systempreferences:com.apple.preference.security"

    /// The deep-link URL for a permission's System Settings pane.
    ///
    /// e.g. `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
    public static func url(for permission: Permission) -> URL? {
        URL(string: "\(base)?\(permission.settingsAnchor)")
    }

    /// Opens the System Settings pane for `permission`.
    ///
    /// Tries `NSWorkspace.open` first, then falls back to `/usr/bin/open`, then
    /// to an AppleScript that activates System Settings — so a single API quirk
    /// on a given macOS version never strands the user.
    @discardableResult
    @MainActor
    public static func open(_ permission: Permission) -> Bool {
        guard let url = url(for: permission) else { return false }
        return open(url)
    }

    @discardableResult
    @MainActor
    static func open(_ url: URL) -> Bool {
        if NSWorkspace.shared.open(url) { return true }
        if openViaProcess(url) { return true }
        return openViaAppleScript()
    }

    /// Fallback 1: shell out to `/usr/bin/open`.
    private static func openViaProcess(_ url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }

    /// Fallback 2: at least bring System Settings to the foreground so the user
    /// can navigate manually.
    private static func openViaAppleScript() -> Bool {
        let source = "tell application \"System Settings\" to activate"
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
}
