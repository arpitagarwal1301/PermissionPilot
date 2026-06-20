import Foundation
import AppKit
import ApplicationServices
import CoreGraphics
import AVFoundation
import IOKit.hid

/// Low-level detection + request implementations, one per permission, built on
/// Apple framework APIs. Stateless; ``PermissionManager`` owns the published state.
///
/// Detection is always queried *fresh* (never cached) so a stale snapshot — most
/// notably the historical `CGPreflightScreenCaptureAccess` launch-time value —
/// cannot mask a change the user just made in System Settings.
enum PermissionProbe {

    // MARK: Detect

    static func status(for permission: Permission) -> PermissionStatus {
        switch permission {
        case .accessibility:   return accessibilityStatus()
        case .screenRecording: return screenRecordingStatus()
        case .inputMonitoring: return inputMonitoringStatus()
        case .fullDiskAccess:  return fullDiskAccessStatus()
        case .camera:          return mediaStatus(for: .video)
        case .microphone:      return mediaStatus(for: .audio)
        }
    }

    static func accessibilityStatus() -> PermissionStatus {
        // No notDetermined distinction is exposed; untrusted is treated as denied
        // (still actionable — the row offers "Enable").
        AXIsProcessTrusted() ? .granted : .denied
    }

    static func screenRecordingStatus() -> PermissionStatus {
        // Queried fresh every call; see the stale-preflight note above.
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    static func inputMonitoringStatus() -> PermissionStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied:  return .denied
        case kIOHIDAccessTypeUnknown: return .notDetermined
        default:                      return .unknown
        }
    }

    static func mediaStatus(for mediaType: AVMediaType) -> PermissionStatus {
        PermissionStatus.from(AVCaptureDevice.authorizationStatus(for: mediaType))
    }

    /// Full Disk Access has no detection API. We probe by attempting to open a
    /// well-known TCC-protected file for reading — success implies FDA is granted.
    ///
    /// Approach credited to the MIT-licensed FullDiskAccess project
    /// (https://github.com/inket/FullDiskAccess), reimplemented here.
    static func fullDiskAccessStatus() -> PermissionStatus {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Safari/CloudTabs.db"),
            URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db"),
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forReadingFrom: url) {
                try? handle.close()
                return .granted
            }
            // The protected file exists but cannot be opened → not yet authorized.
            return .denied
        }
        // None of the probe files exist on this system; cannot confirm.
        return .unknown
    }

    // MARK: Request

    /// Triggers the appropriate request path for `permission` and reports the
    /// resulting status on the main queue.
    ///
    /// - Camera/Microphone show a true one-time system prompt.
    /// - Accessibility shows the system "Open System Settings" prompt.
    /// - Screen Recording / Input Monitoring add the app and may prompt; the
    ///   grant often only applies after relaunch.
    /// - Full Disk Access has no prompt — we deep-link to System Settings.
    @MainActor
    static func request(_ permission: Permission, completion: @escaping (PermissionStatus) -> Void) {
        switch permission {
        case .accessibility:
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
            let options = [key: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            completion(accessibilityStatus())

        case .screenRecording:
            let granted = CGRequestScreenCaptureAccess()
            completion(granted ? .granted : screenRecordingStatus())

        case .inputMonitoring:
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            completion(granted ? .granted : inputMonitoringStatus())

        case .camera:
            requestMedia(.video, completion: completion)

        case .microphone:
            requestMedia(.audio, completion: completion)

        case .fullDiskAccess:
            SystemSettingsLink.open(.fullDiskAccess)
            completion(fullDiskAccessStatus())
        }
    }

    private static func requestMedia(
        _ mediaType: AVMediaType,
        completion: @escaping (PermissionStatus) -> Void
    ) {
        AVCaptureDevice.requestAccess(for: mediaType) { granted in
            DispatchQueue.main.async {
                completion(granted ? .granted : .denied)
            }
        }
    }
}

// MARK: - Status mapping

extension PermissionStatus {
    /// Maps an `AVAuthorizationStatus` to a ``PermissionStatus``. Pure; unit-tested.
    static func from(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:    return .granted
        case .denied:        return .denied
        case .restricted:    return .denied
        case .notDetermined: return .notDetermined
        @unknown default:    return .unknown
        }
    }
}
