import SwiftUI
import PermissionPilotCore

/// A permissions surface with a **single shared header** (title + "N of M enabled"
/// counter) and an **icon List ⇄ Grid toggle**, rendering either the list rows or
/// the grid tiles below. The header/counter stay in the same position in both
/// modes so switching is seamless.
public struct PermissionsView: View {

    /// The two presentations.
    public enum Layout: String, CaseIterable, Sendable { case list, grid }

    @ObservedObject private var manager: PermissionManager
    private let permissions: [Permission]
    private let reasonOverrides: [Permission: String]
    private let title: String
    private let showsCard: Bool
    private let showsRelaunchHint: Bool

    @State private var layout: Layout
    @Environment(\.colorScheme) private var scheme
    @Environment(\.permissionPilotTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - manager: The permission engine to observe.
    ///   - permissions: Which permissions to show (default: the manager's declared
    ///     set). Pass a wider list (e.g. `Permission.allCases`) to advertise the
    ///     "coming soon" roadmap.
    ///   - title: Header title (default "Permissions").
    ///   - reasonOverrides: Per-permission reason copy overrides.
    ///   - defaultLayout: Initial view (default `.list`).
    ///   - showsCard: Whether to draw the rounded card surface (default `true`).
    ///   - showsRelaunchHint: Whether to show the "Quit & Reopen" footer when a
    ///     relaunch-requiring permission is pending (default `true`).
    public init(
        manager: PermissionManager,
        permissions: [Permission]? = nil,
        title: String? = nil,
        reasonOverrides: [Permission: String] = [:],
        defaultLayout: Layout = .list,
        showsCard: Bool = true,
        showsRelaunchHint: Bool = true
    ) {
        self.manager = manager
        self.permissions = permissions ?? manager.allPermissions
        self.title = title ?? ppLocalized("permissions.title")
        self.reasonOverrides = reasonOverrides
        self.showsCard = showsCard
        self.showsRelaunchHint = showsRelaunchHint
        _layout = State(initialValue: defaultLayout)
    }

    private var grantedCount: Int { manager.grantedCount(of: permissions) }
    private var implementedCount: Int { permissions.filter(\.isImplemented).count }
    private var comingSoonCount: Int { permissions.count - implementedCount }

    public var body: some View {
        let pad = showsCard ? PPDesign.cardPadding : 0
        // Header (and relaunch hint) stay pinned; only the list/grid scrolls.
        return VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, pad)
                .padding(.top, pad)
                .padding(.bottom, PPDesign.s12)
            ScrollView {
                content
                    .padding(.horizontal, pad)
                    .padding(.bottom, PPDesign.s12)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: layout)
            }
            if showsRelaunchHint && manager.relaunchSuggested {
                relaunchBanner
                    .padding(.horizontal, pad)
                    .padding(.top, PPDesign.s8)
                    .padding(.bottom, pad)
            }
        }
        .frame(maxWidth: PPDesign.cardWidth)
        .modifier(PermissionsCard(enabled: showsCard))
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(.primary)
                Text(counterText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: PPDesign.s12)

            Picker(ppLocalized("permissions.view.picker"), selection: $layout) {
                Image(systemName: "list.bullet").tag(Layout.list)
                    .accessibilityLabel(ppLocalized("permissions.view.list"))
                Image(systemName: "square.grid.2x2").tag(Layout.grid)
                    .accessibilityLabel(ppLocalized("permissions.view.grid"))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .tint(tint ?? .accentColor)
        }
    }

    private var counterText: String {
        var text = ppFormat("permissions.counter", grantedCount, implementedCount)
        if comingSoonCount > 0 { text += ppFormat("permissions.counter.comingSoon", comingSoonCount) }
        return text
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch layout {
        case .list: listContent
        case .grid:
            PermissionGrid(
                manager: manager,
                permissions: permissions,
                reasonOverrides: reasonOverrides
            )
        }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(permissions.enumerated()), id: \.element) { index, permission in
                PermissionRow(
                    manager: manager,
                    permission: permission,
                    reasonOverride: reasonOverrides[permission]
                )
                if index < permissions.count - 1 {
                    Divider().overlay(PPColor.separator)
                }
            }
        }
    }

    // MARK: Relaunch hint

    private var relaunchBanner: some View {
        HStack(spacing: PPDesign.s8) {
            Image(systemName: "arrow.clockwise.circle")
                .foregroundStyle(.secondary)
            Text(relaunchMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: PPDesign.s12)
            Button(ppLocalized("relaunch.button")) { manager.quitAndReopen() }
                .controlSize(.small)
        }
        .padding(.horizontal, PPDesign.s12)
        .padding(.vertical, PPDesign.s8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PPDesign.iconTileRadius, style: .continuous)
                .fill(PPColor.iconTile(scheme))
        )
    }

    private var relaunchMessage: String {
        let titles = manager.relaunchPendingTitles
        guard !titles.isEmpty else {
            return ppLocalized("relaunch.message.generic")
        }
        // Count-neutral "will take effect" avoids singular/plural verb agreement,
        // so no per-language plural rules are needed.
        let names = ListFormatter.localizedString(byJoining: titles)
        return ppFormat("relaunch.message", names)
    }
}

/// Rounded card surface for ``PermissionsView`` (fill + hairline + soft shadow).
private struct PermissionsCard: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content
                .background(
                    RoundedRectangle(cornerRadius: PPDesign.cardRadius, style: .continuous)
                        .fill(PPColor.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PPDesign.cardRadius, style: .continuous)
                        .strokeBorder(PPColor.separator, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        } else {
            content
        }
    }
}
