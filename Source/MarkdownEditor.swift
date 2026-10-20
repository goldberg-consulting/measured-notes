import SwiftUI
import AppKit

final class MarkdownTextView: NSTextView {
    var insertTable: ((NSRange) -> Void)?
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
        editor.insertTable = { range in context.coordinator.parent.insertTable(range) }
        scroll.documentView = editor
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? MarkdownTextView else { return }
        if editor.string != text {
            let selection = editor.selectedRange()
            editor.string = text
            let length = (text as NSString).length
            editor.setSelectedRange(NSRange(location: min(selection.location, length), length: min(selection.length, max(0, length - selection.location))))
        }
        if focus && !context.coordinator.wasFocused {
            DispatchQueue.main.async { if editor.window != nil { editor.window?.makeFirstResponder(editor) } }
        }
        context.coordinator.wasFocused = focus
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
