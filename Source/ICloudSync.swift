import Foundation
import Combine
import CryptoKit
import UserNotifications

struct SyncInput {
    var notes: [Note]
    var collections: [NoteCollection]
    var storageURL: URL
    var recordingNoteID: UUID?
    var discoveredFiles: [URL] = []
}
struct SyncPrepared {
    var archive: NotesArchive
    var replica: SyncReplica
    var account: Data
    var cloudBlobs: URL
    var devices: URL
}

@MainActor final class ICloudSync: ObservableObject {
    static let containerIdentifier = "iCloud.one.measured.notes"
    @Published var status = "Checking iCloud…" { didSet { store?.syncStatus = status } }
    private weak var store: NoteStore?
    private let worker: SyncWorker
    private var loop: Task<Void, Never>?
    private let query = NSMetadataQuery()
    private var queryObservers: [NSObjectProtocol] = []
    private var discoveredFiles: [URL] = []
    init(store: NoteStore) {
        self.store = store
        worker = SyncWorker(storageURL: store.storageURL)
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K ENDSWITH %@", NSMetadataItemFSNameKey, ".json")
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            queryObservers.append(NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshDiscoveredFiles() }
            })
        }
        query.start()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.synchronize()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }
    deinit {
        loop?.cancel(); query.stop()
        for observer in queryObservers { NotificationCenter.default.removeObserver(observer) }
    }
    private func refreshDiscoveredFiles() {
        query.disableUpdates()
        discoveredFiles = query.results.compactMap { ($0 as? NSMetadataItem)?.value(forAttribute: NSMetadataItemURLKey) as? URL }
        query.enableUpdates()
    }
    private func snapshot(_ store: NoteStore) -> SyncInput {
        SyncInput(notes: store.notes, collections: store.collections, storageURL: store.storageURL, recordingNoteID: store.recordingNoteID, discoveredFiles: discoveredFiles)
    }
    private var syncEnabled: Bool {
        UserDefaults.standard.object(forKey: "iCloudSyncEnabled") == nil || UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }
    private func synchronize() async {
        guard let store, store.storageReadable else { return }
        if !syncEnabled { status = "iCloud sync off · saved locally"; return }
        let input = snapshot(store)
        do {
            if let prepared = try await worker.prepare(input) {
                // Downloads never block typing. Retry if anything changed while they were running.
                guard store.notes == input.notes, store.collections == input.collections,
                      store.recordingNoteID == nil else { status = "Saved locally · waiting for edits to settle"; return }
                guard try await worker.isCurrentAccount(prepared.account) else { status = "iCloud account changed · sync paused"; return }
                // Recheck after the actor hop.
                guard store.notes == input.notes, store.collections == input.collections, store.recordingNoteID == nil else { return }
                guard syncEnabled else { status = "iCloud sync off · saved locally"; return }
                let removed = Set(store.notes.map(\.id)).subtracting(prepared.archive.notes.map(\.id))
                try store.applySyncedArchive(prepared.archive)
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: removed.map(\.uuidString))
                try await worker.commit(prepared, applied: snapshot(store))
            }
            status = await worker.status
        } catch { status = "Saved locally · iCloud will retry: " + error.localizedDescription }
    }
}

// File coordination, hashing, and attachment transfers run off the UI actor.
actor SyncWorker {
    var status = "Checking iCloud…"
    private var checkpoint: SyncCheckpoint
    private let checkpointURL: URL
    private let blobsURL: URL
    private var container: URL?
    private var paused = false
    private var lastPublished: Data?
    private let testContainer: URL?
    private let testAccount: Data
    init(storageURL: URL, testContainer: URL? = nil, testAccount: Data = Data("fixture-account".utf8)) {
        self.testContainer = testContainer
        self.testAccount = testAccount
        let root = storageURL.deletingLastPathComponent().appendingPathComponent("Sync", isDirectory: true)
        checkpointURL = root.appendingPathComponent("checkpoint.json")
        blobsURL = root.appendingPathComponent("Blobs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: blobsURL, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: checkpointURL.path) {
                checkpoint = try JSONDecoder().decode(SyncCheckpoint.self, from: Data(contentsOf: checkpointURL))
            } else { checkpoint = SyncCheckpoint() }
        } catch {
            checkpoint = SyncCheckpoint(); paused = true
            status = "iCloud paused: could not read sync history. Local notes are kept."
        }
    }
    func isCurrentAccount(_ account: Data) throws -> Bool { try identity() == account }
    private func identity() throws -> Data? {
        if testContainer != nil { return testAccount }
        guard let token = FileManager.default.ubiquityIdentityToken else { return nil }
        return try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }
    private func persist() throws { try SyncReplica.encoded(checkpoint).write(to: checkpointURL, options: .atomic) }
    private func blob(_ data: Data) throws -> String {
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let url = blobsURL.appendingPathComponent(hash)
        if !FileManager.default.fileExists(atPath: url.path) { try data.write(to: url, options: .atomic) }
        return hash
    }
    private func digestFile(_ source: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: source); defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { digest.update(data: data) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    private func fileBlob(_ source: URL) throws -> String {
        let hash = try digestFile(source)
        let target = blobsURL.appendingPathComponent(hash)
        if !FileManager.default.fileExists(atPath: target.path) {
            let temporary = blobsURL.deletingLastPathComponent().appendingPathComponent("blob-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: temporary) }
            try FileManager.default.copyItem(at: source, to: temporary)
            try FileManager.default.moveItem(at: temporary, to: target)
        }
        return hash
    }
    private func capture(_ store: SyncInput) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for var note in store.notes {
            let key = "note:" + note.id.uuidString
            if note.id == store.recordingNoteID {
                if let baseline = checkpoint.baseline[key] { result[key] = baseline }
                continue
            }
            var blobs: [String: String] = [:]
            for index in (note.images ?? []).indices {
                blobs[note.images![index].id.uuidString] = try blob(note.images![index].data)
                note.images![index].data = Data()
            }
            for index in (note.documents ?? []).indices {
                blobs[note.documents![index].id.uuidString] = try blob(note.documents![index].data)
                note.documents![index].data = Data()
            }
            for recording in note.recordings ?? [] {
                guard recording.fileName == (recording.fileName as NSString).lastPathComponent else { throw SyncFailure.message("Invalid recording path; sync paused.") }
                let url = store.storageURL.deletingLastPathComponent().appendingPathComponent("Recordings").appendingPathComponent(recording.fileName)
                if FileManager.default.fileExists(atPath: url.path) { blobs[recording.id.uuidString] = try fileBlob(url) }
            }
            result[key] = try SyncReplica.encoded(SyncNote(note: note, blobs: blobs))
        }
        for collection in store.collections { result["collection:" + collection.id.uuidString] = try SyncReplica.encoded(collection) }
        return result
    }
    private func hashURL(_ hash: String, root: URL) throws -> URL {
        guard hash.count == 64, hash.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw SyncFailure.message("Invalid iCloud attachment identifier.") }
        return root.appendingPathComponent(hash)
    }
    private func readBlob(_ hash: String, cloud: URL) throws -> URL {
        let local = try hashURL(hash, root: blobsURL)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        let source = try hashURL(hash, root: cloud)
        if testContainer == nil { try FileManager.default.startDownloadingUbiquitousItem(at: source) }
        let temporary = blobsURL.deletingLastPathComponent().appendingPathComponent("download-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        var coordinatorError: NSError?
        var failure: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinatorError) { url in
            do { try FileManager.default.copyItem(at: url, to: temporary) } catch { failure = error }
        }
        if let error = coordinatorError ?? failure as NSError? { throw error }
        guard try digestFile(temporary) == hash else { throw SyncFailure.message("An iCloud attachment failed verification. Local notes are kept.") }
        try FileManager.default.moveItem(at: temporary, to: local)
        return local
    }
    private func materialize(_ values: [String: Data], cloud: URL, store: SyncInput) throws -> NotesArchive {
        var notes: [Note] = []; var collections: [NoteCollection] = []
        for key in values.keys.sorted() {
            guard let data = values[key], let id = UUID(uuidString: String(key.split(separator: ":").last ?? "")) else { throw SyncFailure.message("Invalid iCloud note identifier.") }
            if key.hasPrefix("collection:") {
                var collection = try JSONDecoder().decode(NoteCollection.self, from: data)
                if collection.id != id { collection.id = id; collection.name += " (conflict copy)" }
                collections.append(collection)
            } else if key.hasPrefix("note:") {
                let envelope = try JSONDecoder().decode(SyncNote.self, from: data)
                var note = envelope.note
                let entityIDs = note.tasks.map(\.id) + (note.images ?? []).map(\.id) + (note.documents ?? []).map(\.id) + (note.recordings ?? []).map(\.id) + (note.recordings ?? []).flatMap { $0.transcript.map(\.id) }
                guard Set(entityIDs).count == entityIDs.count else { throw SyncFailure.message("Duplicate identifiers in iCloud content. Local notes are kept.") }
                for i in (note.images ?? []).indices {
                    guard let hash = envelope.blobs[note.images![i].id.uuidString] else { throw SyncFailure.message("Waiting for an image in iCloud.") }
                    note.images![i].data = try Data(contentsOf: readBlob(hash, cloud: cloud))
                }
                for i in (note.documents ?? []).indices {
                    guard let hash = envelope.blobs[note.documents![i].id.uuidString] else { throw SyncFailure.message("Waiting for a document in iCloud.") }
                    note.documents![i].data = try Data(contentsOf: readBlob(hash, cloud: cloud))
                }
                for recording in note.recordings ?? [] {
                    if let hash = envelope.blobs[recording.id.uuidString] {
                        guard recording.fileName == (recording.fileName as NSString).lastPathComponent else { throw SyncFailure.message("Invalid recording path in iCloud.") }
                        let source = try readBlob(hash, cloud: cloud)
                        let folder = store.storageURL.deletingLastPathComponent().appendingPathComponent("Recordings")
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        let target = folder.appendingPathComponent(recording.fileName)
                        if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: source, to: target) }
                    }
                }
                if note.id != id {
                    note.title = note.displayTitle + " (conflict copy)"
                    note.originID = note.id; note.id = id
                    // IDs in exported relational tables must remain unique across conflict copies.
                    let actionIDs = Dictionary(uniqueKeysWithValues: note.tasks.map { ($0.id, SyncReplica.conflictID(key: $0.id.uuidString, revision: id)) })
                    for i in (note.actions ?? []).indices {
                        note.actions![i].id = actionIDs[note.actions![i].id]!
                        note.actions![i].parentID = note.actions![i].parentID.flatMap { actionIDs[$0] }
                    }
                    for i in (note.images ?? []).indices {
                        let old = note.images![i].markdown
                        note.images![i].id = SyncReplica.conflictID(key: note.images![i].id.uuidString, revision: id)
                        note.body = note.body.replacingOccurrences(of: old, with: note.images![i].markdown)
                    }
                    for i in (note.documents ?? []).indices {
                        let old = note.documents![i].markdown
                        note.documents![i].id = SyncReplica.conflictID(key: note.documents![i].id.uuidString, revision: id)
                        note.body = note.body.replacingOccurrences(of: old, with: note.documents![i].markdown)
                    }
                    for i in (note.recordings ?? []).indices {
                        note.recordings![i].id = SyncReplica.conflictID(key: note.recordings![i].id.uuidString, revision: id)
                        for j in note.recordings![i].transcript.indices { note.recordings![i].transcript[j].id = SyncReplica.conflictID(key: note.recordings![i].transcript[j].id.uuidString, revision: id) }
                    }
                }
                notes.append(note)
            } else { throw SyncFailure.message("Unknown iCloud item. Update the app to continue syncing.") }
        }
        return NotesArchive(notes: notes, collections: collections)
    }
    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinatorError: NSError?; var failure: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { target in
            do { try data.write(to: target, options: .atomic) } catch { failure = error }
        }
        if let error = coordinatorError ?? failure as NSError? { throw error }
    }
    func prepare(_ store: SyncInput) throws -> SyncPrepared? {
        guard !paused else { return nil }
            let current = try capture(store)
            for key in Set(current.keys).union(checkpoint.baseline.keys) where current[key] != checkpoint.baseline[key] {
                checkpoint.replica.set(key, payload: current[key], device: checkpoint.device)
            }
            checkpoint.baseline = current
            try persist() // Offline changes and deletions survive restarts.
            guard let account = try identity() else { container = nil; status = "Saved locally · sign in to iCloud to sync"; return nil }
            if let previous = checkpoint.account, previous != account {
                container = nil; status = "iCloud account changed · sync paused to keep accounts separate"; return nil
            }
            if checkpoint.account == nil { checkpoint.account = account; try persist() }
            if container == nil {
                container = testContainer ?? FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.one.measured.notes")
            }
            guard let container else { status = "Saved locally · iCloud container unavailable"; return nil }
            // Recheck identity after the container lookup; never publish across an account change.
            guard try identity() == account else { self.container = nil; status = "iCloud account changed · retrying"; return nil }
            let root = container.appendingPathComponent("MeasuredSync", isDirectory: true)
            let cloudBlobs = root.appendingPathComponent("Blobs", isDirectory: true)
            let devices = root.appendingPathComponent("Devices", isDirectory: true)
            try FileManager.default.createDirectory(at: cloudBlobs, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: devices, withIntermediateDirectories: true)
            var merged = checkpoint.replica
            let listed = try FileManager.default.contentsOfDirectory(at: devices, includingPropertiesForKeys: nil).map { url in
                let name = url.lastPathComponent
                if name.hasPrefix("."), name.hasSuffix(".json.icloud") { return devices.appendingPathComponent(String(name.dropFirst().dropLast(7))) }
                return url
            }
            let discovered = store.discoveredFiles.filter { $0.deletingLastPathComponent().standardizedFileURL == devices.standardizedFileURL }
            for url in Set(listed + discovered).sorted(by: { $0.path < $1.path }) where url.pathExtension == "json" {
                if testContainer == nil { try FileManager.default.startDownloadingUbiquitousItem(at: url) }
                var data: Data?; var coordinatorError: NSError?; var failure: Error?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { source in do { data = try Data(contentsOf: source) } catch { failure = error } }
                if let error = coordinatorError ?? failure as NSError? { throw error }
                guard let data else { throw SyncFailure.message("Waiting for iCloud downloads.") }
                try merged.merge(JSONDecoder().decode(SyncReplica.self, from: data))
            }
            // Defer all incoming changes during recording/transcription; an active capture stays intact.
            guard store.recordingNoteID == nil else { status = "Saved locally · sync resumes after the meeting"; return nil }
            let archive = try materialize(merged.projected(), cloud: cloudBlobs, store: store)
            guard try identity() == account else { self.container = nil; return nil }
            return SyncPrepared(archive: archive, replica: merged, account: account, cloudBlobs: cloudBlobs, devices: devices)
    }
    func commit(_ prepared: SyncPrepared, applied store: SyncInput) throws {
            guard try identity() == prepared.account else { container = nil; status = "iCloud account changed · sync paused"; return }
            let cloudBlobs = prepared.cloudBlobs
            let devices = prepared.devices
            checkpoint.replica = prepared.replica
            checkpoint.baseline = try capture(store)
            try persist()
            // Upload blobs before publishing references. Keep immutable blobs for offline replicas.
            for url in try FileManager.default.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: nil) {
                let destination = try hashURL(url.lastPathComponent, root: cloudBlobs)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    var coordinatorError: NSError?; var failure: Error?
                    NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinatorError) { target in
                        do { if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: url, to: target) } } catch { failure = error }
                    }
                    if let error = coordinatorError ?? failure as NSError? { throw error }
                }
            }
            let outgoing = try SyncReplica.encoded(checkpoint.replica)
            if outgoing != lastPublished || !FileManager.default.fileExists(atPath: devices.appendingPathComponent(checkpoint.device + ".json").path) {
                guard try identity() == prepared.account else { self.container = nil; return }
                try coordinatedWrite(outgoing, to: devices.appendingPathComponent(checkpoint.device + ".json"))
                lastPublished = outgoing
            }
            status = "iCloud enabled · changes queued with iCloud Drive"
    }
}
