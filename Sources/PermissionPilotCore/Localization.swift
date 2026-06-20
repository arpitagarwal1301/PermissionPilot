import Foundation

/// Localized-string lookup against this module's resource bundle.
///
/// PermissionPilot ships an English base; hosts (or contributors) can add more
/// `.lproj` localizations. Keys are stable identifiers, not English text, so
/// translations don't drift when copy is reworded.
func ppLocalized(_ key: String, _ comment: String = "") -> String {
    NSLocalizedString(key, bundle: .module, comment: comment)
}
