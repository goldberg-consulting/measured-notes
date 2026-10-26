import Foundation
import AVFoundation

// Separate process keeps model inference and its memory lifetime outside the editor.
@MainActor enum MeetingDiarization {
    static func label(url: URL, segments: [TranscriptSegment]) async throws -> [TranscriptSegment] {
        guard let executable = Bundle.main.url(forAuxiliaryExecutable: "MeasuredDiarizer") else {
            throw MeetingMedia.error("The speaker-labeling helper is missing. Reinstall Measured Notes.")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let audio = directory.appendingPathComponent("audio.m4a")
        let output = directory.appendingPathComponent("speakers.json")
        guard let exporter = AVAssetExportSession(asset: AVURLAsset(url: url), presetName: AVAssetExportPresetAppleM4A) else {
            throw MeetingMedia.error("Could not read the recording’s audio.")
        }
        try await exporter.export(to: audio, as: .m4a)
        try Task.checkCancellation()
        let process = Process()
        process.executableURL = executable
        process.arguments = [audio.path, output.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        do {
            while process.isRunning { try await Task.sleep(for: .milliseconds(200)) }
            try Task.checkCancellation()
        } catch {
            if process.isRunning { process.terminate() }
            // Wait for the helper to release the temporary audio before deleting it.
            await Task.detached { process.waitUntilExit() }.value
            throw error
        }
        guard process.terminationStatus == 0 else {
            throw MeetingMedia.error("Speaker labeling failed. Check your connection for the first model download, then retry. Your recording and transcript are unchanged.")
        }
        let turns = try JSONDecoder().decode([SpeakerTurn].self, from: Data(contentsOf: output))
        return SpeakerAlignment.label(segments, turns: turns)
    }
}
