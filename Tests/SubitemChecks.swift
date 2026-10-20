import Foundation
@main struct SubitemChecks {
 static func main() throws {
    let old = try JSONDecoder().decode(NoteAction.self, from: Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"text\":\"Old\",\"completed\":false}".utf8))
    precondition(old.parentID == nil)
    var note = Note(actions: [old, NoteAction(text: "Next")])
    let child = note.addSubitem(to: old.id)!
    note.actions![1].text = "Child"
    let sibling = note.addSubitem(to: child)!
    precondition(note.tasks[2].id == sibling && note.tasks[2].parentID == old.id)
    precondition(note.exportMarkdown.contains("    - [ ] Child"))
    note.actions![1].completed = true
    precondition(!note.tasks[0].completed)
    let decoded = try JSONDecoder().decode(Note.self, from: JSONEncoder().encode(note))
    precondition(decoded == note)
    note.promoteAction(child)
    precondition(note.tasks[2].id == child && note.tasks[2].parentID == nil)
    note.removeAction(old.id)
    precondition(note.tasks.first { $0.id == sibling }?.parentID == nil && note.tasks.count == 3)
    print("PASS: backward compatibility, nesting order, sibling insertion, independent completion, Markdown indentation, save/reload, promotion, parent removal preserves children")
 }
}
