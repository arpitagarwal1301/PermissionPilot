import SwiftUI
import PermissionPilot

/// A README hero composed from the **real** `OnboardingView` screens (welcome /
/// permissions / done) framed as mac windows on an app-dark backdrop. Rendered to
/// PNG by `SnapshotMode` so the banner shows actual app UI, not redrawn mockups.
struct HeroFlowBanner: View {
    let manager: PermissionManager
    let configuration: OnboardingConfiguration

    private let accent = Color(red: 0.04, green: 0.52, blue: 1.0) // system blue #0a84ff
    private let scale: CGFloat = 0.44

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.110, green: 0.110, blue: 0.118),   // #1c1c1e
                         Color(red: 0.086, green: 0.086, blue: 0.090)],  // #161617
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(colors: [accent.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.5, y: 0.08), startRadius: 10, endRadius: 560)

            VStack(spacing: 24) {
                header
                screensRow
                footer
            }
            .padding(44)
        }
        .frame(width: 1160, height: 600)
    }

    private var header: some View {
        VStack(spacing: 10) {
            (Text("Permission").foregroundColor(.white) + Text("Pilot").foregroundColor(accent))
                .font(.system(size: 46, weight: .bold))
            Text("Onboarding + permissions for macOS — declare, detect, deep-link, done.")
                .font(.system(size: 16)).foregroundColor(Color(white: 0.72))
            HStack(spacing: 8) {
                ForEach(["Zero deps", "Detect", "Deep-link", "Auto-recheck", "Drag-to-authorize"], id: \.self) { pill in
                    Text(pill)
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(accent.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(accent.opacity(0.45)))
                }
            }
        }
    }

    private var screensRow: some View {
        HStack(spacing: 22) {
            screen(.welcome, "1 · Welcome")
            chevron
            screen(.permissions, "2 · Grant")
            chevron
            screen(.done, "3 · Done")
        }
    }

    private func screen(_ step: OnboardingView.Step, _ caption: String) -> some View {
        VStack(spacing: 12) {
            MiniWindow {
                OnboardingView(manager: manager, configuration: configuration, initialStep: step)
                    .frame(width: 700, height: 540)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: 700 * scale, height: 540 * scale, alignment: .topLeading)
                    .clipped()
            }
            Text(caption).font(.system(size: 13, weight: .medium)).foregroundColor(Color(white: 0.7))
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(accent.opacity(0.8))
    }

    private var footer: some View {
        (Text("8+ built-in permissions incl. ").foregroundColor(Color(white: 0.62))
            + Text("Bluetooth · Location · Notifications").foregroundColor(.white)
            + Text(" — plus your own.").foregroundColor(Color(white: 0.62)))
            .font(.system(size: 13))
    }
}

/// A minimal mac window frame (titlebar + traffic lights) around arbitrary content.
struct MiniWindow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Color(red: 0.165, green: 0.165, blue: 0.173).frame(height: 26) // titlebar #2a2a2c
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 9, height: 9)
                    Circle().fill(Color(red: 0.996, green: 0.737, blue: 0.18)).frame(width: 9, height: 9)
                    Circle().fill(Color(red: 0.157, green: 0.784, blue: 0.251)).frame(width: 9, height: 9)
                }
                .padding(.leading, 12)
            }
            content
        }
        .background(Color(red: 0.118, green: 0.118, blue: 0.125)) // #1e1e1f
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
    }
}
