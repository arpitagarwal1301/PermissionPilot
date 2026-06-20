import XCTest
import AVFoundation
import CoreLocation
import Contacts
import EventKit
import Photos
import Speech
import CoreBluetooth
import UserNotifications
@testable import PermissionPilotCore
@testable import PermissionPilot

// NOTE: Live detection/request paths touch the real TCC database and require a
// signed `.app` plus user interaction, so they're intentionally not unit-tested.
// Coverage here is the pure mapping/decision layer (the highest-value surface).
final class PermissionPilotTests: XCTestCase {

    // MARK: Deep-link URL building

    func testDeepLinkAnchors() {
        let expected: [Permission: String] = [
            .accessibility:   "Privacy_Accessibility",
            .screenRecording: "Privacy_ScreenCapture",
            .inputMonitoring: "Privacy_ListenEvent",
            .fullDiskAccess:  "Privacy_AllFiles",
            .camera:          "Privacy_Camera",
            .microphone:      "Privacy_Microphone",
        ]
        for (permission, anchor) in expected {
            XCTAssertEqual(permission.settingsAnchor, anchor)
        }
    }

    func testDeepLinkURLFormat() {
        let url = SystemSettingsLink.url(for: .accessibility)
        XCTAssertEqual(
            url?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
        // Every permission produces a valid URL.
        for permission in Permission.allCases {
            XCTAssertNotNil(SystemSettingsLink.url(for: permission), "nil URL for \(permission)")
        }
    }

    func testAnchorsAreDistinct() {
        let anchors = Permission.allCases.map(\.settingsAnchor)
        XCTAssertEqual(Set(anchors).count, anchors.count, "anchors must be unique")
    }

    // MARK: Status mapping

    func testAVAuthorizationStatusMapping() {
        XCTAssertEqual(PermissionStatus.from(AVAuthorizationStatus.authorized), .granted)
        XCTAssertEqual(PermissionStatus.from(AVAuthorizationStatus.denied), .denied)
        XCTAssertEqual(PermissionStatus.from(AVAuthorizationStatus.restricted), .denied)
        XCTAssertEqual(PermissionStatus.from(AVAuthorizationStatus.notDetermined), .notDetermined)
    }

    func testStatusFlags() {
        XCTAssertTrue(PermissionStatus.granted.isGranted)
        XCTAssertFalse(PermissionStatus.denied.isGranted)
        XCTAssertTrue(PermissionStatus.denied.isActionable)
        XCTAssertFalse(PermissionStatus.granted.isActionable)
    }

    // MARK: Required-granted logic

    func testAllGranted() {
        let statuses: [Permission: PermissionStatus] = [
            .accessibility: .granted,
            .screenRecording: .granted,
            .camera: .denied,
        ]
        XCTAssertTrue(PermissionDecision.allGranted([.accessibility, .screenRecording], in: statuses))
        XCTAssertFalse(PermissionDecision.allGranted([.accessibility, .camera], in: statuses))
        // Empty list is vacuously granted.
        XCTAssertTrue(PermissionDecision.allGranted([], in: statuses))
    }

    func testGrantedCount() {
        let statuses: [Permission: PermissionStatus] = [
            .accessibility: .granted,
            .screenRecording: .granted,
            .inputMonitoring: .denied,
        ]
        XCTAssertEqual(
            PermissionDecision.grantedCount([.accessibility, .screenRecording, .inputMonitoring], in: statuses),
            2
        )
        // Missing keys count as not granted.
        XCTAssertEqual(PermissionDecision.grantedCount([.camera], in: statuses), 0)
    }

    // MARK: Metadata

    func testDefaultInfoIsComplete() {
        for permission in Permission.allCases {
            let info = permission.defaultInfo
            XCTAssertFalse(info.title.isEmpty, "empty title for \(permission)")
            XCTAssertFalse(info.reason.isEmpty, "empty reason for \(permission)")
            XCTAssertFalse(info.systemImage.isEmpty, "empty symbol for \(permission)")
        }
    }

    func testWizardConfigUsesLocalizedDefaults() {
        // Exercises the PermissionPilot module's Bundle.module via real defaults —
        // a missing resource would surface the key (e.g. "onboarding.done.title").
        let config = OnboardingConfiguration(appName: "Acme")
        XCTAssertEqual(config.doneTitle, "You're all set")
        XCTAssertEqual(config.resolvedWelcomeHeadline, "Welcome to Acme")
        XCTAssertEqual(
            config.resolvedDoneSubtitle,
            "Acme has everything it needs. You can change these anytime in System Settings."
        )
    }

    func testDefaultInfoIsLocalized() {
        // Proves the .strings lookup resolves against the module bundle — a missing
        // resource would return the key itself ("permission.camera.title").
        XCTAssertEqual(Permission.camera.defaultInfo.title, "Camera")
        XCTAssertEqual(Permission.accessibility.defaultInfo.title, "Accessibility")
        XCTAssertEqual(Permission.fullDiskAccess.defaultInfo.reason,
                       "Read files across your Mac that are normally protected.")
        for p in Permission.allCases {
            XCTAssertFalse(p.defaultInfo.title.hasPrefix("permission."),
                           "\(p) title not localized (got the key back)")
        }
    }

    func testPromptCapability() {
        XCTAssertFalse(Permission.fullDiskAccess.canPromptInApp)
        XCTAssertTrue(Permission.camera.canPromptInApp)
        XCTAssertTrue(Permission.accessibility.canPromptInApp)
    }

    func testRelaunchHints() {
        // Input Monitoring and Screen Recording capture authorization per process
        // launch → relaunch required on all macOS versions (incl. 15+/26).
        XCTAssertTrue(Permission.inputMonitoring.mayRequireRelaunch)
        XCTAssertTrue(Permission.screenRecording.mayRequireRelaunch)
        // Accessibility re-evaluates trust live — no relaunch.
        XCTAssertFalse(Permission.accessibility.mayRequireRelaunch)
        XCTAssertFalse(Permission.camera.mayRequireRelaunch)
    }

    func testInfoPlistKeys() {
        XCTAssertEqual(Permission.camera.requiredInfoPlistKey, "NSCameraUsageDescription")
        XCTAssertEqual(Permission.microphone.requiredInfoPlistKey, "NSMicrophoneUsageDescription")
        XCTAssertNil(Permission.screenRecording.requiredInfoPlistKey)
    }

    // MARK: Implemented tiers

    func testImplementedFlag() {
        // Every permission is implemented now.
        XCTAssertTrue(Permission.allCases.allSatisfy(\.isImplemented))
        XCTAssertEqual(Permission.implemented.count, Permission.allCases.count)
        XCTAssertTrue(Permission.comingSoon.isEmpty)
        // Partition invariant: implemented ∪ comingSoon == allCases, and disjoint.
        XCTAssertEqual(Set(Permission.implemented).union(Permission.comingSoon),
                       Set(Permission.allCases))
        XCTAssertTrue(Set(Permission.implemented).isDisjoint(with: Permission.comingSoon))
    }

    func testDeepLinkOnlyTier() {
        // Deep-link-only permissions can't prompt in-app (handled like Full Disk Access).
        for p in [Permission.fullDiskAccess, .automation, .localNetwork] {
            XCTAssertFalse(p.canPromptInApp, "\(p) should be deep-link-only")
        }
        // Automation / Local Network have no detection API → unknown (no system call).
        XCTAssertEqual(PermissionProbe.status(for: .automation), .unknown)
        XCTAssertEqual(PermissionProbe.status(for: .localNetwork), .unknown)
    }

    func testEveryImplementedNonDeepLinkIsPromptable() {
        let deepLink: Set<Permission> = [.fullDiskAccess, .automation, .localNetwork]
        for p in Permission.implemented where !deepLink.contains(p) {
            XCTAssertTrue(p.canPromptInApp, "\(p) should be promptable")
        }
    }

    // MARK: Mandatory Info.plist keys

    func testPromptBasedPermissionsHaveMandatoryKey() {
        // Requesting any of these without its usage string crashes the host.
        let needKeys: [Permission] = [.camera, .microphone, .bluetooth, .location,
                                      .contacts, .photos, .speechRecognition,
                                      .calendars, .reminders]
        for p in needKeys {
            XCTAssertNotNil(p.requiredInfoPlistKey, "\(p) must declare its usage key")
        }
    }

    func testPermissionsWithoutMandatoryKey() {
        // These never crash without a key → no mandatory key.
        for p in [Permission.accessibility, .screenRecording, .inputMonitoring,
                  .notifications, .fullDiskAccess, .automation, .localNetwork] {
            XCTAssertNil(p.requiredInfoPlistKey, "\(p) should have no mandatory key")
        }
    }

    func testCalendarsRemindersKeyIsVersioned() {
        if #available(macOS 14.0, *) {
            XCTAssertEqual(Permission.calendars.requiredInfoPlistKey, "NSCalendarsFullAccessUsageDescription")
            XCTAssertEqual(Permission.reminders.requiredInfoPlistKey, "NSRemindersFullAccessUsageDescription")
        } else {
            XCTAssertEqual(Permission.calendars.requiredInfoPlistKey, "NSCalendarsUsageDescription")
            XCTAssertEqual(Permission.reminders.requiredInfoPlistKey, "NSRemindersUsageDescription")
        }
    }

    // MARK: Framework status mappers (pure)

    func testCLAuthorizationStatusMapping() {
        // macOS exposes only `.authorizedAlways` (`.authorizedWhenInUse` is iOS-only).
        XCTAssertEqual(PermissionStatus.from(CLAuthorizationStatus.authorizedAlways), .granted)
        XCTAssertEqual(PermissionStatus.from(CLAuthorizationStatus.denied), .denied)
        XCTAssertEqual(PermissionStatus.from(CLAuthorizationStatus.restricted), .denied)
        XCTAssertEqual(PermissionStatus.from(CLAuthorizationStatus.notDetermined), .notDetermined)
    }

    func testCNAuthorizationStatusMapping() {
        XCTAssertEqual(PermissionStatus.from(CNAuthorizationStatus.authorized), .granted)
        XCTAssertEqual(PermissionStatus.from(CNAuthorizationStatus.denied), .denied)
        XCTAssertEqual(PermissionStatus.from(CNAuthorizationStatus.restricted), .denied)
        XCTAssertEqual(PermissionStatus.from(CNAuthorizationStatus.notDetermined), .notDetermined)
    }

    func testPHAuthorizationStatusMapping() {
        XCTAssertEqual(PermissionStatus.from(PHAuthorizationStatus.authorized), .granted)
        XCTAssertEqual(PermissionStatus.from(PHAuthorizationStatus.limited), .granted)
        XCTAssertEqual(PermissionStatus.from(PHAuthorizationStatus.denied), .denied)
        XCTAssertEqual(PermissionStatus.from(PHAuthorizationStatus.restricted), .denied)
        XCTAssertEqual(PermissionStatus.from(PHAuthorizationStatus.notDetermined), .notDetermined)
    }

    func testSpeechAuthorizationStatusMapping() {
        XCTAssertEqual(PermissionStatus.from(SFSpeechRecognizerAuthorizationStatus.authorized), .granted)
        XCTAssertEqual(PermissionStatus.from(SFSpeechRecognizerAuthorizationStatus.denied), .denied)
        XCTAssertEqual(PermissionStatus.from(SFSpeechRecognizerAuthorizationStatus.restricted), .denied)
        XCTAssertEqual(PermissionStatus.from(SFSpeechRecognizerAuthorizationStatus.notDetermined), .notDetermined)
    }

    func testBluetoothAuthorizationMapping() {
        XCTAssertEqual(PermissionStatus.from(CBManagerAuthorization.allowedAlways), .granted)
        XCTAssertEqual(PermissionStatus.from(CBManagerAuthorization.denied), .denied)
        XCTAssertEqual(PermissionStatus.from(CBManagerAuthorization.restricted), .denied)
        XCTAssertEqual(PermissionStatus.from(CBManagerAuthorization.notDetermined), .notDetermined)
    }

    func testNotificationAuthorizationMapping() {
        XCTAssertEqual(PermissionStatus.from(UNAuthorizationStatus.authorized), .granted)
        XCTAssertEqual(PermissionStatus.from(UNAuthorizationStatus.provisional), .granted)
        XCTAssertEqual(PermissionStatus.from(UNAuthorizationStatus.denied), .denied)
        XCTAssertEqual(PermissionStatus.from(UNAuthorizationStatus.notDetermined), .notDetermined)
    }

    func testEventKitAuthorizationMapping() {
        XCTAssertEqual(PermissionStatus.from(EKAuthorizationStatus.denied), .denied)
        XCTAssertEqual(PermissionStatus.from(EKAuthorizationStatus.restricted), .denied)
        XCTAssertEqual(PermissionStatus.from(EKAuthorizationStatus.notDetermined), .notDetermined)
        if #available(macOS 14.0, *) {
            XCTAssertEqual(PermissionStatus.from(EKAuthorizationStatus.fullAccess), .granted)
            XCTAssertEqual(PermissionStatus.from(EKAuthorizationStatus.writeOnly), .granted)
        } else {
            XCTAssertEqual(PermissionStatus.from(EKAuthorizationStatus.authorized), .granted)
        }
    }

    // MARK: Manager

    @MainActor
    func testManagerDedupesOptional() {
        let manager = PermissionManager(
            required: [.accessibility, .screenRecording],
            optional: [.screenRecording, .camera], // screenRecording overlaps required
            pollInterval: 9_999
        )
        XCTAssertEqual(manager.optional, [.camera])
        XCTAssertEqual(manager.allPermissions, [.accessibility, .screenRecording, .camera])
        manager.stopMonitoring()
    }

    @MainActor
    func testManagerInfoOverride() {
        let custom = PermissionInfo(title: "Custom", reason: "Why custom", systemImage: "star")
        let manager = PermissionManager(
            required: [.accessibility],
            infoOverrides: [.accessibility: custom],
            pollInterval: 9_999
        )
        XCTAssertEqual(manager.info(for: .accessibility), custom)
        // Non-overridden permission falls back to the default.
        XCTAssertEqual(manager.info(for: .camera), Permission.camera.defaultInfo)
        manager.stopMonitoring()
    }
}
