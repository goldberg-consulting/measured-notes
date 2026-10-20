import SwiftUI
import AppKit

struct SidebarRegions: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

// Observe right-clicks across the sidebar without intercepting ordinary clicks or scrolling.
final class SidebarMenuView: NSView {
    var regions: [UUID: CGRect] = [:]
    var createNote: ((String, UUID?) -> Void)?
    var createCollection: ((String) -> Void)?
    var manage: (() -> Void)?
    private var monitor: Any?
    private var clickedCollection: UUID?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
            guard let self, event.window === self.window,
                  event.type == .rightMouseDown || event.modifierFlags.contains(.control),
                  self.bounds.contains(self.convert(event.locationInWindow, from: nil)) else { return event }
            let point = self.convert(event.locationInWindow, from: nil)
            self.clickedCollection = self.regions.first(where: { $0.value.contains(point) })?.key
            NSMenu.popUpContextMenu(self.makeMenu(), with: event, for: self)
            return nil
        }
    }
    deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        for (label, kind) in [("note", "Note"), ("example", "Example"), ("meeting note", "Meeting")] {
            let item = NSMenuItem(title: "New " + label + (clickedCollection == nil ? "" : " here"), action: #selector(newNote(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = kind; menu.addItem(item)
        }
        menu.addItem(.separator())
        for kind in ["Folder", "Product", "Flow"] {
            let item = NSMenuItem(title: "New " + kind.lowercased() + "…", action: #selector(newCollection(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = kind; menu.addItem(item)
        }
        menu.addItem(.separator())
        let item = NSMenuItem(title: "Manage collections…", action: #selector(manageCollections), keyEquivalent: "")
        item.target = self; menu.addItem(item)
        return menu
    }
    @objc private func newNote(_ item: NSMenuItem) { createNote?(item.representedObject as? String ?? "Note", clickedCollection) }
    @objc private func newCollection(_ item: NSMenuItem) { createCollection?(item.representedObject as? String ?? "Folder") }
    @objc private func manageCollections() { manage?() }
}

struct SidebarContextMenu: NSViewRepresentable {
    var regions: [UUID: CGRect]
    var createNote: (String, UUID?) -> Void
    var createCollection: (String) -> Void
    var manage: () -> Void
    func makeNSView(context: Context) -> SidebarMenuView { SidebarMenuView() }
    func updateNSView(_ view: SidebarMenuView, context: Context) {
        view.regions = regions; view.createNote = createNote; view.createCollection = createCollection; view.manage = manage
    }
}
