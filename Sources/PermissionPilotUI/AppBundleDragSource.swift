import SwiftUI
import AppKit

/// The app icon as a **real file drag** — what Finder puts on the pasteboard
/// when you drag an app: a `public.file-url` pointing at the installed bundle.
///
/// System Settings' privacy lists (Accessibility, Screen Recording, Input
/// Monitoring, Full Disk Access) only accept a file URL they can resolve to the
/// app on disk. SwiftUI's `.onDrag { NSItemProvider(contentsOf:) }` doesn't give
/// them that: it presents the bundle as a **file promise** (a lazily-delivered
/// copy) and allows only the *copy* operation, so the drop is refused or adds
/// nothing. This AppKit source writes the bundle's `NSURL` directly and offers
/// copy/link/generic — the same pasteboard and operations as a Finder drag.
struct AppBundleDragSource: NSViewRepresentable {
    let appURL: URL

    func makeNSView(context: Context) -> AppBundleDragSourceView {
        AppBundleDragSourceView(appURL: appURL)
    }

    func updateNSView(_ view: AppBundleDragSourceView, context: Context) {
        view.appURL = appURL
    }
}

final class AppBundleDragSourceView: NSView, NSDraggingSource {
    var appURL: URL {
        didSet { if oldValue != appURL { icon = Self.icon(for: appURL); needsDisplay = true } }
    }
    private var icon: NSImage

    init(appURL: URL) {
        self.appURL = appURL
        self.icon = Self.icon(for: appURL)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    // Start the drag on the first click even when the helper isn't key/active,
    // and never let the press move a movable-by-background window instead.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        icon.draw(in: bounds)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: appURL as NSURL)
        item.setDraggingFrame(bounds, contents: icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        // Never .move/.delete: a drop target must not relocate the app bundle.
        context == .outsideApplication ? [.copy, .link, .generic] : []
    }
}
