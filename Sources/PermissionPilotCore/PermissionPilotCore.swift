// PermissionPilotCore — engine (no UI).
//
// A zero-dependency permission model + manager for locally-distributed
// (non–App Store) macOS apps. Detects status, triggers in-app prompts where the
// OS allows, opens System Settings deep-links, and re-checks on app activation.
//
// Built entirely on Apple frameworks: Foundation, AppKit, ApplicationServices,
// CoreGraphics, AVFoundation, IOKit.hid. No third-party dependencies.
//
// The Full Disk Access heuristic and several detection approaches are informed
// by two MIT-licensed projects — PermissionFlow and FullDiskAccess — studied for
// approach and credited here, but never imported.

import Foundation

/// Namespace + version marker for PermissionPilot.
public enum PermissionPilotCore {
    /// Semantic version of the SDK.
    public static let version = "0.1.0"
}
