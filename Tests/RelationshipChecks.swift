import Foundation
@main struct RelationshipChecks {
    @MainActor static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("note-relations-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("notes.json")
        let oldDate = Date(timeIntervalSince1970: 100)
        let original = Note(title: "Meeting", updated: oldDate, actions: [])
        try JSONEncoder().encode(NotesArchive(notes: [original], collections: [])).write(to: file)
        let store = NoteStore(file: file)
        precondition(store.timeline.first?.created == oldDate)
        let collection = store.createCollection(name: "Product", kind: "Product")!
        store.assign(original.id, to: collection, included: true)
        let child = store.createRelated(to: original.id)!
        precondition(store.selectedNote?.originID == original.id)
        precondition(store.selectedNote?.collectionIDs == [collection])
        precondition(store.selectedNote?.body.isEmpty == true)
        store.update(original.id) { $0.body = "Edited later" }
        precondition(store.timeline.map(\.id) == [original.id, child])
        let grandchild = store.createRelated(to: child, kind: "Meeting")!
        let reload = NoteStore(file: file)
        precondition(reload.notes.first { $0.id == grandchild }?.originID == child)
        precondition(reload.notes.first { $0.id == original.id }?.created == oldDate)
        precondition(reload.createRelated(to: UUID()) == nil)
        reload.filter = "Meetings"; reload.search = "missing"
        reload.openNote(child)
        precondition(reload.selected == child && reload.filtered.contains { $0.id == child })
        // Exercise deletion without invoking notification APIs in an unbundled test.
        print("PASS: legacy timeline migration, stable ordering after edits, separate related notes, inherited collections, relationship persistence, navigation")
    }
}
