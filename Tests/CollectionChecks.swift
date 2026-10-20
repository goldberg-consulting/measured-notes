import Foundation
@main struct CollectionChecks {
 @MainActor static func main() throws {
    let folder = URL(fileURLWithPath: "/tmp/measured-collections-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent("notes.json")
    let legacy = Note(title: "Existing", body: "Keep this", actions: [NoteAction(text: "Keep action")])
    try JSONEncoder().encode([legacy]).write(to: file)
    let store = NoteStore(file: file)
    precondition(store.notes[0].body == "Keep this")
    precondition(FileManager.default.fileExists(atPath: folder.appendingPathComponent("notes-before-collections.json").path))
    let product = store.createCollection(name: " App ", kind: "Product")!
    let flow = store.createCollection(name: "Capture", kind: "Flow")!
    precondition(store.createCollection(name: "app", kind: "Product") == product)
    precondition(store.createCollection(name: "  ", kind: "Folder") == nil)
    store.assign(legacy.id, to: product, included: true)
    store.assign(legacy.id, to: flow, included: true)
    store.browseCollection(product); precondition(store.filtered.count == 1)
    store.browseCollection(flow); precondition(store.filtered.count == 1)
    let new = store.create(); precondition(store.selectedNote!.collectionIDs == [flow])
    precondition(store.renameCollection(product, name: "Renamed app"))
    let reload = NoteStore(file: file)
    precondition(reload.collections.count == 2 && reload.notes.first { $0.id == legacy.id }!.collectionIDs!.count == 2)
    reload.search = "Renamed app"; precondition(reload.filtered.count == 1)
    reload.assign(legacy.id, to: product, included: false)
    precondition(reload.notes.first { $0.id == legacy.id }!.collectionIDs == [flow])
    reload.removeCollection(flow)
    precondition(reload.notes.count == 2 && reload.notes.first { $0.id == legacy.id }!.body == "Keep this")
    precondition(reload.notes.first { $0.id == new }!.collectionIDs == [])
    let final = NoteStore(file: file)
    precondition(final.collections.count == 1 && final.notes.count == 2)
    print("PASS: archive migration/backup, multiple assignments, category browsing, inherited assignment, rename, deduplication, search, persistence, unassign, collection deletion preserves notes")
 }
}
