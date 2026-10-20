import Foundation
@main struct ActionChecks {
    @MainActor static func main() throws {
        var legacy = Note(title: "Old", body: "Before\n- [ ] Follow up\n- [x] Done\n```\n- [ ] code example\n```\nAfter")
        legacy.migrateActions()
        precondition(legacy.tasks.count == 2 && legacy.openTasks == 1)
        precondition(legacy.body == "Before\n```\n- [ ] code example\n```\nAfter")
        legacy.body += "\n- [ ] Markdown only"
        legacy.migrateActions()
        precondition(legacy.tasks.count == 2)
        let file = URL(fileURLWithPath: "/tmp/measured-actions-\(UUID().uuidString)/notes.json")
        let store = NoteStore(file: file)
        let id = store.create()
        store.update(id) { $0.body = "Notes only\n- [ ] Markdown only"; $0.actions = [NoteAction(text: "Real action")] }
        precondition(store.selectedNote!.openTasks == 1)
        let original = store.selectedNote!.body
        store.update(id) { $0.actions![0].completed = true; $0.actions![0].text = "Edited action" }
        precondition(store.selectedNote!.body == original && store.selectedNote!.openTasks == 0)
        let reload = NoteStore(file: file)
        let saved = reload.notes.first { $0.id == id }!
        precondition(saved.body == original && saved.tasks[0].text == "Edited action" && saved.tasks[0].completed)
        precondition(saved.exportMarkdown.contains("## Actions\n- [x] Edited action"))
        print("PASS: legacy migration, code-fence preservation, no repeated extraction, independent editing/completion, persistence, export")
    }
}
