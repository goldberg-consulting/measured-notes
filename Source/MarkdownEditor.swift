import SwiftUI
import AppKit

final class MarkdownTextView: NSTextView {
    private(set) var isTornDown = false
    private let editorUndoManager = UndoManager()
    override var undoManager: UndoManager? { editorUndoManager }

    func replaceExternalText(_ text: String) {
        breakUndoCoalescing()
        editorUndoManager.removeAllActions()
        string = text
    }

    func tearDown() {
        isTornDown = true
        breakUndoCoalescing()
        editorUndoManager.removeAllActions()
        delegate = nil
        insertTable = nil
        importImages = nil
    }

    var insertTable: ((NSRange) -> Void)?
    var importImages: ((NSPasteboard) -> String?)?
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self, NSImage.self], options: nil) { return .copy }
        return super.draggingEntered(sender)
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let markdown = importImages?(sender.draggingPasteboard) else { return false }
        let point = convert(sender.draggingLocation, from: nil)
        let index = characterIndexForInsertion(at: point)
        insertText("\n" + markdown + "\n", replacementRange: NSRange(location: index, length: 0))
        return true
    }
    override func paste(_ sender: Any?) {
        if let markdown = importImages?(NSPasteboard.general) {
            insertText("\n" + markdown + "\n", replacementRange: selectedRange())
        } else { super.paste(sender) }
    }
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        menu.insertItem(.separator(), at: 0)
        let item = NSMenuItem(title: "Insert table…", action: #selector(requestTable), keyEquivalent: "")
        item.target = self
        menu.insertItem(item, at: 0)
        return menu
    }
    @objc private func requestTable() { insertTable?(selectedRange()) }
}

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var focus: Bool
    var importImages: (NSPasteboard) -> String?
    var insertTable: (NSRange) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let editor = MarkdownTextView()
        editor.isRichText = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.drawsBackground = false
        editor.textColor = .black
        editor.insertionPointColor = .black
        editor.font = .systemFont(ofSize: 14)
        editor.textContainerInset = NSSize(width: 0, height: 7)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 7
        editor.defaultParagraphStyle = paragraph
        editor.typingAttributes = [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.black, .paragraphStyle: paragraph]
        editor.delegate = context.coordinator
        editor.string = text
        editor.registerForDraggedTypes([.fileURL, .png, .tiff])
        editor.importImages = { context.coordinator.parent.importImages($0) }
        editor.insertTable = { range in context.coordinator.parent.insertTable(range) }
        scroll.documentView = editor
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? MarkdownTextView else { return }
        if editor.string != text {
            let selection = editor.selectedRange()
            editor.replaceExternalText(text)
            let length = (text as NSString).length
            editor.setSelectedRange(NSRange(location: min(selection.location, length), length: min(selection.length, max(0, length - selection.location))))
        }
        if focus && !context.coordinator.wasFocused {
            DispatchQueue.main.async { if !editor.isTornDown, editor.window != nil { editor.window?.makeFirstResponder(editor) } }
        }
        context.coordinator.wasFocused = focus
    }
    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        (scroll.documentView as? MarkdownTextView)?.tearDown()
    }
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        var wasFocused = false
        init(_ parent: MarkdownEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}
