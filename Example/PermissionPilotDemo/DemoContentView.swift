import SwiftUI
import PermissionPilot

/// The demo's main window: the standalone ``PermissionsView`` (live status, with
/// the List/Grid toggle and the full permission board incl. "coming soon") plus
/// controls to re-run onboarding and inspect the persisted flag.
struct DemoContentView: View {
    @ObservedObject var manager: PermissionManager
    var onReopenOnboarding: () -> Void

    @AppStorage(OnboardingState.completedKey) private var completed = false

    var body: some View {
        VStack(alignment: .leading, spacing: PPDesign.s20) {
            VStack(alignment: .leading, spacing: PPDesign.s4) {
                Text("PermissionPilot Demo")
                    .font(.title2).fontWeight(.semibold)
                Text("Live status — rows flip automatically when you change a toggle in System Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Full board: implemented permissions + the "coming soon" roadmap.
            // maxHeight lets PermissionsView scroll its rows/tiles internally.
            PermissionsView(manager: manager, permissions: Permission.allCases)
                .frame(maxHeight: .infinity)

            HStack(spacing: PPDesign.s12) {
                Button("Re-run Onboarding", action: onReopenOnboarding)
                    .buttonStyle(.borderedProminent)
                Button("Reset Completion Flag") { PermissionPilot.resetOnboarding() }
                Button("Refresh") { manager.refresh() }
                Spacer()
                Label(
                    completed ? "Onboarding completed" : "Onboarding not completed",
                    systemImage: completed ? "checkmark.seal.fill" : "circle.dashed"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(PPDesign.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
