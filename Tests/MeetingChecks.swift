import Foundation

@main struct MeetingChecks {
    @MainActor static func main() async throws {
        var recording = MeetingRecording(fileName: "", locale: "en-US", microphone: true)
        recording.fileName = recording.id.uuidString + ".mp4"
        recording.transcript = [TranscriptSegment(seconds: 3661.5, speaker: "Eli", text: "Hello")]
        precondition(recording.transcriptMarkdown == "[01:01:01] Eli: Hello")
        precondition(TranscriptSegment(seconds: -1, text: "").timestamp == "00:00:00")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = directory.appendingPathComponent("notes.json")
        precondition(MeetingRecorder.fileURL(recording, storage: storage)!.lastPathComponent == recording.fileName)
        var audio = recording; audio.fileName = audio.id.uuidString + ".m4a"
        precondition(MeetingRecorder.fileURL(audio, storage: storage)?.pathExtension == "m4a")
        var invalid = recording; invalid.fileName = "../../private.mp4"
        precondition(MeetingRecorder.fileURL(invalid, storage: storage) == nil)
        let note = Note(recordings: [recording])
        let decoded = try JSONDecoder().decode(Note.self, from: JSONEncoder().encode(note))
        precondition(decoded == note && decoded.exportMarkdown.contains("Eli: Hello"))
        let source = directory.appendingPathComponent("source.mp4"), target = directory.appendingPathComponent("target.mp4")
        try Data("media".utf8).write(to: source)
        try Data("old".utf8).write(to: target)
        try MeetingMedia.copy(source: source, to: target)
        let copied = try Data(contentsOf: target)
        precondition(copied == Data("media".utf8))
        do { try MeetingMedia.copy(source: directory.appendingPathComponent("missing"), to: target); preconditionFailure("Expected missing file error") } catch {}
        let preserved = try Data(contentsOf: target)
        precondition(preserved == copied)
        if CommandLine.arguments.count > 1 {
            let result = try await MeetingTranscription.transcribe(url: URL(fileURLWithPath: CommandLine.arguments[1]), locale: Locale(identifier: "en-US"))
            precondition(!result.isEmpty)
            print("TRANSCRIPT:", result.map(\.text).joined(separator: " "))
        }
        print("PASS: transcript persistence, timestamp formatting, recording path guard, safe media export")
    }
}
