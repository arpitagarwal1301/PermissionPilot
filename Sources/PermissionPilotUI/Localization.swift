import Foundation

/// Localized-string lookup against this module's (PermissionPilotUI) resource
/// bundle. Keys are stable identifiers; the English base lives in
/// `Resources/en.lproj/Localizable.strings`.
func ppLocalized(_ key: String, _ comment: String = "") -> String {
    NSLocalizedString(key, bundle: .module, comment: comment)
}

/// `String(format:)` convenience for localized format strings with arguments.
func ppFormat(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .module, comment: ""), arguments: args)
}
