import Foundation
import SQLite3

@main struct ExportChecks {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collection = NoteCollection(name: "Product", kind: "Product")
        let parent = NoteAction(text: "Parent's action")
        let child = NoteAction(text: "子項目", completed: true, parentID: parent.id)
        var note = Note(title: "'Quoted' 📝", body: "| A | B |\nline\u{0}end", pinned: true, tags: ["one", "two"], people: ["A Person"], summary: "Summary", reminder: Date(timeIntervalSince1970: 1800000000), actions: [parent, child], collectionIDs: [collection.id])
        let image = NoteImage(name: "Picture.png", data: Data([0, 1, 127, 255]), caption: "A caption", width: 320)
        note.images = [image]
        note.recordings = [MeetingRecording(fileName: "recording.mp4", locale: "en-US", microphone: true, transcript: [TranscriptSegment(seconds: 12.5, speaker: "Eli", text: "Meeting text")])]
        note.documents = [NoteDocument(name: "Reference.pdf", data: Data([10, 0, 254])), NoteDocument(name: "Empty.txt", data: Data())]
        let archive = NotesArchive(notes: [note, Note()], collections: [collection])
        let output = directory.appendingPathComponent("notes.sqlite")
        try NotesExport.sqlite(archive, to: output)
        var db: OpaquePointer?
        precondition(sqlite3_open_v2(output.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        defer { sqlite3_close(db) }
        func query(_ sql: String) -> String {
            var statement: OpaquePointer?
            precondition(sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK)
            defer { sqlite3_finalize(statement) }
            precondition(sqlite3_step(statement) == SQLITE_ROW)
            let bytes = sqlite3_column_text(statement, 0)!
            return String(decoding: UnsafeBufferPointer(start: bytes, count: Int(sqlite3_column_bytes(statement, 0))), as: UTF8.self)
        }
        precondition(query("PRAGMA integrity_check") == "ok")
        precondition(query("PRAGMA user_version") == "4")
        precondition(query("SELECT body FROM notes WHERE position=0") == note.body)
        precondition(query("SELECT title FROM notes WHERE position=0") == note.title)
        precondition(query("SELECT count(*) FROM notes") == "2")
        precondition(query("SELECT parent_id FROM actions WHERE position=1") == parent.id.uuidString)
        precondition(query("SELECT completed FROM actions WHERE position=1") == "1")
        precondition(query("SELECT collection_id FROM note_collections") == collection.id.uuidString)
        precondition(query("SELECT count(*) FROM tags") == "2")
        precondition(query("SELECT person FROM people") == "A Person")
        precondition(query("SELECT hex(data) FROM images") == "00017FFF")
        precondition(query("SELECT caption FROM images") == image.caption)
        precondition(query("SELECT width FROM images") == "320.0")
        precondition(query("SELECT speaker FROM transcript_segments") == "Eli")
        precondition(query("SELECT seconds FROM transcript_segments") == "12.5")
        precondition(query("SELECT locale FROM recordings") == "en-US")
        precondition(query("SELECT hex(data) FROM documents WHERE position=0") == "0A00FE")
        precondition(query("SELECT name FROM documents WHERE position=0") == "Reference.pdf")
        precondition(query("SELECT length(data) FROM documents WHERE position=1") == "0")
        let decoded = try JSONDecoder().decode(NotesArchive.self, from: Data(query("SELECT json FROM archive").utf8))
        precondition(decoded.notes == archive.notes && decoded.collections == archive.collections)
        let json = directory.appendingPathComponent("notes.json")
        try NotesExport.json(archive, to: json)
        let decodedJSON = try JSONDecoder().decode(NotesArchive.self, from: Data(contentsOf: json))
        precondition(decodedJSON.notes == archive.notes)
        // A failed export must leave an existing destination untouched.
        let protected = directory.appendingPathComponent("existing")
        try FileManager.default.createDirectory(at: protected, withIntermediateDirectories: true)
        let marker = protected.appendingPathComponent("keep")
        try Data("keep".utf8).write(to: marker)
        do { try NotesExport.sqlite(archive, to: protected); preconditionFailure("Expected failure") } catch {}
        let retained = try String(contentsOf: marker, encoding: .utf8)
        precondition(retained == "keep")
        print("PASS: SQLite integrity, complete archive round-trip, Unicode/NUL text, hierarchy, relationships, JSON export, safe failure")
    }
}
