import XCTest
@testable import PermissionPilotCore

/// Scaffold smoke test. Real tests (status mapping, deep-link URL building,
/// required-granted logic) are added during implementation.
final class PermissionPilotTests: XCTestCase {
    func testScaffoldVersion() {
        XCTAssertEqual(PermissionPilotCore.version, "0.0.1")
    }
}
