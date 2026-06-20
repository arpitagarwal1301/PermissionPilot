import SwiftUI

/// A row of step dots for the onboarding wizard. The active dot uses the
/// resolved tint; inactive dots are a quaternary fill.
public struct StepIndicator: View {
    private let total: Int
    private let current: Int

    @Environment(\.permissionPilotTint) private var tint
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    /// - Parameters:
    ///   - current: Zero-based index of the active step.
    ///   - total: Total number of steps.
    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    public var body: some View {
        HStack(spacing: PPDesign.stepDotGap) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Circle()
                    .fill(index == current ? (tint ?? Color.accentColor) : Color(nsColor: .quaternaryLabelColor))
                    .frame(width: PPDesign.stepDotSize, height: PPDesign.stepDotSize)
                    .overlay {
                        // Non-color cue for the active step when the user has
                        // "Differentiate Without Color" on (keeps the default look otherwise).
                        if differentiateWithoutColor && index == current {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 1.5)
                                .padding(-2)
                        }
                    }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(current + 1) of \(total)"))
    }
}
