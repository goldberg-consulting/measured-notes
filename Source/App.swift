import AppKit
import SwiftUI
import Carbon
import UserNotifications

final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var store: NoteStore!
    var window: NSWindow!
    var capturePanel: CapturePanel?
    var statusItem: NSStatusItem!
    var hotKey: EventHotKeyRef?
    var priorApp: NSRunningApplication?
    func applicationDidFinishLaunching(_ notification: Notification) {
        store = NoteStore()
        UNUserNotificationCenter.current().delegate = self
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1230, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "measured.one — Notes"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(ink)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: LibraryView(store: store, capture: { [weak self] in self?.capture() }))
        window.center()
        setupMenu()
        setupHotKey()
        showLibrary()
    }
    func setupMenu() {
        let main = NSMenu()
        let root = NSMenuItem(); main.addItem(root)
        let app = NSMenu(); root.submenu = app
        app.addItem(withTitle: "About measured.one Notes", action: #selector(about), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit measured.one Notes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let fileRoot = NSMenuItem(title: "File", action: nil, keyEquivalent: ""); main.addItem(fileRoot)
        let file = NSMenu(title: "File"); fileRoot.submenu = file
        file.addItem(withTitle: "New note", action: #selector(newNote), keyEquivalent: "n").target = self
        file.addItem(withTitle: "Quick capture", action: #selector(capture), keyEquivalent: "T").target = self
        file.addItem(withTitle: "Open note browser", action: #selector(showLibrary), keyEquivalent: "0").target = self
        let editRoot = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); main.addItem(editRoot)
        let edit = NSMenu(title: "Edit"); editRoot.submenu = edit
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        for (title, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] { edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key) }
        NSApp.mainMenu = main
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "bolt.shield", accessibilityDescription: "measured.one Notes")
        let menu = NSMenu()
        menu.addItem(withTitle: "Capture a thought  ⌘⇧T", action: #selector(capture), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Open sanctuary", action: #selector(showLibrary), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = menu
    }
    func setupHotKey() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { delegate.capture() }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), nil)
        let keyID = EventHotKeyID(signature: OSType(0x4D4E4F54), id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_T), UInt32(cmdKey | shiftKey), keyID, GetApplicationEventTarget(), 0, &hotKey)
        store.shortcutStatus = result == noErr ? "⌘⇧T · global shortcut ready" : "Shortcut unavailable (\(result)) · use menu"
    }
    @objc func capture() {
        if let p = capturePanel, p.isVisible { dismissCapture(); return }
        priorApp = NSWorkspace.shared.frontmostApplication
        let id = store.create()
        let p = CapturePanel(contentRect: NSRect(x: 0, y: 0, width: 820, height: 640), styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
        p.titleVisibility = .hidden; p.titlebarAppearsTransparent = true
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.isFloatingPanel = true; p.level = .floating; p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.minSize = NSSize(width: 780, height: 540)
        p.backgroundColor = NSColor(ink)
        p.contentView = NSHostingView(rootView: CaptureView(store: store, id: id, dismiss: { [weak self] in self?.dismissCapture() }, browse: { [weak self] in self?.capturePanel?.orderOut(nil); self?.showLibrary() }))
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) {
            p.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 410, y: screen.visibleFrame.midY - 320))
        } else { p.center() }
        capturePanel = p
        p.makeKeyAndOrderFront(nil)
    }
    func dismissCapture() {
        store.save(); capturePanel?.orderOut(nil)
        if priorApp?.bundleIdentifier != Bundle.main.bundleIdentifier { priorApp?.activate() }
    }
    @objc func showLibrary() { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    @objc func newNote() { store.create(); showLibrary() }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "measured.one Notes", .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development", .credits: NSAttributedString(string: "Thoughts into thunder.\nLocal notes • On-device intelligence • ⌘⇧T anywhere")]) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showLibrary(); return true }
    func applicationWillTerminate(_ notification: Notification) { store.save() }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { if let id = UUID(uuidString: response.notification.request.identifier) { self.store.selected = id; self.showLibrary() } }
    }
}

@main struct Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}
