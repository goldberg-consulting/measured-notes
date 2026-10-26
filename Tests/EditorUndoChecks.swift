import AppKit
@main struct Checks {
    @MainActor static func main() {
        _ = NSApplication.shared
        let first = MarkdownTextView()
        let second = MarkdownTextView()
        first.allowsUndo = true; second.allowsUndo = true
        first.undoManager!.groupsByEvent = false
        first.undoManager!.beginUndoGrouping()
        first.insertText("hello", replacementRange: NSRange(location: 0, length: 0))
        first.undoManager!.endUndoGrouping()
        precondition(first.undoManager!.canUndo)
        precondition(!second.undoManager!.canUndo)
        first.undoManager!.undo()
        precondition(first.string.isEmpty)
        first.undoManager!.redo()
        precondition(first.string == "hello")
        first.replaceExternalText("sync replacement")
        precondition(!first.undoManager!.canUndo && !first.undoManager!.canRedo)
        first.tearDown()
        precondition(!first.undoManager!.canUndo)
        print("Editor undo isolation checks passed")
    }
}
