import Foundation
import SQLite3

/// A portable snapshot. The JSON archive preserves every model field; the tables
/// expose the same data for queries without requiring knowledge of Swift Codable.
enum NotesExport {
    static func json(_ archive: NotesArchive, to destination: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(archive).write(to: destination, options: .atomic)
    }

    static func sqlite(_ archive: NotesArchive, to destination: URL) throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try writeDatabase(archive, to: temporary)
        // Replace only after the complete database has been closed successfully.
        try Data(contentsOf: temporary).write(to: destination, options: .atomic)
    }

    private static func writeDatabase(_ archive: NotesArchive, to url: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            throw failure("Could not create the SQLite export.")
        }
        defer { sqlite3_close(db) }
        func check(_ result: Int32) throws {
            guard result == SQLITE_OK || result == SQLITE_DONE else {
                throw failure(String(cString: sqlite3_errmsg(db)))
            }
        }
        func execute(_ sql: String) throws { try check(sqlite3_exec(db, sql, nil, nil, nil)) }
        func insert(_ sql: String, _ values: [String?], data: Data? = nil) throws {
            var statement: OpaquePointer?
            try check(sqlite3_prepare_v2(db, sql, -1, &statement, nil))
            defer { sqlite3_finalize(statement) }
            for (index, value) in values.enumerated() {
                if let value {
                    let bytes = Array(value.utf8)
                    try value.withCString { pointer in
                        try check(sqlite3_bind_text(statement, Int32(index + 1), pointer, Int32(bytes.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)))
                    }
                } else { try check(sqlite3_bind_null(statement, Int32(index + 1))) }
            }
            if let data, data.isEmpty {
                try check(sqlite3_bind_zeroblob(statement, Int32(values.count + 1), 0))
            } else if let data {
                try data.withUnsafeBytes { bytes in
                    try check(sqlite3_bind_blob(statement, Int32(values.count + 1), bytes.baseAddress, Int32(bytes.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)))
                }
            }
            try check(sqlite3_step(statement))
        }
        try execute("""
        PRAGMA user_version = 4;
        BEGIN TRANSACTION;
        CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE notes (id TEXT PRIMARY KEY, position INTEGER NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, kind TEXT NOT NULL, updated_at TEXT NOT NULL, pinned INTEGER NOT NULL, summary TEXT NOT NULL, reminder_at TEXT);
        CREATE TABLE actions (id TEXT PRIMARY KEY, note_id TEXT NOT NULL REFERENCES notes(id), position INTEGER NOT NULL, text TEXT NOT NULL, completed INTEGER NOT NULL, parent_id TEXT);
        CREATE TABLE collections (id TEXT PRIMARY KEY, position INTEGER NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL);
        CREATE TABLE note_collections (note_id TEXT NOT NULL REFERENCES notes(id), collection_id TEXT NOT NULL, position INTEGER NOT NULL);
        CREATE TABLE tags (note_id TEXT NOT NULL REFERENCES notes(id), position INTEGER NOT NULL, tag TEXT NOT NULL);
        CREATE TABLE people (note_id TEXT NOT NULL REFERENCES notes(id), position INTEGER NOT NULL, person TEXT NOT NULL);
        CREATE TABLE images (id TEXT PRIMARY KEY, note_id TEXT NOT NULL REFERENCES notes(id), position INTEGER NOT NULL, name TEXT NOT NULL, caption TEXT NOT NULL, width REAL NOT NULL, mime_type TEXT NOT NULL, data BLOB NOT NULL);
        CREATE TABLE recordings (id TEXT PRIMARY KEY, note_id TEXT NOT NULL REFERENCES notes(id), position INTEGER NOT NULL, started_at TEXT NOT NULL, file_name TEXT NOT NULL, locale TEXT NOT NULL, microphone INTEGER NOT NULL, status TEXT NOT NULL);
        CREATE TABLE transcript_segments (id TEXT PRIMARY KEY, recording_id TEXT NOT NULL REFERENCES recordings(id), position INTEGER NOT NULL, seconds REAL NOT NULL, speaker TEXT NOT NULL, text TEXT NOT NULL);
        CREATE TABLE documents (id TEXT PRIMARY KEY, note_id TEXT NOT NULL REFERENCES notes(id), position INTEGER NOT NULL, name TEXT NOT NULL, added_at TEXT NOT NULL, data BLOB NOT NULL);
        CREATE TABLE archive (id INTEGER PRIMARY KEY CHECK (id = 1), json TEXT NOT NULL);
        """)
        let dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try insert("INSERT INTO metadata VALUES (?, ?)", ["exported_at", dates.string(from: Date())])
        try insert("INSERT INTO metadata VALUES (?, ?)", ["format", "one.measured.notes.sqlite.v4"])
        let encoded = try JSONEncoder().encode(archive)
        try insert("INSERT INTO archive VALUES (1, ?)", [String(decoding: encoded, as: UTF8.self)])
        for (position, note) in archive.notes.enumerated() {
            let id = note.id.uuidString
            try insert("INSERT INTO notes VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", [id, String(position), note.title, note.body, note.kind, dates.string(from: note.updated), note.pinned ? "1" : "0", note.summary, note.reminder.map { dates.string(from: $0) }])
            for (position, action) in note.tasks.enumerated() {
                try insert("INSERT INTO actions VALUES (?, ?, ?, ?, ?, ?)", [action.id.uuidString, id, String(position), action.text, action.completed ? "1" : "0", action.parentID?.uuidString])
            }
            for (position, document) in (note.documents ?? []).enumerated() {
                try insert("INSERT INTO documents VALUES (?, ?, ?, ?, ?, ?)", [document.id.uuidString, id, String(position), document.name, dates.string(from: document.added)], data: document.data)
            }
            for (position, recording) in (note.recordings ?? []).enumerated() {
                try insert("INSERT INTO recordings VALUES (?, ?, ?, ?, ?, ?, ?, ?)", [recording.id.uuidString, id, String(position), dates.string(from: recording.started), recording.fileName, recording.locale, recording.microphone ? "1" : "0", recording.status])
                for (position, segment) in recording.transcript.enumerated() {
                    try insert("INSERT INTO transcript_segments VALUES (?, ?, ?, ?, ?, ?)", [segment.id.uuidString, recording.id.uuidString, String(position), String(segment.seconds), segment.speaker, segment.text])
                }
            }
            for (position, image) in (note.images ?? []).enumerated() {
                try insert("INSERT INTO images VALUES (?, ?, ?, ?, ?, ?, ?, ?)", [image.id.uuidString, id, String(position), image.name, image.caption, String(image.width), "image/png"], data: image.data)
            }
            for (position, tag) in note.tags.enumerated() { try insert("INSERT INTO tags VALUES (?, ?, ?)", [id, String(position), tag]) }
            for (position, person) in note.people.enumerated() { try insert("INSERT INTO people VALUES (?, ?, ?)", [id, String(position), person]) }
            for (position, collection) in (note.collectionIDs ?? []).enumerated() { try insert("INSERT INTO note_collections VALUES (?, ?, ?)", [id, collection.uuidString, String(position)]) }
        }
        for (position, collection) in archive.collections.enumerated() {
            try insert("INSERT INTO collections VALUES (?, ?, ?, ?)", [collection.id.uuidString, String(position), collection.name, collection.kind])
        }
        try execute("COMMIT;")
    }
    private static func failure(_ message: String) -> NSError {
        NSError(domain: "one.measured.notes.export", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
