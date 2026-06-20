import XCTest
import AVFoundation
@testable import PermissionPilotCore

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
        XCTAssertEqual(PermissionStatus.from(.authorized), .granted)
        XCTAssertEqual(PermissionStatus.from(.denied), .denied)
        XCTAssertEqual(PermissionStatus.from(.restricted), .denied)
        XCTAssertEqual(PermissionStatus.from(.notDetermined), .notDetermined)
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

    func testPromptCapability() {
        XCTAssertFalse(Permission.fullDiskAccess.canPromptInApp)
        XCTAssertTrue(Permission.camera.canPromptInApp)
        XCTAssertTrue(Permission.accessibility.canPromptInApp)
    }

    func testRelaunchHints() {
        XCTAssertTrue(Permission.inputMonitoring.mayRequireRelaunch)
        XCTAssertTrue(Permission.screenRecording.mayRequireRelaunch)
        XCTAssertFalse(Permission.camera.mayRequireRelaunch)
    }

    func testInfoPlistKeys() {
        XCTAssertEqual(Permission.camera.requiredInfoPlistKey, "NSCameraUsageDescription")
        XCTAssertEqual(Permission.microphone.requiredInfoPlistKey, "NSMicrophoneUsageDescription")
        XCTAssertNil(Permission.screenRecording.requiredInfoPlistKey)
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
