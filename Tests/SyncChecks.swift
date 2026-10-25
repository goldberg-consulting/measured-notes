import Foundation

@main struct SyncChecks {
    @MainActor static func main() async throws {
        let a = Data("a".utf8), b = Data("b".utf8)
        var first = SyncReplica(); first.set("note:test", payload: a, device: "A")
        var second = first
        first.set("note:test", payload: b, device: "A")
        second.set("note:test", payload: Data("c".utf8), device: "B")
        var ab = first; try ab.merge(second)
        var ba = second; try ba.merge(first)
        precondition(ab == ba && ab.projected().count == 2)
        try ab.merge(second); precondition(ab == ba)
        ab.set("note:test", payload: Data("resolved".utf8), device: "A")
        try ab.merge(ba); precondition(ab.projected().count == 1)
        var equalA = SyncReplica(), equalB = SyncReplica()
        equalA.set("note:same", payload: a, device: "A")
        equalB.set("note:same", payload: a, device: "B")
        try equalA.merge(equalB); precondition(equalA.projected().count == 1)
        var deleted = first; deleted.set("note:test", payload: nil, device: "A")
        try deleted.merge(second)
        precondition(deleted.projected()["note:test"] == nil && deleted.projected().count == 1)
        var stale = first; try stale.merge(deleted)
        precondition(stale == deleted)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sync-check-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = root.appendingPathComponent("cloud")
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        let fileA = root.appendingPathComponent("a/notes.json"), fileB = root.appendingPathComponent("b/notes.json")
        for url in [fileA, fileB] {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(NotesArchive(notes: [], collections: [])).write(to: url)
        }
        let storeA = NoteStore(file: fileA), storeB = NoteStore(file: fileB)
        let workerA = SyncWorker(storageURL: fileA, testContainer: cloud)
        let workerB = SyncWorker(storageURL: fileB, testContainer: cloud)
        func input(_ store: NoteStore) -> SyncInput { SyncInput(notes: store.notes, collections: store.collections, storageURL: store.storageURL, recordingNoteID: store.recordingNoteID) }
        func cycle(_ worker: SyncWorker, _ store: NoteStore) async throws {
            if let prepared = try await worker.prepare(input(store)) {
                try store.applySyncedArchive(prepared.archive)
                try await worker.commit(prepared, applied: input(store))
            }
        }
        let collection = storeA.createCollection(name: "Product", kind: "Product")!
        let id = storeA.create()
        let document = NoteDocument(name: "proof.txt", data: Data([0, 1, 255, 42]))
        let image = NoteImage(name: "sample.png", data: Data([10, 20, 30]))
        storeA.update(id) { $0.title = "Original"; $0.body = "Original body\n" + image.markdown + "\n" + document.markdown; $0.documents = [document]; $0.images = [image]; $0.actions = [NoteAction(text: "Keep me")] }
        storeA.assign(id, to: collection, included: true)
        try await cycle(workerA, storeA); try await cycle(workerB, storeB)
        precondition(storeA.notes == storeB.notes && storeB.collections.first?.id == collection)
        precondition(storeB.notes[0].documents?[0].data == document.data && storeB.notes[0].images?[0].data == image.data)
        storeA.update(id) { $0.body = "Edit A" }
        storeB.update(id) { $0.body = "Edit B" }
        try await cycle(workerA, storeA); try await cycle(workerB, storeB); try await cycle(workerA, storeA)
        precondition(storeA.notes.count == 2 && storeB.notes.count == 2)
        precondition(Set(storeA.notes.map(\.body)) == ["Edit A", "Edit B"])
        precondition(Set(storeA.notes.map(\.id)) == Set(storeB.notes.map(\.id)))
        precondition(Set(storeA.notes.flatMap { $0.tasks.map(\.id) }).count == 2)
        precondition(Set(storeA.notes.flatMap { ($0.documents ?? []).map(\.id) }).count == 2)
        // Delete a conflict copy directly to avoid notification APIs in an unbundled executable.
        let copyID = storeA.notes.first { $0.id != id }!.id
        storeA.notes.removeAll { $0.id == copyID }; storeA.save()
        try await cycle(workerA, storeA); try await cycle(workerB, storeB)
        precondition(storeB.notes.count == 1)
        let restart = SyncWorker(storageURL: fileB, testContainer: cloud)
        try await cycle(restart, storeB); precondition(storeB.notes.count == 1)
        // Edit an older device after deletion: retain that work as a separate conflict copy.
        storeA.notes.removeAll(); storeA.save()
        storeB.update(id) { $0.body = "Offline edit" }
        try await cycle(workerA, storeA); try await cycle(workerB, storeB); try await cycle(workerA, storeA)
        precondition(storeA.notes.count == 1 && storeA.notes[0].body == "Offline edit" && storeA.notes[0].id != id)
        let differentCloud = root.appendingPathComponent("different-account")
        let switched = SyncWorker(storageURL: fileA, testContainer: differentCloud, testAccount: Data("other-user".utf8))
        let switchedResult = try await switched.prepare(input(storeA))
        precondition(switchedResult == nil)
        precondition(!FileManager.default.fileExists(atPath: differentCloud.path))
        // A corrupted download is never installed under its claimed content hash.
        let fileC = root.appendingPathComponent("c/notes.json")
        try FileManager.default.createDirectory(at: fileC.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(NotesArchive(notes: [], collections: [])).write(to: fileC)
        let storeC = NoteStore(file: fileC)
        let workerC = SyncWorker(storageURL: fileC, testContainer: cloud)
        let cloudBlobFolder = cloud.appendingPathComponent("MeasuredSync/Blobs")
        let blobFiles = try FileManager.default.contentsOfDirectory(at: cloudBlobFolder, includingPropertiesForKeys: nil)
        let originalBlob = try Data(contentsOf: blobFiles[0])
        try Data("corrupted".utf8).write(to: blobFiles[0], options: .atomic)
        do { _ = try await workerC.prepare(input(storeC)); preconditionFailure("Corrupted attachment accepted") } catch {}
        precondition(storeC.notes.isEmpty)
        try originalBlob.write(to: blobFiles[0], options: .atomic)
        try await cycle(workerC, storeC)
        precondition(storeC.notes.count == 1)
        // A bad remote payload never replaces the local archive.
        let before = storeA.notes
        try Data("broken".utf8).write(to: cloud.appendingPathComponent("MeasuredSync/Devices/broken.json"))
        do { _ = try await workerA.prepare(input(storeA)); preconditionFailure("Corrupt cloud data accepted") } catch {}
        precondition(storeA.notes == before)
        print("PASS: convergence, idempotence, concurrent edits, edit/delete conflicts, tombstones, restart, attachment bytes, unique conflict IDs, corrupt cloud preservation")
    }
}
