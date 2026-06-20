import Foundation
import AVFoundation
import CoreLocation
import Contacts
import EventKit
import Photos
import Speech
import CoreBluetooth
import UserNotifications

/// Pure framework-status → ``PermissionStatus`` mappings, one per Apple
/// authorization enum. Kept free of side effects (no TCC access) so they can be
/// unit-tested exhaustively in CI — the live detection/request paths can't be,
/// since they need a signed app and user interaction.
extension PermissionStatus {

    /// Maps an `AVAuthorizationStatus` (camera / microphone).
    static func from(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:    return .granted
        case .denied:        return .denied
        case .restricted:    return .denied
        case .notDetermined: return .notDetermined
        @unknown default:    return .unknown
        }
    }

    /// Maps a `CLAuthorizationStatus` (location). macOS only exposes
    /// `.authorizedAlways` (the deprecated `.authorized` shares its raw value);
    /// `.authorizedWhenInUse` is iOS-only.
    static func from(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorizedAlways:    return .granted
        case .denied, .restricted: return .denied
        case .notDetermined:       return .notDetermined
        @unknown default:          return .unknown
        }
    }

    /// Maps a `CNAuthorizationStatus` (contacts).
    static func from(_ status: CNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:           return .granted
        case .denied, .restricted:  return .denied
        case .notDetermined:        return .notDetermined
        @unknown default:           return .unknown
        }
    }

    /// Maps a `PHAuthorizationStatus` (photo library). `.limited` still grants
    /// access to the user-picked subset, so it counts as granted.
    static func from(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .limited: return .granted
        case .denied, .restricted:  return .denied
        case .notDetermined:        return .notDetermined
        @unknown default:           return .unknown
        }
    }

    /// Maps an `SFSpeechRecognizerAuthorizationStatus` (speech recognition).
    static func from(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:           return .granted
        case .denied, .restricted:  return .denied
        case .notDetermined:        return .notDetermined
        @unknown default:           return .unknown
        }
    }

    /// Maps a `CBManagerAuthorization` (Bluetooth).
    static func from(_ status: CBManagerAuthorization) -> PermissionStatus {
        switch status {
        case .allowedAlways:        return .granted
        case .denied, .restricted:  return .denied
        case .notDetermined:        return .notDetermined
        @unknown default:           return .unknown
        }
    }

    /// Maps a `UNAuthorizationStatus` (notifications). `.provisional` grants quiet
    /// delivery, so it counts as granted. (`.ephemeral` is iOS-only.)
    static func from(_ status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .provisional: return .granted
        case .denied:                   return .denied
        case .notDetermined:            return .notDetermined
        @unknown default:               return .unknown
        }
    }

    /// Maps an `EKAuthorizationStatus` (calendars / reminders). The case set is
    /// availability- and deprecation-churned (`.authorized` ⇄ `.fullAccess` share
    /// raw value 3; `.writeOnly` is macOS 14+), which makes a case-based switch
    /// either warn ("not exhaustive") or emit deprecation warnings. The raw values
    /// are stable EventKit ABI, so we map on them: 3 = authorized/fullAccess and
    /// 4 = writeOnly both permit access → granted.
    static func from(_ status: EKAuthorizationStatus) -> PermissionStatus {
        switch status.rawValue {
        case 0:    return .notDetermined          // .notDetermined
        case 1, 2: return .denied                 // .restricted, .denied
        case 3, 4: return .granted                // .authorized / .fullAccess, .writeOnly
        default:   return .unknown
        }
    }
}
