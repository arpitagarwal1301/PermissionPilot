// swift-tools-version:5.9
import PackageDescription

// PermissionPilot — a zero-dependency SwiftUI onboarding + permissions SDK
// for locally-distributed (non–App Store) macOS apps.
//
// Three composable products, each usable independently:
//   1. PermissionPilotCore — engine, no UI.
//   2. PermissionPilotUI   — status rows + checklist (depends on Core).
//   3. PermissionPilot     — full onboarding wizard (depends on Core + UI).
//
// Hard constraint: zero third-party dependencies — Apple frameworks only.
let package = Package(
    name: "PermissionPilot",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "PermissionPilotCore", targets: ["PermissionPilotCore"]),
        .library(name: "PermissionPilotUI", targets: ["PermissionPilotUI"]),
        .library(name: "PermissionPilot", targets: ["PermissionPilot"]),
    ],
    dependencies: [
        // Intentionally empty: zero third-party dependencies.
    ],
    targets: [
        // Engine — no UI.
        .target(
            name: "PermissionPilotCore",
            resources: [.process("Resources")]
        ),
        // Components — status rows + checklist.
        .target(
            name: "PermissionPilotUI",
            dependencies: ["PermissionPilotCore"],
            resources: [.process("Resources")]
        ),
        // Flow — full onboarding wizard.
        .target(
            name: "PermissionPilot",
            dependencies: ["PermissionPilotCore", "PermissionPilotUI"],
            resources: [.process("Resources")]
        ),
        // Example macOS app demonstrating the full wizard.
        .executableTarget(
            name: "PermissionPilotDemo",
            dependencies: ["PermissionPilot"],
            path: "Example/PermissionPilotDemo",
            exclude: ["Info.plist"] // bundled by Example/build-demo-app.sh, not a Swift source
        ),
        // Tests.
        .testTarget(
            name: "PermissionPilotTests",
            dependencies: ["PermissionPilotCore", "PermissionPilotUI", "PermissionPilot"]
        ),
    ]
)
