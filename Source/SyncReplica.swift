import Foundation
import CryptoKit

// A multi-value register per item. Device counters express causality without relying on clocks.
struct SyncVersion: Codable, Equatable {
    var revision: UUID = UUID()
    var clock: [String: Int]
    var payload: Data?
    func supersedes(_ other: SyncVersion) -> Bool {
        let keys = Set(clock.keys).union(other.clock.keys)
        return keys.allSatisfy { clock[$0, default: 0] >= other.clock[$0, default: 0] }
            && keys.contains { clock[$0, default: 0] > other.clock[$0, default: 0] }
    }
}
struct SyncReplica: Codable, Equatable {
    var format = 1
    var items: [String: [SyncVersion]] = [:]
    mutating func set(_ key: String, payload: Data?, device: String) {
        var clock: [String: Int] = [:]
        for version in items[key] ?? [] { for (id, count) in version.clock { clock[id] = max(clock[id, default: 0], count) } }
        clock[device, default: 0] += 1
        items[key] = [SyncVersion(clock: clock, payload: payload)]
    }
    mutating func merge(_ other: SyncReplica) throws {
        guard other.format == 1 else { throw SyncFailure.message("A newer app is needed to read this iCloud library.") }
        for (key, incoming) in other.items {
            var unique: [UUID: SyncVersion] = [:]
            for version in (items[key] ?? []) + incoming {
                guard !version.clock.isEmpty, version.clock.values.allSatisfy({ $0 > 0 }) else { throw SyncFailure.message("Invalid sync history. Local notes were kept.") }
                if let previous = unique[version.revision], previous != version { throw SyncFailure.message("Conflicting iCloud revision identifiers. Local notes were kept.") }
                unique[version.revision] = version
            }
            let all = Array(unique.values)
            items[key] = all.filter { version in !all.contains { $0.supersedes(version) } }.sorted { $0.revision.uuidString < $1.revision.uuidString }
        }
    }
    // Tombstones win the original identity during delete/edit conflicts. The edit survives as a copy.
    func projected() -> [String: Data] {
        var result: [String: Data] = [:]
        for key in items.keys.sorted() {
            let versions = (items[key] ?? []).sorted {
                if ($0.payload == nil) != ($1.payload == nil) { return $0.payload == nil }
                return $0.revision.uuidString < $1.revision.uuidString
            }
            var emitted = Set<Data>()
            for (index, version) in versions.enumerated() {
                guard let payload = version.payload, emitted.insert(payload).inserted else { continue }
                if index == 0 { result[key] = payload }
                else {
                    let conflictKey = key.components(separatedBy: ":")[0] + ":" + Self.conflictID(key: key, revision: version.revision).uuidString
                    // Once a conflict copy has been edited or deleted, its own register controls it.
                    if items[conflictKey] == nil { result[conflictKey] = payload }
                }
            }
        }
        return result
    }
    static func conflictID(key: String, revision: UUID) -> UUID {
        let bytes = Array(SHA256.hash(data: Data((key + revision.uuidString).utf8)).prefix(16))
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }
    static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value)
    }
}
enum SyncFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}

struct SyncNote: Codable {
    var note: Note
    var blobs: [String: String] // image/document/recording UUID -> content hash
}
struct SyncCheckpoint: Codable {
    var device = UUID().uuidString
    var account: Data?
    var replica = SyncReplica()
    var baseline: [String: Data] = [:]
}
