// PermissionPilotCore — engine (no UI).
//
// A zero-dependency permission model + manager for locally-distributed
// (non–App Store) macOS apps. Detects status, triggers in-app prompts where the
// OS allows, opens System Settings deep-links, and re-checks on app activation.
//
// Built entirely on Apple frameworks: Foundation, AppKit, ApplicationServices,
// CoreGraphics, AVFoundation, IOKit.hid. No third-party dependencies.
//
// Implemented independently — detection, deep-links, the wizard, and
// drag-to-authorize are all original. The Full Disk Access check uses the
// well-known technique of probing a TCC-protected file (also used by the
// MIT-licensed FullDiskAccess project).

import Foundation

/// Namespace + version marker for PermissionPilot.
public enum PermissionPilotCore {
    /// Semantic version of the SDK.
    public static let version = "0.1.0"
}
